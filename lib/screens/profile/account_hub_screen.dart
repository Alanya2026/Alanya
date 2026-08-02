import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/biometric_lock_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/account_security_score.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/profile/settings_group.dart';
import 'account_security_screen.dart';
import 'edit_profile_screen.dart';
import 'export_data_screen.dart';
import 'my_media_screen.dart';
import 'privacy_screen.dart';
import 'profile_preview_screen.dart';

/// Hub « Mon compte » : score de sécurité et raccourcis profil / protection / données.
class AccountHubScreen extends StatefulWidget {
  const AccountHubScreen({super.key});

  @override
  State<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends State<AccountHubScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<BiometricLockService>().load());
    unawaited(context.read<AuthProvider>().refreshProfile());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    await context.read<BiometricLockService>().load();
  }

  String _suggestionText(SecuritySuggestion type) {
    final l10n = context.l10n;
    return switch (type) {
      SecuritySuggestion.addEmail => l10n.securityScoreAddEmail,
      SecuritySuggestion.enableBiometric => l10n.securityScoreAddBiometric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().currentUser;
    final biometric = context.watch<BiometricLockService>();
    final security = calculateAccountSecurityScore(
      user: user,
      biometricEnabled: biometric.isEnabled,
    );

    final scoreColor = security.isStrong
        ? context.semantic.success
        : security.isModerate
            ? context.semantic.warning
            : context.colors.error;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(l10n.accountHubTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppSpacing.vGapLg,
            Padding(
              padding: AppSpacing.screenH,
              child: Container(
                padding: AppSpacing.card,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: AppRadius.brMd,
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.accountHubSecurityScore,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.accountHubSecurityScoreValue(
                            security.score,
                            security.maxScore,
                          ),
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapSm,
                    ClipRRect(
                      borderRadius: AppRadius.brPill,
                      child: LinearProgressIndicator(
                        value: security.ratio,
                        minHeight: 6,
                        backgroundColor: context.colors.outlineVariant,
                        color: scoreColor,
                      ),
                    ),
                    if (security.suggestionTypes.isNotEmpty) ...[
                      AppSpacing.vGapSm,
                      Text(
                        security.suggestionTypes
                            .map(_suggestionText)
                            .join(' '),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AppSpacing.vGapXxl,
            SettingsGroup(
              title: l10n.accountHubSectionIdentity,
              child: Column(
                children: [
                  SettingsNavTile(
                    icon: Icons.edit_outlined,
                    title: l10n.accountHubEditProfile,
                    subtitle: l10n.accountHubEditProfileSubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                  SettingsNavTile(
                    icon: Icons.photo_library_outlined,
                    title: l10n.accountHubMyMedia,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyMediaScreen(),
                      ),
                    ),
                  ),
                  SettingsNavTile(
                    icon: Icons.visibility_outlined,
                    title: l10n.accountHubProfilePreview,
                    subtitle: l10n.accountHubProfilePreviewSubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfilePreviewScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vGapXxl,
            SettingsGroup(
              title: l10n.accountHubSectionProtection,
              child: Column(
                children: [
                  SettingsNavTile(
                    icon: Icons.lock_outline,
                    title: l10n.accountHubPrivacy,
                    subtitle: l10n.accountHubPrivacySubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyScreen(),
                      ),
                    ),
                  ),
                  SettingsNavTile(
                    icon: Icons.shield_outlined,
                    title: l10n.accountHubSecurity,
                    subtitle: l10n.accountHubSecuritySubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSecurityScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vGapXxl,
            SettingsGroup(
              title: l10n.accountHubSectionData,
              child: SettingsNavTile(
                icon: Icons.inventory_2_outlined,
                title: l10n.accountHubDataAccount,
                subtitle: l10n.accountHubDataAccountSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExportDataScreen(),
                  ),
                ),
              ),
            ),
            AppSpacing.vGapXxl,
          ],
        ),
      ),
    );
  }
}
