//  Préparation d'un fichier avant son dépôt au coffre-fort : compression au
//  choix de l'inscrit, et aperçu.
//
//  Conception : backend/docs/conception/coffre-fort.html, section 04. Depuis le
//  19/10/2026, la compression du coffre est celle des discussions (décision de
//  l'utilisateur : la version « plus douce » ne réduisait pas les fichiers
//  déjà légers, ceux reçus par WhatsApp par exemple) :
//
//  - photo : grand côté 1 600 px, qualité 75 comme les discussions, mais en
//    JPEG et non en WebP : date et appareil de prise de vue gardés, et une
//    photo exportée du coffre s'ouvre partout ;
//  - vidéo : la règle des discussions (`shouldCompressVideo`) : 720p, H.264 à
//    2 Mbit/s, son AAC 64 kbit/s, 30 images/s ; une vidéo déjà en 720p et
//    sous la cible n'est pas recompressée. Android : pont Media3 des
//    discussions ; iOS : `video_compress` en 1280×720. Toujours H.264, jamais
//    HEVC : un fichier transmis à un autre inscrit doit se lire sur son
//    téléphone, quel qu'il soit ;
//  - audio : seulement WAV et FLAC, ramenés en AAC 128 kbit/s (.m4a), sur
//    Android par le même pont (il déduit les pistes du fichier : un son seul
//    passe). Recompresser un MP3 ou un M4A dégraderait le son pour presque
//    rien ;
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

import '../image_upload_compressor.dart'
    show kCompressedImageLongSide, kCompressedImageQuality;
import '../music_metadata_service.dart';
import '../pdf_thumbnail_service.dart';
import '../video_upload_compressor.dart'
    show
        VideoCodec,
        VideoFacts,
        estimateUploadBytesFor,
        kAvcVideoBitrate,
        kCompressedAudioBitrate,
        kCompressedVideoShortSide,
        shouldCompressVideo,
        targetBitsPerSecond;
import '../video_thumbnail_service.dart';
import 'safebox_models.dart';

