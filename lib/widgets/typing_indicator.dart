import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Trois points animés (rebond décalé) — style WhatsApp / Messenger.
class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double spacing;

  const TypingIndicator({
    super.key,
    this.color,
    this.dotSize = 7,
    this.spacing = 4,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : widget.spacing),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              // Décalage de phase par point pour l'effet rebond.
              final t = (_controller.value + i * 0.2) % 1.0;
              final bounce = _bounceOffset(t);
              return Transform.translate(
                offset: Offset(0, bounce),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  /// Courbe en cloche : montée puis redescente sur une fenêtre glissante.
  double _bounceOffset(double t) {
    const peak = -5.0;
    if (t < 0.15) return 0;
    if (t < 0.45) return peak * Curves.easeOut.transform((t - 0.15) / 0.3);
    if (t < 0.75) return peak * (1 - Curves.easeIn.transform((t - 0.45) / 0.3));
    return 0;
  }
}

/// Bulle « en train d'écrire » avec entrée/sortie animée (200 ms).
class TypingBubbleSlot extends StatefulWidget {
  final bool visible;

  const TypingBubbleSlot({super.key, required this.visible});

  @override
  State<TypingBubbleSlot> createState() => _TypingBubbleSlotState();
}

class _TypingBubbleSlotState extends State<TypingBubbleSlot>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 200);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.visible) {
      _shown = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TypingBubbleSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      setState(() => _shown = true);
      _controller.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reverse().then((_) {
        if (mounted) setState(() => _shown = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();

    return SizeTransition(
      sizeFactor: _fade,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md + 2,
              ),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                boxShadow: AppShadows.subtle,
              ),
              child: TypingIndicator(color: context.colors.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
