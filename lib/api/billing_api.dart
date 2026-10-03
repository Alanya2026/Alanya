part of '../talky_api_client.dart';

/// Abonnement Alanya Plus.
///
/// Les réponses restent des `Map` : leur lecture vit dans
/// core/services/billing/billing_models.dart, éprouvée sans réseau.
extension BillingApi on TalkyApiClient {
  /// Droits du compte connecté — même charge utile que la clé `entitlements`
  /// de `/auth/me`. Sert au rafraîchissement ciblé, sans relire le profil.
  Future<Map<String, dynamic>> getMyEntitlements() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/me'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Plans, fonctionnalités, fournisseur et droits : l'écran d'offre en un
  /// seul appel.
  Future<Map<String, dynamic>> getPlusOffer() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/offer'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Active un code d'abonnement reçu après un paiement sur le site : une année,
  /// à la suite de ce qui court (l'essai compris). Rend les droits à jour.
  ///
  /// Rejouable par le même compte sans effet de plus. Refus : `INVALID_CODE`,
  /// `INVALID_CODE_FORMAT`, `CODE_ALREADY_USED`, `CODE_EXPIRED`, `CODE_REVOKED`,
  /// `CODE_LOCKED` (avec `retryAfterSeconds` dans `details`).
  Future<Map<String, dynamic>> redeemActivationCode(String code) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/redeem'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Demande un paiement mobile money.
  ///
  /// La réponse n'est jamais « payé » : l'opérateur confirme plus tard, et
  /// l'application l'apprend par l'événement socket `payment:updated`.
  Future<Map<String, dynamic>> checkoutPlus({
    required String planCode,
    required String channel,
    required String msisdn,
    bool? autoRenew,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/checkout'),
        headers: _headers,
        body: jsonEncode({
          'planCode': planCode,
          'channel': channel,
          'msisdn': msisdn,
          if (autoRenew != null) 'autoRenew': autoRenew,
        }),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Statut d'un paiement du compte — le filet quand l'événement socket
  /// n'est pas arrivé (connexion coupée pendant l'attente).
  Future<Map<String, dynamic>> getPlusPayment(int paymentId) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/payments/$paymentId'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Périodes et paiements du compte, les plus récents d'abord.
  Future<Map<String, dynamic>> getPlusHistory() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/history'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Renouvellement automatique et durée du prochain renouvellement.
  /// Rend les droits à jour.
  Future<Map<String, dynamic>> updatePlusPreferences({
    bool? autoRenew,
    String? renewPlanCode,
  }) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/billing/preferences'),
        headers: _headers,
        body: jsonEncode({
          if (autoRenew != null) 'autoRenew': autoRenew,
          if (renewPlanCode != null) 'renewPlanCode': renewPlanCode,
        }),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
