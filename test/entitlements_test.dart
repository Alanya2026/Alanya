import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/services/billing/entitlements.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Charge utile telle que la rend le serveur (rules.js, decideEntitlements).
Map<String, dynamic> _payload({
  String phase = 'paid',
  Map<String, bool>? features,
  Map<String, dynamic>? period,
  String validUntil = '2026-10-10T00:00:00.000Z',
}) =>
    {
      'phase': phase,
      'graceUntil': null,
      'period': period,
      'upcoming': null,
      'exempt': false,
      'features': features ??
          {
            'translation': false,
            'backup': false,
            'trusted_trips': false,
            'list_ringtones': false,
            'style': false,
            'verified_badge': false,
          },
      'validUntil': validUntil,
    };

/// Charge utile du régime essai : le droit d'émettre est hors catalogue
/// (`features.outgoing`), et `trial` donne la fin de l'essai.
Map<String, dynamic> _trialPayload({
  bool outgoing = true,
  bool trialActive = true,
  Map<String, dynamic>? period,
  String phase = 'paid',
}) =>
    {
      ..._payload(phase: phase, period: period),
      'model': 2,
      'trial': {'endsAt': '2026-12-01T00:00:00.000Z', 'active': trialActive},
      'features': {'translation': trialActive, 'outgoing': outgoing},
    };

