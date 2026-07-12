import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Dimensions standard du PiP vidéo (identiques à l'ancien `_LocalPiP`).
const double kPipWidth = 110;
const double kPipHeight = 160;

/// Seuil de déplacement (px) au-delà duquel un geste est considéré comme un drag.
const double kPipDragThreshold = 8;

/// Zone dans laquelle le PiP peut être positionné.
class PipLayoutBounds {
  const PipLayoutBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

/// Hauteur réservée à la top bar (nom + durée + chevron).
const double kCallTopBarHeight = 80;

/// Hauteur réservée aux contrôles du bas (boutons + safe area approximative).
const double kCallBottomControlsHeight = 140;

/// Calcule les bornes du PiP selon le mode normal ou immersif.
PipLayoutBounds computePipBounds({
  required Size screenSize,
  required EdgeInsets safeArea,
  required bool controlsVisible,
}) {
  const margin = AppSpacing.lg;
  const pipW = kPipWidth;
  const pipH = kPipHeight;

  if (controlsVisible) {
    return PipLayoutBounds(
      minX: margin,
      minY: safeArea.top + kCallTopBarHeight,
      maxX: screenSize.width - pipW - margin,
      maxY: screenSize.height - kCallBottomControlsHeight - pipH,
    );
  }

  return PipLayoutBounds(
    minX: margin,
    minY: safeArea.top + AppSpacing.md,
    maxX: screenSize.width - pipW - margin,
    maxY: screenSize.height - safeArea.bottom - pipH - AppSpacing.md,
  );
}

/// Position par défaut : coin supérieur droit.
Offset defaultPipOffset(PipLayoutBounds bounds) {
  return Offset(bounds.maxX, bounds.minY);
}

/// Borne une position de PiP dans [bounds].
Offset clampPipOffset(Offset position, PipLayoutBounds bounds) {
  return Offset(
    position.dx.clamp(bounds.minX, bounds.maxX),
    position.dy.clamp(bounds.minY, bounds.maxY),
  );
}

/// PiP vidéo déplaçable avec tap optionnel (swap 1-à-1).
class DraggableVideoPiP extends StatefulWidget {
  const DraggableVideoPiP({
    super.key,
    required this.child,
    required this.bounds,
    this.position,
    required this.onPositionChanged,
    this.onTap,
  });

  final Widget child;
  final PipLayoutBounds bounds;
  final Offset? position;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback? onTap;

  @override
  State<DraggableVideoPiP> createState() => _DraggableVideoPiPState();
}

class _DraggableVideoPiPState extends State<DraggableVideoPiP> {
  Offset? _panStartPosition;
  Offset _accumulatedDelta = Offset.zero;
  double _dragDistance = 0;
  bool _suppressNextTap = false;
  bool _tapScale = false;

  Offset _resolvedPosition() {
    final base = widget.position ?? defaultPipOffset(widget.bounds);
    return clampPipOffset(base, widget.bounds);
  }

  void _resetPan() {
    _panStartPosition = null;
    _accumulatedDelta = Offset.zero;
    _dragDistance = 0;
  }

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = _resolvedPosition();
    _accumulatedDelta = Offset.zero;
    _dragDistance = 0;
    _suppressNextTap = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _panStartPosition;
    if (start == null) return;

    _dragDistance += details.delta.distance;
    _accumulatedDelta += details.delta;
    widget.onPositionChanged(
      clampPipOffset(start + _accumulatedDelta, widget.bounds),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragDistance < kPipDragThreshold) {
      widget.onTap?.call();
      _suppressNextTap = true;
    }
    _resetPan();
  }

  void _onTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    if (widget.onTap != null) {
      setState(() => _tapScale = true);
      Future<void>.delayed(AppDurations.fast, () {
        if (mounted) setState(() => _tapScale = false);
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final position = _resolvedPosition();

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: widget.onTap != null ? _onTap : null,
        child: AnimatedScale(
          scale: _tapScale ? 0.95 : 1.0,
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            child: _PipFrame(
              key: ValueKey(identityHashCode(widget.child)),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PipFrame extends StatelessWidget {
  const _PipFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return Container(
      width: kPipWidth,
      height: kPipHeight,
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        border: Border.all(color: callUi.pipBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: callUi.pipShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

/// Ré-clampe une position existante lorsque les bornes changent (ex. sortie du mode immersif).
Offset? reclampPipOffset(Offset? position, PipLayoutBounds bounds) {
  if (position == null) return null;
  final clamped = clampPipOffset(position, bounds);
  if ((clamped - position).distance < 0.5) return position;
  return clamped;
}
