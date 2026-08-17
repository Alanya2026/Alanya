import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../theme/locale_controller.dart';
import '../theme/theme_controller.dart';
import 'playback_speed_preferences.dart';

/// Synchronise les réglages applicatifs avec le serveur et les contrôleurs locaux.
class AppSettingsSyncService extends ChangeNotifier {
  static const _reduceMotionKey = 'app_reduce_motion';
  static const _fontScaleKey = 'app_font_scale';

  final TalkyApiClient _api;

  AppSettingsSyncService({TalkyApiClient? api})
      : _api = api ?? TalkyApiClient();

  static bool _reduceMotion = false;
  static double _fontScale = 1.0;

  static bool get reduceMotion => _reduceMotion;
  static double get fontScale => _fontScale;

  /// Charge les réglages locaux (reduceMotion, fontScale) avant le premier frame.
  static Future<void> preloadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _reduceMotion = prefs.getBool(_reduceMotionKey) ?? false;
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
  }

  /// Récupère les réglages serveur et les applique localement (connexion / reprise).
  Future<AppSettings> syncFromServer({
    ThemeController? theme,
    LocaleController? locale,
  }) async {
    final remote = await _api.getAppSettings();
    await applyLocally(remote, theme: theme, locale: locale);
    return remote;
  }

  /// Pousse un patch partiel vers le serveur puis réapplique la réponse.
  Future<AppSettings> patchAndSync(
    Map<String, dynamic> patch, {
    ThemeController? theme,
    LocaleController? locale,
  }) async {
    final remote = await _api.patchAppSettings(patch);
    await applyLocally(remote, theme: theme, locale: locale);
    return remote;
  }

  /// Applique les réglages aux contrôleurs et préférences locales.
  Future<void> applyLocally(
    AppSettings settings, {
    ThemeController? theme,
    LocaleController? locale,
  }) async {
    if (theme != null) {
      await theme.setMode(_themeModeFromString(settings.themeMode));
    }
    if (locale != null) {
      await locale.setPreference(_localeFromString(settings.locale));
    }

    await PlaybackSpeedPreferences.setSpeed(
      PlaybackSpeedKind.voice,
      settings.playbackSpeedVoice,
    );
    await PlaybackSpeedPreferences.setSpeed(
      PlaybackSpeedKind.music,
      settings.playbackSpeedMusic,
    );
    await PlaybackSpeedPreferences.setSpeed(
      PlaybackSpeedKind.video,
      settings.playbackSpeedVideo,
    );

    _reduceMotion = settings.reduceMotion;
    _fontScale = settings.fontScale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceMotionKey, settings.reduceMotion);
    await prefs.setDouble(_fontScaleKey, settings.fontScale);
    notifyListeners();
  }

  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }

  /// Code serveur → préférence. Tout code inconnu retombe sur « système »,
  /// jamais sur une langue forcée : un serveur en avance sur le client ne doit
  /// pas figer l'app dans une langue qu'elle ne sait pas rendre.
  AppLocalePreference _localeFromString(String code) {
    final normalized = code.toLowerCase().split(RegExp('[-_]')).first;
    for (final preference in kForcedLocalePreferences) {
      if (localeCodeOf(preference) == normalized) return preference;
    }
    return AppLocalePreference.system;
  }

  String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }

  String localeToString(AppLocalePreference preference) {
    return localeCodeOf(preference) ?? 'system';
  }
}
