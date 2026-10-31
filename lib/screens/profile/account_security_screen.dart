import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/billing/phone_models.dart';
import '../../core/services/biometric_lock_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/app_log.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/billing/plus_visuals.dart';
import '../../widgets/profile/settings_group.dart';
import 'change_alanya_phone_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'connected_devices_screen.dart';
import 'empreinte_screen.dart';
import 'qr_scanner_screen.dart';
import 'recovery_code_screen.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';

/// Hub Compte et sécurité : numéro, email, mot de passe, appareils, biométrie.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  /// L'offre du numéro choisi. Absente tant qu'elle n'est pas lue, ou si le
  /// serveur ne la propose pas à ce compte : la section ne s'affiche pas.
  PhoneOffer? _phoneOffer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BiometricLockService>().refreshAvailability();
      _loadPhoneOffer();
    });
  }

  Future<void> _loadPhoneOffer() async {
    try {
      final offer = PhoneOffer.fromJson(
          await context.read<TalkyApiClient>().getPhoneOffer());
      if (mounted) setState(() => _phoneOffer = offer);
    } catch (e, st) {
      // Sans l'offre, rien n'est proposé : l'écran reste utilisable.
      AppLog.w('AccountSecurity', 'Offre du numéro illisible', e, st);
    }
  }

  Future<void> _openPhoneChange(PhoneOffer offer) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeAlanyaPhoneScreen(initialOffer: offer),
      ),
    );
    if (!mounted) return;
    await _loadPhoneOffer();
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().refreshProfile();
    } catch (e, st) {
      AppLog.w('AccountSecurity', 'Profil après le choix du numéro', e, st);
    }
  }

  String _phoneSubtitle(PhoneOffer offer) {
    final l10n = context.l10n;
    final order = offer.order;
    if (order != null &&
        (order.status == PhoneOrderStatus.paying ||
            (order.heldUntil?.isAfter(DateTime.now()) ?? false))) {
      return l10n.accountSecurityPhonePending(
          AlanyaPhoneFormatter.formatDisplay(order.phone));
    }
    if (offer.credit) return l10n.accountSecurityPhoneCredit;
    return l10n.accountSecurityPhoneSubtitle(formatPlusAmount(context, offer.price));
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
    final phoneOffer = _phoneOffer;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.accountSecurityTitle),
      ),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          // Le numéro est l'identifiant de connexion : il passe en tête.
          if (phoneOffer != null && phoneOffer.purchasable) ...[
            SettingsGroup(
              title: l10n.phoneChangeProduct,
              child: SettingsNavTile(
                icon: Icons.dialpad_rounded,
                title: AlanyaPhoneFormatter.formatDisplay(user?.alanyaPhone),
                subtitle: _phoneSubtitle(phoneOffer),
                onTap: () => _openPhoneChange(phoneOffer),
              ),
            ),
            AppSpacing.vGapXxl,
          ],
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
            title: l10n.recoveryCodeTitle,
            child: SettingsNavTile(
              icon: Icons.vpn_key_outlined,
              title: l10n.recoveryCodeTitle,
              subtitle: l10n.recoveryCodeEntrySubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecoveryCodeScreen(),
                ),
              ),
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
                            content: Text(presenterErreur(l10n, e, domaine: ErrorDomain.profil)),
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
          // Documents sensibles : qui a fait sortir une copie signée.
          SettingsGroup(
            title: l10n.fingerprintCheckTitle,
            child: SettingsNavTile(
              icon: Icons.fingerprint,
              title: l10n.fingerprintCheckTitle,
              subtitle: l10n.fingerprintCheckSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmpreinteScreen()),
              ),
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
