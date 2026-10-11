import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../theme/locale_controller.dart';
import '../utils/app_log.dart';
import 'app_error.dart';
import 'error_kind.dart';

/// Seul point de l'application autorisé à transformer une erreur en texte.
///
/// Avant cet entonnoir, chaque écran bricolait sa propre traduction — le plus
/// souvent `l10n.errorColon('$e')`, c'est-à-dire l'exception elle-même. On
/// affichait « Une erreur est survenue: SocketException: Failed host lookup ».
///
/// La résolution s'arrête au premier succès :
///
/// 1. le `code` machine du serveur, s'il est connu ;
/// 2. la nature de la panne croisée avec le domaine ;
/// 3. le repli du domaine ;
/// 4. le repli global.
///
/// L'erreur d'origine n'est **jamais** interpolée dans le résultat. Elle part
/// dans les journaux, donc dans Crashlytics : la capacité de diagnostic ne
/// baisse pas, elle change de destinataire.
String presenterErreur(
  AppLocalizations l10n,
  Object? erreur, {
  required ErrorDomain domaine,
  bool journaliser = true,
  bool avecDiagnostic = kDebugMode,
}) {
  final err = AppError.from(erreur);

  if (journaliser) {
    AppLog.w('Erreur', '${domaine.name} · ${err.diagnostic}');
  }

  final texte = _messagePourCode(l10n, err.code) ??
      _messagePourDomaineEtNature(l10n, domaine, err.kind) ??
      _messagePourNature(l10n, err.kind) ??
      _messagePourDomaine(l10n, domaine);

  // En développement seulement : garder sous les yeux ce que l'utilisateur ne
  // voit plus. `kDebugMode` étant une constante de compilation, la branche
  // disparaît des builds de production. Les tests passent `false` pour vérifier
  // exactement ce que l'utilisateur lira.
  if (avecDiagnostic) return '$texte  [${err.diagnostic}]';
  return texte;
}

/// Variante sans `BuildContext`, pour les services.
///
/// `resolveL10n()` et non `LocaleController.instance` : le contrôleur vient
/// d'un provider paresseux et n'existe pas avant le premier `build`.
String presenterErreurGlobale(
  Object? erreur, {
  required ErrorDomain domaine,
  bool journaliser = true,
}) =>
    presenterErreur(resolveL10n(), erreur,
        domaine: domaine, journaliser: journaliser);

// ── 1. Le code du serveur ───────────────────────────────────────────

