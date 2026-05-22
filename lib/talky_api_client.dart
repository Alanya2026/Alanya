// talky_api_client.dart — aligné avec le backend Alanya
// Routes, champs et socket events corrects

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'talky_models.dart';

class TalkyApiClient {
  // ** Remplace par ton IP/domaine de production
  static const String baseUrl   = 'http://158.220.107.211/api';
  static const String socketUrl = 'http://158.220.107.211/';

  String? _accessToken;
  String? _refreshToken;
  io.Socket? _socket;
  final http.Client _client;

  // Callbacks Socket globaux (pour CallService, MeetingService)
  final Map<String, List<Function(dynamic)>> _socketListeners = {};

  String? get accessToken        => _accessToken;
  String? get currentRefreshToken => _refreshToken;
  bool   get isSocketConnected   => _socket?.connected ?? false;

  TalkyApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String token) => _accessToken = token;
  void setRefreshToken(String token) => _refreshToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ── HTTP HELPER ───────────────────────────────────────────────────

  Future<dynamic> _handleRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (_refreshToken != null) {
          try {
            await _refreshAccessToken();
            final retried = await request().timeout(const Duration(seconds: 15));
            return _parseResponse(retried);
          } catch (_) {
            throw TalkyException('Session expirée', 401);
          }
        }
        throw TalkyException('Non authentifié', 401);
      }
      return _parseResponse(response);
    } on TalkyException {
      rethrow;
    } on TimeoutException {
      throw TalkyException('Timeout réseau', 0);
    } catch (e) {
      throw TalkyException('Erreur réseau: $e', 0);
    }
  }

  dynamic _parseResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 400) {
        final msg = body is Map ? (body['error'] ?? 'Erreur serveur') : 'Erreur serveur';
        throw TalkyException(msg.toString(), response.statusCode);
      }
      return body;
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException('Réponse invalide (${response.statusCode})', response.statusCode);
    }
  }

  // ── AUTH ──────────────────────────────────────────────────────────

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
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'alanyaPhone': alanyaPhone,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (deviceId != null) 'device_ID': deviceId,
      }),
    );
    final data = _parseResponse(response);
    _accessToken  = data['accessToken'];
    _refreshToken = data['refreshToken'];
    return data as Map<String, dynamic>;
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) throw TalkyException('Pas de refresh token', 401);
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _accessToken  = data['accessToken'];
      _refreshToken = data['refreshToken'];
    } else {
      throw TalkyException(data['error'] ?? 'Refresh échoué', response.statusCode);
    }
  }

  // ── PASSWORD RESET WITH OTP ───────────────────────────────────────

  /// Étape 1: Demander un OTP par email
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _parseResponse(response);
  }

  /// Étape 2: Valider l'OTP et récupérer un reset token
  Future<Map<String, dynamic>> validateOTP(String email, String otp) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/validate-otp'),
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
      Uri.parse('$baseUrl/auth/reset-password-confirm'),
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
      () => _client.get(Uri.parse('$baseUrl/auth/me'), headers: _headers),
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
  }) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headers,
        body: jsonEncode({
          if (nom != null) 'nom': nom,
          if (pseudo != null) 'pseudo': pseudo,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (fcmToken != null) 'fcm_token': fcmToken,
          if (deviceId != null) 'device_ID': deviceId,
          if (isOnline != null) 'is_online': isOnline ? 1 : 0,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('$baseUrl/auth/fcm-token'),
        headers: _headers,
        body: jsonEncode({'fcmToken': fcmToken}),
      ),
    );
  }

  // ── WEBRTC / TURN ─────────────────────────────────────────────────

  List<Map<String, dynamic>>? _cachedIceServers;
  DateTime? _iceServersExpiresAt;

  /// Récupère la config iceServers depuis le backend. Cache 50 min par défaut
  /// (les credentials TURN éphémères ont 60 min — on les renouvelle avant).
  Future<List<Map<String, dynamic>>> fetchIceServers({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedIceServers != null &&
        _iceServersExpiresAt != null &&
        now.isBefore(_iceServersExpiresAt!)) {
      debugPrint('[TalkyApiClient] 🧊 fetchIceServers (cache, ${_cachedIceServers!.length} serveur(s))');
      return _cachedIceServers!;
    }

    try {
      final data = await _handleRequest(
        () => _client.get(Uri.parse('$baseUrl/turn/credentials'), headers: _headers),
      ) as Map<String, dynamic>;

      final List<dynamic> raw = data['iceServers'] as List<dynamic>? ?? [];
      final servers = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final ttlSec = (data['ttlSec'] as num?)?.toInt() ?? 0;
      _cachedIceServers = servers;
      _iceServersExpiresAt = ttlSec > 60
          ? now.add(Duration(seconds: ttlSec - 600))
          : now.add(const Duration(minutes: 50));
      debugPrint('[TalkyApiClient] 🧊 fetchIceServers: ${servers.length} serveur(s)');
      for (final s in servers) {
        final urls = s['urls'];
        final hasCreds = s.containsKey('username') && s.containsKey('credential');
        debugPrint('  • urls=$urls, auth=${hasCreds ? "TURN avec creds" : "STUN"}');
      }
      return servers;
    } catch (e) {
      // Fallback STUN public si le backend est injoignable — l'app reste utilisable
      // sur les réseaux non-symétriques.
      debugPrint('[TalkyApiClient] fetchIceServers fallback: $e');
      return const [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
  }

  void logout() {
    _accessToken  = null;
    _refreshToken = null;
    _cachedIceServers = null;
    _iceServersExpiresAt = null;
    disconnectSocket();
  }

  // ── USERS ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserById(int alanyaID) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/users/$alanyaID'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUserByPhone(String phone) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/users/phone/$phone'), headers: _headers),
    );
    return data is List ? data : [data];
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/users/search?q=$query'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<void> blockUser(int userId) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/users/$userId/block'), headers: _headers),
    );
  }

  Future<void> unblockUser(int userId) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('$baseUrl/users/$userId/block'), headers: _headers),
    );
  }

  // ── CONTACTS PRÉFÉRÉS ─────────────────────────────────────────────

  Future<List<dynamic>> getContacts() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/contacts'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> addContact(int userId) async {
    final data = await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/contacts/$userId'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> removeContact(int userId) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('$baseUrl/contacts/$userId'), headers: _headers),
    );
  }

  Future<bool> checkIsContact(int userId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/contacts/check/$userId'), headers: _headers),
    );
    return (data as Map<String, dynamic>)['isContact'] == true;
  }

  // ── CONVERSATIONS ─────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/conversations'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Crée une conversation 1-1 — le backend attend { participantID }
  Future<Map<String, dynamic>> createConversation({required int participantID}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/conversations'),
        headers: _headers,
        body: jsonEncode({'participantID': participantID}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Crée un groupe — le backend attend { participantIDs[], GroupName, groupPhoto }
  Future<Map<String, dynamic>> createGroup({
    required List<int> participantIDs,
    required String groupName,
    String? groupPhoto,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/conversations/group'),
        headers: _headers,
        body: jsonEncode({
          'participantIDs': participantIDs,
          'GroupName': groupName,
          if (groupPhoto != null) 'groupPhoto': groupPhoto,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversation(int conversID) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/conversations/$conversID'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> markConversationAsRead(int conversID) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/conversations/$conversID/read'), headers: _headers),
    );
  }

  Future<void> leaveGroup(int conversID) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/conversations/$conversID/leave'), headers: _headers),
    );
  }

  // ── MESSAGES ──────────────────────────────────────────────────────

  Future<List<dynamic>> getMessages(int conversID, {int limit = 50, int? before}) async {
    String url = '$baseUrl/conversations/$conversID/messages?limit=$limit';
    if (before != null) url += '&before=$before';
    final data = await _handleRequest(
      () => _client.get(Uri.parse(url), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversID,
    String? content,
    int type = 0,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? replyToID,
    String? replyToContent,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/conversations/$conversID/messages'),
        headers: _headers,
        body: jsonEncode({
          if (content != null) 'content': content,
          'type': type,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (mediaName != null) 'mediaName': mediaName,
          if (mediaDuration != null) 'mediaDuration': mediaDuration,
          if (replyToID != null) 'replyToID': replyToID,
          if (replyToContent != null) 'replyToContent': replyToContent,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editMessage(int msgID, String content) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('$baseUrl/messages/$msgID'),
        headers: _headers,
        body: jsonEncode({'content': content}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteMessage(int msgID, {bool forAll = false}) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('$baseUrl/messages/$msgID${forAll ? '?all=true' : ''}'),
        headers: _headers,
      ),
    );
  }

  // ── CALLS ─────────────────────────────────────────────────────────
  // Historique uniquement — les appels se font par Socket (call_user etc.)

  Future<List<dynamic>> getCallHistory() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/calls'), headers: _headers),
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
        Uri.parse('$baseUrl/calls'),
        headers: _headers,
        body: jsonEncode({'idReceiver': idReceiver, 'type': type}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> endCallRecord(int idCall, {int status = 1}) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('$baseUrl/calls/$idCall/end'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      ),
    );
  }

  // ── MEETINGS ──────────────────────────────────────────────────────

  Future<List<dynamic>> getMeetings() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/meetings'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Crée une réunion — backend attend: objet, start_time, room, duree, type_media
  Future<Map<String, dynamic>> createMeeting({
    required String objet,
    required String startTime, // ISO8601 ex: "2026-05-03T14:00:00"
    required String room,
    int duree = 60,
    int typeMedia = 0,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/meetings'),
        headers: _headers,
        body: jsonEncode({
          'objet': objet,
          'start_time': startTime,
          'room': room,
          'duree': duree,
          'type_media': typeMedia,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMeeting(int idMeeting) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/meetings/$idMeeting'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  /// Résout une réunion par son code de room (même si on n'en est pas encore
  /// participant). Lève une exception si introuvable / terminée.
  Future<Map<String, dynamic>> getMeetingByRoom(String room) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('$baseUrl/meetings/by-room/${Uri.encodeComponent(room)}'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> joinMeetingHttp(int idMeeting) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/meetings/$idMeeting/join'), headers: _headers),
    );
  }

  Future<void> leaveMeetingHttp(int idMeeting) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/meetings/$idMeeting/leave'), headers: _headers),
    );
  }

  Future<void> deleteMeeting(int idMeeting) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('$baseUrl/meetings/$idMeeting'), headers: _headers),
    );
  }

  Future<void> updateMeeting(int idMeeting, {
    String? objet,
    String? startTime,
    int? duree,
    int? typeMedia,
  }) async {
    final body = <String, dynamic>{};
    if (objet != null) body['objet'] = objet;
    if (startTime != null) body['start_time'] = startTime;
    if (duree != null) body['duree'] = duree;
    if (typeMedia != null) body['type_media'] = typeMedia;
    await _handleRequest(
      () => _client.put(
        Uri.parse('$baseUrl/meetings/$idMeeting'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> inviteParticipants(int idMeeting, List<int> participantIds) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/meetings/$idMeeting/invite'),
        headers: _headers,
        body: jsonEncode({'participant_ids': participantIds}),
      ),
    );
  }

  // ── STATUTS ───────────────────────────────────────────────────────

  Future<List<dynamic>> getStatuts() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/status'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> createStatut({
    String? text,
    String? mediaUrl,
    String? backgroundColor,
    int type = 0,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('$baseUrl/status'),
        headers: _headers,
        body: jsonEncode({
          if (text != null) 'text': text,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          'type': type,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> viewStatut(int id) async {
    await _handleRequest(
      () => _client.post(Uri.parse('$baseUrl/status/$id/view'), headers: _headers),
    );
  }

  // ── UPLOAD ────────────────────────────────────────────────────────

  // http.MultipartFile.fromPath n'infère PAS le type MIME (octet-stream par
  // défaut), que le filtre multer du backend rejette. On le détecte ici.
  Future<http.MultipartFile> _multipartFile(String field, File file) async {
    final mimeStr = lookupMimeType(file.path) ?? 'application/octet-stream';
    final slash = mimeStr.indexOf('/');
    final mediaType = slash > 0
        ? MediaType(mimeStr.substring(0, slash), mimeStr.substring(slash + 1))
        : MediaType('application', 'octet-stream');
    return http.MultipartFile.fromPath(field, file.path, contentType: mediaType);
  }

  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/avatar'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw TalkyException(jsonDecode(response.body)['error'] ?? 'Upload échoué', response.statusCode);
  }

  Future<Map<String, dynamic>> uploadMedia(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/media'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw TalkyException(jsonDecode(response.body)['error'] ?? 'Upload échoué', response.statusCode);
  }

  // ── SOCKET.IO ─────────────────────────────────────────────────────

  void connectSocket() {
    if (_accessToken == null) return;
    if (_socket?.connected == true) return;

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 2000,
      'reconnectionAttempts': 10,
    });

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connecté — envoi auth:login');
      // !! AUTH SOCKET obligatoire — sinon tous les handlers ignorent les events
      _socket!.emit(SocketEvents.authLogin, {'token': _accessToken});
    });

    _socket!.on(SocketEvents.authVerified, (data) {
      debugPrint('[Socket] Authentifié: ${data['alanyaID']}');
      // Signaler présence en ligne
      _socket!.emit(SocketEvents.presenceOnline, {'userID': data['alanyaID']});
      // Rejouer les listeners en attente
      _replayPendingListeners();
    });

    _socket!.on(SocketEvents.authError, (data) {
      debugPrint('[Socket] Erreur auth: ${data['message']}');
    });

    _socket!.on(SocketEvents.authConflict, (data) {
      debugPrint('[Socket] Conflit connexion: ${data['message']}');
    });

    _socket!.onDisconnect((_) => debugPrint('[Socket] Déconnecté'));
    _socket!.onError((err) => debugPrint('[Socket] Erreur: $err'));
    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnecté — ré-auth');
      _socket!.emit(SocketEvents.authLogin, {'token': _accessToken});
    });

    _socket!.connect();
  }

  void _replayPendingListeners() {
    debugPrint('[Socket] 🔄 Replay ${_socketListeners.length} listener group(s)');
    _socketListeners.forEach((event, callbacks) {
      // !! IMPORTANT : Nettoyer les anciens listeners d'abord
      _socket?.off(event);
      debugPrint('[Socket] 🔄 Replay event "$event" (${callbacks.length} callback(s))');
      for (final cb in callbacks) {
        _socket?.on(event, cb);
      }
    });
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _socketListeners.clear();
  }

  void sendSocketEvent(String event, dynamic data) {
    if (_socket?.connected != true) {
      debugPrint('[Socket] ** Tentative d\'emit "$event" sans connexion');
      return;
    }
    _socket!.emit(event, data);
  }

  void onSocketEvent(String event, Function(dynamic) callback) {
    // !! Stocker une seule fois pour replay après reconnexion
    final listeners = _socketListeners.putIfAbsent(event, () => []);
    
    // !! Éviter les doublons (même si peu probable)
    if (!listeners.contains(callback)) {
      listeners.add(callback);
      debugPrint('[Socket] 📌 Listener enregistré pour "$event"');
    }
    
    // !! Enregistrer le listener socket.io s'il n'est pas déjà là
    if (_socket?.connected == true) {
      _socket?.on(event, callback);
      debugPrint('[Socket] !! Listener activé pour "$event" sur socket actif');
    }
  }

  void offSocketEvent(String event) {
    _socketListeners.remove(event);
    _socket?.off(event);
  }

  // ── PAYS ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getPays() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$baseUrl/pays'), headers: _headers),
    );
    return data is List ? data : [];
  }

  // ── HEALTH ────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('http://158.220.107.211/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
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