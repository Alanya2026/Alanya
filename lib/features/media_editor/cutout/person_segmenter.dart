import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Pourquoi le détourage automatique n'a pas abouti.
enum PersonSegmentationIssue {
  /// Le modèle n'a trouvé personne sur la photo.
  noPerson,

  /// Échec du traitement (modèle indisponible, mémoire, erreur native).
  failed,
}

class PersonSegmentationException implements Exception {
  const PersonSegmentationException(this.issue, [this.detail]);
  final PersonSegmentationIssue issue;
  final String? detail;

  @override
  String toString() =>
      'PersonSegmentationException(${issue.name}${detail == null ? '' : ': $detail'})';
}

/// Un masque de personnes : **un seul canal** (1 octet par pixel, 0 = fond,
/// 255 = personne), à la taille [width]×[height] — pas forcément celle de la
/// photo : le rendu l'étire sur l'image de travail avec un filtrage doux.
class PersonMask {
  PersonMask({required this.width, required this.height, required this.alpha})
    : assert(width > 0 && height > 0),
      assert(alpha.length == width * height);

  final int width;
  final int height;

  /// Canal alpha, ligne par ligne.
  final Uint8List alpha;

  /// Part des pixels qui sont « personne » (alpha ≥ 128).
  double get coverage {
    var n = 0;
    for (final a in alpha) {
      if (a >= 128) n++;
    }
    return n / alpha.length;
  }

  /// Crée l'image du masque (celle que l'éditeur référence dans son
  /// document). RVB = alpha : valide en alpha prémultiplié. L'appelant
  /// possède l'image rendue.
  Future<ui.Image> toImage() async {
    final rgba = Uint8List(width * height * 4);
    for (var i = 0, o = 0; i < alpha.length; i++, o += 4) {
      final a = alpha[i];
      rgba[o] = a;
      rgba[o + 1] = a;
      rgba[o + 2] = a;
      rgba[o + 3] = a;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Transforme des confiances brutes (0..1 par pixel, `NaN` toléré) en
  /// masque net mais aux bords adoucis.
  ///
  /// 1. seuil progressif : sous [lowThreshold] c'est du fond, au-dessus de
  ///    [highThreshold] c'est la personne, entre les deux une rampe lissée
  ///    (le contour n'est pas crénelé) ;
  /// 2. un léger flou 3×3 supprime les pixels isolés et adoucit le bord.
  ///
  /// Lève [PersonSegmentationException] (`noPerson`) si moins de
  /// [minCoverage] de la photo est une personne, `failed` si les dimensions
  /// ne correspondent pas aux données.
  static PersonMask fromConfidences(
    List<double> confidences, {
    required int width,
    required int height,
    double lowThreshold = 0.35,
    double highThreshold = 0.75,
    double minCoverage = 0.005,
  }) {
    if (width <= 0 || height <= 0 || confidences.length != width * height) {
      throw PersonSegmentationException(
        PersonSegmentationIssue.failed,
        'masque ${confidences.length} ≠ $width×$height',
      );
    }
    final sharp = Uint8List(confidences.length);
    final span = math.max(highThreshold - lowThreshold, 1e-6);
    for (var i = 0; i < sharp.length; i++) {
      final c = confidences[i];
      if (c.isNaN) continue;
      final t = ((c - lowThreshold) / span).clamp(0.0, 1.0);
      sharp[i] = (t * t * (3 - 2 * t) * 255).round();
    }
    final soft = _blur3x3(sharp, width, height);
    final mask = PersonMask(width: width, height: height, alpha: soft);
    if (mask.coverage < minCoverage) {
      throw const PersonSegmentationException(
        PersonSegmentationIssue.noPerson,
      );
    }
    return mask;
  }

  /// Flou [1 2 1] séparable (un seul tampon intermédiaire d'un octet par
  /// pixel).
  static Uint8List _blur3x3(Uint8List src, int w, int h) {
    if (w < 3 || h < 3) return src;
    final tmp = Uint8List(src.length);
    for (var y = 0; y < h; y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        final l = src[row + (x > 0 ? x - 1 : x)];
        final r = src[row + (x < w - 1 ? x + 1 : x)];
        tmp[row + x] = (l + 2 * src[row + x] + r + 2) >> 2;
      }
    }
    final out = Uint8List(src.length);
    for (var y = 0; y < h; y++) {
      final up = (y > 0 ? y - 1 : y) * w;
      final mid = y * w;
      final down = (y < h - 1 ? y + 1 : y) * w;
      for (var x = 0; x < w; x++) {
        out[mid + x] = (tmp[up + x] + 2 * tmp[mid + x] + tmp[down + x] + 2) >> 2;
      }
    }
    return out;
  }
}

/// Détourage automatique des **personnes**, sur l'appareil uniquement (la
/// photo n'est envoyée nulle part). Interface injectable : les tests posent
/// un faux ; l'application utilise l'implémentation ML Kit
/// (`MlKitPersonSegmenter`).
///
/// Seules les personnes sont reconnues : objets, animaux et dessins se
/// détourent au pinceau.
abstract interface class PersonSegmenter {
  /// Ce téléphone sait détourer (Android, iOS) : sinon le bouton est masqué.
  bool get isSupported;

  /// Calcule le masque des personnes de [image] (l'image de travail, ≤ 1024
  /// px). Lève [PersonSegmentationException] : `noPerson`, `failed`.
  /// N'est pas propriétaire de [image].
  Future<PersonMask> segment(ui.Image image);

  /// Libère les ressources natives. Idempotent.
  Future<void> dispose();
}
