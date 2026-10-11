import 'dart:async';

import 'package:flutter/material.dart';

import '../../talky_api_client.dart' show TalkyException;
import '../../widgets/billing/paywall_sheet.dart';
import '../navigation/app_navigator.dart';
import '../services/billing/entitlement_service.dart';
import '../services/billing/entitlements.dart';
import '../theme/app_theme.dart';
import 'app_error.dart';
import 'error_presenter.dart';

/// Codes d'erreur des stickers (contrat §9, miroir de `docs/error-codes.md`
/// côté backend). **Un code ne se renomme jamais.** Chacun a son texte dans
/// `error_presenter.dart` (`_messagePourCode`) ; `SUBSCRIPTION_REQUIRED`
/// (`feature: "stickers_premium"`) ouvre le panneau Plus via [afficherErreur].
const List<String> kStickerErrorCodes = [
  'STICKER_NOT_FOUND',
  'STICKER_PACK_UNAVAILABLE',
  'STICKER_INVALID_PAYLOAD',
  'STICKER_ASSET_INVALID',
  'STICKER_ASSET_BLOCKED',
  'STICKER_QUOTA_EXCEEDED',
  'STICKER_PACK_LIMIT',
];

/// Affiche une erreur en SnackBar, traduite par [presenterErreur].
///
/// Prend l'erreur **brute** et jamais une `String` déjà composée : l'appelant
/// n'a aucun moyen de glisser un texte ici, donc aucun moyen de retomber dans
/// `showSnackBar(Text('$e'))`. Un écran qui sait dire mieux que le repli de son
/// domaine appelle `presenterErreur` et compose sa propre SnackBar.
///
/// Seule exception : un refus `SUBSCRIPTION_REQUIRED` ouvre le panneau
/// Alanya Plus de la fonctionnalité demandée. Aucun écran n'a à le prévoir.
void afficherErreur(
  BuildContext context,
  Object? erreur, {
  required ErrorDomain domaine,
}) {
  if (!context.mounted) return;
  final refus = refusAlanyaPlus(erreur);
  if (refus != null) {
    unawaited(showPaywall(context, refus.feature, outgoing: refus.outgoing));
    // Les droits en cache disaient oui, le serveur vient de dire non.
    final droits = EntitlementService.maybeInstance;
    if (droits != null) unawaited(droits.refresh());
    return;
  }
  final texte = presenterErreur(context.l10n, erreur, domaine: domaine);
  _montrer(ScaffoldMessenger.maybeOf(context), texte, context.colors.error);
}

/// Variante sans `BuildContext`, pour les services.
///
/// Passe par [appMessengerKey], déjà branchée sur `MaterialApp` et déjà
/// utilisée par `CallService` pour ses messages d'appel occupé ou sans réponse.
void afficherErreurGlobale(Object? erreur, {required ErrorDomain domaine}) {
  final texte = presenterErreurGlobale(erreur, domaine: domaine);
  _montrer(appMessengerKey.currentState, texte, null);
}

/// Le refus « réservé aux abonnés », la fonctionnalité qu'il vise, et s'il vise
/// l'émission (`feature: "outgoing"` : envoyer, appeler — hors catalogue).
/// Nul pour toute autre erreur.
({PlusFeature? feature, bool outgoing})? refusAlanyaPlus(Object? erreur) {
  final cause = erreur is AppError ? erreur.cause : erreur;
  if (cause is! TalkyException || cause.code != 'SUBSCRIPTION_REQUIRED') {
    return null;
  }
  final feature = cause.details?['feature'];
  return (
    feature: PlusFeature.fromCode(feature),
    outgoing: feature == 'outgoing',
  );
}

void _montrer(ScaffoldMessengerState? messenger, String texte, Color? fond) {
  if (messenger == null) {
    // Rien à faire : le texte est déjà parti dans les journaux via le
    // presenter, donc l'incident reste diagnosticable.
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: fond,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
}
