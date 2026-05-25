import 'dart:math' as math;
import 'package:flutter/material.dart';
/// Avatar circulaire encadr
 d'un anneau segment
 (un arc par statut).
/// Arcs verts pour les statuts non-vus, gris pour les vus 
 style WhatsApp.
class StatusRingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackText;
  final int totalCount;
  final int unseenCount;
  final double size;
  final double strokeWidth;
  final double gapDeg;
  final Widget? overlay;
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
  });
  @override
  Widget build(BuildContext context) {
    final inner = size - strokeWidth * 2 - 4;
    final avatar = CircleAvatar(
      radius: inner / 2,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? NetworkImage(avatarUrl!)
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? Text(
              fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: inner * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            )
          : null,
    );
    if (totalCount == 0) {
      return SizedBox(width: size, height: size, child: Center(child: avatar));
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
          avatar,
          if (overlay != null)
            Positioned(right: 0, bottom: 0, child: overlay!),
        ],
      ),
    );
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
  static const _unseenColor = Color(0xFF25D366); // vert WhatsApp
  static const _seenColor = Color(0xFFBDBDBD);
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
    // Start at -90
 (top) for natural feel
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
  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.total != total ||
      old.unseen != unseen ||
      old.strokeWidth != strokeWidth ||
      old.gapDeg != gapDeg;