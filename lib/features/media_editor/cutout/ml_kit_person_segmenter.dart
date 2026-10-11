import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';

import 'person_segmenter.dart';

/// Détourage des personnes par ML Kit Selfie Segmentation : **tout se passe
/// sur l'appareil** (modèle embarqué), la photo n'est envoyée nulle part.
///
/// Mémoire (téléphones d'entrée de gamme) :
/// - l'image de travail (≤ 1024 px) est écrite en PNG dans un fichier
///   temporaire, **effacé** dès la fin du traitement (succès ou échec) ;
/// - le masque brut est demandé à la **taille du modèle** (`enableRawSizeMask`,
///   256×256) : 65 000 valeurs franchissent le canal natif, pas 1 million ;
///   le rendu l'étire (filtrage doux) sur l'image de travail ;
/// - le traitement tourne sur les fils natifs de ML Kit (canal de plateforme
///   asynchrone) ; l'encodage PNG est fait par le moteur hors du fil de
///   l'interface ; aucune copie pleine résolution côté Dart.
class MlKitPersonSegmenter implements PersonSegmenter {
  MlKitPersonSegmenter({Future<Directory> Function()? tempDir})
    : _tempDir = tempDir ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDir;
  SelfieSegmenter? _segmenter;
  bool _closed = false;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<PersonMask> segment(ui.Image image) async {
    if (!isSupported || _closed) {
      throw const PersonSegmentationException(
        PersonSegmentationIssue.failed,
        'plateforme non prise en charge',
      );
    }
    File? file;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const PersonSegmentationException(
          PersonSegmentationIssue.failed,
          'encodage impossible',
        );
      }
      final dir = await _tempDir();
      file = File(
        '${dir.path}${Platform.pathSeparator}cutout_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      final segmenter = _segmenter ??= SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: true,
      );
      final mask = await segmenter.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (mask == null) {
        throw const PersonSegmentationException(
          PersonSegmentationIssue.noPerson,
        );
      }
      return PersonMask.fromConfidences(
        mask.confidences,
        width: mask.width,
        height: mask.height,
      );
    } on PersonSegmentationException {
      rethrow;
    } on PlatformException catch (e) {
      throw PersonSegmentationException(
        PersonSegmentationIssue.failed,
        e.message ?? e.code,
      );
    } on MissingPluginException catch (e) {
      throw PersonSegmentationException(
        PersonSegmentationIssue.failed,
        e.message,
      );
    } on FileSystemException catch (e) {
      throw PersonSegmentationException(
        PersonSegmentationIssue.failed,
        e.message,
      );
    } finally {
      try {
        await file?.delete();
      } catch (_) {
        // Fichier déjà absent : rien à faire.
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    final s = _segmenter;
    _segmenter = null;
    try {
      await s?.close();
    } catch (_) {
      // Fermeture best-effort.
    }
  }
}
