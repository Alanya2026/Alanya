import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';

SafeboxQuota _espace(int utilise, {int total = 1000}) => SafeboxQuota(
      quotaBytes: total,
      usedBytes: utilise,
      pendingBytes: 0,
      trashBytes: 0,
      byRoot: const {},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('paliers : 0, 80, 95, 100 %', () {
    expect(SafeboxQuotaAlerter.levelOf(_espace(799)), 0);
    expect(SafeboxQuotaAlerter.levelOf(_espace(800)), 80);
    expect(SafeboxQuotaAlerter.levelOf(_espace(950)), 95);
    expect(SafeboxQuotaAlerter.levelOf(_espace(1000)), 100);
    expect(SafeboxQuotaAlerter.levelOf(_espace(1200)), 100);
    expect(SafeboxQuotaAlerter.levelOf(_espace(0, total: 0)), 100);
  });

  test('une alerte par palier franchi en montant, aucune en redescendant', () async {
    final alertes = <int>[];
    final a = SafeboxQuotaAlerter((n) async => alertes.add(n));
    await a.check(_espace(500));
    await a.check(_espace(810));
    await a.check(_espace(850)); // même palier : rien
    await a.check(_espace(960));
    await a.check(_espace(1000));
    await a.check(_espace(700)); // place libérée : silence, palier réarmé
    expect(alertes, [80, 95, 100]);
    await a.check(_espace(820)); // franchi à nouveau : prévenu à nouveau
    expect(alertes, [80, 95, 100, 80]);
  });

  test('un saut direct à 100 % ne prévient qu\'une fois', () async {
    final alertes = <int>[];
    final a = SafeboxQuotaAlerter((n) async => alertes.add(n));
    await a.check(_espace(1000));
    await a.check(_espace(1000));
    expect(alertes, [100]);
  });

  test('le palier survit au redémarrage de l\'application', () async {
    final alertes = <int>[];
    await SafeboxQuotaAlerter((n) async => alertes.add(n)).check(_espace(900));
    await SafeboxQuotaAlerter((n) async => alertes.add(n)).check(_espace(900));
    expect(alertes, [80]);
  });
}
