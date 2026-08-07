import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/media_download_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/profile/settings_group.dart';

/// Wi-Fi uniquement et économiseur de données. Les réglages médias ont
/// rejoint le groupe « Médias » de l'écran Paramètres, où on les trouve.
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
            AppSpacing.vGapXxl,
          ],
        ),
      ),
    );
  }
}
