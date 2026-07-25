import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Mini-vignette image (PNG base64) pour l'aperçu destinataire hors téléchargement.
///
/// Redimensionnée côté encode (`targetWidth`) pour rester légère dans le message,
/// puis affichée floutée côté UI tant que le fichier plein n'est pas local.
class ImageThumbnailService {
  ImageThumbnailService._();

  /// Génère une vignette compacte destinée à [mediaThumb].
  static Future<String?> base64ForFile(
    String path, {
    int maxWidth = 120,
  }) async {
    try {
      if (!File(path).existsSync()) return null;
      final raw = await File(path).readAsBytes();
      return base64ForBytes(raw, maxWidth: maxWidth);
    } catch (e) {
      debugPrint('[ImageThumb] base64ForFile échec $path: $e');
      return null;
    }
  }

  /// Même vignette, à partir d'octets déjà en mémoire (pochette extraite des
  /// tags d'un fichier audio, par exemple).
  static Future<String?> base64ForBytes(
    Uint8List raw, {
    int maxWidth = 120,
  }) async {
    try {
      if (raw.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(
        raw,
        targetWidth: maxWidth,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final bd = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bd == null) return null;
        return base64Encode(bd.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('[ImageThumb] base64ForBytes échec: $e');
      return null;
    }
  }
}
