import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_urls.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/profile/settings_group.dart';

/// Version de l'app et liens légaux.
class AboutLegalScreen extends StatefulWidget {
  const AboutLegalScreen({super.key});

  @override
  State<AboutLegalScreen> createState() => _AboutLegalScreenState();
}

class _AboutLegalScreenState extends State<AboutLegalScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSupport() async {
    if (await canLaunchUrl(LegalUrls.supportMailto)) {
      await launchUrl(LegalUrls.supportMailto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = _info?.version ?? '…';
    final build = _info?.buildNumber ?? '…';

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        children: [
          AppSpacing.vGapXxl,
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: AppRadius.brMd,
                ),
                alignment: Alignment.center,
                child: Text(
                  'A',
                  style: context.text.headlineMedium?.copyWith(
                    color: context.colors.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppSpacing.vGapMd,
              Text(
                l10n.appTitle,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.vGapXs,
              Text(
                l10n.aboutVersion(version, build),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.aboutSectionLegal,
            child: Column(
              children: [
                SettingsNavTile(
                  title: l10n.aboutTerms,
                  onTap: () => _openUrl(LegalUrls.termsOfService),
                ),
                SettingsNavTile(
                  title: l10n.aboutPrivacy,
                  onTap: () => _openUrl(LegalUrls.privacyPolicy),
                ),
                SettingsNavTile(
                  title: l10n.aboutLicenses,
                  onTap: () => _openUrl(LegalUrls.openSourceLicenses),
                ),
                SettingsNavTile(
                  title: l10n.aboutSupport,
                  onTap: _openSupport,
                ),
              ],
            ),
          ),
          AppSpacing.vGapXxl,
          Padding(
            padding: AppSpacing.screenH,
            child: Text(
              l10n.aboutCopyright,
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: context.colors.outlineVariant,
              ),
            ),
          ),
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}
