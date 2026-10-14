import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';

/// Fait parler les tests en français, la langue de référence de l'app.
///
/// La plateforme de test est en anglais (en_US) : sans ça, `resolveL10n()`
/// rend « Video » au lieu de « Vidéo ».
///
/// [withController] crée aussi le [LocaleController] (en mode système, donc
/// français), qu'exige le code d'interface via `LocaleController.instance`.
/// Sans lui, on reproduit l'isolate FCM d'arrière-plan, où seul
/// `resolveL10n()` est permis.
void useFrenchLocale({bool withController = true}) {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('fr');
  if (withController) LocaleController();
}
