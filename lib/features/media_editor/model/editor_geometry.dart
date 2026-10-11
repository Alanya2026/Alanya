import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Position, taille et orientation d'un élément posé sur le canevas (texte,
/// emoji) : centre en coordonnées du **document** (l'unité du canevas, 512 pour
/// un sticker), échelle (1 = taille de base) et rotation en radians.
///
/// Toute la géométrie est pure (aucun widget) : elle se teste sans moteur.
@immutable
class EditorPlacement {
  const EditorPlacement({
    required this.center,
    this.scale = 1,
    this.rotation = 0,
  });

  final Offset center;
  final double scale;
  final double rotation;

  /// Bornes d'échelle : un élément ne disparaît pas, ne déborde pas à l'infini.
  static const double minScale = 0.2;
  static const double maxScale = 8;

  EditorPlacement copyWith({Offset? center, double? scale, double? rotation}) =>
      EditorPlacement(
        center: center ?? this.center,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  /// Point du document → repère de l'élément (non mis à l'échelle, origine au
  /// centre, axes tournés avec l'élément).
  Offset toLocal(Offset docPoint) {
    final d = docPoint - center;
    final c = math.cos(-rotation);
    final s = math.sin(-rotation);
    return Offset((d.dx * c - d.dy * s) / scale, (d.dx * s + d.dy * c) / scale);
  }

  /// Inverse de [toLocal].
  Offset toDoc(Offset local) {
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final x = local.dx * scale;
    final y = local.dy * scale;
    return center + Offset(x * c - y * s, x * s + y * c);
  }

  /// Les quatre coins d'un élément de taille [size] (repère du document), dans
  /// l'ordre haut-gauche, haut-droit, bas-droit, bas-gauche.
  List<Offset> corners(Size size) {
    final hw = size.width / 2;
    final hh = size.height / 2;
    return [
      toDoc(Offset(-hw, -hh)),
      toDoc(Offset(hw, -hh)),
      toDoc(Offset(hw, hh)),
      toDoc(Offset(-hw, hh)),
    ];
  }

  /// [docPoint] touche-t-il l'élément de taille locale [size] ? [minTouch] est
  /// la cible tactile minimale **dans l'unité du document** : un petit texte
  /// reste attrapable du doigt (48 dp ramenés au document par l'appelant).
  bool contains(Offset docPoint, Size size, {double minTouch = 0}) {
    final p = toLocal(docPoint);
    final halfW = math.max(size.width, minTouch / scale) / 2;
    final halfH = math.max(size.height, minTouch / scale) / 2;
    return p.dx.abs() <= halfW && p.dy.abs() <= halfH;
  }

  /// Applique un geste de pincement : déplacement [translate] (document),
  /// facteur d'échelle [scaleFactor] et rotation [rotationDelta].
  EditorPlacement transformedBy({
    Offset translate = Offset.zero,
    double scaleFactor = 1,
    double rotationDelta = 0,
  }) {
    return EditorPlacement(
      center: center + translate,
      scale: (scale * scaleFactor).clamp(minScale, maxScale),
      rotation: normalizeAngle(rotation + rotationDelta),
    );
  }

  /// Ramène un angle dans ]−π, π].
  static double normalizeAngle(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    if (r <= -math.pi) r += 2 * math.pi;
    return r;
  }

  @override
  bool operator ==(Object other) =>
      other is EditorPlacement &&
      other.center == center &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(center, scale, rotation);

  @override
  String toString() =>
      'EditorPlacement($center, x${scale.toStringAsFixed(2)}, ${rotation.toStringAsFixed(2)} rad)';
}

/// Placement de l'image de base dans le cadre : centre de l'image en
/// coordonnées du document et échelle (pixels du document par pixel de
/// l'image de travail). C'est tout le « rognage » : le cadre ne bouge pas,
/// l'image glisse et zoome dessous.
@immutable
class EditorImageTransform {
  const EditorImageTransform({required this.center, required this.scale});

  final Offset center;
  final double scale;

  /// Image entière visible dans le cadre (comme `BoxFit.contain`).
  factory EditorImageTransform.contain(Size canvas, int imageW, int imageH) {
    final s = math.min(canvas.width / imageW, canvas.height / imageH);
    return EditorImageTransform(
      center: Offset(canvas.width / 2, canvas.height / 2),
      scale: s,
    );
  }

  /// Cadre entièrement rempli par l'image (comme `BoxFit.cover`).
  factory EditorImageTransform.cover(Size canvas, int imageW, int imageH) {
    final s = math.max(canvas.width / imageW, canvas.height / imageH);
    return EditorImageTransform(
      center: Offset(canvas.width / 2, canvas.height / 2),
      scale: s,
    );
  }

  /// Rectangle occupé par l'image dans le document.
  Rect rect(int imageW, int imageH) => Rect.fromCenter(
    center: center,
    width: imageW * scale,
    height: imageH * scale,
  );

  /// Ramène la transformation dans des bornes raisonnables : zoom entre un
  /// quart de « contain » et 8× « cover » ; le centre reste dans le cadre (on
  /// ne peut pas faire sortir l'image).
  EditorImageTransform clamped(Size canvas, int imageW, int imageH) {
    final lo = EditorImageTransform.contain(canvas, imageW, imageH).scale / 4;
    final hi = EditorImageTransform.cover(canvas, imageW, imageH).scale * 8;
    return EditorImageTransform(
      center: Offset(
        center.dx.clamp(0, canvas.width),
        center.dy.clamp(0, canvas.height),
      ),
      scale: scale.clamp(lo, hi),
    );
  }

  EditorImageTransform copyWith({Offset? center, double? scale}) =>
      EditorImageTransform(
        center: center ?? this.center,
        scale: scale ?? this.scale,
      );

  @override
  bool operator ==(Object other) =>
      other is EditorImageTransform &&
      other.center == center &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(center, scale);

  @override
  String toString() => 'EditorImageTransform($center, x$scale)';
}