void main() {
  group('Régime essai', () {
    test('un serveur qui n\'en parle pas : Alanya Plus, tout est permis', () {
      final e = Entitlements.fromJson(_payload());
      expect(e.model, PlusModel.plus);
      expect(e.isTrialModel, isFalse);
      expect(e.trial, isNull);
      // Le droit d'émettre n'existe pas dans cette charge utile : ouvert.
      expect(e.canSend, isTrue);
    });

    test('essai en cours : on peut tout faire, la fin est connue', () {
      final e = Entitlements.fromJson(_trialPayload());
      expect(e.model, PlusModel.trial);
      expect(e.isTrialModel, isTrue);
      expect(e.canSend, isTrue);
      expect(e.trial!.active, isTrue);
      expect(e.trial!.endsAt, DateTime.utc(2026, 12, 1));
      expect(e.has(PlusFeature.translation), isTrue);
    });

    test('essai fini, sans abonnement : on ne peut ni envoyer ni appeler', () {
      final e = Entitlements.fromJson(_trialPayload(outgoing: false, trialActive: false));
      expect(e.canSend, isFalse);
      expect(e.trial!.active, isFalse);
      expect(e.has(PlusFeature.translation), isFalse);
    });

    test('sans droits connus, ou sans mention du droit : on ne ferme jamais', () {
      expect(Entitlements.unrestricted.canSend, isTrue);
      final sansDroit = Entitlements.fromJson({..._trialPayload(), 'features': <String, bool>{}});
      expect(sansDroit.canSend, isTrue);
    });

    test('le régime et l\'essai survivent au cache local', () {
      final e = Entitlements.fromJson(_trialPayload(outgoing: false, trialActive: false));
      final back = Entitlements.fromJson(e.toJson());
      expect(back.model, PlusModel.trial);
      expect(back.canSend, isFalse);
      expect(back.trial!.endsAt, DateTime.utc(2026, 12, 1));
      expect(back.trial!.active, isFalse);
    });

    test('une période née d\'un code porte la source 4', () {
      final e = Entitlements.fromJson(_trialPayload(period: {
        'plan': 'plus_annuel',
        'startsAt': '2026-10-10T00:00:00.000Z',
        'endsAt': '2027-10-10T00:00:00.000Z',
        'source': 4,
        'autoRenew': false,
      }));
      expect(e.period!.source, 4);
      expect(e.isSubscribed, isTrue);
    });
  });

  group('Entitlements', () {
    test('sans droits connus, tout est permis', () {
      const e = Entitlements.unrestricted;
      expect(e.known, isFalse);
      for (final f in PlusFeature.values) {
        expect(e.has(f), isTrue, reason: f.code);
      }
      expect(Entitlements.fromJson(null).known, isFalse);
    });

    test('phase payante sans abonnement : fermé', () {
      final e = Entitlements.fromJson(_payload());
      expect(e.phase, PlusPhase.paid);
      expect(e.has(PlusFeature.translation), isFalse);
      expect(e.has(PlusFeature.trustedTrips), isFalse);
      expect(e.isSubscribed, isFalse);
    });

    test('abonné : ce que le plan ouvre, et la période', () {
      final e = Entitlements.fromJson(_payload(
        features: {'translation': true, 'backup': true, 'style': false},
        period: {
          'plan': 'plus_annuel',
          'startsAt': '2026-10-10T00:00:00.000Z',
          'endsAt': '2027-10-10T00:00:00.000Z',
          'source': 0,
          'autoRenew': true,
        },
      ));
      expect(e.has(PlusFeature.translation), isTrue);
      expect(e.has(PlusFeature.style), isFalse);
      expect(e.isSubscribed, isTrue);
      expect(e.period!.plan, 'plus_annuel');
      expect(e.period!.autoRenew, isTrue);
      expect(e.period!.endsAt, DateTime.utc(2027, 10, 10));
    });

    test('une fonctionnalité que le serveur ne connaît pas reste ouverte', () {
      final e = Entitlements.fromJson(_payload(features: {'translation': false}));
      expect(e.has(PlusFeature.listRingtones), isTrue);
    });

    test('validUntil dépassé : périmé, mais rien ne se ferme pour autant', () {
      final e = Entitlements.fromJson(
        _payload(features: {'translation': true}, validUntil: '2026-09-01T00:00:00.000Z'),
      );
      expect(e.isStale(DateTime.utc(2026, 9, 2)), isTrue);
      expect(e.has(PlusFeature.translation), isTrue);
      expect(Entitlements.unrestricted.isStale(DateTime.utc(2100)), isFalse);
    });

    test('aller-retour par le cache', () {
      final e = Entitlements.fromJson(_payload(
        phase: 'grace',
        features: {'translation': true},
        period: {'plan': 'plus_mensuel', 'endsAt': '2026-11-17T00:00:00.000Z'},
      ));
      final back = Entitlements.fromJson(e.toJson());
      expect(back.phase, PlusPhase.grace);
      expect(back.has(PlusFeature.translation), isTrue);
      expect(back.period!.plan, 'plus_mensuel');
      expect(back.validUntil, e.validUntil);
    });
  });

  group('EntitlementService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('le profil sans clé entitlements laisse tout ouvert', () async {
      final s = EntitlementService(api: TalkyApiClient());
      await s.applyFromProfile({'alanyaID': 7});
      expect(s.current.known, isFalse);
      expect(EntitlementService.allows(PlusFeature.backup), isTrue);
    });

    test('un refus d\'émettre est annoncé une fois, pas à chaque message', () async {
      final s = EntitlementService(api: TalkyApiClient());
      await s.apply(_trialPayload(outgoing: false, trialActive: false));
      expect(s.canSend, isFalse);
      expect(EntitlementService.allowsOutgoing, isFalse);

      var signals = 0;
      final sub = s.outgoingBlocked.listen((_) => signals++);
      // Cinq messages en file qui échouent ensemble : un seul signal.
      for (var i = 0; i < 5; i++) {
        s.reportOutgoingBlocked();
      }
      await Future<void>.delayed(Duration.zero);
      expect(signals, 1);
      await sub.cancel();

      await s.apply(_trialPayload());
      expect(EntitlementService.allowsOutgoing, isTrue,
          reason: 'un code activé rouvre l\'émission sans redémarrage');
    });

    test('les droits survivent au redémarrage, pas à la déconnexion', () async {
      final a = EntitlementService(api: TalkyApiClient());
      await a.applyFromProfile({'entitlements': _payload()});
      expect(a.has(PlusFeature.translation), isFalse);

      final b = EntitlementService(api: TalkyApiClient());
      await b.loadFromCache();
      expect(b.current.known, isTrue);
      expect(EntitlementService.allows(PlusFeature.translation), isFalse);

      await b.clear();
      final c = EntitlementService(api: TalkyApiClient());
      await c.loadFromCache();
      expect(c.current.known, isFalse);
    });
  });
}
