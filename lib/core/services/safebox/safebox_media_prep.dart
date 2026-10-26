//  Préparation d'un fichier avant son dépôt au coffre-fort : compression dans
//  le format choisi (Original, HD, Compressé), et aperçu.
//
//  Conception : backend/docs/conception/coffre-fort.html, section 05. Les
//  formats eux-mêmes sont dans safebox_quality.dart (règles pures). Ici, ce
//  qui touche le téléphone :
//
//  - photo : JPEG (date et appareil de prise de vue gardés), par
//    flutter_image_compress ;
//  - vidéo : Android, pont Media3 des discussions, en H.265 quand c'est
//    permis (sinon H.264), débit constant ; iOS, `video_compress` en
//    1280×720 ou 640×480, toujours H.264 ;
//  - musique : Android, même pont, en AAC dans un .m4a ;
//  - documents : jamais compressés.
//
//  Règle commune avec les discussions : jamais bloquant. Un échec, ou un
//  résultat plus lourd que l'original, rend le fichier d'origine.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import 'package:video_compress/video_compress.dart';

import '../music_metadata_service.dart';
import '../pdf_thumbnail_service.dart';
import '../video_thumbnail_service.dart';
import 'safebox_models.dart';
import 'safebox_quality.dart';

const int kSafeboxPreviewSide = 480;

/// Musiques que le pont Media3 sait relire pour les ramener en AAC. Les
/// vocaux (AMR, Opus) sont déjà minuscules.
const Set<String> kSafeboxCompressibleAudio = {'wav', 'flac', 'mp3', 'm4a', 'aac', 'ogg'};

/// Fichier produit par la compression.
class SafeboxCompressed {
  const SafeboxCompressed({required this.path, required this.name});
  final String path;

  /// Nom à déposer : une photo HEIC compressée devient « .jpg ».
  final String name;
}

class SafeboxMediaPrep {
  SafeboxMediaPrep({required this.workDir});

  /// Dossier des copies de travail (compression, aperçus chiffrés).
  final Directory workDir;

  static const _video = MethodChannel('com.alanya237.alanya/video_transcode');
  static int _seq = 0;

  /// La compression a-t-elle un sens pour ce fichier, sur ce téléphone ?
  static bool canCompress(SafeboxFamily family, String name) {
    if (kIsWeb) return false;
    final ext = safeboxExtensionOf(name);
    switch (family) {
      case SafeboxFamily.photos:
        return ext != 'gif'; // l'animation se perdrait
      case SafeboxFamily.videos:
        return Platform.isAndroid || Platform.isIOS;
      case SafeboxFamily.audios:
        return Platform.isAndroid && kSafeboxCompressibleAudio.contains(ext);
      case SafeboxFamily.documents:
        return false;
    }
  }

  /// Ce qu'on sait du fichier pour décider et estimer ; le poids seul si le
  /// reste est illisible.
  Future<SafeboxMediaFacts> facts(String path, SafeboxFamily family, int size) async {
    try {
      switch (family) {
        case SafeboxFamily.photos:
          final d = await _dimensions(path);
          return SafeboxMediaFacts(sizeBytes: size, width: d?.width, height: d?.height);
        case SafeboxFamily.videos:
        case SafeboxFamily.audios:
          if (Platform.isAndroid) {
            final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
            if (raw == null) return SafeboxMediaFacts(sizeBytes: size);
            return SafeboxMediaFacts(
              sizeBytes: size,
              width: (raw['width'] as num?)?.toInt(),
              height: (raw['height'] as num?)?.toInt(),
              durationMs: (raw['durationMs'] as num?)?.toDouble(),
              frameRate: (raw['frameRate'] as num?)?.toDouble(),
              hevcSource: '${raw['videoMime']}'.toLowerCase() == 'video/hevc',
            );
          }
          final info = await VideoCompress.getMediaInfo(path);
          return SafeboxMediaFacts(sizeBytes: size, width: info.width, height: info.height, durationMs: info.duration);
        case SafeboxFamily.documents:
          return SafeboxMediaFacts(sizeBytes: size);
      }
    } catch (e) {
      debugPrint('[Coffre] fichier illisible pour l\'estimation : $e');
      return SafeboxMediaFacts(sizeBytes: size);
    }
  }

  /// Poids estimé dans le format [quality], pour la feuille de choix. Égal à
  /// l'original quand il n'y a rien à gagner (fichier déjà léger).
  static int estimateFrom(SafeboxMediaFacts f, SafeboxFamily family, String name, SafeboxQuality quality,
      {required bool hevc}) {
    if (quality == SafeboxQuality.original || !canCompress(family, name)) return f.sizeBytes;
    return switch (family) {
      SafeboxFamily.photos => safeboxEstimatePhotoBytes(f, quality),
      SafeboxFamily.videos => safeboxEstimateVideoBytes(f, quality, hevc: hevc),
      SafeboxFamily.audios => safeboxEstimateAudioBytes(f, quality),
      SafeboxFamily.documents => f.sizeBytes,
    };
  }

