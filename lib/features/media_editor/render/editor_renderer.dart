import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../model/editor_document.dart';
import 'editor_look.dart';

/// Polices du texte. Le projet n'impose aucune police au thème (le système
/// gère le CJK) ; la seule police embarquée est la manuscrite Caveat des
/// messages, avec le même repli CJK que `rich_text_parser.dart`.
abstract final class EditorFonts {
  /// Repli pour les idéogrammes, absents de Caveat.
  static const List<String> handwritingFallback = <String>[
    'Noto Sans SC',
    'PingFang SC',
    'Heiti SC',
    'Microsoft YaHei',
  ];

  /// Fabrique de style, remplaçable (les tests n'ont pas accès au réseau de
  /// `google_fonts`).
  @visibleForTesting
  static TextStyle Function(EditorFont font, Color color, double fontSize)
  resolver = _defaultStyle;

  static TextStyle style(EditorFont font, Color color, double fontSize) =>
      resolver(font, color, fontSize);

  static TextStyle _defaultStyle(EditorFont font, Color color, double size) {
    switch (font) {
      case EditorFont.standard:
        return TextStyle(color: color, fontSize: size, height: 1.15);
      case EditorFont.bold:
        return TextStyle(
          color: color,
          fontSize: size,
          height: 1.15,
          fontWeight: FontWeight.w800,
        );
      case EditorFont.handwriting:
        // Caveat est plus petite à corps égal : même correctif que les messages.
        return GoogleFonts.caveat(
          textStyle: TextStyle(color: color, fontSize: size * 1.3, height: 1.1),
        ).copyWith(fontFamilyFallback: handwritingFallback);
    }
  }

  /// Attend le chargement de la police avant un rendu qui doit être exact
  /// (export). Sans réseau ni cache, on exporte avec le repli du système.
  static Future<void> ensureLoaded(Iterable<EditorFont> fonts) async {
    if (!fonts.contains(EditorFont.handwriting)) return;
    try {
      await GoogleFonts.pendingFonts([GoogleFonts.caveat()]);
    } catch (_) {
      // Hors ligne : repli.
    }
  }
}

/// Dimensions de base des éléments, proportionnelles au cadre (un texte
/// occupe la même part d'un sticker 512 et d'une photo 1024).
abstract final class EditorItemMetrics {
  /// Corps du texte à l'échelle 1.
  static double textFontSize(ui.Size canvas) => canvas.shortestSide / 8;

  /// Corps d'un emoji à l'échelle 1.
  static double emojiFontSize(ui.Size canvas) => canvas.shortestSide / 4;

  /// Largeur au-delà de laquelle un texte passe à la ligne.
  static double textMaxWidth(ui.Size canvas) => canvas.width * 0.9;

