import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Variantes sémantiques d'un chip d'état.
enum StatusChipTone { neutral, brand, success, warning, error, info }

/// Petit chip d'état coloré (« En cours », « À venir », « Terminé »…).
///
/// Couleur de fond = container atténué, texte = couleur pleine, pour un rendu
/// lisible et cohérent quelle que soit la sémantique.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusChipTone.neutral,
    this.icon,
  });

  final String label;
  final StatusChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sem = context.semantic;

    final (Color fg, Color bg) = switch (tone) {
      StatusChipTone.neutral => (colors.onSurfaceVariant, sem.surfaceMuted),
      StatusChipTone.brand => (colors.primary, colors.primaryContainer),
      StatusChipTone.success => (sem.success, sem.successContainer),
      StatusChipTone.warning => (sem.warning, sem.warningContainer),
      StatusChipTone.error => (colors.error, colors.errorContainer),
      StatusChipTone.info => (sem.info, sem.infoContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
