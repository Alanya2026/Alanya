import 'package:flutter/material.dart';

/// Waveform interactive : barres extraites du fichier audio.
class VoiceWaveformBar extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final Color foregroundColor;
  final bool enabled;
  final ValueChanged<double> onSeek;

  const VoiceWaveformBar({
    super.key,
    required this.samples,
    required this.progress,
    required this.foregroundColor,
    required this.onSeek,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final data =
        samples.isEmpty ? List<double>.filled(56, 0.35) : samples;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveAlpha = isDark ? 50 : 80;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (d) => onSeek((d.localPosition.dx / width).clamp(0.0, 1.0))
              : null,
          onHorizontalDragUpdate: enabled
              ? (d) => onSeek((d.localPosition.dx / width).clamp(0.0, 1.0))
              : null,
          child: SizedBox(
            height: 28,
            width: width,
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: data,
                progress: progress.clamp(0.0, 1.0),
                activeColor: enabled
                    ? foregroundColor
                    : foregroundColor.withAlpha(100),
                inactiveColor: foregroundColor.withAlpha(inactiveAlpha),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = samples.length;
    if (count == 0) return;

    final gap = 1.5;
    final barWidth = (size.width - gap * (count - 1)) / count;
    final maxSample = samples.reduce((a, b) => a > b ? a : b);
    final scale = maxSample <= 0 ? 1.0 : 1.0 / maxSample;
    final splitX = size.width * progress;

    for (var i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final normalized = (samples[i] * scale).clamp(0.08, 1.0);
      final barHeight = normalized * size.height;
      final top = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, barHeight),
        const Radius.circular(1.2),
      );
      final centerX = x + barWidth / 2;
      final paint = Paint()
        ..color = centerX <= splitX ? activeColor : inactiveColor;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.samples != samples ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