  /// Mise en page d'un élément ; l'appelant libère le [TextPainter].
  static TextPainter layout(EditorItem item, ui.Size canvas) {
    final TextSpan span;
    var maxWidth = double.infinity;
    var align = TextAlign.center;
    switch (item) {
      case EditorTextItem():
        span = TextSpan(
          text: item.text,
          style: EditorFonts.style(
            item.font,
            textColorOf(item),
            textFontSize(canvas),
          ),
        );
        maxWidth = textMaxWidth(canvas);
        align = switch (item.align) {
          EditorTextAlign.left => TextAlign.left,
          EditorTextAlign.center => TextAlign.center,
          EditorTextAlign.right => TextAlign.right,
        };
      case EditorEmojiItem():
        span = TextSpan(
          text: item.emoji,
          style: TextStyle(fontSize: emojiFontSize(canvas)),
        );
    }
    final tp = TextPainter(
      text: span,
      textAlign: align,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  /// Couleur des lettres : sur fond plein, la couleur choisie devient le fond
  /// et le texte prend le noir ou le blanc, selon ce qui se lit le mieux.
  static ui.Color textColorOf(EditorTextItem item) {
    if (item.background != EditorTextBackground.solid) return item.color;
    return item.color.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;
  }

  /// Marge du fond d'un texte autour des lettres ; zéro sans fond.
  static ui.Size backgroundPadding(EditorItem item, ui.Size canvas) {
    if (item is! EditorTextItem ||
        item.background == EditorTextBackground.none) {
      return ui.Size.zero;
    }
    final f = textFontSize(canvas);
    return ui.Size(f * 0.35, f * 0.15);
  }

  /// Taille de l'élément à l'échelle 1 (repère de l'élément), fond compris.
  static ui.Size sizeOf(EditorItem item, ui.Size canvas) {
    final tp = layout(item, canvas);
    final pad = backgroundPadding(item, canvas);
    final s = ui.Size(tp.width + 2 * pad.width, tp.height + 2 * pad.height);
    tp.dispose();
    return s;
  }
}

/// Le dessin du document, **partagé** par l'écran (`EditorPainter`) et
/// l'export : ce qu'on voit est exactement ce qu'on exporte.
///
/// Ordre, du dessous au dessus : image de base (rendu des couleurs, détourée
/// si besoin) → zones floutées → traits (la gomme du crayon n'efface que les
/// traits) → éléments. Rien n'est peint derrière : le fond hors de l'image
/// reste transparent.
abstract final class EditorRenderer {
  /// Flou d'un trait de masque à bords doux, en part de sa largeur.
  static const double softSigmaRatio = 0.22;

  /// Force du flou de zone, en part du petit côté du cadre (même rendu à
  /// l'écran et à l'export, quelle que soit la résolution).
  static const double blurSigmaRatio = 1 / 45;

  /// Peint [doc] dans le repère du document (0,0)–(canvas) ; l'appelant a
  /// déjà réglé l'échelle du canevas. [contentScale] < 1 réduit tout le
  /// contenu autour du centre (repli d'export quand le PNG dépasse 1 Mo).
  /// [paintBase] = `false` : seulement les traits et les éléments, sur fond
  /// transparent (calque incrusté dans une vidéo ; l'image n'est qu'une image
  /// de la vidéo, et le flou de zone ne la suivrait pas).
  static void paint(
    ui.Canvas canvas,
    EditorDoc doc,
    ui.Image image, {
    double contentScale = 1,
    bool paintBase = true,
  }) {
    final bounds = ui.Offset.zero & doc.canvas;
    canvas.save();
    canvas.clipRect(bounds);
    if (contentScale != 1) {
      canvas.translate(doc.canvas.width / 2, doc.canvas.height / 2);
      canvas.scale(contentScale);
      canvas.translate(-doc.canvas.width / 2, -doc.canvas.height / 2);
    }
    if (paintBase) {
      _paintImage(canvas, doc, image);
      _paintBlur(canvas, doc, image, bounds);
    }
    _paintStrokes(canvas, doc.strokes, bounds);
    for (final item in doc.items) {
      final tp = EditorItemMetrics.layout(item, doc.canvas);
      final p = item.placement;
      canvas.save();
      canvas.translate(p.center.dx, p.center.dy);
      canvas.rotate(p.rotation);
      canvas.scale(p.scale);
      if (item is EditorTextItem &&
          item.background != EditorTextBackground.none) {
        final pad = EditorItemMetrics.backgroundPadding(item, doc.canvas);
        final r = ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: tp.width + 2 * pad.width,
          height: tp.height + 2 * pad.height,
        );
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(r, ui.Radius.circular(pad.width)),
          ui.Paint()
            ..color = item.background == EditorTextBackground.solid
                ? item.color
                : AppColors.black.withValues(alpha: 0.55),
        );
      }
      tp.paint(canvas, ui.Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      tp.dispose();
    }
    canvas.restore();
  }

  /// Zones floutées : l'image (avec son rendu) repeinte floutée, gardée
  /// seulement sous les traits de flou.
  static void _paintBlur(
    ui.Canvas canvas,
    EditorDoc doc,
    ui.Image image,
    ui.Rect bounds,
  ) {
    final blurs = doc.strokes.where((s) => s.isBlur).toList();
    if (blurs.isEmpty) return;
    final sigma = doc.canvas.shortestSide * blurSigmaRatio;
    canvas.saveLayer(bounds, ui.Paint());
    canvas.saveLayer(
      bounds,
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        ),
    );
    _paintImage(canvas, doc, image);
    canvas.restore();
    canvas.saveLayer(bounds, ui.Paint()..blendMode = ui.BlendMode.dstIn);
    for (final s in blurs) {
      final p = ui.Paint()
        ..color = AppColors.white
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..isAntiAlias = true;
      _drawPoints(canvas, s.points, s.width, p);
    }
    canvas.restore();
    canvas.restore();
  }

