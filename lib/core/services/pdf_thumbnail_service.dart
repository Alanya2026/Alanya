import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import 'media_cache_service.dart';
import 'media_download_preferences.dart';

/// Génère (et met en cache **en mémoire**) une vignette de la première page
/// d'un PDF, pour l'afficher dans la bulle.
///
/// Source du fichier, par ordre de préférence :
///  1. `localPath` / fichier déjà sur l'appareil → rendu net ;
///  2. `thumbBase64` (`mediaThumb`) → aperçu immédiat sans télécharger le PDF ;
///  3. sinon `url` → téléchargé **seulement** si le téléchargement automatique
///     est activé (sinon on laisse l'utilisateur télécharger via la bulle).
///
/// Un échec est aussi caché (null) pour ne pas réessayer en boucle au scroll.
class PdfThumbnailService {
  PdfThumbnailService._();

  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static final MediaCacheService _media = MediaCacheService();

  /// Mini-vignette PNG base64 destinée à [mediaThumb] (payload message léger).
  static Future<String?> base64ForFile(
    String path, {
    double maxWidth = 120,
  }) async {
    try {
      if (!File(path).existsSync()) return null;
      final bytes = await _renderPage(path, maxWidth: maxWidth);
      if (bytes == null || bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('[PdfThumb] base64ForFile échec $path: $e');
      return null;
    }
  }

  static Uint8List? decodeBase64(String? base64Thumb) {
    if (base64Thumb == null || base64Thumb.isEmpty) return null;
    try {
      return base64Decode(base64Thumb);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> forMessage({
    String? localPath,
    String? url,
    String? thumbBase64,
  }) {
    final key = localPath ?? url ?? thumbBase64;
    if (key == null) return Future.value(null);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _inFlight.putIfAbsent(
      key,
      () => _generate(key, localPath, url, thumbBase64),
    );
  }

  static Future<Uint8List?> _generate(
    String key,
    String? localPath,
    String? url,
    String? thumbBase64,
  ) async {
    try {
      String? path =
          (localPath != null && File(localPath).existsSync()) ? localPath : null;
      if (path != null) {
        final rendered = await _renderPage(path, maxWidth: 480);
        if (rendered != null) return _remember(key, rendered);
      }

      final fromThumb = decodeBase64(thumbBase64);
      if (fromThumb != null && fromThumb.isNotEmpty) {
        return _remember(key, fromThumb);
      }

      if (path == null &&
          url != null &&
          MediaDownloadPreferences.isAutoDownloadEnabled) {
        path = await _media.ensureCached(url);
        if (path != null) {
          final rendered = await _renderPage(path, maxWidth: 480);
          if (rendered != null) return _remember(key, rendered);
        }
      }

      return _remember(key, null);
    } catch (e) {
      debugPrint('[PdfThumb] échec $key: $e');
      return _remember(key, null);
    }
  }

  static Future<Uint8List?> _renderPage(
    String path, {
    required double maxWidth,
  }) async {
    final document = await PdfDocument.openFile(path);
    try {
      final page = await document.getPage(1);
      try {
        final scale = maxWidth / page.width;
        final image = await page.render(
          width: maxWidth,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        return image?.bytes;
      } finally {
        await page.close();
      }
    } finally {
      await document.close();
    }
  }

  static Uint8List? _remember(String key, Uint8List? bytes) {
    _cache[key] = bytes;
    _inFlight.remove(key);
    return bytes;
  }
}
