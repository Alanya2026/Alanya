import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_settings_sync_service.dart';
import '../../core/services/media_download_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../providers/chat_provider.dart';
import '../../core/db/app_database.dart';
import '../../widgets/profile/settings_group.dart';
import 'about_legal_screen.dart';
import 'accessibility_screen.dart';
import 'muted_conversations_screen.dart' show isConversationMuted, MutedConversationsScreen;
import 'network_data_screen.dart';
import 'notification_settings_screen.dart';
import 'ringtone_settings_screen.dart';
import 'playback_speed_screen.dart';
import 'storage_screen.dart';
import '../../core/services/ringtone_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  int _countMuted(List<LocalConversation> convs) =>
      convs.where(isConversationMuted).length;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          SettingsGroup(
            title: l10n.settingsSectionCommunication,
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.notifications_outlined,
                  title: l10n.settingsNotifications,
                  subtitle: l10n.settingsNotificationsSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                StreamBuilder<List<LocalConversation>>(
                  stream: context.read<ChatProvider>().watchConversations(),
                  builder: (context, snapshot) {
                    final count = _countMuted(snapshot.data ?? []);
                    return SettingsNavTile(
                      icon: Icons.notifications_off_outlined,
                      title: l10n.settingsMutedConversations,
                      subtitle: count == 0
                          ? l10n.mutedConversationsEmpty
                          : l10n.mutedConversationsCount(count),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MutedConversationsScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          AppSpacing.vGapXxl,
          // Enregistrer dans la galerie était enfoui dans Réseau et données,
          // sous un libellé qui ne disait pas « galerie ». Il remonte ici, avec
          // le téléchargement automatique dont il ne se lit pas séparément.
          SettingsGroup(
            title: l10n.settingsMedia,
            child: Consumer<MediaDownloadPreferences>(
              builder: (_, prefs, __) => Column(
                children: [
                  SettingsBoolTile(
                    icon: Icons.photo_library_outlined,
                    title: l10n.settingsMediaVisibility,
                    subtitle: l10n.settingsMediaVisibilitySubtitle,
                    value: prefs.mediaVisibility,
                    onChanged: prefs.setMediaVisibility,
                  ),
                  SettingsBoolTile(
                    icon: Icons.download_rounded,
                    title: l10n.settingsAutoDownload,
                    subtitle: l10n.settingsAutoDownloadSubtitle,
                    value: prefs.autoDownload,
                    onChanged: prefs.setAutoDownload,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.settingsSectionApplication,
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.sd_storage_outlined,
                  title: l10n.settingsStorage,
                  subtitle: l10n.settingsStorageSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorageScreen()),
                  ),
                ),
                SettingsNavTile(
                  icon: Icons.wifi,
                  title: l10n.settingsNetwork,
                  subtitle: l10n.settingsNetworkSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NetworkDataScreen(),
                    ),
                  ),
                ),
                SettingsNavTile(
                  icon: Icons.speed_outlined,
                  title: l10n.playbackSpeed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlaybackSpeedScreen(),
                    ),
                  ),
                ),
                SettingsNavTile(
                  icon: Icons.accessibility_new_outlined,
                  title: l10n.settingsAccessibility,
                  subtitle: l10n.settingsAccessibilitySubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccessibilityScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.settingsAppearance,
            child: Padding(
              padding: AppSpacing.card,
              child: Consumer<ThemeController>(
                builder: (_, tc, __) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.buttonHeight),
                  ),
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: Text(l10n.settingsThemeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.nights_stay_outlined),
                      label: Text(l10n.settingsThemeDark),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(l10n.settingsThemeSystem),
                    ),
                  ],
                  selected: {tc.mode},
                  onSelectionChanged: (s) async {
                    final mode = s.first;
                    await tc.setMode(mode);
                    try {
                      await context.read<AppSettingsSyncService>().patchAndSync(
                            {
                              'themeMode': context
                                  .read<AppSettingsSyncService>()
                                  .themeModeToString(mode),
                            },
                            theme: tc,
                          );
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.settingsLanguage,
            child: Padding(
              padding: AppSpacing.card,
              child: Consumer<LocaleController>(
                builder: (_, lc, __) => SegmentedButton<AppLocalePreference>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.buttonHeight),
                  ),
                  segments: [
                    ButtonSegment(
                      value: AppLocalePreference.french,
                      icon: const Icon(Icons.language),
                      label: Text(l10n.settingsLangFr),
                    ),
                    ButtonSegment(
                      value: AppLocalePreference.english,
                      icon: const Icon(Icons.translate),
                      label: Text(l10n.settingsLangEn),
                    ),
                    ButtonSegment(
                      value: AppLocalePreference.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(l10n.settingsLangSystem),
                    ),
                  ],
                  selected: {lc.preference},
                  onSelectionChanged: (s) async {
                    final pref = s.first;
                    await lc.setPreference(pref);
                    try {
                      await context.read<AppSettingsSyncService>().patchAndSync(
                            {
                              'locale': context
                                  .read<AppSettingsSyncService>()
                                  .localeToString(pref),
                            },
                            locale: lc,
                          );
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.settingsCalls,
            child: Consumer<RingtonePreferences>(
              builder: (_, prefs, __) => SettingsNavTile(
                icon: Icons.music_note_outlined,
                title: l10n.settingsRingtone,
                subtitle: prefs.selectedId == RingtoneOption.systemId
                    ? l10n.ringtoneSystemDefaultLabel
                    : prefs.selected.label,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RingtoneSettingsScreen(),
                  ),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.settingsSectionInformation,
            child: SettingsNavTile(
              icon: Icons.info_outline,
              title: l10n.settingsAbout,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutLegalScreen()),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}
