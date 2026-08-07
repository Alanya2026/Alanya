import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'common/app_avatar.dart';

/// Avatar de la liste des chats entouré d'un anneau de statut segmenté, **sans
/// changer la taille, la forme ni l'ombre de la photo**.
///
/// Contrairement à [StatusRingAvatar] (qui réduit et arrondit le centre en
/// `CircleAvatar`), ici la photo est un [AppAvatar] rendu à la taille pleine
/// avec ombre — identique à [ProfileAvatar] — et l'anneau est simplement peint
/// sur son bord extérieur. La largeur du `leading` reste donc constante avec ou
/// sans statut → liste uniforme (mêmes tailles, titres alignés).
///
/// Couleur des statuts NON VUS (choix design) :
///  - thème sombre → **vert** plein (#25D366) ;
///  - thème clair  → **dégradé indigo→cyan** (#4F46E5 → #22D3EE).
/// Statuts VUS → gris `onSurfaceVariant` dans les deux thèmes.
class StatusRingedAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final int totalCount;
  final int unseenCount;
  final double strokeWidth;

  /// Écartement de base entre segments (degrés). Réduit automatiquement au-delà
  /// de ~5 statuts (voir [_RingPainter]).
  final double gapDeg;
  final VoidCallback? onTap;

  const StatusRingedAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.totalCount,
    required this.unseenCount,
    this.size = 56,
    this.strokeWidth = 3,
    this.gapDeg = 18,
    this.onTap,
  });

  static const Color _unseenDark = Color(0xFF25D366); // vert (sombre)
  static const List<Color> _unseenLight = [
    Color(0xFF4F46E5),
    Color(0xFF22D3EE),
  ]; // dégradé indigo→cyan (clair)

  /// Diamètre de la PHOTO à l'intérieur d'un emplacement [slot] : réduit pour
  /// laisser un anneau + un petit espace AUTOUR (style onglet Statut). La liste
  /// des chats réserve cette même marge pour TOUS les avatars (avec ou sans
  /// statut) → tailles homogènes, l'anneau apparaît dans la marge.
  static double innerPhotoSize(double slot, double strokeWidth) =>
      slot - strokeWidth * 2 - 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoSize = innerPhotoSize(size, strokeWidth);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Photo réduite (centrée) : l'anneau se dessine AUTOUR, avec un petit
          // espace, comme dans l'onglet Statut. Même rendu que ProfileAvatar
          // (cercle + ombre).
          AppAvatar(
            imageUrl: avatarUrl,
            name: name,
            size: photoSize,
            shape: AppAvatarShape.circle,
            showShadow: true,
            onTap: onTap,
          ),
          // Anneau peint autour de la photo (dans la marge réservée). Ne capte
          // pas les taps → ils atteignent l'AppAvatar.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  total: totalCount,
                  unseen: unseenCount.clamp(0, totalCount),
                  strokeWidth: strokeWidth,
                  gapDeg: gapDeg,
                  seenColor: context.colors.onSurfaceVariant,
                  unseenColor: isDark ? _unseenDark : null,
                  unseenGradient: isDark ? null : _unseenLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int total;
  final int unseen;
  final double strokeWidth;
  final double gapDeg;
  final Color seenColor;

  /// Couleur pleine des non-vus (thème sombre). Ignoré si [unseenGradient] est
  /// fourni.
  final Color? unseenColor;

  /// Dégradé des non-vus (thème clair) — appliqué en shader sur les arcs.
  final List<Color>? unseenGradient;

  _RingPainter({
    required this.total,
    required this.unseen,
    required this.strokeWidth,
    required this.gapDeg,
    required this.seenColor,
    this.unseenColor,
    this.unseenGradient,
  });

  static const Color _fallbackUnseen = Color(0xFF25D366);

  // Somme maximale des espaces (degrés) : au-delà, l'écartement se réduit pour
  // garder des arcs lisibles quand il y a beaucoup de statuts (adaptatif).
  static const double _kMaxTotalGapDeg = 90;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );
    final n = math.max(1, total);
    // Écartement ADAPTATIF : [gapDeg] (18° par défaut) tant qu'il y a peu de
    // statuts, réduit au-delà pour que la somme des espaces ne dépasse pas
    // [_kMaxTotalGapDeg] — sinon les arcs deviendraient minuscules avec 6+
    // statuts. Ex. : ≤5 → 18° ; 6 → 15° ; 8 → 11° ; 10 → 9°.
    final gap = n == 1 ? 0.0 : math.min(gapDeg, _kMaxTotalGapDeg / n);
    final arcDeg = (360 - gap * n) / n;
    final arcRad = arcDeg * math.pi / 180;
    final gapRad = gap * math.pi / 180;

    final ui.Shader? unseenShader = unseenGradient == null
        ? null
        : ui.Gradient.linear(
            Offset(rect.left, rect.top),
            Offset(rect.right, rect.bottom),
            unseenGradient!,
          );

    double start = -math.pi / 2 + gapRad / 2;
    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      if (i < unseen) {
        if (unseenShader != null) {
          paint.shader = unseenShader;
        } else {
          paint.color = unseenColor ?? _fallbackUnseen;
        }
      } else {
        paint.color = seenColor;
      }
      canvas.drawArc(rect, start, arcRad, false, paint);
      start += arcRad + gapRad;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.total != total ||
      old.unseen != unseen ||
      old.strokeWidth != strokeWidth ||
      old.gapDeg != gapDeg ||
      old.seenColor != seenColor ||
      old.unseenColor != unseenColor ||
      old.unseenGradient != unseenGradient;
}
