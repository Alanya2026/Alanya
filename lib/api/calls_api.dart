// Historique des appels (part of talky_api_client.dart).
// Les appels eux-mêmes se font par Socket (call_user etc.), pas en HTTP.
part of '../talky_api_client.dart';

extension CallsApi on TalkyApiClient {
  Future<List<dynamic>> getCallHistory() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/calls'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Crée l'entrée en DB (utilisé si besoin — sinon le socket le fait)
  Future<Map<String, dynamic>> createCallRecord({
    required int idReceiver,
    int type = 0, // 0=audio, 1=vidéo
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/calls'),
        headers: _headers,
        body: jsonEncode({'idReceiver': idReceiver, 'type': type}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> endCallRecord(int idCall, {int status = 1}) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/calls/$idCall/end'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );
  }
}
