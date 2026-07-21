// Endpoints d'authentification et de profil (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension AuthApi on TalkyApiClient {
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? nom,
    String? pseudo,
    int? idPays,
    String? fcmToken,
    String? deviceId,
  }) async {
    final deviceModel = await TalkyApiClient._currentDeviceModel();
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (nom != null) 'nom': nom,
        if (pseudo != null) 'pseudo': pseudo,
        if (idPays != null) 'idPays': idPays,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
        'device_model': deviceModel,
        'os_system': TalkyApiClient._currentOs(),
      }),
    );
    final data = _parseResponse(response);
    _accessToken  = data['accessToken'];
    _refreshToken = data['refreshToken'];
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String alanyaPhone,
    required String password,
    String? fcmToken,
    String? deviceId,
  }) async {
    final deviceModel = await TalkyApiClient._currentDeviceModel();
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'alanyaPhone': alanyaPhone,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
        'device_model': deviceModel,
        'os_system': TalkyApiClient._currentOs(),
      }),
    );
    final data = _parseResponse(response);
    _accessToken  = data['accessToken'];
    _refreshToken = data['refreshToken'];
    return data as Map<String, dynamic>;
  }

  // ── PASSWORD RESET WITH OTP ───────────────────────────────────────

  /// Étape 1: Demander un OTP par email
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(response);
  }

  /// Étape 2: Valider l'OTP et récupérer un reset token
  Future<Map<String, dynamic>> validateOTP(String email, String otp) async {
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/validate-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    return _parseResponse(response);
  }

  /// Étape 3: Compléter le reset password avec le reset token
  Future<Map<String, dynamic>> completePasswordReset(
    String resetToken,
    String newPassword,
  ) async {
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/reset-password-confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'resetToken': resetToken,
        'newPassword': newPassword,
      }),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getMe() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/auth/me'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe({
    String? nom,
    String? pseudo,
    String? avatarUrl,
    String? fcmToken,
    String? deviceId,
    bool? isOnline,
    int? idPays,
  }) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me'),
        headers: _headers,
        body: jsonEncode({
          if (nom != null) 'nom': nom,
          if (pseudo != null) 'pseudo': pseudo,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (fcmToken != null) 'fcm_token': fcmToken,
          if (deviceId != null) 'device_ID': deviceId,
          if (isOnline != null) 'is_online': isOnline ? 1 : 0,
          if (idPays != null) 'idPays': idPays,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> updateFcmToken(String fcmToken, {String? deviceId}) async {
    final did = deviceId ?? await ensureStableDeviceId();
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/fcm-token'),
        headers: _headers,
        body: jsonEncode({'fcmToken': fcmToken, 'deviceId': did}),
      ),
    );
  }

  void logout() {
    _accessToken  = null;
    _refreshToken = null;
    _cachedIceServers = null;
    _iceServersExpiresAt = null;
    disconnectSocket();
  }
}
