import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/biometric_lock_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/profile/settings_group.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'connected_devices_screen.dart';
import 'qr_scanner_screen.dart';

/// Hub Compte et sécurité : email, mot de passe, appareils, biométrie.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BiometricLockService>().refreshAvailability();
    });
  }

  Future<void> _logoutAllDevices(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.logoutAllDevices),
        content: Text(l10n.logoutAllDevicesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logoutAllDevicesAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final api = context.read<TalkyApiClient>();
      final sessions = await api.listDeviceSessions();
      for (final raw in sessions) {
        final id = raw['id'] as int? ?? int.tryParse('${raw['id']}') ?? 0;
        final isCurrent = raw['current'] == true;
        if (id > 0 && !isCurrent) {
          await api.revokeDeviceSession(id);
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.logoutAllDevicesDone)),
      );
    } catch (e, st) {
      AppLog.e('AccountSecurity', 'Déconnexion globale échouée', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.logoutAllDevicesFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final biometric = context.watch<BiometricLockService>();
    final email = user?.email.trim() ?? '';
    final hasEmail = email.isNotEmpty;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.accountSecurityTitle),
      ),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          if (!hasEmail) ...[
            Padding(
              padding: AppSpacing.screenH,
              child: WarningBanner(
                message: l10n.emailMissingRecoveryBanner,
              ),
            ),
            AppSpacing.vGapXxl,
          ],
          SettingsGroup(
            title: l10n.emailLabel,
            child: SettingsNavTile(
              icon: hasEmail ? Icons.email_outlined : Icons.warning_amber_rounded,
              title: hasEmail ? email : l10n.emailNotSet,
              subtitle: l10n.emailNeededForRecovery,
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
          SettingsGroup(
            title: l10n.changePasswordTitle,
            child: SettingsNavTile(
              icon: Icons.lock_outline,
              title: l10n.changePasswordTitle,
              subtitle: l10n.changePasswordSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.accountSecuritySectionProtection,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              secondary: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: context.colors.onSurfaceVariant,
                  size: AppIconSize.md,
                ),
              ),
              title: Text(
                l10n.biometricLock,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                biometric.hasBiometricHardware
                    ? l10n.biometricLockSubtitle
                    : l10n.biometricLockUnavailable,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              value: biometric.isEnabled,
              onChanged: biometric.hasBiometricHardware
                  ? (v) async {
                      try {
                        await biometric.setEnabled(
                          v,
                          confirmationReason: l10n.biometricLockEnableConfirm,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.biometricLockFailed('$e')),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.qrDevicesEntryTitle,
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.devices_outlined,
                  title: l10n.qrDevicesEntryTitle,
                  subtitle: l10n.qrDevicesEntrySubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConnectedDevicesScreen(),
                    ),
                  ),
                ),
                SettingsNavTile(
                  icon: Icons.logout,
                  title: l10n.logoutAllDevices,
                  subtitle: l10n.logoutAllDevicesSubtitle,
                  onTap: () => _logoutAllDevices(context),
                ),
              ],
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.qrLinkDeviceTitle,
            child: SettingsNavTile(
              icon: Icons.qr_code_scanner,
              title: l10n.qrLinkDeviceTitle,
              subtitle: l10n.qrLinkDeviceSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}