  static void _paintImage(ui.Canvas canvas, EditorDoc doc, ui.Image image) {
    final t = doc.imageTransform;
    final w = doc.imageWidth.toDouble();
    final h = doc.imageHeight.toDouble();
    final imgRect = ui.Rect.fromLTWH(0, 0, w, h);
    canvas.save();
    canvas.translate(t.center.dx, t.center.dy);
    canvas.rotate(t.angle);
    canvas.scale(t.flipX ? -t.scale : t.scale, t.scale);
    canvas.translate(-w / 2, -h / 2);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;
    final matrix = EditorLookMatrix.of(doc.look);
    if (matrix != null) paint.colorFilter = ui.ColorFilter.matrix(matrix);
    final cut = doc.cutout;
    if (cut == null || cut.isEmpty) {
      canvas.drawImageRect(image, imgRect, imgRect, paint);
    } else {
      // Image → masque appliqué par `dstIn` : l'alpha du masque décide de ce
      // qui reste. Masque = calcul automatique (ou tout visible), puis traits
      // de gomme (cachent) et de pinceau (restaurent) dans l'ordre.
      canvas.saveLayer(imgRect, ui.Paint());
      canvas.drawImageRect(image, imgRect, imgRect, paint);
      canvas.saveLayer(imgRect, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      final mask = cut.baseMask;
      if (mask == null) {
        canvas.drawRect(imgRect, ui.Paint()..color = AppColors.white);
      } else {
        canvas.drawImageRect(
          mask,
          ui.Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
          imgRect,
          paint,
        );
      }
      for (final s in cut.strokes) {
        final p = ui.Paint()
          ..color = AppColors.white
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = s.width
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..isAntiAlias = true;
        if (!s.restore) p.blendMode = ui.BlendMode.clear;
        if (s.soft) {
          // Bords doux : le trait est flouté (transition progressive).
          p.maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            math.max(s.width, 1) * softSigmaRatio,
          );
        }
        _drawPoints(canvas, s.points, s.width, p);
      }
      canvas.restore(); // masque
      canvas.restore(); // image
    }
    canvas.restore();
  }

  static void _paintStrokes(
    ui.Canvas canvas,
    List<EditorStroke> strokes,
    ui.Rect bounds,
  ) {
    if (strokes.every((s) => s.isBlur)) return;
    // Calque à part : la gomme (`clear`) ne perce que les traits.
    canvas.saveLayer(bounds, ui.Paint());
    for (final s in strokes) {
      if (s.isBlur) continue;
      ui.Paint stroke(ui.Color color, double width) => ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..isAntiAlias = true;
      if (s.erase) {
        _drawPoints(
          canvas,
          s.points,
          s.width,
          stroke(s.color, s.width)..blendMode = ui.BlendMode.clear,
        );
        continue;
      }
      switch (s.brush) {
        case EditorBrush.pen || EditorBrush.blur:
          _drawPoints(canvas, s.points, s.width, stroke(s.color, s.width));
        case EditorBrush.highlighter:
          // Large et translucide : un seul chemin, donc pas de surépaisseur
          // aux croisements d'un même trait.
          final w = s.width * 1.8;
          _drawPoints(
            canvas,
            s.points,
            w,
            stroke(s.color.withValues(alpha: 0.42), w)
              ..strokeCap = ui.StrokeCap.square,
          );
        case EditorBrush.neon:
          // Halo de la couleur, puis cœur clair.
          final glow = s.width * 1.6;
          _drawPoints(
            canvas,
            s.points,
            glow,
            stroke(s.color, glow)
              ..maskFilter = ui.MaskFilter.blur(
                ui.BlurStyle.normal,
                glow * 0.45,
              ),
          );
          final core = math.max(s.width * 0.4, 1.0);
          _drawPoints(
            canvas,
            s.points,
            core,
            stroke(AppColors.white, core),
          );
      }
    }
    canvas.restore();
  }

  /// Trace une polyligne lissée (courbes passant par les milieux) ; un point
  /// isolé donne un disque.
  static void _drawPoints(
    ui.Canvas canvas,
    List<ui.Offset> pts,
    double width,
    ui.Paint paint,
  ) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.first,
        math.max(width, 1) / 2,
        paint..style = ui.PaintingStyle.fill,
      );
      return;
    }
    final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }
}

/// Peinture de l'écran : le document dans la zone [viewport] (le cadre,
/// centré, à l'échelle de l'écran). Redessiné à chaque changement du
/// contrôleur ([repaint]) ; le document est lu à la demande.
class EditorPainter extends CustomPainter {
  EditorPainter({
    required this.docOf,
    required this.image,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final EditorDoc Function() docOf;
  final ui.Image image;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final doc = docOf();
    canvas.scale(
      size.width / doc.canvas.width,
      size.height / doc.canvas.height,
    );
    EditorRenderer.paint(canvas, doc, image);
  }

  @override
  bool shouldRepaint(EditorPainter old) => old.image != image;
}
