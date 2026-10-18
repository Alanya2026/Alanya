// Annuaire des clés publiques du chiffrement de bout en bout
// (part of talky_api_client.dart).
//
// Le serveur n'est qu'un annuaire : rien de ce qui part d'ici n'est secret.
// Les clés privées ne quittent jamais l'appareil (voir lib/core/e2ee/).
part of '../talky_api_client.dart';

extension E2eeApi on TalkyApiClient {
  /// État des clés de CET appareil : publié ? quelle identité ? quel stock ?
  ///
  /// `404 E2EE_INACTIF` : le chiffrement n'est pas ouvert pour ce compte.
  /// Ce n'est pas une erreur, l'appelant s'arrête sans bruit.
  Future<Map<String, dynamic>> fetchE2eeState() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/keys/state'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Publie (ou remplace) le bundle de cet appareil.
  Future<Map<String, dynamic>> publishE2eeBundle(Map<String, dynamic> bundle) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/keys'),
        headers: _headers,
        body: jsonEncode(bundle),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Regarnit le stock de clés à usage unique.
  Future<Map<String, dynamic>> publishE2eePreKeys(List<Map<String, dynamic>> cles) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/keys/prekeys'),
        headers: _headers,
        body: jsonEncode({'oneTimePreKeys': cles}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Tourne la pré-clé signée.
  Future<Map<String, dynamic>> rotateE2eeSignedPreKey(Map<String, dynamic> signedPreKey) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/keys/signed-prekey'),
        headers: _headers,
        body: jsonEncode({'signedPreKey': signedPreKey}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Pour qui chiffrer dans cette conversation : les appareils de chaque
  /// participant, leur clé d'identité et leur capacité, sans rien consommer.
  /// Fait passer la conversation en chiffré quand elle le peut, et rend
  /// `e2eeSince` (nul : on écrit en clair).
  Future<Map<String, dynamic>> fetchE2eeDevices(int conversationID) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/devices?conversationID=$conversationID'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Paquets des appareils demandés — chacun CONSOMME une clé à usage unique.
  /// À ne demander que pour les appareils sans session, ou dont l'identité a
  /// changé (docs/e2ee, chapitre 13).
  Future<Map<String, dynamic>> fetchE2eeBundles(List<int> appareilIds) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/bundles'),
        headers: _headers,
        body: jsonEncode({'appareilIds': appareilIds}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Retire l'identité de cet appareil (déconnexion). Toujours permis.
  Future<void> deleteE2eeKeys() async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/e2ee/keys'),
        headers: _headers,
      ),
    );
  }
}
