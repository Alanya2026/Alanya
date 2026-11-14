import 'dart:convert';
import 'dart:io';

import 'package:alanya_coffre/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('les numéros de version se comparent morceau par morceau', () {
    expect(compareVersions('1.10.0', '1.9.2'), 1);
    expect(compareVersions('1.0.0', '1.0.0+7'), 0);
    expect(compareVersions('1.0', '1.0.1'), -1);
    expect(compareVersions('2.0.0', '10.0.0'), -1);
  });

  test('la version est lue dans le version.json écrit par Flutter', () async {
    final dir = Directory.systemTemp.createTempSync('coffre_version');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(await loadAppVersion(assetsDir: dir.path), '0.0.0');
    File('${dir.path}/version.json').writeAsStringSync('{"app_name":"alanya_coffre","version":"1.2.3","build_number":"4"}');
    expect(await loadAppVersion(assetsDir: dir.path), '1.2.3');
  });

  test('une version plus récente s’annonce ; « Plus tard » l’écarte jusqu’à la suivante', () async {
    SharedPreferences.setMockInitialValues({});
    var annoncee = '1.1.0';
    final u = UpdateChecker(
      current: '1.0.0',
      client: MockClient((req) async {
        expect(req.url.toString(), kVersionUrl);
        return http.Response(jsonEncode({'version': annoncee}), 200);
      }),
    );
    await u.check();
    expect(u.available, '1.1.0');
    await u.dismiss();
    expect(u.available, isNull);
    await u.check();
    expect(u.available, isNull);
    annoncee = '1.2.0';
    await u.check();
    expect(u.available, '1.2.0');
    u.dispose();
  });

  test('pas de bandeau pour une version égale, ni si la page manque', () async {
    SharedPreferences.setMockInitialValues({});
    final egale = UpdateChecker(current: '1.0.0', client: MockClient((_) async => http.Response('{"version":"1.0.0"}', 200)));
    await egale.check();
    expect(egale.available, isNull);
    final absente = UpdateChecker(current: '1.0.0', client: MockClient((_) async => http.Response('introuvable', 404)));
    await absente.check();
    expect(absente.available, isNull);
  });
}
