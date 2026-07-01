import 'dart:io';

import '../db/app_database.dart';
import 'media_album.dart';

class ForwardResult {
  const ForwardResult({
    required this.succeeded,
    required this.failed,
    this.errors = const [],
  });

  final int succeeded;
  final int failed;
  final List<String> errors;

  bool get hasSuccess => succeeded > 0;
}

/// Indique si un message peut être transféré.
bool canForwardMessage(LocalMessage message) {
  if (message.isDeleted) return false;
  // Un média à vue unique ne peut jamais être transféré.
  if (message.isViewOnce) return false;

  if (message.type == 0) {
    return message.content != null && message.content!.trim().isNotEmpty;
  }

  final url = message.mediaUrl;
  if (url != null && url.isNotEmpty) return true;

  return _localMediaPath(message) != null;
}

/// Indique si un album complet peut être transféré.
bool canForwardAlbum(List<LocalMessage> items) {
  if (items.isEmpty) return false;
  return items.every(canForwardMessage);
}

String? _localMediaPath(LocalMessage message) {
  for (final path in [message.pendingUploadPath, message.localMediaPath]) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
  }
  return null;
}

/// Légende effective lors d'un transfert (caption utilisateur prioritaire).
String? resolveForwardCaption(LocalMessage source, String? userCaption) {
  final trimmed = userCaption?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  if (source.type == 0) return null;
  if (isAlbumMarkerContent(source.content)) return null;
  final original = source.content?.trim();
  if (original != null && original.isNotEmpty) return original;
  return null;
}

String mediaLabelForType(int type, {String? mediaName}) {
  switch (type) {
    case 1:
      return 'Photo';
    case 2:
      return 'Vidéo';
    case 3:
      return 'Audio';
    case 4:
      return mediaName?.isNotEmpty == true ? mediaName! : 'Fichier';
    default:
      return 'Média';
  }
}

String previewTextForForward(LocalMessage message) {
  if (message.isDeleted) return 'Message supprimé';
  if (message.type == 0) {
    return message.content?.trim().isNotEmpty == true
        ? message.content!.trim()
        : 'Message vide';
  }
  if (isAlbumMarkerContent(message.content)) {
    final marker = parseAlbumMarker(message.content);
    if (marker != null) {
      return 'Album · ${marker.total} médias';
    }
  }
  final caption = message.content?.trim();
  if (caption != null && caption.isNotEmpty) {
    return '${mediaLabelForType(message.type, mediaName: message.mediaName)} · $caption';
  }
  return mediaLabelForType(message.type, mediaName: message.mediaName);
}

String previewTextForForwardAlbum(List<LocalMessage> items) {
  if (items.isEmpty) return 'Album vide';
  return previewLabelForAlbumMessages(items);
}

File? localMediaFileForForward(LocalMessage message) {
  final path = _localMediaPath(message);
  return path != null ? File(path) : null;
}
