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
  static const String baseUrl   = 'http://158.220.107.211/api';
  static const String socketUrl = 'http://158.220.107.211/';

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
