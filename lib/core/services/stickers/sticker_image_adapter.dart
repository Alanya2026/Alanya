import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'sticker_image_check.dart';

/// Étape d'adaptation d'une photo de la galerie avant envoi (en attendant
/// l'éditeur T4b) : l'image est décodée, ajustée en « contain » (sans la
/// déformer) dans un canevas **512×512 transparent**, puis exportée en PNG.
///
/// Tout passe par `dart:ui` (`PictureRecorder`, `drawImageRect`,
/// `Picture.toImage`, `toByteData(png)`) : le paquet `image` (transitif 4.8.0)
/// ne sert pas à encoder. Le résultat est ensuite contrôlé par
/// [StickerImageCheck.validate] — c'est lui, pas cette classe, qui tranche.
abstract final class StickerImageAdapter {
  /// Taille d'entrée maximale (octets lus depuis la galerie).
  static const int maxInputBytes = 20 * 1024 * 1024;

  /// Au-delà, le décodage coûterait trop de mémoire sur un téléphone d'entrée
  /// de gamme (un PNG ne se décode pas « à échelle réduite »).
  static const int maxInputPixels = 50 * 1000 * 1000;

  /// Plus grand côté du décodage : on ne garde jamais la pleine résolution.
  static const int decodeBound = 1024;

  /// Échelles successives du contenu dans le canevas quand le PNG dépasse
  /// 1 Mo (bruit, photo très détaillée) : le canevas reste 512×512.
  static const List<double> _fitScales = [1.0, 0.85, 0.7, 0.55, 0.4];

  /// Adapte [input] en PNG 512×512 avec alpha ≤ 1 Mo.
  ///
  /// Lève [StickerImageRejected] : [StickerImageIssue.inputTooBig] (> 20 Mo ou
  /// > 50 mégapixels), [StickerImageIssue.animated] (GIF, WebP animé),
  /// [StickerImageIssue.format] (illisible, ou format que ce téléphone ne
  /// décode pas), [StickerImageIssue.tooBig] (PNG > 1 Mo même réduit).
  ///
  /// [maxOutputBytes] ne sert qu'aux tests (forcer les réessais plus petits,
  /// que l'encodeur PNG de Skia déclenche rarement : même du bruit pur tient
  /// en moins de 1 Mo à 512×512) ; le contrôle d'envoi garde son 1 Mo.
  static Future<Uint8List> adapt(
    Uint8List input, {
    int maxOutputBytes = StickerImageCheck.maxBytes,
  }) async {
    if (input.length > maxInputBytes) {
      throw const StickerImageRejected(StickerImageIssue.inputTooBig);
    }
    if (input.isEmpty) {
      throw const StickerImageRejected(StickerImageIssue.format);
    }
    // Déjà conforme (PNG/WebP 512×512 alpha ≤ 1 Mo) : on n'y touche pas, rien
    // n'est ré-encodé. Un animé est refusé ici, sans décoder.
    try {
      StickerImageCheck.validate(input);
      return input;
    } on StickerImageRejected catch (e) {
      if (e.issue == StickerImageIssue.animated) rethrow;
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      try {
        buffer = await ui.ImmutableBuffer.fromUint8List(input);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
      } catch (_) {
        throw const StickerImageRejected(StickerImageIssue.format);
      }
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) {
        throw const StickerImageRejected(StickerImageIssue.format);
      }
      if (w * h > maxInputPixels) {
        throw const StickerImageRejected(StickerImageIssue.inputTooBig);
      }

      // Décodage borné : le plus grand côté ne dépasse pas [decodeBound], le
      // rapport est conservé (on fixe les deux cibles, arrondies ensemble).
      final longest = w > h ? w : h;
      int? targetW;
      int? targetH;
      if (longest > decodeBound) {
        final k = decodeBound / longest;
        targetW = (w * k).round().clamp(1, decodeBound);
        targetH = (h * k).round().clamp(1, decodeBound);
      }
      try {
        codec = await descriptor.instantiateCodec(
          targetWidth: targetW,
          targetHeight: targetH,
        );
      } catch (_) {
        throw const StickerImageRejected(StickerImageIssue.format);
      }
      if (codec.frameCount > 1) {
        throw const StickerImageRejected(StickerImageIssue.animated);
      }
      try {
        decoded = (await codec.getNextFrame()).image;
      } catch (_) {
        throw const StickerImageRejected(StickerImageIssue.format);
      }

      for (final scale in _fitScales) {
        final png = await _render(decoded, scale);
        if (png.length <= maxOutputBytes) {
          // Garde-fou : le contrôle d'envoi doit réussir sur ce qu'on produit.
          StickerImageCheck.validate(png);
          return png;
        }
      }
      throw const StickerImageRejected(StickerImageIssue.tooBig);
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Dessine [src] en « contain » dans un canevas transparent 512×512, à
  /// l'échelle [scale] du cadre, et l'exporte en PNG.
  static Future<Uint8List> _render(ui.Image src, double scale) async {
    const side = StickerImageCheck.side;
    final sw = src.width.toDouble();
    final sh = src.height.toDouble();
    final fit = (side / sw < side / sh ? side / sw : side / sh) * scale;
    final dw = sw * fit;
    final dh = sh * fit;
    final dst = ui.Rect.fromLTWH((side - dw) / 2, (side - dh) / 2, dw, dh);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    );
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, sw, sh),
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.high
        ..isAntiAlias = true,
    );
    final picture = recorder.endRecording();
    ui.Image? out;
    try {
      out = await picture.toImage(side, side);
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
