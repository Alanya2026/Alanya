import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
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
    this.gapDeg = 18,
    this.overlay,
    this.previewUrl,
    this.statusType,
  });

  // Couleur non-vu par thème (aligné sur StatusRingedAvatar de la liste chats) :
  // vert plein en sombre, dégradé indigo→cyan en clair.
  static const Color _unseenDark = Color(0xFF25D366);
  static const List<Color> _unseenLight = [
    Color(0xFF4F46E5),
    Color(0xFF22D3EE),
  ];

  @override
  Widget build(BuildContext context) {
    final inner = size - strokeWidth * 2 - 4;
    final showPreview = previewUrl != null && hasValidAvatarUrl(previewUrl);
    final showAvatar = hasValidAvatarUrl(avatarUrl);

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = showPreview
        ? CircleAvatar(
            radius: inner / 2,
            backgroundImage: CachedNetworkImageProvider(previewUrl!),
            onBackgroundImageError: (_, __) {},
          )
        : CircleAvatar(
            radius: inner / 2,
            backgroundColor: colors.surfaceContainerHighest,
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
                      color: colors.onSurfaceVariant,
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
              seenColor: colors.onSurfaceVariant,
              unseenColor: isDark ? _unseenDark : null,
              unseenGradient: isDark ? null : _unseenLight,
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
  final Color seenColor;

  /// Couleur pleine des non-vus (thème sombre). Ignoré si [unseenGradient] est
  /// fourni (thème clair).
  final Color? unseenColor;
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
    // Écartement adaptatif : gapDeg (18°) tant qu'il y a peu de statuts, réduit
    // au-delà pour que la somme des espaces ne dépasse pas _kMaxTotalGapDeg.
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
