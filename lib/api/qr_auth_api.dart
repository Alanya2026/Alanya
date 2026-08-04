// Connexion par QR d'un nouvel appareil et gestion des appareils connectés
// (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension QrAuthApi on TalkyApiClient {
  /// Ouvre une session de connexion sur l'appareil qui AFFICHE le QR.
  /// Appel non authentifié : cet appareil n'a précisément pas encore de token.
  Future<QrLoginCreated> createQrSession({
    required String deviceId,
    String? deviceName,
    String? platform,
  }) async {
    final name = deviceName ?? await TalkyApiClient._currentDeviceModel();
    final response = await _client
        .post(
          Uri.parse('${TalkyApiClient.baseUrl}/auth/qr-session'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'deviceName': name,
            'platform': platform ?? TalkyApiClient._currentOs(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = _parseResponse(response);
    return QrLoginCreated.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Interroge le statut d'une session. Non authentifié également : le
  /// pollToken tient lieu de preuve, et lui seul — il n'est jamais dans le QR,
  /// sans quoi photographier le code suffirait à voler les tokens.
  Future<QrLoginPollResult> pollQrSession(String sessionId, String pollToken) async {
    final uri = Uri.parse(
      '${TalkyApiClient.baseUrl}/auth/qr-session/${Uri.encodeComponent(sessionId)}',
    );
    // En-tête et non query string : l'URL est journalisée par défaut par
    // nginx/Cloudflare, et la réponse de cet appel transporte les tokens.
    final response = await _client
        .get(uri, headers: {
          'Content-Type': 'application/json',
          'X-Poll-Token': pollToken,
        })
        .timeout(const Duration(seconds: 15));
    final data = _parseResponse(response);
    return QrLoginPollResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Approuve la connexion depuis l'appareil déjà connecté qui a scanné le QR.
  /// À n'appeler qu'après confirmation explicite de l'utilisateur.
  Future<void> approveQrSession(String sessionId, String scanSecret) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse(
          '${TalkyApiClient.baseUrl}/auth/qr-session/${Uri.encodeComponent(sessionId)}/approve',
        ),
        headers: _headers,
        body: jsonEncode({'scanSecret': scanSecret}),
      ),
    );
  }

  /// Refuse la connexion depuis l'appareil qui a scanné le QR.
  Future<void> denyQrSession(String sessionId, String scanSecret) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse(
          '${TalkyApiClient.baseUrl}/auth/qr-session/${Uri.encodeComponent(sessionId)}/deny',
        ),
        headers: _headers,
        body: jsonEncode({'scanSecret': scanSecret}),
      ),
    );
  }

  // ── APPAREILS CONNECTÉS ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listDeviceSessions() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/device-sessions'),
        headers: _headers,
      ),
    );
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Révoque un appareil : le backend pose revoked_at et émet
  /// `auth:device_revoked`, l'appareil visé se déconnectera de lui-même.
  Future<void> revokeDeviceSession(int appareilId) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/device-sessions/$appareilId'),
        headers: _headers,
      ),
    );
  }
}
