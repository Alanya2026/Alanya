import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// L'image à retoucher : des octets déjà lus (galerie, appareil photo) ou un
/// fichier. Dans les deux cas elle n'est **jamais** décodée en pleine
/// résolution : voir [EditorImageLoader].
class MediaEditorSource {
  /// Image déjà en mémoire (PNG, JPEG, WebP…).
  const MediaEditorSource.bytes(Uint8List this._bytes) : _path = null;

  /// Fichier sur le disque ; sa taille est vérifiée avant de le lire.
  const MediaEditorSource.file(String this._path) : _bytes = null;

  final Uint8List? _bytes;
  final String? _path;

  /// Lit les octets de la source.
  Future<Uint8List> readBytes() async {
    final b = _bytes;
    if (b != null) return b;
    final f = File(_path!);
    if (await f.length() > EditorImageLoader.maxInputBytes) {
      throw const MediaEditorLoadException(MediaEditorLoadIssue.tooBig);
    }
    return f.readAsBytes();
  }
}

enum MediaEditorLoadIssue {
  /// Illisible, vide ou format que ce téléphone ne décode pas.
  unreadable,

  /// Plus de 20 Mo ou de 50 mégapixels.
  tooBig,

  /// Image animée (refusée pour un sticker).
  animated,
}

class MediaEditorLoadException implements Exception {
  const MediaEditorLoadException(this.issue);
  final MediaEditorLoadIssue issue;

  @override
  String toString() => 'MediaEditorLoadException(${issue.name})';
}

/// Décodage **borné** de l'image de travail : au plus [workBound] pixels sur le
/// grand côté (le décodeur réduit à la volée, la pleine résolution n'existe
/// jamais en mémoire). Sur un téléphone d'entrée de gamme, c'est le seul
/// bitmap de grande taille de l'éditeur.
abstract final class EditorImageLoader {
  static const int maxInputBytes = 20 * 1024 * 1024;
  static const int maxInputPixels = 50 * 1000 * 1000;
  static const int workBound = 1024;

  /// Décode [bytes]. L'appelant possède l'image rendue et la libère.
  static Future<ui.Image> decode(
    Uint8List bytes, {
    bool rejectAnimated = false,
    int bound = workBound,
  }) async {
    if (bytes.isEmpty) {
      throw const MediaEditorLoadException(MediaEditorLoadIssue.unreadable);
    }
    if (bytes.length > maxInputBytes) {
      throw const MediaEditorLoadException(MediaEditorLoadIssue.tooBig);
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      try {
        buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
      } catch (_) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.unreadable);
      }
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.unreadable);
      }
      if (w * h > maxInputPixels) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.tooBig);
      }
      final longest = w > h ? w : h;
      int? targetW;
      int? targetH;
      if (longest > bound) {
        final k = bound / longest;
        targetW = (w * k).round().clamp(1, bound);
        targetH = (h * k).round().clamp(1, bound);
      }
      try {
        codec = await descriptor.instantiateCodec(
          targetWidth: targetW,
          targetHeight: targetH,
        );
      } catch (_) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.unreadable);
      }
      if (rejectAnimated && codec.frameCount > 1) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.animated);
      }
      try {
        return (await codec.getNextFrame()).image;
      } catch (_) {
        throw const MediaEditorLoadException(MediaEditorLoadIssue.unreadable);
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
