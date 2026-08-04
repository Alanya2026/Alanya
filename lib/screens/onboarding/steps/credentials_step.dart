import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/onboarding_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/account/warning_banner.dart';
import '../../../widgets/alanya_phone_field.dart';
import '../../../widgets/common/status_chip.dart';
import '../widgets/onboarding_shell.dart';

/// Étape 1 : les trois secrets du compte, affichés une seule fois.
///
/// Le mot de passe et le code de récupération arrivent par
/// [OnboardingService.pendingSignupPassword] / [OnboardingService.pendingRecoveryCode] :
/// aucun des deux n'est relisible depuis le serveur (l'un est haché, l'autre
/// exige le mot de passe), donc c'est bien ici, et nulle part ailleurs, qu'ils
/// doivent être vus.
///
/// Le code de récupération n'est montré qu'aux comptes SANS e-mail : c'est pour
/// eux qu'il est l'unique voie de retour. Les autres le retrouvent dans
/// Mon compte → Sécurité, sans encombrer ce premier écran.
class CredentialsStep extends StatelessWidget {
  const CredentialsStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().currentUser;
    final password = OnboardingService.pendingSignupPassword ?? '••••••••';
    final recoveryCode = OnboardingService.pendingRecoveryCode;
    final sansEmail = (user?.email.trim().isEmpty ?? true);
    final montrerCode = sansEmail && recoveryCode != null;

    return OnboardingShell(
      title: l10n.onboardingCredentialsTitle,
      subtitle: l10n.onboardingCredentialsSubtitle,
      onContinue: onContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WarningBanner(
            message: montrerCode
                ? l10n.onboardingCredentialsBannerNoEmail
                : l10n.onboardingCredentialsBanner,
          ),
          AppSpacing.vGapXl,
          OnboardingCard(
            child: Column(
              children: [
                _CredentialTile(
                  icon: Icons.badge_outlined,
                  label: l10n.alanyaPhone,
                  copyValue: user?.alanyaPhone ?? '',
                  copiedMessage: l10n.alanyaPhone,
                  value: AlanyaPhoneText(
                    user?.alanyaPhone ?? '',
                    style: context.text.headlineMedium?.copyWith(
                      letterSpacing: 2,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                const Divider(height: AppSpacing.xxl),
                _CredentialTile(
                  icon: Icons.lock_outline,
                  label: l10n.signupPasswordHint,
                  copyValue: password,
                  copiedMessage: l10n.signupPasswordHint,
                  value: SelectableText(
                    password,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (montrerCode) ...[
                  const Divider(height: AppSpacing.xxl),
                  _CredentialTile(
                    icon: Icons.vpn_key_outlined,
                    label: l10n.recoveryCodeTitle,
                    copyValue: recoveryCode,
                    copiedMessage: l10n.recoveryCodeCopied,
                    trailingChip: StatusChip(
                      label: l10n.recoveryCodeKeepSafe,
                      tone: StatusChipTone.warning,
                    ),
                    value: SelectableText(
                      recoveryCode,
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (montrerCode) ...[
            AppSpacing.vGapLg,
            Text(
              l10n.recoveryCodeOnboardingHint,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un secret : pastille d'icône, libellé, valeur, bouton copier.
class _CredentialTile extends StatelessWidget {
  const _CredentialTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.copyValue,
    required this.copiedMessage,
    this.trailingChip,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final String copyValue;
  final String copiedMessage;
  final Widget? trailingChip;

  Future<void> _copier(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: copyValue));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copiedMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.semantic.brandContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: AppIconSize.sm,
            color: context.colors.primary,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (trailingChip != null) ...[
                    AppSpacing.hGapSm,
                    trailingChip!,
                  ],
                ],
              ),
              AppSpacing.vGapXs,
              value,
            ],
          ),
        ),
        AppSpacing.hGapSm,
        IconButton(
          onPressed: copyValue.isEmpty ? null : () => _copier(context),
          icon: const Icon(Icons.copy_rounded, size: AppIconSize.sm),
          tooltip: context.l10n.copy,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
