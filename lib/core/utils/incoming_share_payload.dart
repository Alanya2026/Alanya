import 'dart:io';

import 'package:mime/mime.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'media_album.dart';

/// Contenu reçu depuis une autre app (share intent OS).
class IncomingSharePayload {
  const IncomingSharePayload({
    this.text,
    this.mediaItems = const [],
  });

  final String? text;
  final List<IncomingShareMediaItem> mediaItems;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) && mediaItems.isEmpty;

  bool get hasMedia => mediaItems.isNotEmpty;

  bool get isTextOnly =>
      mediaItems.isEmpty && text != null && text!.trim().isNotEmpty;

  /// True si les médias peuvent partir en album (≥ 2 photos/vidéos).
  bool get canSendAsAlbum {
    if (mediaItems.length < 2) return false;
    return mediaItems.every((m) => m.type == 1 || m.type == 2);
  }

  String previewLabel() {
    if (isTextOnly) {
      final t = text!.trim();
      return t.length > 120 ? '${t.substring(0, 120)}…' : t;
    }
    if (canSendAsAlbum) {
      return albumPreviewLabel(
        photoCount: mediaItems.where((m) => m.type == 1).length,
        videoCount: mediaItems.where((m) => m.type == 2).length,
      );
    }
    if (mediaItems.length == 1) {
      final m = mediaItems.first;
      return m.name ?? m.file.path.split('/').last;
    }
    return '${mediaItems.length} fichiers';
  }
}

class IncomingShareMediaItem {
  const IncomingShareMediaItem({
    required this.file,
    required this.type,
    this.name,
    this.duration,
  });

  final File file;
  final int type;
  final String? name;
  final int? duration;
}

/// Convertit les fichiers du plugin en payload métier Talky.
IncomingSharePayload incomingSharePayloadFromSharedMedia(
  List<SharedMediaFile> files,
) {
  if (files.isEmpty) return const IncomingSharePayload();

  String? text;
  final items = <IncomingShareMediaItem>[];

  for (final file in files) {
    switch (file.type) {
      case SharedMediaType.text:
      case SharedMediaType.url:
        final value = file.path.trim();
        if (value.isNotEmpty) text = value;
        break;
      case SharedMediaType.image:
        items.add(_mediaItem(file, type: 1));
        break;
      case SharedMediaType.video:
        items.add(_mediaItem(
          file,
          type: 2,
          duration: file.duration != null ? file.duration! ~/ 1000 : null,
        ));
        break;
      case SharedMediaType.file:
        items.add(_mediaItem(file, type: _fileMessageType(file)));
        break;
    }
  }

  return IncomingSharePayload(text: text, mediaItems: items);
}

IncomingShareMediaItem _mediaItem(
  SharedMediaFile file, {
  required int type,
  int? duration,
}) {
  final path = file.path;
  final name = _basename(path);
  return IncomingShareMediaItem(
    file: File(path),
    type: type,
    name: name,
    duration: duration,
  );
}

int _fileMessageType(SharedMediaFile file) {
  final mime = file.mimeType ?? lookupMimeType(file.path) ?? '';
  if (mime.startsWith('audio/')) return 3;
  if (mime.startsWith('image/')) return 1;
  if (mime.startsWith('video/')) return 2;
  return 4;
}

String? _basename(String path) {
  final parts = path.split('/');
  if (parts.isEmpty) return null;
  final name = parts.last.trim();
  return name.isEmpty ? null : name;
}
