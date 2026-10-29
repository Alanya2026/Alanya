import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/services/stickers/sticker_image_check.dart';
import '../model/editor_document.dart';
import 'editor_renderer.dart';

/// Ce que rend l'éditeur : un PNG et ses dimensions, et pour une photo le
/// document qui l'a produit (pour reprendre la retouche, calques modifiables).
class MediaEditorResult {
  const MediaEditorResult({
    required this.png,
    required this.width,
    required this.height,
    this.doc,
  });

  final Uint8List png;
  final int width;
  final int height;

  /// Mode photo seulement ; `null` pour un sticker.
  final EditorDoc? doc;
}

/// Export du document en PNG par `dart:ui` seulement (`PictureRecorder` →
/// `Picture.toImage` → `toByteData(png)`) : le paquet `image` (transitif
/// 4.8.0) n'encode rien.
///
/// Mode sticker : canevas **512×512** transparent, puis contrôle d'envoi
/// [StickerImageCheck.validate] (≤ 1 Mo, 512×512, alpha) — c'est lui qui
/// tranche. Mode photo : le cadre tel quel (taille de l'image de travail).
abstract final class MediaEditorExporter {
  /// Réductions successives du contenu dans le cadre quand le PNG dépasse
  /// 1 Mo (bruit, photo très détaillée) ; le canevas reste 512×512.
  static const List<double> _fitScales = [1.0, 0.85, 0.7, 0.55, 0.4];

  /// Exporte [doc] dessiné sur [image] (l'image de travail du document).
  ///
  /// Mode sticker : lève [StickerImageRejected] si le résultat n'est pas
  /// conforme (par ex. `tooBig` si même réduit il dépasse [maxOutputBytes]).
  /// [maxOutputBytes] ne sert qu'aux tests.
  static Future<MediaEditorResult> export(
    EditorDoc doc,
    ui.Image image,
    MediaEditorMode mode, {
    int maxOutputBytes = StickerImageCheck.maxBytes,
  }) async {
    if (mode == MediaEditorMode.photo) {
      final w = doc.canvas.width.round().clamp(1, 4096);
      final h = doc.canvas.height.round().clamp(1, 4096);
      final png = await _render(doc, image, w, h, 1);
      return MediaEditorResult(png: png, width: w, height: h, doc: doc);
    }
    const side = StickerImageCheck.side;
    for (final scale in _fitScales) {
      final png = await _render(doc, image, side, side, scale);
      if (png.length <= maxOutputBytes) {
        // Garde-fou : le contrôle d'envoi doit réussir sur ce qu'on produit.
        StickerImageCheck.validate(png);
        return MediaEditorResult(png: png, width: side, height: side);
      }
    }
    throw const StickerImageRejected(StickerImageIssue.tooBig);
  }

  /// Calque d'une vidéo : traits et éléments seuls, PNG transparent
  /// [width]×[height] (la taille de la vidéo rendue). `null` si le document
  /// n'a rien à incruster.
  static Future<Uint8List?> exportOverlay(
    EditorDoc doc,
    ui.Image image,
    int width,
    int height,
  ) async {
    final drawn = doc.strokes.any((s) => !s.isBlur) || doc.items.isNotEmpty;
    if (!drawn) return null;
    return _render(doc, image, width, height, 1, paintBase: false);
  }

  static Future<Uint8List> _render(
    EditorDoc doc,
    ui.Image image,
    int width,
    int height,
    double contentScale, {
    bool paintBase = true,
  }) async {
    await EditorFonts.ensureLoaded(
      doc.items.whereType<EditorTextItem>().map((t) => t.font),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.scale(width / doc.canvas.width, height / doc.canvas.height);
    EditorRenderer.paint(
      canvas,
      doc,
      image,
      contentScale: contentScale,
      paintBase: paintBase,
    );
    final picture = recorder.endRecording();
    ui.Image? out;
    try {
      out = await picture.toImage(width, height);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const StickerImageRejected(StickerImageIssue.format);
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      out?.dispose();
      picture.dispose();
    }
  }
}
