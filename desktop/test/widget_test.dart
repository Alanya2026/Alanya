import 'dart:convert';

import 'package:alanya_coffre/core/desktop_api.dart';
import 'package:alanya_coffre/core/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('le sondage du QR envoie le pollToken en en-tête et lit les jetons', () async {
    http.Request? vue;
    final api = DesktopApi(
      store: SessionStore(),
      client: MockClient((req) async {
        vue = req;
        return http.Response(
          jsonEncode({
            'status': 'approved',
            'accessToken': 'a',
            'refreshToken': 'r',
            'user': {'pseudo': 'Alfred'},
          }),
          200,
        );
      }),
    );
    final r = await api.pollQrSession(QrSession(sessionId: 's 1', pollToken: 'p', payload: 'x', ttl: const Duration(seconds: 90)));
    expect(vue!.url.path, '/api/auth/qr-session/s%201');
    expect(vue!.headers['X-Poll-Token'], 'p');
    expect(vue!.url.query, isEmpty);
    expect(r.status, QrStatus.approved);
    expect(r.hasTokens, isTrue);
    expect(r.user!['pseudo'], 'Alfred');
  });

  test('un 401 renouvelle le jeton une fois puis rejoue la requête', () async {
    final appels = <String>[];
    var jeton = 'ancien';
    final api = DesktopApi(
      store: _Memoire(),
      client: MockClient((req) async {
        appels.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? ''}');
        if (req.url.path == '/api/auth/refresh') {
          jeton = 'neuf';
          return http.Response(jsonEncode({'accessToken': 'neuf', 'refreshToken': 'r2'}), 200);
        }
        if (req.headers['Authorization'] != 'Bearer $jeton' || jeton == 'ancien') {
          return http.Response(jsonEncode({'error': 'expiré'}), 401);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    )..setTokens(access: 'ancien', refresh: 'r1');
    await api.emptySafeboxTrash();
    expect(appels, [
      'DELETE /api/safebox/trash Bearer ancien',
      'POST /api/auth/refresh ',
      'DELETE /api/safebox/trash Bearer neuf',
    ]);
  });

  test('un renouvellement refusé met fin à la session', () async {
    var finie = false;
    final api = DesktopApi(
      store: _Memoire(),
      client: MockClient((req) async => http.Response(jsonEncode({'error': 'non'}), 401)),
    )
      ..setTokens(access: 'a', refresh: 'r')
      ..onSessionEnded = () => finie = true;
    await expectLater(api.fetchSafebox(), throwsA(isA<SessionEndedException>()));
    expect(finie, isTrue);
    expect(api.hasSession, isFalse);
  });
}

class _Memoire extends SessionStore {
  @override
  Future<void> saveTokens({required String access, required String refresh}) async {}
}
