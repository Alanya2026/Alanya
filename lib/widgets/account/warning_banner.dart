import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

enum WarningBannerVariant { error, info }

/// Bandeau d'avertissement / info — couleurs via le thème (clair / sombre).
class WarningBanner extends StatelessWidget {
  final String message;
  final WarningBannerVariant variant;
  final IconData? icon;

  const WarningBanner({
    super.key,
    required this.message,
    this.variant = WarningBannerVariant.error,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isError = variant == WarningBannerVariant.error;
    final bg = isError
        ? context.colors.errorContainer
        : context.semantic.infoContainer;
    final fg = isError
        ? context.colors.onErrorContainer
        : context.semantic.onInfo;
    final leading = icon ??
        (isError ? Icons.warning_amber_rounded : Icons.info_outline);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(leading, color: fg, size: AppIconSize.md),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(
                color: fg,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
