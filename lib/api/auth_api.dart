// Endpoints d'authentification et de profil (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension AuthApi on TalkyApiClient {
  Future<Map<String, dynamic>> register({
    String? email,
    required String password,
    String? nom,
    String? pseudo,
    int? idPays,
    String? fcmToken,
    String? deviceId,
  }) async {
    final deviceModel = await TalkyApiClient._currentDeviceModel();
    final cleanEmail = email?.trim();
    final response = await _client.post(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
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

  /// Demande un OTP pour ajouter ou remplacer l'email du compte connecté.
  Future<Map<String, dynamic>> requestEmailChangeOtp(String email) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me/email/request-otp'),
        headers: _headers,
        body: jsonEncode({'email': email.trim()}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Confirme l'OTP et applique le nouvel email.
  Future<Map<String, dynamic>> confirmEmailChange({
    required String email,
    required String otp,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me/email/confirm'),
        headers: _headers,
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
        }),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Change le mot de passe (authentifié).
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me/password'),
        headers: _headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
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
    await registerPushDevice(fcmToken: fcmToken, deviceId: did);
  }

  Future<void> registerPushDevice({
    String? fcmToken,
    String? deviceId,
    String? platform,
    String? voipToken,
    String? locale,
  }) async {
    final did = deviceId ?? await ensureStableDeviceId();
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/push-devices/register'),
        headers: _headers,
        body: jsonEncode({
          'deviceId': did,
          if (platform != null) 'platform': platform,
          if (fcmToken != null) 'fcmToken': fcmToken,
          if (voipToken != null) 'voipToken': voipToken,
          if (locale != null) 'locale': locale,
        }),
      ),
    );
  }

  Future<void> updateVoipToken(String voipToken, {String? deviceId}) async {
    await registerPushDevice(
      deviceId: deviceId,
      platform: 'ios',
      voipToken: voipToken,
    );
  }

  Future<void> updatePushDeviceState({
    String? deviceId,
    required String appState,
    int? activeConversationId,
    bool? notificationsEnabled,
  }) async {
    final did = deviceId ?? await ensureStableDeviceId();
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/push-devices/state'),
        headers: _headers,
        body: jsonEncode({
          'deviceId': did,
          'appState': appState,
          if (activeConversationId != null)
            'activeConversationId': activeConversationId,
          if (notificationsEnabled != null)
            'notificationsEnabled': notificationsEnabled,
        }),
      ),
    );
  }

  Future<void> deletePushDevice({String? deviceId}) async {
    final did = deviceId ?? await ensureStableDeviceId();
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/push-devices/$did'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/notification-prefs'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> patchNotificationPrefs(
    Map<String, dynamic> patch,
  ) async {
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/notification-prefs'),
        headers: _headers,
        body: jsonEncode(patch),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  void logout() {
    _accessToken  = null;
    _refreshToken = null;
    _cachedIceServers = null;
    _iceServersExpiresAt = null;
    disconnectSocket();
  }
}
