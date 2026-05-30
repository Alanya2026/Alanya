import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Action rapide circulaire avec libellé (favoris, recherche, effacer…).
/// Gère un état « actif » optionnel (ex. favori ajouté → étoile pleine).
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = const Color(0xFFF59E0B),
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.primary;
    final effective = active ? activeColor : base;
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - 2,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: effective.withAlpha(active ? 38 : 22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effective, size: AppIconSize.md),
            ),
            AppSpacing.vGapSm,
            Text(label, style: context.text.labelSmall),
          ],
        ),
      ),
    );
  }
}
