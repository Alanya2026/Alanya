import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../model/editor_document.dart';

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
    switch (item) {
      case EditorTextItem():
        span = TextSpan(
          text: item.text,
          style: EditorFonts.style(item.font, item.color, textFontSize(canvas)),
        );
        maxWidth = textMaxWidth(canvas);
      case EditorEmojiItem():
        span = TextSpan(
          text: item.emoji,
          style: TextStyle(fontSize: emojiFontSize(canvas)),
        );
    }
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  /// Taille de l'élément à l'échelle 1 (repère de l'élément).
  static ui.Size sizeOf(EditorItem item, ui.Size canvas) {
    final tp = layout(item, canvas);
    final s = ui.Size(tp.width, tp.height);
    tp.dispose();
    return s;
  }
}

/// Le dessin du document, **partagé** par l'écran (`EditorPainter`) et
/// l'export : ce qu'on voit est exactement ce qu'on exporte.
///
/// Ordre, du dessous au dessus : image de base (détourée si besoin) → traits
/// (la gomme du crayon n'efface que les traits) → éléments. Rien n'est peint
/// derrière : le fond hors de l'image reste transparent.
abstract final class EditorRenderer {
  /// Flou d'un trait de masque à bords doux, en part de sa largeur.
  static const double softSigmaRatio = 0.22;

  /// Peint [doc] dans le repère du document (0,0)–(canvas) ; l'appelant a
  /// déjà réglé l'échelle du canevas. [contentScale] < 1 réduit tout le
  /// contenu autour du centre (repli d'export quand le PNG dépasse 1 Mo).
  static void paint(
    ui.Canvas canvas,
    EditorDoc doc,
    ui.Image image, {
    double contentScale = 1,
  }) {
    final bounds = ui.Offset.zero & doc.canvas;
    canvas.save();
    canvas.clipRect(bounds);
    if (contentScale != 1) {
      canvas.translate(doc.canvas.width / 2, doc.canvas.height / 2);
      canvas.scale(contentScale);
      canvas.translate(-doc.canvas.width / 2, -doc.canvas.height / 2);
    }
    _paintImage(canvas, doc, image);
    _paintStrokes(canvas, doc.strokes, bounds);
    for (final item in doc.items) {
      final tp = EditorItemMetrics.layout(item, doc.canvas);
      final p = item.placement;
      canvas.save();
      canvas.translate(p.center.dx, p.center.dy);
      canvas.rotate(p.rotation);
      canvas.scale(p.scale);
      tp.paint(canvas, ui.Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      tp.dispose();
    }
    canvas.restore();
  }

  static void _paintImage(ui.Canvas canvas, EditorDoc doc, ui.Image image) {
    final t = doc.imageTransform;
    final w = doc.imageWidth.toDouble();
    final h = doc.imageHeight.toDouble();
    final imgRect = ui.Rect.fromLTWH(0, 0, w, h);
    canvas.save();
    canvas.translate(t.center.dx, t.center.dy);
    canvas.scale(t.scale);
    canvas.translate(-w / 2, -h / 2);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;
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
    if (strokes.isEmpty) return;
    // Calque à part : la gomme (`clear`) ne perce que les traits.
    canvas.saveLayer(bounds, ui.Paint());
    for (final s in strokes) {
      final p = ui.Paint()
        ..color = s.color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..isAntiAlias = true;
      if (s.erase) p.blendMode = ui.BlendMode.clear;
      _drawPoints(canvas, s.points, s.width, p);
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
