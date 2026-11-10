// Le client de l'application de bureau : connexion par QR code, jetons,
// renouvellement, et les appels du coffre (paquet alanya_safebox).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';

const String kApiBaseUrl = 'https://www.alanya237.com/api';

/// Session de connexion ouverte par l'ordinateur (`POST /auth/qr-session`).
class QrSession {
  QrSession({required this.sessionId, required this.pollToken, required this.payload, required this.ttl});

  factory QrSession.fromJson(Map<String, dynamic> j) {
    final ttlMs = int.tryParse('${j['ttlMs']}');
    return QrSession(
      sessionId: '${j['sessionId'] ?? ''}',
      pollToken: '${j['pollToken'] ?? ''}',
      payload: '${j['payload'] ?? ''}',
      ttl: ttlMs != null && ttlMs > 0 ? Duration(milliseconds: ttlMs) : const Duration(seconds: 90),
    );
  }

  final String sessionId;

  /// Preuve pour lire le statut ; jamais dans le QR code.
  final String pollToken;

  /// Ce que le QR code affiche ; le téléphone le scanne.
  final String payload;

  /// Durée de vie, comptée depuis la réception (l'horloge du PC peut être fausse).
  final Duration ttl;
}

enum QrStatus { pending, scanned, approved, denied, expired }

class QrPoll {
  QrPoll(this.status, {this.user, this.accessToken, this.refreshToken});

  factory QrPoll.fromJson(Map<String, dynamic> j) => QrPoll(
        QrStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => QrStatus.pending),
        user: j['user'] is Map ? Map<String, dynamic>.from(j['user'] as Map) : null,
        accessToken: j['accessToken'] is String ? j['accessToken'] as String : null,
        refreshToken: j['refreshToken'] is String ? j['refreshToken'] as String : null,
      );

  final QrStatus status;
  final Map<String, dynamic>? user;
  final String? accessToken;
  final String? refreshToken;

  bool get hasTokens => accessToken != null && refreshToken != null;
}

/// La session a pris fin côté serveur (appareil retiré depuis le téléphone,
/// jeton de renouvellement refusé) : l'application revient à la connexion.
class SessionEndedException extends SafeboxHttpException {
  SessionEndedException() : super('session terminée', 401, code: 'SESSION_ENDED');
}

