import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/account/warning_banner.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';

/// Hub Compte et sécurité : email + mot de passe.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final email = user?.email.trim() ?? '';
    final hasEmail = email.isNotEmpty;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(context.l10n.accountSecurityTitle),
      ),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          if (!hasEmail) ...[
            Padding(
              padding: AppSpacing.screenH,
              child: WarningBanner(
                message: context.l10n.emailMissingRecoveryBanner,
              ),
            ),
            AppSpacing.vGapXxl,
          ],
          _Group(
            title: context.l10n.emailLabel,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasEmail
                      ? Icons.email_outlined
                      : Icons.warning_amber_rounded,
                  color: hasEmail
                      ? context.colors.onSurfaceVariant
                      : context.colors.error,
                  size: AppIconSize.md,
                ),
              ),
              title: Text(
                hasEmail ? email : context.l10n.emailNotSet,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: hasEmail
                      ? null
                      : context.colors.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                context.l10n.emailNeededForRecovery,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
              ),
              onTap: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangeEmailScreen(),
                  ),
                );
                if (ok == true && context.mounted) {
                  await context.read<AuthProvider>().refreshProfile();
                }
              },
            ),
          ),
          AppSpacing.vGapXxl,
          _Group(
            title: context.l10n.changePasswordTitle,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: context.colors.onSurfaceVariant,
                  size: AppIconSize.md,
                ),
              ),
              title: Text(
                context.l10n.changePasswordTitle,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                context.l10n.changePasswordSubtitle,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          color: context.colors.surface,
          child: child,
        ),
      ],
    );
  }
}
