import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'media_cache_service.dart';

/// Génère (et met en cache **en mémoire**) une vignette de la première page
/// d'un PDF, pour l'afficher dans la bulle.
///
/// Source du fichier, par ordre de préférence :
///  1. `localPath` (le PDF que J'AI envoyé, déjà sur l'appareil) → immédiat ;
///  2. sinon `url` → téléchargé via le cache média (qui gère le cert auto-signé
///     du serveur), puis rasterisé. Les PDF < 5 Mo sont déjà préfetchés par
///     l'app, donc c'est souvent instantané.
///
/// Un échec est aussi caché (null) pour ne pas réessayer en boucle au scroll.
class PdfThumbnailService {
  PdfThumbnailService._();

  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static final MediaCacheService _media = MediaCacheService();

  static Future<Uint8List?> forMessage({String? localPath, String? url}) {
    final key = localPath ?? url;
    if (key == null) return Future.value(null);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _inFlight.putIfAbsent(key, () => _generate(key, localPath, url));
  }

  static Future<Uint8List?> _generate(String key, String? localPath, String? url) async {
    try {
      String? path = (localPath != null && File(localPath).existsSync()) ? localPath : null;
      path ??= (url != null) ? await _media.ensureCached(url) : null;
      if (path == null) return _remember(key, null);

      final document = await PdfDocument.openFile(path);
      final page = await document.getPage(1);

      // Rendu à ~480 px de large (net sur écran), hauteur proportionnelle.
      const targetW = 480.0;
      final scale = targetW / page.width;
      final image = await page.render(
        width: targetW,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      await page.close();
      await document.close();
      return _remember(key, image?.bytes);
    } catch (e) {
      debugPrint('[PdfThumb] échec $key: $e');
      return _remember(key, null);
    }
  }

  static Uint8List? _remember(String key, Uint8List? bytes) {
    _cache[key] = bytes;
    _inFlight.remove(key);
    return bytes;
  }
}
