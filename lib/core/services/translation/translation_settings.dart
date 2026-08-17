import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/locale_controller.dart';
import 'translation_languages.dart';

/// Réglages de traduction, persistés localement (miroir de [LocaleController]).
///
/// **Volontairement non synchronisés avec le serveur**, contrairement au reste
/// des préférences applicatives (`user_settings`, migration 032) : la
/// traduction s'appuie sur des modèles ML Kit téléchargés *par appareil*. Un
/// réglage synchronisé promettrait sur un téléphone une traduction que seul un
/// autre pourrait rendre.
class TranslationSettings extends ChangeNotifier {
  static const _kAutoKey = 'translation_auto';
  static const _kTargetKey = 'translation_target';

  static TranslationSettings? _instance;
  static TranslationSettings? get maybeInstance => _instance;
  static TranslationSettings get instance =>
      _instance ?? (throw StateError('TranslationSettings not ready'));

  TranslationSettings() {
    _instance = this;
  }

  bool _auto = false;
  String _target = _defaultTarget();

  /// Traduction automatique des messages entrants. `false` par défaut :
  /// personne n'est traduit sans l'avoir demandé.
  bool get auto => _auto;

  /// Langue de lecture, en BCP-47.
  ///
  /// Indépendante de la langue d'interface : un lusophone peut utiliser l'app
  /// en français et lire ses messages en portugais.
  String get target => _target;

  /// Langue de l'interface si elle fait partie des cibles proposées, français
  /// sinon. `platformResolvedLocale` est sûre hors arbre de widgets.
  static String _defaultTarget() {
    final code = platformResolvedLocale().languageCode;
    final known = kTranslationTargets.any((l) => l.code == code);
    return known ? code : 'fr';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _auto = prefs.getBool(_kAutoKey) ?? false;
    final saved = prefs.getString(_kTargetKey);
    if (saved != null && kTranslationTargets.any((l) => l.code == saved)) {
      _target = saved;
    }
    notifyListeners();
  }

  Future<void> setAuto(bool value) async {
    if (_auto == value) return;
    _auto = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoKey, value);
  }

  /// Change la langue de lecture.
  ///
  /// Les traductions déjà en base visaient l'ancienne langue : c'est au
  /// service de traduction, qui écoute ce notifieur, de les invalider. Les
  /// laisser afficherait durablement des bulles dans une langue que
  /// l'utilisateur vient précisément de quitter.
  Future<void> setTarget(String code) async {
    if (_target == code) return;
    if (!kTranslationTargets.any((l) => l.code == code)) return;
    _target = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTargetKey, code);
  }

  @override
  void dispose() {
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }
}
