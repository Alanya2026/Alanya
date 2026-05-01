import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TalkyApiClient {
  static const String baseUrl = 'http://158.220.107.211/api';
  static const String socketUrl = 'http://158.220.107.211';

  String? _accessToken;
  String? _refreshToken;
  IO.Socket? _socket;
  final http.Client _client;

  String? get accessToken => _accessToken;
  String? get currentRefreshToken => _refreshToken;

  TalkyApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String token) => _accessToken = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<Map<String, dynamic>> _handleRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode == 401 && _refreshToken != null) {
        try {
          await refreshToken();
          final retried = await request();
          return _parseResponse(retried);
        } catch (_) {
          throw TalkyException('Session expired', 401);
        }
      }
      return _parseResponse(response);
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException('Network error: $e', 0);
    }
  }

  // ── AUTH ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? nom,
    String? pseudo,
    int? idPays,
    String? fcmToken,
    String? deviceId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (nom != null) 'nom': nom,
        if (pseudo != null) 'pseudo': pseudo,
        if (idPays != null) 'idPays': idPays,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
      }),
    );

    final data = _parseResponse(response);
    if (response.statusCode == 201) {
      _accessToken = data['accessToken'];
      _refreshToken = data['refreshToken'];
      return data;
    }
    throw TalkyException(
      data['error'] ?? 'Registration failed',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
      }),
    );

    final data = _parseResponse(response);
    if (response.statusCode == 200) {
      _accessToken = data['accessToken'];
      _refreshToken = data['refreshToken'];
      return data;
    }
    throw TalkyException(data['error'] ?? 'Login failed', response.statusCode);
  }

  Future<String> refreshToken() async {
    if (_refreshToken == null) throw TalkyException('No refresh token', 401);

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _accessToken = data['accessToken'];
      _refreshToken = data['refreshToken'];
      return _accessToken!;
    }
    throw TalkyException(
      data['error'] ?? 'Token refresh failed',
      response.statusCode,
    );
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'newPassword': newPassword}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw TalkyException(
        data['error'] ?? 'Reset failed',
        response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    return _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    ));
  }

  Future<Map<String, dynamic>> updateMe({
    String? nom,
    String? pseudo,
    String? avatarUrl,
    String? fcmToken,
    String? deviceId,
    bool? isOnline,
  }) async {
    return _handleRequest(() => _client.put(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
      body: jsonEncode({
        if (nom != null) 'nom': nom,
        if (pseudo != null) 'pseudo': pseudo,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
        if (isOnline != null) 'is_online': isOnline,
      }),
    ));
  }

  void logout() {
    _accessToken = null;
    _refreshToken = null;
    disconnectSocket();
  }

  // ── USERS ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getUsers() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/users'),
      headers: _headers,
    ));
    return data is List ? data : data['users'] ?? [];
  }

  Future<Map<String, dynamic>> getUser(int alanyaID) async {
    return _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/users/$alanyaID'),
      headers: _headers,
    ));
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: _headers,
    ));
    // Backend returns array directly
    if (data is List) return data;
    return [];
  }

  // ── CONTACTS ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getContacts() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/contacts'),
      headers: _headers,
    ));
    return data is List ? data : data['contacts'] ?? [];
  }

  Future<void> addContact(int userId) async {
    await _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/contacts/$userId'),
      headers: _headers,
    ));
  }

  Future<void> removeContact(int userId) async {
    await _handleRequest(() => _client.delete(
      Uri.parse('$baseUrl/contacts/$userId'),
      headers: _headers,
    ));
  }

  Future<bool> checkIsContact(int userId) async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/contacts/check/$userId'),
      headers: _headers,
    ));
    return data['isContact'] ?? false;
  }

  // ── CONVERSATIONS ────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/conversations'),
      headers: _headers,
    ));
    return data is List ? data : data['conversations'] ?? [];
  }

  Future<Map<String, dynamic>> createConversation({
    required List<int> participants,
    String? type,
    String? nomGroupe,
    String? description,
    String? avatarUrl,
  }) async {
    return _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/conversations'),
      headers: _headers,
      body: jsonEncode({
        'participants': participants,
        if (type != null) 'type': type,
        if (nomGroupe != null) 'nomGroupe': nomGroupe,
        if (description != null) 'description': description,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    ));
  }

  Future<Map<String, dynamic>> getConversation(int convId) async {
    return _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/conversations/$convId'),
      headers: _headers,
    ));
  }

  // ── MESSAGES ────────────────────────────────────────────────────────

  Future<List<dynamic>> getMessages(int conversationId, {int page = 1}) async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages?page=$page'),
      headers: _headers,
    ));
    return data is List ? data : data['messages'] ?? [];
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String contenu,
    String type = 'text',
    String? mediaUrl,
    int? dureeVocal,
  }) async {
    return _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: _headers,
      body: jsonEncode({
        'contenu': contenu,
        'type': type,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (dureeVocal != null) 'duree_vocal': dureeVocal,
      }),
    ));
  }

  Future<void> deleteMessage(int messageId) async {
    await _handleRequest(() => _client.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: _headers,
    ));
  }

  // ── CALLS ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateCall({
    required int receiverId,
    String type = 'audio',
  }) async {
    return _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/calls/initiate'),
      headers: _headers,
      body: jsonEncode({'receiver_id': receiverId, 'type': type}),
    ));
  }

  Future<void> endCall(int callId) async {
    await _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/calls/$callId/end'),
      headers: _headers,
    ));
  }

  Future<List<dynamic>> getCallHistory() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/calls'),
      headers: _headers,
    ));
    return data is List ? data : data['calls'] ?? [];
  }

  Future<List<dynamic>> getPreferredContacts() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/contacts/preferred'),
      headers: _headers,
    ));
    return data is List ? data : data['contacts'] ?? [];
  }

  Future<Map<String, dynamic>> getUserByPhone(String alanyaPhone) async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/users/phone/$alanyaPhone'),
      headers: _headers,
    ));
    // Backend returns array, take first element
    if (data is List && data.isNotEmpty) return data[0];
    if (data is Map) return data;
    throw TalkyException('User not found', 404);
  }

  // ── MEETINGS ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createMeeting({
    required String titre,
    String? description,
    required String dateDebut,
    required String dateFin,
    List<int>? participants,
  }) async {
    return _handleRequest(() => _client.post(
      Uri.parse('$baseUrl/meetings'),
      headers: _headers,
      body: jsonEncode({
        'titre': titre,
        if (description != null) 'description': description,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        if (participants != null) 'participants': participants,
      }),
    ));
  }

  Future<List<dynamic>> getMeetings() async {
    final data = await _handleRequest(() => _client.get(
      Uri.parse('$baseUrl/meetings'),
      headers: _headers,
    ));
    return data is List ? data : data['meetings'] ?? [];
  }

  // ── UPLOAD ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadFile({
    required File file,
    String type = 'image',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['type'] = type;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw TalkyException(
      jsonDecode(response.body)['error'] ?? 'Upload failed',
      response.statusCode,
    );
  }

  // ── SOCKET.IO ───────────────────────────────────────────────────────

  void connectSocket() {
    if (_accessToken == null) return;

    _socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': _accessToken},
    });

    _socket!.onConnect((_) => print('[Socket] Connected'));
    _socket!.onDisconnect((_) => print('[Socket] Disconnected'));
    _socket!.onError((err) => print('[Socket] Error: $err'));
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket = null;
  }

  void sendSocketEvent(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void onSocketEvent(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void offSocketEvent(String event) {
    _socket?.off(event);
  }

  // ── HEALTH CHECK ────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/../health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  dynamic _parseResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (e) {
      print('[TalkyApiClient] Response parsing failed:');
      print('  Status: ${response.statusCode}');
      print('  Body (first 500 chars): ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}');
      throw TalkyException(
        'Server error: Invalid response format (${response.statusCode})',
        response.statusCode,
      );
    }
  }

  void dispose() {
    logout();
    _client.close();
  }
}

class TalkyException implements Exception {
  final String message;
  final int statusCode;

  TalkyException(this.message, this.statusCode);

  @override
  String toString() => 'TalkyException: $message (Status: $statusCode)';
}
