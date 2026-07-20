import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connectivity_provider.dart';

/// Bandeau discret « hors ligne » basé sur le réseau OS (`isOnline`),
/// pas sur le socket (évite le clignotement à la reconnexion).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message,
    this.wrapSafeArea = true,
  });

  /// Message override. Sinon clé l10n `offlineBanner`.
  final String? message;

  /// `false` sous une AppBar (évite le double padding status-bar).
  final bool wrapSafeArea;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, conn, _) {
        if (conn.isOnline) return const SizedBox.shrink();
        final colors = context.colors;
        final l10n = AppLocalizations.of(context);
        final content = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: context.semantic.warning,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  message ??
                      l10n?.offlineBanner ??
                      context.l10n.offlineBanner,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
        return Material(
          color: context.semantic.warningContainer,
          child: wrapSafeArea
              ? SafeArea(bottom: false, child: content)
              : content,
        );
      },
    );
  }
}
