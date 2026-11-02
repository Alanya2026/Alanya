import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/billing/entitlement_service.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/services/call/video_capture_profile.dart';
import '../../core/services/media_download_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/profile/settings_group.dart';

/// Wi-Fi uniquement, économiseur de données et qualité des appels vidéo. Les
/// réglages médias ont rejoint le groupe « Médias » de l'écran Paramètres,
/// où on les trouve.
class NetworkDataScreen extends StatelessWidget {
  const NetworkDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.networkDataTitle)),
      body: Consumer<MediaDownloadPreferences>(
        builder: (_, prefs, __) => ListView(
          children: [
            AppSpacing.vGapLg,
            SettingsGroup(
              title: l10n.networkDataSectionNetwork,
              child: Column(
                children: [
                  SettingsBoolTile(
                    icon: Icons.wifi,
                    title: l10n.networkWifiOnly,
                    subtitle: l10n.networkWifiOnlySubtitle,
                    value: prefs.wifiOnly,
                    onChanged: prefs.setWifiOnly,
                  ),
                  SettingsBoolTile(
                    icon: Icons.data_saver_on_outlined,
                    title: l10n.networkDataSaver,
                    subtitle: l10n.networkDataSaverSubtitle,
                    value: prefs.dataSaver,
                    onChanged: prefs.setDataSaver,
                  ),
                ],
              ),
            ),
            AppSpacing.vGapLg,
            const _CallVideoQualityGroup(),
            AppSpacing.vGapXxl,
          ],
        ),
      ),
    );
  }
}

/// Basse résolution, standard (par défaut) ou HD, réservée à Alanya Plus.
/// Sans le droit, la HD enregistrée reste gardée mais l'écran montre le
/// niveau réellement appliqué : le standard.
class _CallVideoQualityGroup extends StatelessWidget {
  const _CallVideoQualityGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = context.watch<CallVideoQualityPreferences>();
    final hdAllowed =
        context.watch<EntitlementService>().has(PlusFeature.videoHd);
    final shown = CallVideoQualityPreferences.effectiveFor(
      prefs.quality,
      hdAllowed: hdAllowed,
    );

    (String, String) copy(CallVideoQuality q) => switch (q) {
          CallVideoQuality.low => (
              l10n.callVideoQualityLow,
              l10n.callVideoQualityLowSubtitle,
            ),
          CallVideoQuality.standard => (
              l10n.callVideoQualityStandard,
              l10n.callVideoQualityStandardSubtitle,
            ),
          CallVideoQuality.hd => (
              l10n.callVideoQualityHd,
              l10n.callVideoQualityHdSubtitle,
            ),
        };

    return SettingsGroup(
      title: l10n.callVideoQualitySection,
      child: RadioGroup<CallVideoQuality>(
        groupValue: shown,
        onChanged: (q) {
          if (q == null) return;
          if (q == CallVideoQuality.hd &&
              !guardPlus(context, PlusFeature.videoHd)) {
            return;
          }
          prefs.setQuality(q);
        },
        child: Column(
          children: [
            for (final q in CallVideoQuality.values)
              RadioListTile<CallVideoQuality>(
                value: q,
                title: Text(copy(q).$1),
                subtitle: Text(copy(q).$2),
                secondary: q == CallVideoQuality.hd && !hdAllowed
                    ? Icon(
                        Icons.workspace_premium_outlined,
                        color: context.colors.primary,
                      )
                    : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(
                l10n.callVideoQualityNote,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
