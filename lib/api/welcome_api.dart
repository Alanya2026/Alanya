// Endpoints message de bienvenue (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension WelcomeHttpApi on TalkyApiClient {
  /// Livre le message de bienvenue ALANYA (idempotent).
  Future<Map<String, dynamic>> deliverWelcome({String locale = 'fr'}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/welcome/deliver'),
        headers: _headers,
        body: jsonEncode({'locale': locale}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
