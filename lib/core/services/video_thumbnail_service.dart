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
///
/// Les succès sont cachés durablement. Les échecs ne le sont pas, pour permettre
/// un nouvel essai après téléchargement / fichier stabilisé (sinon le destinataire
/// resterait coincé sur le `mediaThumb` basse qualité).
class VideoThumbnailService {
  VideoThumbnailService._();

  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  /// Échecs récents : cooldown pour éviter un storm au scroll, sans bloquer
  /// définitivement un retry (ex. fichier pas encore stabilisé après download).
  static final Map<String, DateTime> _failedAt = {};
  static const Duration _failCooldown = Duration(seconds: 30);

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
    final cached = _cache[path];
    if (cached != null) return Future.value(cached);
    final failed = _failedAt[path];
    if (failed != null &&
        DateTime.now().difference(failed) < _failCooldown) {
      return Future.value(null);
    }
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
      // timeMs: 0 échoue parfois (frame noire / codec) → retry un peu plus loin.
      var bytes = await _thumbnailData(path, timeMs: 0);
      if (bytes == null || bytes.isEmpty) {
        bytes = await _thumbnailData(path, timeMs: 1000);
      }
      if (bytes == null || bytes.isEmpty) {
        debugPrint('[VideoThumb] vide $path');
        _failedAt[path] = DateTime.now();
        _inFlight.remove(path);
        return null;
      }
      _cache[path] = bytes;
      _failedAt.remove(path);
      _inFlight.remove(path);
      return bytes;
    } catch (e) {
      debugPrint('[VideoThumb] échec $path: $e');
      _failedAt[path] = DateTime.now();
      _inFlight.remove(path);
      return null;
    }
  }

  static Future<Uint8List?> _thumbnailData(String path, {required int timeMs}) {
    return VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 480,
      quality: 75,
      timeMs: timeMs,
    );
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
      var bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 45,
        timeMs: 0,
      );
      if (bytes == null || bytes.isEmpty) {
        bytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 320,
          quality: 45,
          timeMs: 1000,
        );
      }
      if (bytes == null || bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('[VideoThumb] base64ForFile échec $path: $e');
      return null;
    }
  }
}
