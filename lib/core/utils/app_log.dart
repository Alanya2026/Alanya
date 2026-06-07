import 'dart:developer' as developer;

/// Journalisation centralisée de Talky.
///
/// Remplace les `debugPrint` ad hoc et, surtout, les `catch (_) {}` qui
/// avalaient silencieusement des erreurs réseau/données. Repose sur
/// `dart:developer` (structuré : tag, niveau, erreur, stack — visible dans
/// DevTools et la console), sans dépendance externe.
///
/// Niveaux alignés sur la convention `package:logging` :
/// 700=info, 900=warning, 1000=error.
class AppLog {
  AppLog._();

  /// Information de déroulé (peu verbeux).
  static void i(String tag, String message) =>
      _log(tag, message, level: 700);

  /// Avertissement : anomalie non bloquante (best-effort qui a échoué).
  static void w(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(tag, message, level: 900, error: error, st: st);

  /// Erreur : opération importante qui a échoué (réseau, données, parsing…).
  static void e(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(tag, message, level: 1000, error: error, st: st);

  static void _log(
    String tag,
    String message, {
    int level = 0,
    Object? error,
    StackTrace? st,
  }) {
    developer.log(
      message,
      name: tag,
      level: level,
      error: error,
      stackTrace: st,
    );
  }
}
