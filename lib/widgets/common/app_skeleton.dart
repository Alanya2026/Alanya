import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palette shimmer alignée sur le web (clair / sombre).
class _SkeletonPalette {
  const _SkeletonPalette({
    required this.base,
    required this.highlight,
  });

  final Color base;
  final Color highlight;

  factory _SkeletonPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _SkeletonPalette(
            base: const Color(0xFF333338),
            highlight: Colors.white.withValues(alpha: 0.28),
          )
        : _SkeletonPalette(
            base: const Color(0xFFE4E4E7),
            highlight: Colors.white.withValues(alpha: 0.95),
          );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required this.palette,
    required super.child,
  });

  final Animation<double> animation;
  final _SkeletonPalette palette;

  static _ShimmerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();
  }

  @override
  bool updateShouldNotify(covariant _ShimmerScope oldWidget) =>
      oldWidget.animation != animation || oldWidget.palette != palette;
}

/// Synchronise le shimmer de tous les [AppSkeleton] descendants.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _SkeletonPalette.of(context);
    return _ShimmerScope(
      animation: _controller,
      palette: palette,
      child: widget.child,
    );
  }
}

/// Bloc skeleton avec shimmer pour les états de chargement.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  Animation<double>? _scopedAnimation;
  _SkeletonPalette? _scopedPalette;
  AnimationController? _ownController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _ShimmerScope.maybeOf(context);
    if (scope != null) {
      _scopedAnimation = scope.animation;
      _scopedPalette = scope.palette;
      _ownController?.dispose();
      _ownController = null;
    } else if (_ownController == null) {
      _ownController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1250),
      )..repeat();
      _scopedAnimation = _ownController;
      _scopedPalette = _SkeletonPalette.of(context);
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _scopedAnimation;
    final palette = _scopedPalette ?? _SkeletonPalette.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    if (animation == null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: ColoredBox(color: palette.base),
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _ShimmerPainter(
                progress: animation.value,
                base: palette.base,
                highlight: palette.highlight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.progress,
    required this.base,
    required this.highlight,
  });

  final double progress;
  final Color base;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final double band = math.max(size.width * 0.65, 96.0);
    final travel = size.width + band * 2;
    final start = -band + travel * progress;

    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        highlight.withValues(alpha: highlight.a * 0.35),
        highlight,
        highlight.withValues(alpha: highlight.a * 0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 0.42, 0.5, 0.58, 1.0],
    ).createShader(Rect.fromLTWH(start, 0, band, size.height));

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight;
}

const _rowWidths = [
  (phone: 116.0, label: 0.42, meta: 0.58),
  (phone: 104.0, label: 0.36, meta: 0.48),
  (phone: 128.0, label: 0.44, meta: 0.52),
  (phone: 112.0, label: 0.38, meta: 0.46),
  (phone: 120.0, label: 0.40, meta: 0.50),
  (phone: 108.0, label: 0.34, meta: 0.44),
];

/// Ligne skeleton pour un numéro réservé.
class ReservedPhoneRowSkeleton extends StatelessWidget {
  const ReservedPhoneRowSkeleton({
    super.key,
    this.compact = false,
    this.index = 0,
    this.showDivider = true,
  });

  final bool compact;
  final int index;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final widths = _rowWidths[index % _rowWidths.length];
    final divider = Theme.of(context).dividerColor.withValues(alpha: 0.45);

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const badgeW = 56.0;
                    const gap = 8.0;
                    final phoneW = compact
                        ? math.min(96.0, constraints.maxWidth)
                        : math.min(
                            widths.phone,
                            math.max(48.0, constraints.maxWidth - badgeW - gap),
                          );
                    return Wrap(
                      spacing: gap,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppSkeleton(
                          width: phoneW,
                          height: compact ? 14 : 16,
                        ),
                        if (!compact)
                          const AppSkeleton(
                            width: badgeW,
                            height: 18,
                            borderRadius: BorderRadius.all(Radius.circular(999)),
                          ),
                      ],
                    );
                  },
                ),
                SizedBox(height: compact ? 8 : 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AppSkeleton(
                      width: constraints.maxWidth * widths.label,
                      height: compact ? 12 : 14,
                    );
                  },
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return AppSkeleton(
                        width: constraints.maxWidth * widths.meta,
                        height: 12,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            const AppSkeleton(
              width: 80,
              height: 34,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(width: 2),
            const AppSkeleton(
              width: 36,
              height: 36,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ],
        ],
      ),
    );

    if (!showDivider) return row;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: row,
    );
  }
}

/// Liste de lignes skeleton pour numéros réservés.
class ReservedPhoneListSkeleton extends StatelessWidget {
  const ReservedPhoneListSkeleton({
    super.key,
    this.count = 6,
    this.compact = false,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      children: List.generate(
        count,
        (i) => ReservedPhoneRowSkeleton(
          compact: compact,
          index: i,
          showDivider: i < count - 1,
        ),
      ),
    );

    if (!compact) {
      return ShimmerScope(child: list);
    }

    return ShimmerScope(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          ),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: list,
        ),
      ),
    );
  }
}

/// Section liste complète : filtres + lignes + pagination.
class ReservedPhonesListSectionSkeleton extends StatelessWidget {
  const ReservedPhonesListSectionSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeleton(height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 12),
          const AppSkeleton(
            height: 48,
            width: 144,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(height: 16),
          ReservedPhoneListSkeleton(count: count),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: AppSkeleton(
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: AppSkeleton(
                  height: 36,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: AppSkeleton(
                  height: 36,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton compact pour la recherche dans le formulaire de création utilisateur.
class ReservedPhoneSearchSkeleton extends StatelessWidget {
  const ReservedPhoneSearchSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeleton(
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(height: 8),
          ReservedPhoneListSkeleton(count: count, compact: true),
        ],
      ),
    );
  }
}
