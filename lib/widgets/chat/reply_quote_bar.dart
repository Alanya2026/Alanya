import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// Barre de citation compacte (direction A) : accent + texte + vignette.
///
/// Sans [Expanded] glouton : la largeur suit le contenu (plafonnée), pour que
/// la bulle puisse faire `max(citation, message)` via [IntrinsicWidth].
class ReplyQuoteBar extends StatelessWidget {
  const ReplyQuoteBar({
    super.key,
    required this.accent,
    required this.body,
    required this.bodyColor,
    this.title,
    this.titleColor,
    this.thumb,
    this.onTap,
    this.thumbSize = 40,
  });

  final Color accent;
  final String body;
  final Color bodyColor;
  final String? title;
  final Color? titleColor;
  final Widget? thumb;
  final VoidCallback? onTap;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    final hasThumb = thumb != null;
    final textStyle = Theme.of(context).textTheme.bodySmall;

    final textBlock = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        hasThumb ? 5 : 6,
        hasThumb ? 6 : AppSpacing.sm + 2,
        hasThumb ? 5 : 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Text(
              title!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle?.copyWith(
                color: titleColor ?? accent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 1),
          ],
          Text(
            body,
            maxLines: title != null ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: textStyle?.copyWith(
              color: bodyColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Après IntrinsicWidth + stretch : largeur serrée → on remplit.
            final tight = constraints.hasBoundedWidth &&
                (constraints.maxWidth - constraints.minWidth).abs() < 0.5;
            final maxText = _maxTextWidth(context, constraints, hasThumb);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: tight ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 3,
                    height: hasThumb ? thumbSize : 34,
                    color: accent,
                  ),
                  if (tight)
                    Expanded(child: textBlock)
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxText),
                      child: textBlock,
                    ),
                  if (hasThumb)
                    SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: thumb,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _maxTextWidth(
    BuildContext context,
    BoxConstraints constraints,
    bool hasThumb,
  ) {
    final screenCap = MediaQuery.sizeOf(context).width * 0.75;
    final reserved = 3.0 + (hasThumb ? thumbSize : 0.0);
    final raw = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : screenCap;
    return (raw - reserved).clamp(48.0, screenCap);
  }
}
