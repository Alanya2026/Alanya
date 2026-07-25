import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'image_thumbnail_service.dart';

/// Métadonnées d'un fichier musical exploitées à l'envoi : pochette et durée.
///
/// Volontairement limité à ce que le schéma sait transporter. La pochette part
/// dans la colonne `mediaThumb` existante, la durée dans `mediaDuration` —
/// aucune migration. Titre et artiste ne sont pas remontés : aucune colonne ne
/// pourrait les porter jusqu'au destinataire.
class MusicMetadataService {
  MusicMetadataService._();

  /// Pochette en base64, redimensionnée comme les vignettes d'image.
  /// `null` si le morceau n'en a pas ou si le parsing échoue.
  static Future<String?> coverBase64(String? path) async {
    final picture = _readPicture(path);
    if (picture == null) return null;
    return ImageThumbnailService.base64ForBytes(picture, maxWidth: 160);
  }

  /// Durée en secondes. Lue d'abord dans les tags (gratuit, on parse déjà le
  /// fichier), sinon en décodant le flux avec just_audio.
  static Future<int?> durationSeconds(String? path) async {
    if (path == null || !File(path).existsSync()) return null;

    try {
      final tagged = readMetadata(File(path), getImage: false).duration;
      if (tagged != null && tagged.inSeconds > 0) return tagged.inSeconds;
    } catch (e) {
      debugPrint('[MusicMetadata] durée tag illisible $path: $e');
    }

    final player = AudioPlayer();
    try {
      final decoded = await player.setFilePath(path);
      final seconds = decoded?.inSeconds;
      return (seconds != null && seconds > 0) ? seconds : null;
    } catch (e) {
      debugPrint('[MusicMetadata] durée non lue $path: $e');
      return null;
    } finally {
      await player.dispose();
    }
  }

  static Uint8List? _readPicture(String? path) {
    if (path == null || !File(path).existsSync()) return null;
    try {
      final pictures = readMetadata(File(path), getImage: true).pictures;
      if (pictures.isEmpty) return null;
      // Préférer la pochette avant, sinon la première image trouvée.
      final front = pictures.firstWhere(
        (p) => p.pictureType == PictureType.coverFront,
        orElse: () => pictures.first,
      );
      return front.bytes.isEmpty ? null : front.bytes;
    } catch (e) {
      debugPrint('[MusicMetadata] pochette illisible $path: $e');
      return null;
    }
  }
}