class DesktopApi with SafeboxCalls {
  DesktopApi({required this.store, http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  final SessionStore store;
  final http.Client _client;
  final Duration timeout;

  String? _accessToken;
  String? _refreshToken;
  Future<void>? _renouvellement;

  /// Appelé quand la session prend fin d'elle-même (voir [SessionEndedException]).
  void Function()? onSessionEnded;

  bool get hasSession => _refreshToken != null;

  void setTokens({required String access, required String refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  late final SafeboxHttp safeboxHttp = _DesktopSafeboxHttp(this);

  // ── Connexion par QR code ────────────────────────────────────────────────

  Future<QrSession> createQrSession({required String deviceId, required String deviceName}) async {
    final r = await _envoyer(() => _client.post(
          Uri.parse('$kApiBaseUrl/auth/qr-session'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'deviceName': deviceName,
            'platform': Platform.isWindows ? 'windows' : 'linux',
          }),
        ));
    return QrSession.fromJson(_lire(r) as Map<String, dynamic>);
  }

  /// En-tête et non adresse : la réponse porte les jetons, et les adresses
  /// sont journalisées.
  Future<QrPoll> pollQrSession(QrSession s) async {
    final r = await _envoyer(() => _client.get(
          Uri.parse('$kApiBaseUrl/auth/qr-session/${Uri.encodeComponent(s.sessionId)}'),
          headers: {'Content-Type': 'application/json', 'X-Poll-Token': s.pollToken},
        ));
    return QrPoll.fromJson(_lire(r) as Map<String, dynamic>);
  }

  /// Retire cet ordinateur des « Appareils connectés » du compte : ses jetons
  /// ne valent plus rien. Sans réseau, la session locale est effacée quand
  /// même (l'appelant s'en charge) ; le téléphone peut finir le travail.
  Future<void> logout() async {
    if (_refreshToken == null) return;
    try {
      final liste = await authed('GET', Uri.parse('$kApiBaseUrl/auth/device-sessions'));
      final moi = (liste is List ? liste : const [])
          .whereType<Map>()
          .firstWhere((a) => a['current'] == true, orElse: () => const {});
      final id = moi['id'];
      if (id != null) await authed('DELETE', Uri.parse('$kApiBaseUrl/auth/device-sessions/$id'));
    } catch (_) {}
  }

  // ── Requêtes avec jeton ──────────────────────────────────────────────────

  Map<String, String> get _entetes => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<dynamic> authed(String method, Uri url, {Object? body}) async {
    final corps = body == null ? null : jsonEncode(body);
    Future<http.Response> requete() => switch (method) {
          'GET' => _client.get(url, headers: _entetes),
          'POST' => _client.post(url, headers: _entetes, body: corps),
          'PUT' => _client.put(url, headers: _entetes, body: corps),
          'PATCH' => _client.patch(url, headers: _entetes, body: corps),
          'DELETE' => _client.delete(url, headers: _entetes, body: corps),
          _ => throw ArgumentError.value(method, 'method'),
        };
    var r = await _envoyer(requete);
    if (r.statusCode == 401 && _refreshToken != null) {
      await _renouveler();
      r = await _envoyer(requete);
    }
    return _lire(r);
  }

  Future<void> _renouveler() => _renouvellement ??= _faireRenouveler().whenComplete(() => _renouvellement = null);

  Future<void> _faireRenouveler() async {
    final r = await _envoyer(() => _client.post(
          Uri.parse('$kApiBaseUrl/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': _refreshToken}),
        ));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body);
      if (j is Map && j['accessToken'] is String && j['refreshToken'] is String) {
        setTokens(access: j['accessToken'] as String, refresh: j['refreshToken'] as String);
        await store.saveTokens(access: _accessToken!, refresh: _refreshToken!);
        return;
      }
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      clearTokens();
      onSessionEnded?.call();
      throw SessionEndedException();
    }
    throw SafeboxHttpException('renouvellement refusé', r.statusCode);
  }

  Future<http.Response> _envoyer(Future<http.Response> Function() requete) async {
    try {
      return await requete().timeout(timeout);
    } on TimeoutException catch (e) {
      throw SafeboxHttpException('délai dépassé', 0, cause: e);
    } on SocketException catch (e) {
      throw SafeboxHttpException('réseau', 0, cause: e);
    } on http.ClientException catch (e) {
      throw SafeboxHttpException('réseau', 0, cause: e);
    }
  }

  dynamic _lire(http.Response r) {
    dynamic corps;
    try {
      corps = r.body.isEmpty ? const <String, dynamic>{} : jsonDecode(r.body);
    } catch (e) {
      throw SafeboxHttpException('réponse illisible', r.statusCode, cause: e);
    }
    if (r.statusCode >= 400) {
      final m = corps is Map ? corps : const {};
      throw SafeboxHttpException('${m['error'] ?? 'erreur du serveur'}', r.statusCode, code: m['code']?.toString());
    }
    return corps is Map ? Map<String, dynamic>.from(corps) : corps;
  }
}

class _DesktopSafeboxHttp implements SafeboxHttp {
  _DesktopSafeboxHttp(this._api);

  final DesktopApi _api;

  @override
  Future<dynamic> send(String method, String path, {Map<String, String>? query, Object? body}) =>
      _api.authed(method, Uri.parse('$kApiBaseUrl/safebox$path').replace(queryParameters: query), body: body);

  @override
  http.Client get transferClient => _api._client;

  @override
  Duration get stallTimeout => const Duration(seconds: 60);

  @override
  SafeboxHttpException transferFailure(SafeboxTransferFailure kind, {int status = 0, String? code, Object? cause}) =>
      SafeboxHttpException(kind.name, kind == SafeboxTransferFailure.rejected ? status : 0, code: code, cause: cause);
}
