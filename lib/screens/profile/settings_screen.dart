import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/services/media_download_preferences.dart';
import '../../core/services/ringtone_preferences.dart';
import 'privacy_screen.dart';
import 'notification_settings_screen.dart';
import 'ringtone_settings_screen.dart';
import 'account_security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          _SettingsGroup(
            title: l10n.accountSecurityTitle,
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
                  Icons.shield_outlined,
                  color: context.colors.onSurfaceVariant,
                  size: AppIconSize.md,
                ),
              ),
              title: Text(
                l10n.accountSecurityTitle,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                l10n.accountSecuritySubtitle,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSecurityScreen(),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
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
                  onSelectionChanged: (s) => tc.setMode(s.first),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
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
                  onSelectionChanged: (s) => lc.setPreference(s.first),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
            title: l10n.settingsMedia,
            child: Consumer<MediaDownloadPreferences>(
              builder: (_, prefs, __) => Column(
                children: [
                  SwitchListTile(
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
                        Icons.download_rounded,
                        color: context.colors.onSurfaceVariant,
                        size: AppIconSize.md,
                      ),
                    ),
                    title: Text(
                      l10n.settingsAutoDownload,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      l10n.settingsAutoDownloadSubtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    value: prefs.autoDownload,
                    onChanged: prefs.setAutoDownload,
                  ),
                  SwitchListTile(
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
                        Icons.photo_library_outlined,
                        color: context.colors.onSurfaceVariant,
                        size: AppIconSize.md,
                      ),
                    ),
                    title: Text(
                      l10n.settingsMediaVisibility,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      l10n.settingsMediaVisibilitySubtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    value: prefs.mediaVisibility,
                    onChanged: prefs.setMediaVisibility,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
            title: l10n.settingsNotifications,
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
                  Icons.notifications_outlined,
                  color: context.colors.onSurfaceVariant,
                  size: AppIconSize.md,
                ),
              ),
              title: Text(
                l10n.settingsNotifications,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                l10n.settingsNotificationsSubtitle,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
            title: l10n.settingsCalls,
            child: Consumer<RingtonePreferences>(
              builder: (_, prefs, __) => ListTile(
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
                    Icons.music_note_outlined,
                    color: context.colors.onSurfaceVariant,
                    size: AppIconSize.md,
                  ),
                ),
                title: Text(
                  l10n.settingsRingtone,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  prefs.selectedId == RingtoneOption.systemId
                      ? l10n.ringtoneSystemDefaultLabel
                      : prefs.selected.label,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.colors.outlineVariant,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RingtoneSettingsScreen()),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
          _SettingsGroup(
            title: l10n.settingsPrivacy,
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
                l10n.settingsPrivacy,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                l10n.settingsPrivacySubtitle,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.colors.outlineVariant,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

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
          width: double.infinity,
          color: context.colors.surface,
          child: child,
        ),
      ],
    );
  }
}
