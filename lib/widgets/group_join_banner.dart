import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Bannière discrète (style WhatsApp) pour un membre tout juste ajouté.
///
/// Fixée sous l'app bar, au-dessus du fil scrollable — pas une carte dans le
/// fil. « Rester » ack serveur ; « Quitter » appelle leaveGroup.
class GroupJoinBanner extends StatelessWidget {
  const GroupJoinBanner({
    super.key,
    required this.actorName,
    required this.groupName,
    required this.onStay,
    required this.onLeave,
    this.busy = false,
  });

  final String actorName;
  final String groupName;
  final VoidCallback onStay;
  final VoidCallback onLeave;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final semantic = context.semantic;

    return Material(
      color: semantic.surfaceMuted,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm + 2,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.groupJoinBannerBody(actorName, groupName),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            IgnorePointer(
              ignoring: busy,
              child: Opacity(
                opacity: busy ? 0.5 : 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: onStay,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: context.text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(l10n.stay),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '·',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                    TextButton(
                      onPressed: onLeave,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: context.text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(l10n.leave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
