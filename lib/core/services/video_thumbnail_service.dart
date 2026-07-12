import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Génère (et met en cache **en mémoire**) une vignette vidéo pour l'afficher
/// dans les bulles et grilles médias.
///
/// Source du fichier, par ordre de préférence :
///  1. `pendingPath` (vidéo en cours d'envoi, déjà sur l'appareil) ;
///  2. `localPath` (vidéo locale téléchargée ou conservée après envoi).
///
/// Pas de téléchargement réseau : si aucun fichier local n'existe, retourne null.
/// Un échec est aussi caché (null) pour ne pas réessayer en boucle au scroll.
class VideoThumbnailService {
  VideoThumbnailService._();

  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static String? resolveLocalPath({
    String? pendingPath,
    String? localPath,
  }) =>
      _resolvePath(pendingPath, localPath);

  static bool hasLocalSource({
    String? pendingPath,
    String? localPath,
  }) =>
      resolveLocalPath(pendingPath: pendingPath, localPath: localPath) != null;

  static Future<Uint8List?> forMessage({
    String? pendingPath,
    String? localPath,
  }) {
    final path = _resolvePath(pendingPath, localPath);
    if (path == null) return Future.value(null);
    return forFile(path);
  }

  static Future<Uint8List?> forFile(String path) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);
    return _inFlight.putIfAbsent(path, () => _generate(path));
  }

  static String? _resolvePath(String? pendingPath, String? localPath) {
    if (pendingPath != null && File(pendingPath).existsSync()) {
      return pendingPath;
    }
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    return null;
  }

  static Future<Uint8List?> _generate(String path) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
        timeMs: 0,
      );
      return _remember(path, bytes);
    } catch (e) {
      debugPrint('[VideoThumb] échec $path: $e');
      return _remember(path, null);
    }
  }

  static Uint8List? _remember(String key, Uint8List? bytes) {
    _cache[key] = bytes;
    _inFlight.remove(key);
    return bytes;
  }

  /// Cache des bytes décodés d'une vignette base64 reçue, indexé par hashCode
  /// de la chaîne, pour éviter de re-décoder à chaque rebuild.
  static final Map<int, Uint8List> _decodedBase64 = {};

  /// Décode (et mémoïse) une vignette base64 reçue avec le message.
  static Uint8List? decodeBase64(String? base64Thumb) {
    if (base64Thumb == null || base64Thumb.isEmpty) return null;
    final key = base64Thumb.hashCode;
    final cached = _decodedBase64[key];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(base64Thumb);
      _decodedBase64[key] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('[VideoThumb] base64 invalide: $e');
      return null;
    }
  }

  /// Génère une mini-vignette compacte (JPEG base64) destinée à être transmise
  /// dans le message pour l'aperçu chez le destinataire. Plus petite/compressée
  /// que la vignette d'affichage local afin de limiter la taille du message.
  static Future<String?> base64ForFile(String path) async {
    try {
      if (!File(path).existsSync()) return null;
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 45,
        timeMs: 0,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('[VideoThumb] base64ForFile échec $path: $e');
      return null;
    }
  }
}
