import 'dart:convert';
import 'dart:typed_data';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FauxHttp implements SafeboxHttp {
  _FauxHttp({this.reponse = const <String, dynamic>{}, http.Client? transferts})
      : transferClient = transferts ?? MockClient((_) async => http.Response('', 200));

  final Object reponse;
  final appels = <({String method, String path, Map<String, String>? query, Object? body})>[];

  @override
  final http.Client transferClient;

  @override
  Duration get stallTimeout => const Duration(seconds: 5);

  @override
  Future<dynamic> send(String method, String path, {Map<String, String>? query, Object? body}) async {
    appels.add((method: method, path: path, query: query, body: body));
    return reponse;
  }

  @override
  SafeboxHttpException transferFailure(SafeboxTransferFailure kind, {int status = 0, String? code, Object? cause}) =>
      SafeboxHttpException(kind.name, status, code: code, cause: cause);
}

void main() {
  test('les appels passent par SafeboxHttp avec la route, la requête et le corps', () async {
    final h = _FauxHttp(reponse: {'ok': true});
    final api = SafeboxClient(h);

    await api.trashSafeboxFile(12, everywhere: true);
    await api.createSafeboxFolder(parentId: 3, name: 'Kribi');
    await api.skipSafeboxBackup(['a', 'b']);

    expect(h.appels[0].method, 'DELETE');
    expect(h.appels[0].path, '/files/12');
    expect(h.appels[0].query, {'everywhere': '1'});
    expect(h.appels[1].method, 'POST');
    expect(h.appels[1].path, '/folders');
    expect(h.appels[1].body, {'parentId': 3, 'name': 'Kribi'});
    expect(h.appels[2].body, {
      'fps': ['a', 'b'],
    });
  });

  test('checkSafeboxBackup rend l’état de chaque empreinte', () async {
    final api = SafeboxClient(_FauxHttp(reponse: {
      'results': {
        'fp1': {'state': 'saved'},
        'fp2': {'state': 'elsewhere'},
      },
    }));
    expect(await api.checkSafeboxBackup(['fp1', 'fp2']), {'fp1': 'saved', 'fp2': 'elsewhere'});
  });

  test('checkSafeboxBackupQuality : la qualité, absente d’un ancien serveur', () async {
    final api = SafeboxClient(_FauxHttp(reponse: {
      'results': {
        'fp1': {'state': 'saved', 'original': true},
        'fp2': {'state': 'elsewhere', 'original': false},
        'fp3': {'state': 'saved'},
        'fp4': {'state': 'new'},
      },
    }));
    expect(await api.checkSafeboxBackupQuality(['fp1', 'fp2', 'fp3', 'fp4']), {
      'fp1': (state: 'saved', original: true),
      'fp2': (state: 'elsewhere', original: false),
      'fp3': (state: 'saved', original: null),
      'fp4': (state: 'new', original: null),
    });
  });

  test('un bloc refusé par le stockage lève l’erreur de l’application', () async {
    final h = _FauxHttp(transferts: MockClient((_) async => http.Response('', 403)));
    final api = SafeboxClient(h);
    await expectLater(
      api.putSafeboxBlock('https://stockage/bloc', Uint8List(10)),
      throwsA(isA<SafeboxHttpException>()
          .having((e) => e.statusCode, 'statut', 403)
          .having((e) => e.code, 'code', 'SAFEBOX_BLOCK_REJECTED')),
    );
  });

  test('un bloc lu arrive entier, sans jeton joint', () async {
    http.BaseRequest? vue;
    final h = _FauxHttp(transferts: MockClient((req) async {
      vue = req;
      return http.Response.bytes(utf8.encode('chiffre'), 200);
    }));
    final octets = await SafeboxClient(h).getSafeboxPreview('https://stockage/apercu');
    expect(utf8.decode(octets), 'chiffre');
    expect(vue!.headers.containsKey('Authorization'), isFalse);
  });
}
