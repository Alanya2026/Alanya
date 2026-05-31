import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/avatar_utils.dart';

/// Avatar circulaire encadré d'un anneau segmenté (un arc par statut).
/// Arcs verts pour les statuts non-vus, gris pour les vus — style WhatsApp.
/// Si [previewUrl] est fourni (statut de type image), il est affiché
/// en aperçu au centre. Un badge de type (▶ 🎵) apparaît pour vidéo/audio.
class StatusRingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackText;
  final int totalCount;
  final int unseenCount;
  final double size;
  final double strokeWidth;
  final double gapDeg;
  final Widget? overlay;
  final String? previewUrl;
  final int? statusType;

  const StatusRingAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackText,
    required this.totalCount,
    required this.unseenCount,
    this.size = 56,
    this.strokeWidth = 3,
    this.gapDeg = 6,
    this.overlay,
    this.previewUrl,
    this.statusType,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - strokeWidth * 2 - 4;
    final showPreview = previewUrl != null && hasValidAvatarUrl(previewUrl);
    final showAvatar = hasValidAvatarUrl(avatarUrl);

    final center = showPreview
        ? CircleAvatar(
            radius: inner / 2,
            backgroundImage: CachedNetworkImageProvider(previewUrl!),
            onBackgroundImageError: (_, __) {},
          )
        : CircleAvatar(
            radius: inner / 2,
            backgroundColor: AppColors.outlineStrong,
            backgroundImage: showAvatar
                ? CachedNetworkImageProvider(avatarUrl!)
                : null,
            onBackgroundImageError: showAvatar ? (_, __) {} : null,
            child: !showAvatar
                ? Text(
                    fallbackText.isNotEmpty
                        ? fallbackText[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: inner * 0.4,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
          );

    if (totalCount == 0) {
      return SizedBox(
          width: size, height: size, child: Center(child: center));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              total: totalCount,
              unseen: unseenCount.clamp(0, totalCount),
              strokeWidth: strokeWidth,
              gapDeg: gapDeg,
            ),
          ),
          center,
          if (statusType == 2)
            Positioned(
              right: 2,
              bottom: 2,
              child: _TypeBadge(icon: Icons.play_arrow, size: inner * 0.3),
            ),
          if (statusType == 3)
            Positioned(
              right: 2,
              bottom: 2,
              child:
                  _TypeBadge(icon: Icons.music_note, size: inner * 0.3),
            ),
          if (overlay != null)
            Positioned(right: 0, bottom: 0, child: overlay!),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const _TypeBadge({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 6,
      height: size + 6,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int total;
  final int unseen;
  final double strokeWidth;
  final double gapDeg;

  _RingPainter({
    required this.total,
    required this.unseen,
    required this.strokeWidth,
    required this.gapDeg,
  });

  // Couleurs intentionnelles de l'anneau de statut (style WhatsApp).
  static const _unseenColor = Color(0xFF25D366);
  static const _seenColor = AppColors.outlineStrong;

  @override
  void paint(Canvas canvas, Size size) {
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
        ..color = i < unseen ? _unseenColor : _seenColor
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
      old.gapDeg != gapDeg;
}
