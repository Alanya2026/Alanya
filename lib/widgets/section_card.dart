import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Carte blanche arrondie réutilisable, avec titre optionnel et action
/// « Voir tout » (>) à droite. Sert de conteneur aux sections de la fiche.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.onSeeAll,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final String? title;
  final VoidCallback? onSeeAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: AppSpacing.screenH,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerHigh : colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(color: colors.outline.withValues(alpha: 0.55))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title!, style: context.text.titleSmall),
                  if (onSeeAll != null)
                    TextButton(
                      onPressed: onSeeAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.seeAll,
                            style: context.text.labelMedium?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: colors.primary,
                            size: AppIconSize.sm,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
