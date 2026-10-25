import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

import '../../../core/services/photo_edit_service.dart' show PhotoEditService;
import '../model/editor_document.dart';
import '../render/editor_look.dart';

/// Retouche d'une vidéo avant envoi : découpe, son, calques (textes, traits,
/// emoji) et filtre de couleur. **Rien n'est encodé** pendant la retouche : un
/// seul rendu natif, au moment d'envoyer.
@immutable
class VideoRetouch {
  const VideoRetouch({
    this.start = Duration.zero,
    this.end,
    this.muted = false,
    this.doc,
  });

  /// Début gardé.
  final Duration start;

  /// Fin gardée ; `null` = jusqu'au bout.
  final Duration? end;

  final bool muted;

  /// Calques et filtre, posés sur une image de la vidéo ; `null` si aucun.
  final EditorDoc? doc;

  /// Durée la plus courte qu'on puisse garder.
  static const Duration minLength = Duration(seconds: 1);

  VideoRetouch copyWith({
    Duration? start,
    Duration? end,
    bool? muted,
    EditorDoc? doc,
  }) => VideoRetouch(
    start: start ?? this.start,
    end: end ?? this.end,
    muted: muted ?? this.muted,
    doc: doc ?? this.doc,
  );

  /// Fin effective pour une vidéo de durée [total].
  Duration endFor(Duration total) {
    final e = end;
    return e == null || e > total ? total : e;
  }

  bool isTrimmed(Duration total) =>
      start > Duration.zero || endFor(total) < total;

  bool get hasLayers {
    final d = doc;
    return d != null &&
        (d.items.isNotEmpty || d.strokes.any((s) => !s.isBlur));
  }

  bool get hasLook => doc != null && !doc!.look.isNeutral;

  /// Faut-il réencoder la vidéo ?
  bool needsRender(Duration total) =>
      isTrimmed(total) || muted || hasLayers || hasLook;

  /// Matrice de couleur à passer au rendu, `null` sans filtre.
  List<double>? get colorMatrix {
    final d = doc;
    return d == null ? null : EditorLookMatrix.of(d.look);
  }
}

/// Ce que l'écran d'envoi sait d'une vidéo.
@immutable
class VideoInfo {
  const VideoInfo({required this.duration, required this.size});
  final Duration duration;

  /// Taille d'affichage (rotation déjà appliquée).
  final ui.Size size;
}

/// Le moteur vidéo natif (Media3 sur Android, AVFoundation sur iOS),
/// injectable : les tests n'en ont pas.
abstract class VideoEngine {
  Future<VideoInfo> info(File video);

  /// Image de la vidéo à [at], tenant dans [box] (JPEG) ; `null` si illisible.
  Future<Uint8List?> frame(File video, Duration at, ui.Size box);

  /// Images régulièrement espacées pour la bande de découpe.
  Future<List<Uint8List>> strip(
    File video,
    List<Duration> at,
    ui.Size thumbSize,
  );

  /// Rend [retouch] dans un fichier neuf ; [overlayPng] : calque transparent
  /// étiré sur toute l'image. Lève [VideoRenderCanceled] si [cancel] l'arrête.
  Future<File> render(
    File video,
    VideoRetouch retouch, {
    required String taskId,
    Uint8List? overlayPng,
  });

  Stream<double> progress(String taskId);

  Future<void> cancel(String taskId);
}

class VideoRenderCanceled implements Exception {
  const VideoRenderCanceled();
}

class VideoRenderException implements Exception {
  const VideoRenderException(this.message);
  final String message;
  @override
  String toString() => 'VideoRenderException($message)';
}

/// [VideoEngine] de l'app, par pro_video_editor. Les vidéos rendues vont dans
/// le dossier des retouches (`alanya_edited`, préfixe `edited_`) : elles se
/// suppriment comme les photos retouchées.
class ProVideoEngine implements VideoEngine {
  const ProVideoEngine();

  static pve.ProVideoEditor get _pve => pve.ProVideoEditor.instance;

  @override
  Future<VideoInfo> info(File video) async {
    final m = await _pve.getMetadata(pve.EditorVideo.file(video));
    return VideoInfo(duration: m.duration, size: m.resolution);
  }

  @override
  Future<Uint8List?> frame(File video, Duration at, ui.Size box) async {
    final list = await _pve.getThumbnails(
      pve.ThumbnailConfigs(
        video: pve.EditorVideo.file(video),
        outputSize: box,
        boxFit: pve.ThumbnailBoxFit.contain,
        jpegQuality: 90,
        timestamps: [at],
        maxParallelDecoders: 1,
      ),
    );
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<List<Uint8List>> strip(
    File video,
    List<Duration> at,
    ui.Size thumbSize,
  ) => _pve.getThumbnails(
    pve.ThumbnailConfigs(
      video: pve.EditorVideo.file(video),
      outputSize: thumbSize,
      boxFit: pve.ThumbnailBoxFit.cover,
      jpegQuality: 70,
      timestamps: at,
      // Le lecteur de l'aperçu utilise déjà un décodeur.
      maxParallelDecoders: 1,
    ),
  );

  @override
  Future<File> render(
    File video,
    VideoRetouch retouch, {
    required String taskId,
    Uint8List? overlayPng,
  }) async {
    final matrix = retouch.colorMatrix;
    final data = pve.VideoRenderData(
      id: taskId,
      videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(video))],
      startTime: retouch.start > Duration.zero ? retouch.start : null,
      endTime: retouch.end,
      enableAudio: !retouch.muted,
      imageLayers: overlayPng == null
          ? null
          // Sans position : le calque est étiré sur toute l'image.
          : [pve.ImageLayer(image: pve.EditorLayerImage.memory(overlayPng))],
      colorFilters: matrix == null
          ? const []
          : [pve.ColorFilter(matrix: matrix)],
      shouldOptimizeForNetworkUse: true,
    );
    final out = await _outputFile();
    try {
      await _pve.renderVideoToFile(out.path, data);
    } on pve.RenderCanceledException {
      if (out.existsSync()) await out.delete();
      throw const VideoRenderCanceled();
    } catch (e) {
      if (out.existsSync()) await out.delete();
      throw VideoRenderException('$e');
    }
    return out;
  }

  @override
  Stream<double> progress(String taskId) =>
      _pve.progressStreamById(taskId).map((m) => m.progress);

  @override
  Future<void> cancel(String taskId) => _pve.cancel(taskId);

  static Future<File> _outputFile() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, PhotoEditService.directoryName));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final name = 'edited_${DateTime.now().microsecondsSinceEpoch}_'
        '${Random().nextInt(999999)}.mp4';
    return File(p.join(dir.path, name));
  }
}
