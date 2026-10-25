import '../../talky_api_client.dart' show TalkyException;
import '../utils/app_exceptions.dart';
import '../utils/media_staging.dart' show MediaStagingException;
import 'error_kind.dart';

/// Domaine fonctionnel où la panne s'est produite.
///
/// Sert uniquement à choisir le repli quand ni le code serveur ni la nature de
/// la panne ne donnent de phrase précise : « La réunion n'a pas pu s'ouvrir »
/// aide davantage que « Une erreur est survenue ».
enum ErrorDomain {
  auth,
  chat,
  appel,
  reunion,
  qr,
  media,
  trajet,
  statut,
  profil,
  admin,
  abonnement,
  stickers,
  generique,
}

/// Description normalisée d'une panne, prête à être traduite.
///
/// Point de passage obligé entre « une exception est remontée » et « une phrase
/// s'affiche ». Ne contient aucun texte destiné à l'utilisateur : c'est
/// `presenterErreur` qui choisit les mots, à partir de [code] puis [kind].
///
/// [cause] n'est là que pour la journalisation et Crashlytics. Elle ne doit
/// **jamais** être interpolée dans un message affiché — c'est précisément ce
/// que cet audit corrige.
class AppError implements Exception {
  /// Code machine stable envoyé par le backend (`TRUST_LIST_EMPTY`…).
  ///
  /// Nul tant que la route serveur n'a pas été migrée : le client sait s'en
  /// passer et retombe sur [kind].
  final String? code;

  /// Statut HTTP, ou `0` quand la requête n'a jamais abouti. Nul hors HTTP.
  final int? statusCode;

  /// Nature de la panne, toujours renseignée.
  final ErrorKind kind;

  /// Exception d'origine, pour les journaux uniquement.
  final Object? cause;

  const AppError({
    required this.kind,
    this.code,
    this.statusCode,
    this.cause,
  });

  /// Normalise n'importe quoi en [AppError].
  ///
  /// Une [AppError] déjà construite passe telle quelle : un service peut donc
  /// classer finement une panne qu'il est seul à comprendre (acquisition média,
  /// refus d'entrée en réunion) sans que l'écran ait à la reclasser.
  factory AppError.from(Object? erreur) {
    if (erreur is AppError) return erreur;

    if (erreur is TalkyException) {
      // La cause d'origine, quand elle a survécu, classe mieux que le statut :
      // elle distingue une coupure réseau d'un délai dépassé, là où le statut
      // `0` les confond.
      final parCause = kindPourException(erreur.cause);
      return AppError(
        code: erreur.code,
        statusCode: erreur.statusCode,
        kind: parCause != ErrorKind.inconnu
            ? parCause
            : kindPourStatut(erreur.statusCode),
        cause: erreur,
      );
    }

    if (erreur is MediaStagingException) {
      return AppError(kind: erreur.kind, cause: erreur);
    }

    if (erreur is AppException) {
      final statut = erreur.statusCode;
      return AppError(
        code: erreur.code,
        statusCode: statut,
        kind: statut != null ? kindPourStatut(statut) : ErrorKind.inconnu,
        cause: erreur,
      );
    }

    return AppError(kind: kindPourException(erreur), cause: erreur);
  }

  /// Étiquette courte pour les journaux et Crashlytics.
  ///
  /// C'est ce que l'écran cesse de montrer et que le rapport d'incident gagne :
  /// la capacité de diagnostic ne baisse pas, elle change de destinataire.
  String get diagnostic {
    final morceaux = <String>[kind.name];
    if (code != null) morceaux.add(code!);
    if (statusCode != null) morceaux.add('HTTP $statusCode');
    return morceaux.join(' · ');
  }

  @override
  String toString() => 'AppError($diagnostic)';
}