/// Codes machine que l'application sait nommer.
///
/// Un code absent d'ici n'est pas une erreur : la résolution continue sur la
/// nature de la panne. C'est ce qui permet au backend d'ajouter des codes à son
/// rythme, et à l'application de rester utile sur les routes non migrées.
String? _messagePourCode(AppLocalizations l10n, String? code) {
  switch (code) {
    // Session et compte
    case 'TOKEN_EXPIRED':
    case 'REFRESH_EXPIRED':
    case 'TOKEN_INVALID':
    case 'TOKEN_REQUIRED':
      return l10n.errSessionExpiree;
    case 'DEVICE_REVOKED':
      return l10n.errCodeDeviceRevoked;
    case 'ACCOUNT_DELETION_PENDING':
      return l10n.errCodeAccountDeletionPending;
    case 'REGISTER_RATE_LIMITED':
      return l10n.errCodeRegisterRateLimited;
    case 'INVALID_CREDENTIALS':
      return l10n.errCodeInvalidCredentials;
    case 'PASSWORD_INCORRECT':
      return l10n.errCodePasswordIncorrect;

    // QR et appairage
    case 'QR_SESSION_EXPIRED':
      return l10n.errCodeQrSessionExpired;
    case 'DEVICE_NOT_OWNER':
      return l10n.errCodeDeviceNotOwner;
    case 'DEVICE_NOT_TRUSTED':
      return l10n.errCodeDeviceNotTrusted;
    case 'ADD_ALREADY_USED':
      return l10n.errCodeAddAlreadyUsed;
    case 'ADD_ME_POLICY_DENIED':
      return l10n.errCodeAddMePolicyDenied;

    // Réunions
    case 'MEETING_EXPIRED':
      return l10n.errCodeMeetingExpired;
    case 'MEETING_ENDED':
      return l10n.errCodeMeetingEnded;
    case 'MEETING_ORGANISER_REQUIRED':
      return l10n.errCodeMeetingOrganiserRequired;
    case 'ACCOUNT_ALREADY_IN_MEETING':
      return l10n.errCodeAccountAlreadyInMeeting;
    case 'SESSION_BUSY':
      return l10n.errCodeSessionBusy;
    case 'MAX_DURATION_REACHED':
      return l10n.errCodeMaxDurationReached;

    // Conversations, groupes et listes
    case 'BLOCKED_BY_SENDER':
      return l10n.errCodeBlockedBySender;
    case 'NOT_A_MEMBER':
      return l10n.errCodeNotAMember;
    case 'GROUP_ADMINS_ONLY':
      return l10n.errCodeGroupAdminsOnly;
    case 'GROUP_OWNER_REQUIRED':
      return l10n.errCodeGroupOwnerRequired;
    case 'CONVERSATION_NOT_FOUND':
      return l10n.errCodeConversationNotFound;
    case 'OFFICIAL_READONLY':
      return l10n.errCodeOfficialReadonly;
    case 'LIST_MEMBER_LIMIT':
      return l10n.errCodeListMemberLimit;
    case 'SYSTEM_LIST_READONLY':
      return l10n.errCodeSystemListReadonly;
    case 'INVITE_BLOCKED':
      return l10n.errCodeInviteBlocked;
    case 'BUSINESS_ONLY':
      return l10n.errCodeBusinessOnly;

    // Trajets
    case 'TRUST_LIST_EMPTY':
      return l10n.errCodeTrustListEmpty;
    case 'TRIP_ALREADY_ACTIVE':
      return l10n.errCodeTripAlreadyActive;
    case 'TRIP_TERMINAL':
      return l10n.errCodeTripTerminal;
    case 'TRIP_STILL_OPEN':
      return l10n.errCodeTripStillOpen;
    case 'SOS_RATE_LIMITED':
      return l10n.errCodeSosRateLimited;
    case 'INVALID_ETA':
      return l10n.errCodeInvalidEta;
    case 'INVALID_DESTINATION':
      return l10n.errCodeInvalidDestination;

    // Médias
    case 'MEDIA_EXPIRED':
      return l10n.errCodeMediaExpired;
    case 'INVALID_EXTENSION':
      return l10n.errCodeInvalidExtension;

    // Alanya Plus. `SUBSCRIPTION_REQUIRED` n'arrive ici qu'en repli :
    // `afficherErreur` en fait le panneau de l'offre, pas une SnackBar.
    case 'SUBSCRIPTION_REQUIRED':
      return l10n.errCodeSubscriptionRequired;
    case 'BILLING_NOT_ACTIVE':
      return l10n.errCodeBillingNotActive;
    case 'PAYMENT_PENDING':
      return l10n.errCodePaymentPending;
    case 'INVALID_MSISDN':
      return l10n.errCodeInvalidMsisdn;
    case 'INVALID_CHANNEL':
      return l10n.errCodeInvalidChannel;
    case 'PLAN_NOT_FOUND':
      return l10n.errCodePlanNotFound;
    case 'PAYMENT_PROVIDER_ERROR':
      return l10n.errCodePaymentProviderError;

    // Codes d'activation (régime essai). `CODE_LOCKED` porte `retryAfterSeconds` :
    // l'écran de saisie en tire des minutes, ce texte n'est que le repli.
    case 'INVALID_CODE':
      return l10n.errCodeInvalidCode;
    case 'INVALID_CODE_FORMAT':
      return l10n.errCodeInvalidCodeFormat;
    case 'CODE_ALREADY_USED':
      return l10n.errCodeCodeAlreadyUsed;
    case 'CODE_EXPIRED':
      return l10n.errCodeCodeExpired;
    case 'CODE_REVOKED':
      return l10n.errCodeCodeRevoked;
    case 'CODE_LOCKED':
      return l10n.errCodeCodeLocked;

    // Numéro Alanya choisi. `PHONE_UNAVAILABLE` porte sa raison : l'écran du
    // numéro l'affiche sous le champ, ce texte n'est que le repli.
    case 'PHONE_PURCHASE_UNAVAILABLE':
      return l10n.errCodePhonePurchaseUnavailable;
    case 'OFFICIAL_PHONE_FIXED':
      return l10n.errCodeOfficialPhoneFixed;
    case 'PHONE_NOT_PURCHASABLE':
      return l10n.errCodePhoneNotPurchasable;
    case 'PHONE_UNAVAILABLE':
      return l10n.errCodePhoneUnavailable;
    case 'PHONE_HOLD_EXPIRED':
      return l10n.errCodePhoneHoldExpired;
    case 'PHONE_ORDER_NOT_FOUND':
      return l10n.errCodePhoneOrderNotFound;
    case 'PHONE_ORDER_PENDING':
      return l10n.errCodePhoneOrderPending;

    // Vérification d'identité
    case 'VERIFICATION_UNAVAILABLE':
      return l10n.errCodeVerificationUnavailable;
    case 'DOCUMENTS_REQUIRED':
      return l10n.errCodeDocumentsRequired;
    case 'NAME_REQUIRED':
      return l10n.errCodeNameRequired;
    case 'VERIFICATION_ALREADY_OPEN':
      return l10n.errCodeVerificationAlreadyOpen;
    case 'VERIFICATION_ALREADY_APPROVED':
      return l10n.errCodeVerificationAlreadyApproved;
    case 'REQUEST_NOT_PENDING':
      return l10n.errCodeRequestNotPending;

    // Droits
    case 'INSUFFICIENT_ROLE':
      return l10n.errCodeInsufficientRole;
    case 'FIELD_IMMUTABLE':
      return l10n.errCodeFieldImmutable;
  }
  return null;
}

