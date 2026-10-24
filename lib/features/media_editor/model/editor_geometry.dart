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
/// coordonnées du document, échelle (pixels du document par pixel de l'image
/// de travail) et orientation. C'est tout le « rognage » : le cadre ne bouge
/// pas, l'image glisse, zoome et tourne dessous.
///
/// Orientation, appliquée dans cet ordre autour du centre de l'image : miroir
/// horizontal ([flipX]), quarts de tour ([quarterTurns], sens horaire), puis
/// rotation fine ([rotation], radians, la molette du rognage).
@immutable
class EditorImageTransform {
  const EditorImageTransform({
    required this.center,
    required this.scale,
    this.rotation = 0,
    this.quarterTurns = 0,
    this.flipX = false,
  });

  final Offset center;
  final double scale;
  final double rotation;
  final int quarterTurns;
  final bool flipX;

  /// Bornes de la rotation fine (± 45°) : au-delà, on pivote d'un quart de
  /// tour.
  static const double maxFineRotation = math.pi / 4;

  /// Taille de l'image une fois ses quarts de tour appliqués.
  static Size orientedSize(int imageW, int imageH, int quarterTurns) =>
      quarterTurns.isOdd
      ? Size(imageH.toDouble(), imageW.toDouble())
      : Size(imageW.toDouble(), imageH.toDouble());

  /// Image entière visible dans le cadre (comme `BoxFit.contain`).
  factory EditorImageTransform.contain(
    Size canvas,
    int imageW,
    int imageH, {
    int quarterTurns = 0,
    bool flipX = false,
  }) {
    final o = orientedSize(imageW, imageH, quarterTurns);
    final s = math.min(canvas.width / o.width, canvas.height / o.height);
    return EditorImageTransform(
      center: Offset(canvas.width / 2, canvas.height / 2),
      scale: s,
      quarterTurns: quarterTurns,
      flipX: flipX,
    );
  }

  /// Cadre entièrement rempli par l'image (comme `BoxFit.cover`), y compris
  /// quand elle est tournée de [rotation] : aucun coin vide.
  factory EditorImageTransform.cover(
    Size canvas,
    int imageW,
    int imageH, {
    double rotation = 0,
    int quarterTurns = 0,
    bool flipX = false,
  }) {
    return EditorImageTransform(
      center: Offset(canvas.width / 2, canvas.height / 2),
      scale: coverScale(canvas, imageW, imageH, rotation, quarterTurns),
      rotation: rotation,
      quarterTurns: quarterTurns,
      flipX: flipX,
    );
  }

  /// Échelle minimale pour que l'image tournée de [rotation] couvre le cadre
  /// (centrée).
  static double coverScale(
    Size canvas,
    int imageW,
    int imageH,
    double rotation,
    int quarterTurns,
  ) {
    final o = orientedSize(imageW, imageH, quarterTurns);
    final c = math.cos(rotation).abs();
    final s = math.sin(rotation).abs();
    final needW = canvas.width * c + canvas.height * s;
    final needH = canvas.width * s + canvas.height * c;
    return math.max(needW / o.width, needH / o.height);
  }

  /// Angle total appliqué à l'image (quarts de tour + rotation fine).
  double get angle => quarterTurns * math.pi / 2 + rotation;

  /// Rectangle occupé par l'image dans le document (sans rotation fine).
  Rect rect(int imageW, int imageH) {
    final o = orientedSize(imageW, imageH, quarterTurns);
    return Rect.fromCenter(
      center: center,
      width: o.width * scale,
      height: o.height * scale,
    );
  }

  /// Point du document → pixel de l'image de travail (inverse exact de la
  /// peinture de l'image).
  Offset docToImage(Offset docPoint, int imageW, int imageH) {
    final d = docPoint - center;
    final c = math.cos(-angle);
    final s = math.sin(-angle);
    var x = (d.dx * c - d.dy * s) / scale;
    final y = (d.dx * s + d.dy * c) / scale;
    if (flipX) x = -x;
    return Offset(x + imageW / 2, y + imageH / 2);
  }

  /// Ramène la transformation dans des bornes raisonnables : zoom entre un
  /// quart de « contain » et 8× « cover » ; le centre reste dans le cadre (on
  /// ne peut pas faire sortir l'image).
  EditorImageTransform clamped(Size canvas, int imageW, int imageH) {
    final lo = EditorImageTransform.contain(
          canvas,
          imageW,
          imageH,
          quarterTurns: quarterTurns,
        ).scale /
        4;
    final hi = EditorImageTransform.cover(
          canvas,
          imageW,
          imageH,
          quarterTurns: quarterTurns,
        ).scale *
        8;
    return copyWith(
      center: Offset(
        center.dx.clamp(0, canvas.width),
        center.dy.clamp(0, canvas.height),
      ),
      scale: scale.clamp(lo, hi),
    );
  }

  EditorImageTransform copyWith({
    Offset? center,
    double? scale,
    double? rotation,
    int? quarterTurns,
    bool? flipX,
  }) => EditorImageTransform(
    center: center ?? this.center,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    flipX: flipX ?? this.flipX,
  );

  @override
  bool operator ==(Object other) =>
      other is EditorImageTransform &&
      other.center == center &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.quarterTurns == quarterTurns &&
      other.flipX == flipX;

  @override
  int get hashCode =>
      Object.hash(center, scale, rotation, quarterTurns, flipX);

  @override
  String toString() =>
      'EditorImageTransform($center, x$scale, ${quarterTurns}q '
      '${rotation.toStringAsFixed(3)} rad${flipX ? ', miroir' : ''})';
}
