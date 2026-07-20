import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Préférence de langue persistante (miroir de [ThemeController]).
enum AppLocalePreference {
  /// Suit la langue du système (FR si non supportée).
  system,

  /// Français forcé.
  french,

  /// Anglais forcé.
  english,
}

/// Contrôleur de locale persistant.
///
/// Appeler [load] au démarrage. Passer [locale] à `MaterialApp.locale`
/// (`null` = système). Utiliser [l10n] hors arbre de widgets (CallKit, notifs).
class LocaleController extends ChangeNotifier {
  static const _kKey = 'app_locale';

  /// Instance courante (services hors arbre : CallKit, notifs).
  static LocaleController? _instance;
  static LocaleController get instance =>
      _instance ?? (throw StateError('LocaleController not ready'));

  LocaleController() {
    _instance = this;
  }


  AppLocalePreference _preference = AppLocalePreference.system;

  AppLocalePreference get preference => _preference;

  /// `null` = laisser Flutter résoudre via le système.
  Locale? get locale {
    switch (_preference) {
      case AppLocalePreference.system:
        return null;
      case AppLocalePreference.french:
        return const Locale('fr');
      case AppLocalePreference.english:
        return const Locale('en');
    }
  }

  /// Locale effective pour lookups hors context (FR par défaut).
  Locale get resolvedLocale {
    switch (_preference) {
      case AppLocalePreference.french:
        return const Locale('fr');
      case AppLocalePreference.english:
        return const Locale('en');
      case AppLocalePreference.system:
        final platform =
            WidgetsBinding.instance.platformDispatcher.locale;
        if (platform.languageCode == 'en') return const Locale('en');
        return const Locale('fr');
    }
  }

  /// Chaînes localisées sans [BuildContext] (services, CallKit…).
  AppLocalizations get l10n => lookupAppLocalizations(resolvedLocale);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    final match = AppLocalePreference.values.where((e) => e.name == raw);
    if (match.isEmpty) return;
    _preference = match.first;
    notifyListeners();
  }

  Future<void> setPreference(AppLocalePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, preference.name);
  }
}
