import 'package:flutter/material.dart';
import 'dart:math' as math;

class StatusRingAvatar extends StatelessWidget {
  final int authorId;
  final bool hasUnseen;
  final int unseenCount;

  const StatusRingAvatar({
    super.key,
    required this.authorId,
    required this.hasUnseen,
    required this.unseenCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: hasUnseen
            ? [
                BoxShadow(
                  color: Colors.green.withAlpha(100),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring painter for status indicators
          CustomPaint(
            painter: _RingPainter(
              total: 3, // Example: 3 total statuses
              unseen: unseenCount,
              strokeWidth: 3,
              gapDeg: 8,
            ),
            size: const Size(75, 75),
          ),
          // Avatar circle
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.indigo.shade100,
            child: Text(
              'U${authorId % 1000}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          // Unseen badge
          if (hasUnseen)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text(
                  '●',
                  style: TextStyle(color: Colors.white, fontSize: 10),
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

  const _RingPainter({
    required this.total,
    required this.unseen,
    required this.strokeWidth,
    required this.gapDeg,
  });

  static const _unseenColor = Color(0xFF25D366);
  static const _seenColor = Color(0xFFBDBDBD);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final n = math.max(1, total);
    final gap = n == 1 ? 0.0 : gapDeg;
    final arcAngle = (360 - (n * gap)) / n;

    for (int i = 0; i < n; i++) {
      final startAngle = (i * (arcAngle + gap)) - 90;
      paint
        ..color = i < unseen ? _unseenColor : _seenColor
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: radius),
        _degToRad(startAngle),
        _degToRad(arcAngle),
        false,
        paint,
      );
    }
  }

  double _degToRad(double deg) => deg * (3.141592653589793 / 180);

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.total != total ||
      old.unseen != unseen ||
      old.strokeWidth != strokeWidth ||
      old.gapDeg != gapDeg;
}
