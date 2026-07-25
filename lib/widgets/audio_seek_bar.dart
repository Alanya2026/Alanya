import 'package:flutter/material.dart';

/// Barre de progression audio interactive : tap pour sauter, drag pour scrubber.
class AudioSeekBar extends StatefulWidget {
  final double value;
  final Color foregroundColor;
  final bool enabled;
  final ValueChanged<double> onSeek;

  const AudioSeekBar({
    super.key,
    required this.value,
    required this.foregroundColor,
    required this.onSeek,
    this.enabled = true,
  });

  @override
  State<AudioSeekBar> createState() => _AudioSeekBarState();
}

class _AudioSeekBarState extends State<AudioSeekBar> {
  double? _dragValue;

  double get _displayValue => (_dragValue ?? widget.value).clamp(0.0, 1.0);

  void _seekAt(double localDx, double width) {
    if (!widget.enabled || width <= 0) return;
    widget.onSeek((localDx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackBg = widget.foregroundColor.withAlpha(isDark ? 50 : 80);
    final thumbSize = widget.enabled ? 10.0 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * _displayValue;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (d) => _seekAt(d.localPosition.dx, width)
              : null,
          onPanUpdate: widget.enabled
              ? (d) => setState(() {
                    _dragValue =
                        (d.localPosition.dx / width).clamp(0.0, 1.0);
                  })
              : null,
          onPanEnd: widget.enabled
              ? (_) {
                  final value = _dragValue;
                  setState(() => _dragValue = null);
                  if (value != null) widget.onSeek(value);
                }
              : null,
          child: SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  width: width,
                  decoration: BoxDecoration(
                    color: trackBg,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Container(
                  height: 3,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: widget.enabled
                        ? widget.foregroundColor
                        : widget.foregroundColor.withAlpha(100),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                if (thumbSize > 0)
                  Positioned(
                    left: (fillWidth - thumbSize / 2).clamp(0.0, width - thumbSize),
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.foregroundColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
