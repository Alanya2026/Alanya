import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// État vide homogène : icône dans une pastille + titre + message + action
/// optionnelle. Remplace les `Center(child: Text(...))` disparates.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = iconColor ?? colors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: tint.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: tint),
            ),
            AppSpacing.vGapLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            if (message != null) ...[
              AppSpacing.vGapSm,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
            if (action != null) ...[
              AppSpacing.vGapLg,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Indicateur de chargement centré homogène.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          if (message != null) ...[
            AppSpacing.vGapLg,
            Text(message!, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}
