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
    try {
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
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException('Network error: $e', 0);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceId,
  }) async {
    try {
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
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException('Network error: $e', 0);
    }
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
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
      );

      final data = _parseResponse(response);
      if (response.statusCode == 200) return data;
      throw TalkyException(
        data['error'] ?? 'Failed to get user',
        response.statusCode,
      );
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException('Network error: $e', 0);
    }
  }

  Future<Map<String, dynamic>> updateMe({
    String? nom,
    String? pseudo,
    String? avatarUrl,
    String? fcmToken,
    String? deviceId,
    bool? isOnline,
  }) async {
    final response = await _client.put(
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
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(data['error'] ?? 'Update failed', response.statusCode);
  }

  void logout() {
    _accessToken = null;
    _refreshToken = null;
    disconnectSocket();
  }

  // ── USERS ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getUsers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to get users',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> getUser(int alanyaID) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users/$alanyaID'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'User not found',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(data['error'] ?? 'Search failed', response.statusCode);
  }

  // ── CONTACTS ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getContacts() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/contacts'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to get contacts',
      response.statusCode,
    );
  }

  Future<void> addContact(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/contacts/$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw TalkyException(
        data['error'] ?? 'Failed to add contact',
        response.statusCode,
      );
    }
  }

  Future<void> removeContact(int userId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/contacts/$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw TalkyException(
        data['error'] ?? 'Failed to remove contact',
        response.statusCode,
      );
    }
  }

  Future<bool> checkIsContact(int userId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/contacts/check/$userId'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data['isContact'] ?? false;
    throw TalkyException(data['error'] ?? 'Check failed', response.statusCode);
  }

  // ── CONVERSATIONS ────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/conversations'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to get conversations',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> createConversation({
    required List<int> participants,
    String? type,
    String? nomGroupe,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/conversations'),
      headers: _headers,
      body: jsonEncode({
        'participants': participants,
        if (type != null) 'type': type,
        if (nomGroupe != null) 'nomGroupe': nomGroupe,
        if (description != null) 'description': description,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to create conversation',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> getConversation(int convId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/conversations/$convId'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Conversation not found',
      response.statusCode,
    );
  }

  // ── MESSAGES ────────────────────────────────────────────────────────

  Future<List<dynamic>> getMessages(int conversationId, {int page = 1}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages?page=$page'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to get messages',
      response.statusCode,
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String contenu,
    String type = 'text',
    String? mediaUrl,
    int? dureeVocal,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: _headers,
      body: jsonEncode({
        'contenu': contenu,
        'type': type,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (dureeVocal != null) 'duree_vocal': dureeVocal,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to send message',
      response.statusCode,
    );
  }

  Future<void> deleteMessage(int messageId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw TalkyException(
        data['error'] ?? 'Failed to delete message',
        response.statusCode,
      );
    }
  }

  // ── CALLS ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateCall({
    required int receiverId,
    String type = 'audio',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/calls/initiate'),
      headers: _headers,
      body: jsonEncode({'receiver_id': receiverId, 'type': type}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to initiate call',
      response.statusCode,
    );
  }

  Future<void> endCall(int callId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/calls/$callId/end'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw TalkyException(
        data['error'] ?? 'Failed to end call',
        response.statusCode,
      );
    }
  }

  // ── MEETINGS ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createMeeting({
    required String titre,
    String? description,
    required String dateDebut,
    required String dateFin,
    List<int>? participants,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/meetings'),
      headers: _headers,
      body: jsonEncode({
        'titre': titre,
        if (description != null) 'description': description,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        if (participants != null) 'participants': participants,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to create meeting',
      response.statusCode,
    );
  }

  Future<List<dynamic>> getMeetings() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/meetings'),
      headers: _headers,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw TalkyException(
      data['error'] ?? 'Failed to get meetings',
      response.statusCode,
    );
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

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw TalkyException(data['error'] ?? 'Upload failed', response.statusCode);
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

  Map<String, dynamic> _parseResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
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
