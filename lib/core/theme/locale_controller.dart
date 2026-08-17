import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Préférence de langue persistante (miroir de [ThemeController]).
///
/// ⚠️ Les valeurs sont sérialisées **en clair** sous la clé `app_locale` et
/// synchronisées vers `user_settings.locale` : on n'ajoute des cas, on n'en
/// renomme jamais. Renommer une valeur existante réinitialiserait la langue de
/// tous les appareils déjà installés.
enum AppLocalePreference {
  /// Suit la langue du système (FR si non supportée).
  system,

  /// Français forcé.
  french,

  /// Anglais forcé.
  english,

  /// Chinois (simplifié) forcé.
  chinese,
}

/// Langues d'interface, dans l'ordre d'affichage des sélecteurs.
///
/// Une seule liste pour les deux écrans qui proposent la langue (réglages et
/// onboarding) : sans elle, ajouter une langue à un endroit et l'oublier à
/// l'autre passe inaperçu.
const List<AppLocalePreference> kForcedLocalePreferences = [
  AppLocalePreference.french,
  AppLocalePreference.english,
  AppLocalePreference.chinese,
];

/// Code BCP-47 d'une préférence forcée, `null` pour [AppLocalePreference.system].
String? localeCodeOf(AppLocalePreference preference) => switch (preference) {
      AppLocalePreference.french => 'fr',
      AppLocalePreference.english => 'en',
      AppLocalePreference.chinese => 'zh',
      AppLocalePreference.system => null,
    };

/// Locale plateforme parmi les langues supportées (FR par défaut).
///
/// Utilisable **hors [LocaleController]** — isolate FCM d'arrière-plan, CallKit.
/// C'est la raison pour laquelle elle ne lit ni le contrôleur ni les
/// préférences : dans un isolate, ni l'un ni l'autre n'existe. Oublier d'y
/// ajouter une langue donne des notifications d'appel en français à un
/// utilisateur qui a mis son téléphone en chinois — et le défaut ne se voit
/// qu'app fermée.
Locale platformResolvedLocale() {
  final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  for (final preference in kForcedLocalePreferences) {
    if (localeCodeOf(preference) == code) return Locale(code);
  }
  return const Locale('fr');
}

/// l10n safe pour CallKit / notifs / isolate FCM.
///
/// Utilise [LocaleController] s'il est prêt, sinon la locale plateforme.
/// Ne lance jamais [StateError] — obligatoire dans
/// [firebaseMessagingBackgroundHandler].
AppLocalizations resolveL10n() {
  final ctrl = LocaleController.maybeInstance;
  if (ctrl != null) return ctrl.l10n;
  return lookupAppLocalizations(platformResolvedLocale());
}

/// Contrôleur de locale persistant.
///
/// Appeler [load] au démarrage. Passer [locale] à `MaterialApp.locale`
/// (`null` = système). Utiliser [resolveL10n] hors arbre de widgets (CallKit, notifs).
class LocaleController extends ChangeNotifier {
  static const _kKey = 'app_locale';

  /// Instance courante (services hors arbre : CallKit, notifs).
  static LocaleController? _instance;
  static LocaleController? get maybeInstance => _instance;
  static LocaleController get instance =>
      _instance ?? (throw StateError('LocaleController not ready'));

  LocaleController() {
    _instance = this;
  }


  AppLocalePreference _preference = AppLocalePreference.system;

  AppLocalePreference get preference => _preference;

  /// `null` = laisser Flutter résoudre via le système.
  Locale? get locale {
    final code = localeCodeOf(_preference);
    return code == null ? null : Locale(code);
  }

  /// Locale effective pour lookups hors context (FR par défaut).
  Locale get resolvedLocale {
    final code = localeCodeOf(_preference);
    return code == null ? platformResolvedLocale() : Locale(code);
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
