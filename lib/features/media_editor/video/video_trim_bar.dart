import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import 'video_retouch.dart';

/// `m:ss`.
String formatVideoTime(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Bande de découpe : miniatures de la vidéo, deux poignées (début, fin),
/// tête de lecture. Un glissement = un seul changement ([onChangeEnd]).
/// Accessible comme deux curseurs (± 1 s par action).
class VideoTrimBar extends StatefulWidget {
  const VideoTrimBar({
    super.key,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.thumbs,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Duration duration;
  final Duration start;
  final Duration end;

  /// Tête de lecture (position du lecteur).
  final Duration position;

  /// Miniatures ; `null` pendant leur calcul.
  final List<Uint8List>? thumbs;

  /// Pendant le glissement (aperçu).
  final void Function(Duration start, Duration end) onChanged;

  /// Fin du glissement : la découpe retenue.
  final void Function(Duration start, Duration end) onChangeEnd;

  static const double height = 56;
  static const double handle = 16;

  @override
  State<VideoTrimBar> createState() => _VideoTrimBarState();
}

class _VideoTrimBarState extends State<VideoTrimBar> {
  static const _second = Duration(seconds: 1);

  /// Poignée saisie : `true` début, `false` fin, `null` aucune.
  bool? _dragging;
  late Duration _start = widget.start;
  late Duration _end = widget.end;

  @override
  void didUpdateWidget(VideoTrimBar old) {
    super.didUpdateWidget(old);
    if (_dragging == null) {
      _start = widget.start;
      _end = widget.end;
    }
  }

  int get _totalMs => widget.duration.inMilliseconds.clamp(1, 1 << 31);

  double _xOf(Duration d, double width) =>
      VideoTrimBar.handle +
      (width - 2 * VideoTrimBar.handle) * d.inMilliseconds / _totalMs;

  Duration _timeAt(double x, double width) {
    final inner = width - 2 * VideoTrimBar.handle;
    final f = ((x - VideoTrimBar.handle) / inner).clamp(0.0, 1.0);
    return Duration(milliseconds: (f * _totalMs).round());
  }

  void _move(double x, double width) {
    final t = _timeAt(x, width);
    const min = VideoRetouch.minLength;
    setState(() {
      if (_dragging == true) {
        final limit = _end - min;
        _start = t > limit ? limit : t;
        if (_start < Duration.zero) _start = Duration.zero;
      } else {
        final limit = _start + min;
        _end = t < limit ? limit : t;
        if (_end > widget.duration) _end = widget.duration;
      }
    });
    widget.onChanged(_start, _end);
  }

  void _step(bool start, int seconds) {
    const min = VideoRetouch.minLength;
    var s = widget.start;
    var e = widget.end;
    final delta = Duration(seconds: seconds);
    if (start) {
      s = s + delta;
      if (s < Duration.zero) s = Duration.zero;
      if (s > e - min) s = e - min;
    } else {
      e = e + delta;
      if (e > widget.duration) e = widget.duration;
      if (e < s + min) e = s + min;
    }
    widget.onChangeEnd(s, e);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final xs = _xOf(_start, w);
        final xe = _xOf(_end, w);
        final xp = _xOf(widget.position, w);
        final thumbs = widget.thumbs;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            final x = d.localPosition.dx;
            _dragging = (x - xs).abs() <= (x - xe).abs();
            HapticFeedback.selectionClick();
          },
          onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
          onHorizontalDragEnd: (_) {
            _dragging = null;
            widget.onChangeEnd(_start, _end);
          },
          child: SizedBox(
            height: VideoTrimBar.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Miniatures.
                Positioned(
                  left: VideoTrimBar.handle,
                  right: VideoTrimBar.handle,
                  top: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: AppRadius.brSm,
                    child: thumbs == null || thumbs.isEmpty
                        ? ColoredBox(color: colors.surfaceContainerHighest)
                        : Row(
                            children: [
                              for (final t in thumbs)
                                Expanded(
                                  child: Image.memory(
                                    t,
                                    fit: BoxFit.cover,
                                    height: VideoTrimBar.height,
                                    gaplessPlayback: true,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                // Hors découpe : voilé.
                Positioned(
                  left: VideoTrimBar.handle,
                  width: (xs - VideoTrimBar.handle).clamp(0, w),
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                Positioned(
                  left: xe,
                  right: VideoTrimBar.handle,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                ),
                // Cadre de la découpe.
                Positioned(
                  left: xs,
                  width: (xe - xs).clamp(0, w),
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: colors.onSurface,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Handle(
                  left: xs - VideoTrimBar.handle,
                  start: true,
                  label: l10n.videoTrimStart,
                  value: formatVideoTime(widget.start),
                  increased: formatVideoTime(widget.start + _second),
                  decreased: formatVideoTime(
                    widget.start > _second ? widget.start - _second : Duration.zero,
                  ),
                  onIncrease: () => _step(true, 1),
                  onDecrease: () => _step(true, -1),
                ),
                _Handle(
                  left: xe,
                  start: false,
                  label: l10n.videoTrimEnd,
                  value: formatVideoTime(widget.end),
                  increased: formatVideoTime(
                    widget.end + _second > widget.duration
                        ? widget.duration
                        : widget.end + _second,
                  ),
                  decreased: formatVideoTime(widget.end - _second),
                  onIncrease: () => _step(false, 1),
                  onDecrease: () => _step(false, -1),
                ),
                if (_dragging == null &&
                    widget.position >= _start &&
                    widget.position <= _end)
                  Positioned(
                    left: xp - 1.5,
                    top: -2,
                    bottom: -2,
                    child: IgnorePointer(
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: AppColors.drawYellow,
                          borderRadius: BorderRadius.circular(2),
                        ),
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

class _Handle extends StatelessWidget {
  const _Handle({
    required this.left,
    required this.start,
    required this.label,
    required this.value,
    required this.increased,
    required this.decreased,
    required this.onIncrease,
    required this.onDecrease,
  });

  final double left;
  final bool start;
  final String label;
  final String value;
  final String increased;
  final String decreased;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const r = Radius.circular(6);
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: VideoTrimBar.handle,
      child: Semantics(
        slider: true,
        label: label,
        value: value,
        increasedValue: increased,
        decreasedValue: decreased,
        onIncrease: onIncrease,
        onDecrease: onDecrease,
        child: Container(
          decoration: BoxDecoration(
            color: colors.onSurface,
            borderRadius: start
                ? const BorderRadius.horizontal(left: r)
                : const BorderRadius.horizontal(right: r),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 2,
            height: 18,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}
