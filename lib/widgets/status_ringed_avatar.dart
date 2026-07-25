import 'dart:math' as math;

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
class StatusRingedAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final int totalCount;
  final int unseenCount;
  final double strokeWidth;
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
    this.gapDeg = 6,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Photo : même rendu que ProfileAvatar (cercle, taille pleine, ombre).
          AppAvatar(
            imageUrl: avatarUrl,
            name: name,
            size: size,
            shape: AppAvatarShape.circle,
            showShadow: true,
            onTap: onTap,
          ),
          // Anneau peint sur le bord extérieur de la photo (aucun décalage de
          // taille). Ne capte pas les taps → ils atteignent l'AppAvatar.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  total: totalCount,
                  unseen: unseenCount.clamp(0, totalCount),
                  strokeWidth: strokeWidth,
                  gapDeg: gapDeg,
                  // Gris bien visible pour les statuts déjà vus (plus contrasté
                  // que `outline`, lisible en clair comme en sombre).
                  seenColor: context.colors.onSurfaceVariant,
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

  _RingPainter({
    required this.total,
    required this.unseen,
    required this.strokeWidth,
    required this.gapDeg,
    required this.seenColor,
  });

  // Vert non-vu (style WhatsApp) — aligné sur StatusRingAvatar.
  static const _unseenColor = Color(0xFF25D366);

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );
    final n = math.max(1, total);
    final gap = n == 1 ? 0.0 : gapDeg;
    final arcDeg = (360 - gap * n) / n;
    final arcRad = arcDeg * math.pi / 180;
    final gapRad = gap * math.pi / 180;
    double start = -math.pi / 2 + gapRad / 2;
    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..color = i < unseen ? _unseenColor : seenColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
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
      old.seenColor != seenColor;
}
