import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Navigation par double tap : moitié gauche pour reculer, moitié droite pour
/// avancer, avec un disque translucide en retour visuel.
///
/// Le geste est posé au-dessus du lecteur en `HitTestBehavior.translucent` et
/// n'écoute que `onDoubleTapDown`, pour laisser passer le tap simple dont
/// Chewie a besoin pour afficher ses contrôles. Conséquence assumée : ce tap
/// simple est retardé du délai de reconnaissance du double tap, le temps que
/// l'arène tranche.
class DoubleTapSeekOverlay extends StatefulWidget {
  const DoubleTapSeekOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.step = const Duration(seconds: 10),
  });

  final VideoPlayerController controller;
  final Widget child;
  final Duration step;

  @override
  State<DoubleTapSeekOverlay> createState() => _DoubleTapSeekOverlayState();
}

class _DoubleTapSeekOverlayState extends State<DoubleTapSeekOverlay> {
  static const _visibleFor = Duration(milliseconds: 700);

  /// `true` = gauche, `false` = droite, `null` = rien à afficher.
  bool? _rewind;

  /// Cumul affiché : deux doubles taps rapprochés font 20 s, pas deux fois 10 s.
  int _accumulated = 0;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details, double width) {
    final value = widget.controller.value;
    if (!value.isInitialized || width <= 0) return;

    final rewind = details.localPosition.dx < width / 2;
    // Changer de côté repart de zéro : accumuler à travers un aller-retour
    // n'aurait aucun sens.
    final seconds = (_rewind == rewind ? _accumulated : 0) +
        widget.step.inSeconds;

    final delta = rewind ? -widget.step : widget.step;
    final target = value.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > value.duration ? value.duration : target);
    unawaited(widget.controller.seekTo(clamped));

    setState(() {
      _rewind = rewind;
      _accumulated = seconds;
    });

    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, () {
      if (!mounted) return;
      setState(() {
        _rewind = null;
        _accumulated = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            widget.child,
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: (d) => _onDoubleTapDown(d, width),
                // Requis pour que le recogniseur de double tap s'arme ;
                // laissé vide, le tap simple continue vers Chewie.
                onDoubleTap: () {},
              ),
            ),
            if (_rewind != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: _rewind!
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Center(
                        child: _SeekPuck(
                          rewind: _rewind!,
                          seconds: _accumulated,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeekPuck extends StatelessWidget {
  const _SeekPuck({required this.rewind, required this.seconds});

  final bool rewind;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('$rewind-$seconds'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 140),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              rewind ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              '$seconds s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
