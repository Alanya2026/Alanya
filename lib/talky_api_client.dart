// talky_api_client.dart — aligné avec le backend Alanya
// Routes, champs et socket events corrects
//
// Ce fichier ne contient que le cœur du client (état + plomberie HTTP/refresh +
// helpers privés). Les endpoints sont répartis par domaine dans des extensions
// `part of` sous lib/api/ (auth, users, chat, calls, meetings, media, socket,
// status, admin, misc). Tout partage la même librairie : les extensions ont
// accès aux membres privés et aux imports déclarés ici.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'talky_models.dart';

part 'api/auth_api.dart';
part 'api/users_api.dart';
part 'api/chat_api.dart';
part 'api/calls_api.dart';
part 'api/meetings_api.dart';
part 'api/media_api.dart';
part 'api/socket_api.dart';
part 'api/status_api.dart';
part 'api/admin_api.dart';
part 'api/misc_api.dart';

class TalkyApiClient {
  // ** Remplace par ton IP/domaine de production
  static const String baseUrl   = 'https://www.alanya237.com/api';
  static const String socketUrl = 'https://www.alanya237.com/';

  String? _accessToken;
  String? _refreshToken;
  io.Socket? _socket;
  final http.Client _client;

  // Callbacks Socket globaux (pour CallService, MeetingService)
  final Map<String, List<Function(dynamic)>> _socketListeners = {};

  /// Vrai uniquement après que le serveur a confirmé `auth:verified`. Le simple
  /// `_socket.connected` ne suffit pas : émettre avant l'auth fait silencieusement
  /// jeter les events côté serveur.
  bool _isSocketAuthVerified = false;

  /// Garde anti-réentrance : refresh JWT en cours suite à un `auth:error`
  /// TOKEN_EXPIRED (évite d'empiler plusieurs refresh sur des events répétés).
  bool _socketReauthInFlight = false;

  // Cache TURN/ICE (voir fetchIceServers dans misc_api.dart)
  List<Map<String, dynamic>>? _cachedIceServers;
  DateTime? _iceServersExpiresAt;

  String? get accessToken        => _accessToken;
  String? get currentRefreshToken => _refreshToken;
  bool   get isSocketConnected   => _socket?.connected ?? false;
  bool   get isSocketReady       => isSocketConnected && _isSocketAuthVerified;

  TalkyApiClient({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String token) => _accessToken = token;
  void setRefreshToken(String token) => _refreshToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ── HTTP HELPER ───────────────────────────────────────────────────

  Future<dynamic> _handleRequest(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await request().timeout(timeout);

      if (response.statusCode == 401) {
        if (_refreshToken != null) {
          try {
            await _refreshAccessToken();
            final retried = await request().timeout(timeout);
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
      reauthSocketIfConnected();
    } else {
      throw TalkyException(data['error'] ?? 'Refresh échoué', response.statusCode);
    }
  }

  // ── HELPERS APPAREIL (auth) ───────────────────────────────────────

  /// OS courant à envoyer dans `os_system` pour la table userAccess.
  /// Capitalise pour cohérence avec le parser server-side (Android / iOS / …).
  static String _currentOs() {
    if (kIsWeb) return 'Web';
    switch (Platform.operatingSystem) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      default:
        return Platform.operatingSystem;
    }
  }

  /// Libellé lisible du téléphone (marque + modèle) à envoyer dans
  /// `device_model` lors de login/register, stocké dans userAccess.device.
  /// Best-effort : retourne 'INDEFINI' si l'info n'est pas disponible.
  static Future<String> _currentDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final b = await info.webBrowserInfo;
        return b.browserName.name;
      }
      switch (Platform.operatingSystem) {
        case 'android':
          final a = await info.androidInfo;
          final brand = (a.manufacturer.isNotEmpty ? a.manufacturer : a.brand).trim();
          final model = a.model.trim();
          final label = (brand.isEmpty ? model : '$brand $model').trim();
          return label.isEmpty ? 'INDEFINI' : label;
        case 'ios':
          final i = await info.iosInfo;
          final machine = i.utsname.machine.trim();
          final model = i.model.trim();
          return machine.isNotEmpty ? 'Apple $machine' : (model.isEmpty ? 'INDEFINI' : 'Apple $model');
        case 'macos':
          final m = await info.macOsInfo;
          return m.model.isNotEmpty ? m.model : 'macOS';
        case 'windows':
          final w = await info.windowsInfo;
          return w.computerName.isNotEmpty ? w.computerName : 'Windows';
        case 'linux':
          final l = await info.linuxInfo;
          return l.prettyName.isNotEmpty ? l.prettyName : 'Linux';
        default:
          return 'INDEFINI';
      }
    } catch (_) {
      return 'INDEFINI';
    }
  }

  // ── UPLOAD HELPER ─────────────────────────────────────────────────

  /// MIME pour upload multipart — fallback par extension si lookup échoue.
  MediaType mimeTypeForPath(String path) {
    final mimeStr = lookupMimeType(path) ?? _mimeFallbackFromExtension(path);
    final slash = mimeStr.indexOf('/');
    if (slash > 0) {
      return MediaType(mimeStr.substring(0, slash), mimeStr.substring(slash + 1));
    }
    return MediaType('application', 'octet-stream');
  }

  String _mimeFallbackFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case '3gp':
        return 'video/3gpp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Duration uploadTimeoutForFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    final seconds = (30 + mb * 2).ceil();
    return Duration(seconds: seconds.clamp(30, 600));
  }

  TalkyException uploadHttpException(http.Response response) {
    final code = response.statusCode;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        return TalkyException(body['error'].toString(), code);
      }
    } catch (_) {
      // body non JSON (ex. page nginx HTML)
    }
    final snippet = response.body.length > 120
        ? '${response.body.substring(0, 120)}…'
        : response.body;
    return TalkyException(
      snippet.isEmpty ? 'Upload échoué' : snippet,
      code,
    );
  }

  // http.MultipartFile.fromPath n'infère PAS le type MIME (octet-stream par
  // défaut), que le filtre multer du backend rejette. On le détecte ici.
  Future<http.MultipartFile> _multipartFile(
    String field,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final mediaType = mimeTypeForPath(file.path);
    final length = await file.length();
    if (onProgress == null) {
      return http.MultipartFile.fromPath(
        field,
        file.path,
        contentType: mediaType,
      );
    }
    var sent = 0;
    final stream = file.openRead().map((chunk) {
      sent += chunk.length;
      if (length > 0) onProgress(sent / length);
      return chunk;
    });
    final name = file.path.split('/').last;
    return http.MultipartFile(
      field,
      stream,
      length,
      filename: name,
      contentType: mediaType,
    );
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
