import 'package:shared_preferences/shared_preferences.dart';

import '../utils/backend_url.dart';
import '../../talky_models.dart';

/// Parcours post-inscription : persistance par compte (alanyaID).
class OnboardingService {
  static const defaultCountryId = 10;

  static String _completedKey(int alanyaID) =>
      'onboarding_completed_$alanyaID';

  static String _stepKey(int alanyaID) => 'onboarding_step_$alanyaID';

  static String _legacySkipKey(int alanyaID) =>
      'onboarding_legacy_skip_$alanyaID';

  static String _falseCompleteFixKey(int alanyaID) =>
      'onboarding_false_complete_fix_$alanyaID';

  static String _startedKey(int alanyaID) => 'onboarding_started_$alanyaID';

  /// Mot de passe affiché une seule fois sur l'écran identifiants (post-signup).
  static String? pendingSignupPassword;

  /// Code de récupération renvoyé par l'inscription. Il ne transite qu'une fois
  /// (la réponse de `register`) : ni `getMe` ni aucun autre endpoint ne le
  /// redonne sans le mot de passe. D'où ce passage de main en mémoire, comme
  /// pour [pendingSignupPassword].
  static String? pendingRecoveryCode;

  Future<bool> isCompleted(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey(alanyaID)) ?? false;
  }

  Future<void> markCompleted(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey(alanyaID), true);
    await prefs.remove(_stepKey(alanyaID));
    await prefs.remove(_startedKey(alanyaID));
  }

  Future<void> clear(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey(alanyaID));
    await prefs.remove(_stepKey(alanyaID));
    await prefs.remove(_startedKey(alanyaID));
  }

  /// Marque un compte comme « sorti tout juste de l'inscription ».
  ///
  /// Sans ce drapeau, un compte créé AVEC un e-mail satisfait déjà
  /// [profileLooksComplete] : si l'app est tuée pendant l'onboarding, la reprise
  /// (qui passe par [needsOnboarding] sans `afterRegister`) sauterait le
  /// parcours — et l'écran identifiants, seul endroit où le code de récupération
  /// est affiché, ne serait jamais revu.
  Future<void> markStarted(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startedKey(alanyaID), true);
  }

  Future<bool> isStarted(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_startedKey(alanyaID)) ?? false;
  }

  Future<int> getStepIndex(int alanyaID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_stepKey(alanyaID)) ?? 0;
  }

  Future<void> setStepIndex(int alanyaID, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey(alanyaID), index);
  }

  /// Ancien parcours 8 écrans → 3 écrans (identifiants, profil, personnalisation).
  static int normalizeStepIndex(int saved, {int stepCount = 3}) {
    if (saved <= 0) return 0;
    if (saved <= 4) return 1;
    return stepCount - 1;
  }

  /// Comptes existants : profil déjà renseigné → pas d'onboarding forcé.
  /// Ignore les sentinels backend (`NON DEFINI`, etc.) pour l'avatar.
  bool profileLooksComplete(User user) {
    final hasAvatar = !isPlaceholderBackendUrl(user.avatarUrl);
    return user.idPays != defaultCountryId ||
        hasAvatar ||
        user.email.trim().isNotEmpty ||
        user.bio.trim().isNotEmpty;
  }

  Future<bool> needsOnboarding(
    User user, {
    bool afterRegister = false,
  }) async {
    if (afterRegister) return true;

    final prefs = await SharedPreferences.getInstance();
    final id = user.alanyaID;

    // Corrige une seule fois les faux « complétés » (bug avatar sentinelle).
    if (await isCompleted(id) && !profileLooksComplete(user)) {
      final fixed = prefs.getBool(_falseCompleteFixKey(id)) ?? false;
      if (!fixed) {
        await clear(id);
        await prefs.setBool(_falseCompleteFixKey(id), true);
        return true;
      }
    }

    if (await isCompleted(id)) return false;

    // Un parcours commencé mais non terminé se reprend toujours, quel que soit
    // l'état du profil : les raccourcis ci-dessous ne servent qu'aux comptes
    // antérieurs à l'onboarding.
    if (await isStarted(id)) return true;

    if (prefs.getBool(_legacySkipKey(id)) ?? false) return false;

    if (profileLooksComplete(user)) {
      await prefs.setBool(_legacySkipKey(id), true);
      return false;
    }
    return true;
  }
}