const int kSafeboxPhotoLongSide = kCompressedImageLongSide; // 1 600 px, comme les discussions
const int kSafeboxPhotoQuality = kCompressedImageQuality; // 75
const int kSafeboxVideoShortSide = kCompressedVideoShortSide; // 720p
const int kSafeboxVideoBitrate = kAvcVideoBitrate; // 2 Mbit/s, H.264
const int kSafeboxVideoAudioBitrate = kCompressedAudioBitrate; // 64 kbit/s
/// Musique WAV ou FLAC ramenée en AAC : les discussions n'en compressent pas,
/// 128 kbit/s garde un son fidèle.
const int kSafeboxAudioBitrate = 128000;
const int kSafeboxPreviewSide = 480;

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
  static bool canCompress(SafeboxRoot family, String name) {
    if (kIsWeb) return false;
    final ext = safeboxExtensionOf(name);
    switch (family) {
      case SafeboxRoot.albums:
        return ext != 'gif'; // l'animation se perdrait
      case SafeboxRoot.videos:
        return Platform.isAndroid || Platform.isIOS;
      case SafeboxRoot.audios:
        return Platform.isAndroid && (ext == 'wav' || ext == 'flac');
      case SafeboxRoot.documents:
        return false;
    }
  }

  /// Durée en millisecondes, ou null.
  Future<double?> _duree(String path) async {
    try {
      if (Platform.isAndroid) {
        final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
        return (raw?['durationMs'] as num?)?.toDouble();
      }
      return (await VideoCompress.getMediaInfo(path)).duration;
    } catch (e) {
      debugPrint('[Coffre] durée illisible : $e');
      return null;
    }
  }

  /// Poids estimé après compression, pour la feuille de choix.
  /// Poids estimé après compression, pour la feuille de choix. Égal à
  /// l'original quand il n'y a rien à gagner (fichier déjà léger) : la feuille
  /// le dit au lieu de proposer une compression vaine.
  Future<int> estimate(String path, SafeboxRoot family, int size) async {
    switch (family) {
      case SafeboxRoot.albums:
        try {
          final d = await _dimensions(path);
          if (d == null || d.width <= 0 || d.height <= 0) return (size * 0.3).round();
          final long = math.max(d.width, d.height);
          final echelle = long > kSafeboxPhotoLongSide ? kSafeboxPhotoLongSide / long : 1.0;
          final pixels = d.width * d.height * echelle * echelle;
          return math.min(size, (pixels * _octetsParPixelJpeg).round());
        } catch (_) {
          return (size * 0.3).round();
        }
      case SafeboxRoot.videos:
        final faits = await _faitsVideo(path);
        if (faits == null) return (size * 0.5).round();
        // La règle et le débit des discussions, en H.264.
        return estimateUploadBytesFor(path, faits, maxOutputBitsPerSecond: targetBitsPerSecond(VideoCodec.avc));
      case SafeboxRoot.audios:
        final ms = await _duree(path);
        if (ms != null && ms > 0) return math.min(size, (ms / 1000 * kSafeboxAudioBitrate / 8).round());
        return (size * 0.3).round();
      case SafeboxRoot.documents:
        return size;
    }
  }

  /// Poids moyen d'un pixel en JPEG qualité 75 (photo d'appareil) : une photo
  /// de 1 600 × 1 200 pèse environ 300 Ko.
  static const double _octetsParPixelJpeg = 0.16;

  /// Ce qu'on sait d'une vidéo, pour lui appliquer la règle des discussions.
  Future<VideoFacts?> _faitsVideo(String path) async {
    try {
      if (Platform.isAndroid) {
        final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
        if (raw == null) return null;
        return VideoFacts(
          sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? await File(path).length(),
          width: (raw['width'] as num?)?.toInt(),
          height: (raw['height'] as num?)?.toInt(),
          durationMs: (raw['durationMs'] as num?)?.toDouble(),
          codec: VideoCodec.fromMime(raw['videoMime'] as String?),
          frameRate: (raw['frameRate'] as num?)?.toDouble(),
        );
      }
      final info = await VideoCompress.getMediaInfo(path);
      return VideoFacts(
        sizeBytes: info.filesize ?? await File(path).length(),
        width: info.width,
        height: info.height,
        durationMs: info.duration,
      );
    } catch (e) {
      debugPrint('[Coffre] vidéo illisible : $e');
      return null;
    }
  }

  /// Compresse, ou rend null pour garder l'original.
  Future<SafeboxCompressed?> compress(String path, String name, SafeboxRoot family) async {
    if (!canCompress(family, name)) return null;
    await workDir.create(recursive: true);
    try {
      if (family == SafeboxRoot.videos) {
        // Comme les discussions : une vidéo déjà en 720p et sous la cible ne
        // gagnerait rien, on ne la convertit pas (temps et batterie épargnés).
        final faits = await _faitsVideo(path);
        if (faits != null && !shouldCompressVideo(path, faits)) {
          debugPrint('[Coffre] vidéo déjà légère, gardée telle quelle : $name');
          return null;
        }
      }
      final c = switch (family) {
        SafeboxRoot.albums => await _photo(path, name),
        SafeboxRoot.videos => Platform.isAndroid ? await _videoTranscode(path, name) : await _videoIos(path, name),
        SafeboxRoot.audios => await _audio(path, name),
        SafeboxRoot.documents => null,
      };
      if (c == null) return null;
      final avant = await File(path).length();
      final apres = await File(c.path).length();
      if (apres >= avant) {
        debugPrint('[Coffre] compression sans gain ($apres ≥ $avant octets), original gardé : $name');
        await File(c.path).delete();
        return null;
      }
      debugPrint('[Coffre] compressé : $avant → $apres octets ($name)');
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

  Future<SafeboxCompressed?> _photo(String path, String name) async {
    final dims = await _dimensions(path);
    if (dims == null) return null;
    final long = math.max(dims.width, dims.height);
    final short = math.min(dims.width, dims.height);
    // Le moteur réduit jusqu'à ce qu'un côté touche la borne : on lui donne le
    // côté court visé pour les deux, et le grand côté tombe sur 3 000 px.
    final cible = long <= kSafeboxPhotoLongSide ? short : (short * kSafeboxPhotoLongSide / long).round();
    final base = p.basenameWithoutExtension(name);
    final sortie = p.join(workDir.path, 'photo_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.jpg');
    final r = await FlutterImageCompress.compressAndGetFile(
      path,
      sortie,
      minWidth: cible,
      minHeight: cible,
      quality: kSafeboxPhotoQuality,
      format: CompressFormat.jpeg,
      // Date et appareil de prise de vue gardés : c'est un souvenir qu'on archive.
      keepExif: true,
    );
    return r == null ? null : SafeboxCompressed(path: r.path, name: '$base.jpg');
  }

  Future<SafeboxCompressed?> _videoTranscode(String path, String name) async {
    final id = 'coffre_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final sortie = p.join(workDir.path, '$id.mp4');
    final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('transcode', {
      'id': id,
      'input': path,
      'output': sortie,
      'videoMime': 'video/avc',
      'videoBitrate': kSafeboxVideoBitrate,
      'audioBitrate': kSafeboxVideoAudioBitrate,
      'maxShortSide': kSafeboxVideoShortSide,
      'maxFrameRate': 30,
      'iFrameIntervalSeconds': 3.0,
    });
    if (raw == null) return null;
    final produit = (raw['path'] as String?) ?? sortie;
    return SafeboxCompressed(path: produit, name: '${p.basenameWithoutExtension(name)}.mp4');
  }

  /// iOS : `video_compress`, H.264 en 1280×720 comme les discussions, recopié
  /// dans le dossier de travail (le greffon écrit dans son propre cache).
  Future<SafeboxCompressed?> _videoIos(String path, String name) async {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.Res1280x720Quality,
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

  /// WAV ou FLAC → AAC 128 kbit/s dans un .m4a, par le pont Media3 (Android).
  Future<SafeboxCompressed?> _audio(String path, String name) async {
    final id = 'coffre_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
    final sortie = p.join(workDir.path, '$id.m4a');
    final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('transcode', {
      'id': id,
      'input': path,
      'output': sortie,
      'audioBitrate': kSafeboxAudioBitrate,
    });
    if (raw == null) return null;
    return SafeboxCompressed(path: (raw['path'] as String?) ?? sortie, name: '${p.basenameWithoutExtension(name)}.m4a');
  }

  /// Aperçu en clair (JPEG ou PNG d'environ 480 px), ou null. Chiffré ensuite
  /// avec la clé du fichier.
  Future<Uint8List?> preview(String path, SafeboxRoot family, String name) async {
    try {
      switch (family) {
        case SafeboxRoot.albums:
          return await FlutterImageCompress.compressWithFile(
            path,
            minWidth: kSafeboxPreviewSide,
            minHeight: kSafeboxPreviewSide,
            quality: 70,
            format: CompressFormat.jpeg,
          );
        case SafeboxRoot.videos:
          return await VideoThumbnailService.forFile(path);
        case SafeboxRoot.audios:
          final b64 = await MusicMetadataService.coverBase64(path);
          return b64 == null ? null : base64Decode(b64);
        case SafeboxRoot.documents:
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
  Future<SafeboxMeta?> meta(String path, SafeboxRoot family, String name) async {
    try {
      switch (family) {
        case SafeboxRoot.videos:
          if (Platform.isAndroid) {
            final raw = await _video.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
            if (raw == null) return null;
            final rotation = (raw['rotation'] as num?)?.toInt() ?? 0;
            final w = (raw['width'] as num?)?.toInt();
            final h = (raw['height'] as num?)?.toInt();
            final tourne = rotation == 90 || rotation == 270;
            return SafeboxMeta.fromJson({
              'durationMs': raw['durationMs'],
              'width': tourne ? h : w,
              'height': tourne ? w : h,
            });
          }
          final info = await VideoCompress.getMediaInfo(path);
          return SafeboxMeta.fromJson({
            'durationMs': info.duration?.round(),
            'width': info.width,
            'height': info.height,
          });
        case SafeboxRoot.audios:
          final tags = readMetadata(File(path), getImage: false);
          var ms = tags.duration?.inMilliseconds;
          if (ms == null || ms <= 0) {
            final s = await MusicMetadataService.durationSeconds(path);
            ms = s == null ? null : s * 1000;
          }
          return SafeboxMeta.fromJson({'durationMs': ms, 'title': tags.title, 'artist': tags.artist});
        case SafeboxRoot.documents:
          if (safeboxExtensionOf(name) != 'pdf') return null;
          final doc = await PdfDocument.openFile(path);
          try {
            return SafeboxMeta.fromJson({'pages': doc.pagesCount});
          } finally {
            await doc.close();
          }
        case SafeboxRoot.albums:
          return null;
      }
    } catch (e) {
      debugPrint('[Coffre] détails illisibles : $e');
      return null;
    }
  }
}
