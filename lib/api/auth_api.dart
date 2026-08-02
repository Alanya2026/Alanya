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
    String? hardwareId,
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
        if (hardwareId != null) 'hardware_id': hardwareId,
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
    String? hardwareId,
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
        if (hardwareId != null) 'hardware_id': hardwareId,
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
    String? bio,
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
          if (bio != null) 'bio': bio,
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

  Future<PrivacyPrefs> getPrivacyPrefs() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/privacy-prefs'),
        headers: _headers,
      ),
    );
    return PrivacyPrefs.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PrivacyPrefs> patchPrivacyPrefs(Map<String, dynamic> patch) async {
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/privacy-prefs'),
        headers: _headers,
        body: jsonEncode(patch),
      ),
    );
    return PrivacyPrefs.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AppSettings> getAppSettings() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/app-settings'),
        headers: _headers,
      ),
    );
    return AppSettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AppSettings> patchAppSettings(Map<String, dynamic> patch) async {
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/app-settings'),
        headers: _headers,
        body: jsonEncode(patch),
      ),
    );
    return AppSettings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DndSchedule> getDndSchedule() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/dnd-schedule'),
        headers: _headers,
      ),
    );
    return DndSchedule.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DndSchedule> patchDndSchedule(Map<String, dynamic> patch) async {
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/dnd-schedule'),
        headers: _headers,
        body: jsonEncode(patch),
      ),
    );
    return DndSchedule.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AccountDeletionSchedule> deleteAccount(String password) async {
    final data = await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me'),
        headers: _headers,
        body: jsonEncode({'password': password}),
      ),
    );
    return AccountDeletionSchedule.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> cancelAccountDeletion() async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me/cancel-deletion'),
        headers: _headers,
      ),
    );
  }

  Future<MyMediaPage> getMyMedia({int? cursor, int limit = 30}) async {
    final uri = Uri.parse('${TalkyApiClient.baseUrl}/auth/me/media').replace(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null) 'cursor': '$cursor',
      },
    );
    final data = await _handleRequest(
      () => _client.get(uri, headers: _headers),
    );
    return MyMediaPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Télécharge un export prêt (authentifié) vers un fichier temporaire.
  Future<List<int>> downloadExportBytes(int jobId) async {
    final response = await _client.get(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/me/export/$jobId'),
      headers: _headers,
    );

    if (response.statusCode == 401 && _refreshToken != null) {
      await _refreshAccessToken();
      return downloadExportBytes(jobId);
    }

    if (response.statusCode >= 400) {
      throw TalkyException(
        LocaleController.instance.l10n.serverError,
        response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  /// Export synchrone (sans messages) ou déclenchement d'un job async.
  Future<Map<String, dynamic>> requestExport({bool includeMessages = false}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/auth/me/export'),
        headers: _headers,
        body: jsonEncode({'includeMessages': includeMessages}),
      ),
      timeout: includeMessages
          ? const Duration(seconds: 30)
          : const Duration(seconds: 60),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Statut JSON d'un job d'export (pending / processing / failed).
  Future<ExportJob> getExportJob(int jobId) async {
    final response = await _client.get(
      Uri.parse('${TalkyApiClient.baseUrl}/auth/me/export/$jobId'),
      headers: _headers,
    );

    if (response.statusCode == 401 && _refreshToken != null) {
      await _refreshAccessToken();
      return getExportJob(jobId);
    }

    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode == 200 &&
        !contentType.contains('application/json')) {
      return ExportJob(
        jobId: jobId,
        status: ExportJobStatus.ready,
        downloadUrl:
            '${TalkyApiClient.baseUrl}/auth/me/export/$jobId',
      );
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map) {
        throw TalkyException(
          LocaleController.instance.l10n.invalidResponseWithCode(response.statusCode),
          response.statusCode,
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (response.statusCode >= 400) {
        final msg = map['error']?.toString() ??
            LocaleController.instance.l10n.serverError;
        throw TalkyException(msg, response.statusCode);
      }
      return ExportJob.fromJson(map);
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException(
        LocaleController.instance.l10n.invalidResponseWithCode(response.statusCode),
        response.statusCode,
      );
    }
  }

  /// Télécharge le fichier JSON d'un export prêt.
  Future<List<int>> downloadExportJob(int jobId) async {
    Future<http.Response> request() => _client.get(
          Uri.parse('${TalkyApiClient.baseUrl}/auth/me/export/$jobId'),
          headers: _headers,
        );

    var response = await request().timeout(const Duration(minutes: 5));
    if (response.statusCode == 401 && _refreshToken != null) {
      await _refreshAccessToken();
      response = await request().timeout(const Duration(minutes: 5));
    }

    if (response.statusCode == 202) {
      final body = jsonDecode(response.body);
      final status = body is Map ? body['status']?.toString() : null;
      throw TalkyException(
        'Export en cours (${status ?? 'pending'})',
        response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      String msg = LocaleController.instance.l10n.serverError;
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          msg = body['error'].toString();
        }
      } catch (_) {}
      throw TalkyException(msg, response.statusCode);
    }

    return response.bodyBytes;
  }

  void logout() {
    _accessToken  = null;
    _refreshToken = null;
    _cachedIceServers = null;
    _iceServersExpiresAt = null;
    disconnectSocket();
  }
}
