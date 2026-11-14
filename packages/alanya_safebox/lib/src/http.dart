// Ce que le paquet attend de l'application pour parler au serveur.
//
// Le jeton, son renouvellement et la traduction des erreurs restent chez
// chaque application (téléphone, ordinateur) : le paquet ne connaît que
// cette interface.

import 'package:http/http.dart' as http;

/// Une erreur du serveur ou du réseau, telle que le coffre la lit.
///
/// [statusCode] vaut 0 quand la requête n'a jamais abouti (coupure, délai
/// dépassé) : les gestionnaires d'envois et de téléchargements réessaient.
/// L'application peut lever son propre type, pourvu qu'il implémente
/// celui-ci.
class SafeboxHttpException implements Exception {
  SafeboxHttpException(this.message, this.statusCode, {this.code, this.cause});

  /// Pour les journaux, jamais pour l'écran.
  final String message;
  final int statusCode;

  /// Code machine du serveur (`SAFEBOX_QUOTA_EXCEEDED`…).
  final String? code;

  /// Exception d'origine quand la requête n'a jamais abouti.
  final Object? cause;

  @override
  String toString() => 'SafeboxHttpException($statusCode${code == null ? '' : ', $code'}): $message';
}

/// Pourquoi un transfert direct (adresse signée) a échoué.
enum SafeboxTransferFailure {
  /// Le stockage a répondu par un refus ([SafeboxHttpException.statusCode]).
  rejected,

  /// Le transfert n'avançait plus et a été coupé.
  timeout,

  /// Le réseau a lâché.
  network,
}

abstract class SafeboxHttp {
  /// Appelle l'API du coffre (`/api/safebox[path]`) avec le jeton de
  /// l'inscrit ; renouvelle le jeton au besoin. [body] est encodé en JSON.
  /// Rend la réponse décodée ; lève une [SafeboxHttpException] en cas
  /// d'échec.
  Future<dynamic> send(String method, String path, {Map<String, String>? query, Object? body});

  /// Client des transferts directs vers le stockage : aucun jeton n'y est
  /// joint, l'adresse signée suffit.
  http.Client get transferClient;

  /// Un transfert sans aucun octet pendant cette durée est coupé.
  Duration get stallTimeout;

  /// L'erreur à lever pour un transfert direct qui échoue.
  SafeboxHttpException transferFailure(SafeboxTransferFailure kind, {int status = 0, String? code, Object? cause});
}