  /// Compresse dans le format [quality], ou rend null pour garder l'original
  /// (Original, rien à gagner, ou échec). [hevc] : la vidéo peut partir en H.265.
  Future<SafeboxCompressed?> compress(String path, String name, SafeboxFamily family, SafeboxQuality quality,
      {required bool hevc}) async {
    if (quality == SafeboxQuality.original || !canCompress(family, name)) return null;
    await workDir.create(recursive: true);
    try {
      final taille = await File(path).length();
      final f = await facts(path, family, taille);
      SafeboxCompressed? c;
      switch (family) {
        case SafeboxFamily.photos:
          c = await _photo(path, name, safeboxPhotoProfile(quality)!);
        case SafeboxFamily.videos:
          final profil = safeboxVideoProfile(quality, hevc: hevc)!;
          if (!safeboxShouldTranscodeVideo(f, profil)) {
            debugPrint('[Coffre] vidéo déjà légère, gardée telle quelle : $name');
            return null;
          }
          c = Platform.isAndroid ? await _videoTranscode(path, name, profil) : await _videoIos(path, name, quality);
        case SafeboxFamily.audios:
          if (safeboxEstimateAudioBytes(f, quality) >= taille) return null;
          c = await _audio(path, name, safeboxAudioBitrate(quality)!);
        case SafeboxFamily.documents:
          return null;
      }
      if (c == null) return null;
      final apres = await File(c.path).length();
      if (apres >= taille) {
        debugPrint('[Coffre] compression sans gain ($apres ≥ $taille octets), original gardé : $name');
        await File(c.path).delete();
        return null;
      }
      debugPrint('[Coffre] ${quality.name} : $taille → $apres octets ($name)');
      return c;
    } catch (e) {
      debugPrint('[Coffre] compression abandonnée, original gardé : $e');
      return null;
    }
  }

