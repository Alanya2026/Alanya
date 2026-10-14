import 'package:flutter/material.dart';

import '../../core/services/billing/entitlement_service.dart';
import '../../screens/billing/plus_offer_screen.dart';
import 'paywall_sheet.dart';

/// Mène à l'abonnement, selon le régime en vigueur.
///
/// Alanya Plus : l'écran d'offre, où l'on choisit une formule et paie par
/// mobile money. Régime essai : on ne paie pas dans l'application, le panneau
/// dit où payer et reçoit le code. Le téléphone ne code aucun des deux : il lit
/// le régime dans les droits, que le serveur envoie.
///
/// Rend vrai si un paiement a abouti dans l'écran d'offre (la liste des
/// paiements est alors à relire).
Future<bool> openPlusOffer(BuildContext context, {String? planCode}) async {
  final trial = EntitlementService.maybeInstance?.current.isTrialModel ?? false;
  if (trial) {
    await showPaywall(context, null);
    return false;
  }
  final paid = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PlusOfferScreen(initialPlanCode: planCode),
    ),
  );
  return paid == true;
}
