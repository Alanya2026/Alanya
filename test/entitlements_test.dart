import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/services/billing/entitlements.dart';
import 'package:talky_flutter/core/services/media_expiry_policy.dart';
import 'package:talky_flutter/core/utils/media_upload_limits.dart';
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

const int _mo = 1024 * 1024;

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
  group('Plafonds d\'envoi', () {
    const mb = 1024 * 1024;

    test('sans mention du serveur : palier standard, 100 Mo et 30 médias', () {
      final e = Entitlements.fromJson(_payload());
      expect(e.limits.maxUploadBytes, 100 * mb);
      expect(e.limits.maxAlbumItems, 30);
      expect(e.limits.paid, isFalse);
      expect(e.limits.maxUploadMb, 100);
      expect(Entitlements.unrestricted.limits.maxAlbumItems, 30);
    });

    test('abonné : 200 Mo et 100 médias, tels que le serveur les annonce', () {
      final e = Entitlements.fromJson({
        ..._payload(),
        'limits': {'maxUploadBytes': 200 * mb, 'maxAlbumItems': 100, 'tier': 'paid'},
      });
      expect(e.limits.maxUploadBytes, 200 * mb);
      expect(e.limits.maxUploadMb, 200);
      expect(e.limits.maxAlbumItems, 100);
      expect(e.limits.paid, isTrue);
    });

    test('une valeur absurde ne donne jamais un plafond nul ou négatif', () {
      for (final bad in [0, -5, 'abc', null]) {
        final e = Entitlements.fromJson({
          ..._payload(),
          'limits': {'maxUploadBytes': bad, 'maxAlbumItems': bad},
        });
        expect(e.limits.maxUploadBytes, 100 * mb, reason: '$bad');
        expect(e.limits.maxAlbumItems, 30, reason: '$bad');
      }
    });

    test('les plafonds survivent au cache local', () {
      final e = Entitlements.fromJson({
        ..._payload(),
        'limits': {'maxUploadBytes': 200 * mb, 'maxAlbumItems': 100, 'tier': 'paid'},
      });
      final back = Entitlements.fromJson(e.toJson());
      expect(back.limits.maxUploadBytes, 200 * mb);
      expect(back.limits.maxAlbumItems, 100);
      expect(back.limits.paid, isTrue);
    });

    test('le service les rend sans contexte, et les reprend à l\'expiration', () async {
      SharedPreferences.setMockInitialValues({});
      final s = EntitlementService(api: TalkyApiClient());
      expect(EntitlementService.maxUploadBytes, 100 * mb);
      await s.apply({
        ..._payload(),
        'limits': {'maxUploadBytes': 200 * mb, 'maxAlbumItems': 100, 'tier': 'paid'},
      });
      expect(EntitlementService.maxUploadBytes, 200 * mb);
      expect(EntitlementService.maxUploadMb, 200);
      expect(EntitlementService.maxAlbumItems, 100);
      // L'abonnement a pris fin : le serveur n'annonce plus que le palier standard.
      await s.apply(_payload());
      expect(EntitlementService.maxUploadBytes, 100 * mb);
      expect(EntitlementService.maxAlbumItems, 30);
      s.dispose();
      expect(EntitlementService.maxAlbumItems, 30, reason: 'sans service : standard');
    });
  });

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

  // Durée pendant laquelle CE compte peut télécharger un média de discussion :
  // c'est elle que l'app applique pour afficher « Média expiré ».
  group('conservation des médias', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MediaExpiryPolicy.resetForTests();
    });

    test('lue dans les droits, gardée par le cache', () {
      final e = Entitlements.fromJson({..._payload(), 'mediaRetentionDays': 365});
      expect(e.mediaRetentionDays, 365);
      expect(Entitlements.fromJson(e.toJson()).mediaRetentionDays, 365);
      expect(Entitlements.fromJson(_payload()).mediaRetentionDays, isNull, reason: 'serveur antérieur');
    });

    test('appliquée à la politique d’expiration, oubliée à la déconnexion', () async {
      // Le 410 annonce le plafond du serveur (un abonné garde 365 jours)…
      MediaExpiryPolicy.resetForTests(retentionDays: 365);
      final s = EntitlementService(api: TalkyApiClient());
      // … mais ce compte, standard, s'arrête à 30.
      await s.applyFromProfile({
        'entitlements': {..._payload(), 'mediaRetentionDays': 30},
      });
      expect(MediaExpiryPolicy.retentionDays, 30);

      const url = 'https://www.alanya237.com/uploads/media/2026-08-01/images/a.jpg';
      expect(MediaExpiryPolicy.isExpired(url, now: DateTime.utc(2026, 9, 15)), isTrue);

      await s.clear();
      expect(MediaExpiryPolicy.retentionDays, 365, reason: 'retour à la durée apprise');
      expect(MediaExpiryPolicy.isExpired(url, now: DateTime.utc(2026, 9, 15)), isFalse);
    });

    test('rechargée depuis le cache au démarrage', () async {
      final a = EntitlementService(api: TalkyApiClient());
      await a.applyFromProfile({
        'entitlements': {..._payload(), 'mediaRetentionDays': 365},
      });
      MediaExpiryPolicy.resetForTests();

      final b = EntitlementService(api: TalkyApiClient());
      await b.loadFromCache();
      expect(MediaExpiryPolicy.retentionDays, 365);
    });
  });

  // Plafonds d'envoi de CE compte : l'app les applique dès le choix du fichier.
  group('plafonds d’envoi', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MediaUploadLimits.apply();
    });

    Map<String, dynamic> withLimits(int bytes, int album, String tier) => {
          ..._payload(),
          'limits': {'maxUploadBytes': bytes, 'maxAlbumItems': album, 'tier': tier},
        };

    test('lus dans les droits, gardés par le cache', () {
      final e = Entitlements.fromJson(withLimits(200 * _mo, 100, 'paid'));
      expect(e.limits.maxUploadBytes, 200 * _mo);
      expect(e.limits.maxAlbumItems, 100);
      final relu = Entitlements.fromJson(e.toJson());
      expect(relu.limits.maxUploadBytes, 200 * _mo);
      expect(relu.limits.maxAlbumItems, 100);
      expect(relu.limits.paid, isTrue);
      expect(Entitlements.fromJson(_payload()).limits.maxUploadBytes,
          kMaxMediaUploadBytes,
          reason: 'serveur antérieur : palier standard');
    });

    test('sans rien d’annoncé : palier standard', () {
      expect(MediaUploadLimits.maxBytes, kMaxMediaUploadBytes);
      expect(MediaUploadLimits.maxMegabytes, 100);
      expect(MediaUploadLimits.maxAlbumItems, kMaxAlbumItems);
    });

    test('appliqués à l’app, oubliés à la déconnexion', () async {
      final s = EntitlementService(api: TalkyApiClient());
      await s.applyFromProfile({'entitlements': withLimits(200 * _mo, 100, 'paid')});
      expect(MediaUploadLimits.maxBytes, 200 * _mo);
      expect(MediaUploadLimits.maxMegabytes, 200);
      expect(MediaUploadLimits.maxAlbumItems, 100);

      await s.clear();
      expect(MediaUploadLimits.maxBytes, kMaxMediaUploadBytes,
          reason: 'le compte suivant ne garde pas les plafonds de l’abonné');
      expect(MediaUploadLimits.maxAlbumItems, kMaxAlbumItems);
    });

    test('serveur antérieur, sans plafonds : palier standard', () async {
      final s = EntitlementService(api: TalkyApiClient());
      await s.applyFromProfile({'entitlements': _payload()});
      expect(MediaUploadLimits.maxBytes, kMaxMediaUploadBytes);
      expect(MediaUploadLimits.maxAlbumItems, kMaxAlbumItems);
    });

    test('rechargés depuis le cache au démarrage', () async {
      final a = EntitlementService(api: TalkyApiClient());
      await a.applyFromProfile({'entitlements': withLimits(200 * _mo, 100, 'paid')});
      MediaUploadLimits.apply();

      final b = EntitlementService(api: TalkyApiClient());
      await b.loadFromCache();
      expect(MediaUploadLimits.maxBytes, 200 * _mo);
      expect(MediaUploadLimits.maxAlbumItems, 100);
    });
  });
}