  Future<({int width, int height})?> _dimensions(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final d = await ui.ImageDescriptor.encoded(buffer);
      final r = (width: d.width, height: d.height);
      d.dispose();
      return r;
    } finally {
      buffer.dispose();
    }
  }

  Future<SafeboxCompressed?> _photo(
      String path, String name, ({int longSide, int jpegQuality, double bytesPerPixel}) profil) async {
    final dims = await _dimensions(path);
    if (dims == null) return null;
    final long = math.max(dims.width, dims.height);
    final short = math.min(dims.width, dims.height);
    // Le moteur réduit jusqu'à ce qu'un côté touche la borne : on lui donne le
    // côté court visé pour les deux, et le grand côté tombe sur la cible.
    final cible = long <= profil.longSide ? short : (short * profil.longSide / long).round();
    final base = p.basenameWithoutExtension(name);
    final sortie = p.join(workDir.path, 'photo_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.jpg');
    final r = await FlutterImageCompress.compressAndGetFile(
      path,
      sortie,
      minWidth: cible,
      minHeight: cible,
      quality: profil.jpegQuality,
      format: CompressFormat.jpeg,
      // Date et appareil de prise de vue gardés : c'est un souvenir qu'on archive.
      keepExif: true,
    );
    return r == null ? null : SafeboxCompressed(path: r.path, name: '$base.jpg');
  }

  Future<SafeboxCompressed?> _videoTranscode(String path, String name, SafeboxVideoProfile profil) async {
    final id = 'coffre_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final sortie = p.join(workDir.path, '$id.mp4');
    final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('transcode', {
      'id': id,
      'input': path,
      'output': sortie,
      'videoMime': profil.mime,
      'videoBitrate': profil.videoBitrate,
      'audioBitrate': kSafeboxVideoAudioBitrate,
      'maxShortSide': profil.shortSide,
      'maxFrameRate': kSafeboxVideoMaxFrameRate,
      'iFrameIntervalSeconds': kSafeboxVideoIFrameIntervalSeconds,
    });
    if (raw == null) return null;
    final produit = (raw['path'] as String?) ?? sortie;
    return SafeboxCompressed(path: produit, name: '${p.basenameWithoutExtension(name)}.mp4');
  }

  /// iOS : `video_compress`, toujours en H.264, recopié dans le dossier de
  /// travail (le greffon écrit dans son propre cache).
  Future<SafeboxCompressed?> _videoIos(String path, String name, SafeboxQuality quality) async {
    final info = await VideoCompress.compressVideo(
      path,
      quality: quality == SafeboxQuality.hd ? VideoQuality.Res1280x720Quality : VideoQuality.Res640x480Quality,
      includeAudio: true,
    );
    final produit = info?.path;
    if (produit == null) return null;
    final sortie = p.join(workDir.path, 'video_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.mp4');
    await File(produit).rename(sortie).catchError((_) async {
      final copie = await File(produit).copy(sortie);
      await File(produit).delete();
      return copie;
    });
    return SafeboxCompressed(path: sortie, name: '${p.basenameWithoutExtension(name)}.mp4');
  }

  /// Musique → AAC au débit du format, dans un .m4a, par le pont Media3
  /// (Android ; il déduit les pistes : un son seul passe).
  Future<SafeboxCompressed?> _audio(String path, String name, int bitrate) async {
    final id = 'coffre_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final sortie = p.join(workDir.path, '$id.m4a');
    final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('transcode', {
      'id': id,
      'input': path,
      'output': sortie,
      'audioBitrate': bitrate,
    });
    if (raw == null) return null;
    return SafeboxCompressed(path: (raw['path'] as String?) ?? sortie, name: '${p.basenameWithoutExtension(name)}.m4a');
  }

  /// Aperçu en clair (JPEG ou PNG d'environ 480 px), ou null. Chiffré ensuite
  /// avec la clé du fichier.
  Future<Uint8List?> preview(String path, SafeboxFamily family, String name) async {
    try {
      switch (family) {
        case SafeboxFamily.photos:
          return await FlutterImageCompress.compressWithFile(
            path,
            minWidth: kSafeboxPreviewSide,
            minHeight: kSafeboxPreviewSide,
            quality: 70,
            format: CompressFormat.jpeg,
          );
        case SafeboxFamily.videos:
          return await VideoThumbnailService.forFile(path);
        case SafeboxFamily.audios:
          final b64 = await MusicMetadataService.coverBase64(path);
          return b64 == null ? null : base64Decode(b64);
        case SafeboxFamily.documents:
          if (safeboxExtensionOf(name) != 'pdf') return null;
          final b64 = await PdfThumbnailService.base64ForFile(path, maxWidth: kSafeboxPreviewSide.toDouble());
          return b64 == null ? null : base64Decode(b64);
      }
    } catch (e) {
      debugPrint('[Coffre] aperçu impossible : $e');
      return null;
    }
  }

  /// Détails affichés par la carte d'un fichier partagé (durée et définition
  /// d'une vidéo, pages d'un PDF, titre, artiste et durée d'un audio), lus sur
  /// le fichier qui part — la copie compressée s'il y en a une. Null si rien
  /// n'est lisible : ils décorent, ils ne bloquent jamais un envoi.
  Future<SafeboxMeta?> meta(String path, SafeboxFamily family, String name) async {
    try {
      switch (family) {
        case SafeboxFamily.videos:
          if (Platform.isAndroid) {
            final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
            if (raw == null) return null;
            final rotation = (raw['rotation'] as num?)?.toInt() ?? 0;
            final w = (raw['width'] as num?)?.toInt();
            final h = (raw['height'] as num?)?.toInt();
            final tourne = rotation == 90 || rotation == 270;
            final mime = '${raw['videoMime']}'.toLowerCase();
            return SafeboxMeta.fromJson({
              'durationMs': raw['durationMs'],
              'width': tourne ? h : w,
              'height': tourne ? w : h,
              // Pour prévenir avant d'envoyer du H.265 à qui ne le lit pas.
              if (mime == 'video/hevc') 'codec': 'hevc' else if (mime == 'video/avc') 'codec': 'avc',
            });
          }
          final info = await VideoCompress.getMediaInfo(path);
          return SafeboxMeta.fromJson({
            'durationMs': info.duration?.round(),
            'width': info.width,
            'height': info.height,
          });
        case SafeboxFamily.audios:
          final tags = readMetadata(File(path), getImage: false);
          var ms = tags.duration?.inMilliseconds;
          if (ms == null || ms <= 0) {
            final s = await MusicMetadataService.durationSeconds(path);
            ms = s == null ? null : s * 1000;
          }
          return SafeboxMeta.fromJson({'durationMs': ms, 'title': tags.title, 'artist': tags.artist});
        case SafeboxFamily.documents:
          if (safeboxExtensionOf(name) != 'pdf') return null;
          final doc = await PdfDocument.openFile(path);
          try {
            return SafeboxMeta.fromJson({'pages': doc.pagesCount});
          } finally {
            await doc.close();
          }
        case SafeboxFamily.photos:
          return null;
      }
    } catch (e) {
      debugPrint('[Coffre] détails illisibles : $e');
      return null;
    }
  }
}