// ── 2. Domaine × nature ─────────────────────────────────────────────

/// Les quelques croisements où le domaine change ce qu'il faut dire.
///
/// Volontairement court : un croisement ne mérite sa phrase que s'il conduit
/// l'utilisateur à une action différente du message générique.
String? _messagePourDomaineEtNature(
  AppLocalizations l10n,
  ErrorDomain domaine,
  ErrorKind kind,
) {
  if (kind == ErrorKind.horsLigne) {
    if (domaine == ErrorDomain.appel) return l10n.errAppelHorsLigne;
    if (domaine == ErrorDomain.chat) return l10n.errChatHorsLigne;
  }
  if (kind == ErrorKind.permissionRefusee) {
    if (domaine == ErrorDomain.appel) {
      return l10n.permissionDeniedPleaseAllowMicrophoneCamera;
    }
    if (domaine == ErrorDomain.reunion) {
      return l10n.microphoneCameraPermissionDenied;
    }
  }
  if (kind == ErrorKind.peripheriqueIndisponible &&
      (domaine == ErrorDomain.appel || domaine == ErrorDomain.reunion)) {
    return l10n.cannotAccessDevicesCheckPermissions;
  }
  if (kind == ErrorKind.stockage && domaine == ErrorDomain.media) {
    return l10n.errMediaStockage;
  }
  return null;
}

// ── 3. La nature seule ──────────────────────────────────────────────

String? _messagePourNature(AppLocalizations l10n, ErrorKind kind) {
  switch (kind) {
    case ErrorKind.horsLigne:
      return l10n.networkError;
    case ErrorKind.delaiDepasse:
      return l10n.errDelaiDepasse;
    case ErrorKind.reseauSuspect:
      return l10n.errReseauSuspect;
    case ErrorKind.nonAutorise:
      return l10n.errSessionExpiree;
    case ErrorKind.introuvable:
      return l10n.errIntrouvable;
    case ErrorKind.conflit:
      return l10n.errConflit;
    case ErrorKind.tropDeRequetes:
      return l10n.errTropDeRequetes;
    case ErrorKind.serveur:
      return l10n.errServeur;
    case ErrorKind.permissionRefusee:
      return l10n.errPermission;
    case ErrorKind.peripheriqueIndisponible:
      return l10n.errPeripherique;
    case ErrorKind.stockage:
      return l10n.errStockage;
    case ErrorKind.inconnu:
      // Laisser le domaine parler : « La réunion n'a pas pu s'ouvrir » aide
      // davantage que « Une erreur est survenue ».
      return null;
  }
}

// ── 4. Le repli du domaine ──────────────────────────────────────────

String _messagePourDomaine(AppLocalizations l10n, ErrorDomain domaine) {
  switch (domaine) {
    case ErrorDomain.auth:
      return l10n.errDomaineAuth;
    case ErrorDomain.chat:
      return l10n.errDomaineChat;
    case ErrorDomain.appel:
      return l10n.errDomaineAppel;
    case ErrorDomain.reunion:
      return l10n.errDomaineReunion;
    case ErrorDomain.qr:
      return l10n.errDomaineQr;
    case ErrorDomain.media:
      return l10n.errDomaineMedia;
    case ErrorDomain.trajet:
      return l10n.errDomaineTrajet;
    case ErrorDomain.statut:
      return l10n.errDomaineStatut;
    case ErrorDomain.profil:
      return l10n.errDomaineProfil;
    case ErrorDomain.admin:
      return l10n.errDomaineAdmin;
    case ErrorDomain.abonnement:
      return l10n.errDomaineAbonnement;
    case ErrorDomain.generique:
      return l10n.errGenerique;
  }
}
