import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Gros bouton d'action principal (Appel vocal / vidéo / Message) affiché
/// sous le profil dans la fiche contact. Style « pilule » moderne.
class ContactActionButton extends StatelessWidget {
  const ContactActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Expanded(
      child: Material(
        color: tint.withAlpha(20),
        borderRadius: AppRadius.brMd,
        child: InkWell(
          borderRadius: AppRadius.brMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: tint, size: AppIconSize.lg - 2),
                AppSpacing.vGapSm,
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
