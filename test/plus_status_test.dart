import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/billing/entitlements.dart';
import 'package:talky_flutter/core/services/billing/plus_status.dart';

final _now = DateTime.utc(2026, 9, 22, 12);
String _at(int days) => _now.add(Duration(days: days)).toIso8601String();

Entitlements _e({
  int model = 1,
  Map<String, dynamic>? trial,
  String phase = 'paid',
  Map<String, dynamic>? period,
  Map<String, dynamic>? upcoming,
  String? graceUntil,
  String? lapsedAt,
  bool exempt = false,
}) =>
    Entitlements.fromJson({
      'model': model,
      if (trial != null) 'trial': trial,
      'phase': phase,
      'graceUntil': graceUntil,
      'period': period,
      'upcoming': upcoming,
      'exempt': exempt,
      'features': const <String, bool>{},
      'lapsedAt': lapsedAt,
    });

Map<String, dynamic> _period(int fromDays, int toDays,
        {String plan = 'plus_mensuel'}) =>
    {'plan': plan, 'startsAt': _at(fromDays), 'endsAt': _at(toDays)};

void main() {
  group('plusStatusOf — un message par situation', () {
    test('droits inconnus ou compte exempté : rien à montrer', () {
      expect(plusStatusOf(Entitlements.unrestricted), PlusStatus.hidden);
      expect(plusStatusOf(_e(exempt: true)), PlusStatus.hidden);
    });

    test('interrupteur éteint : rien, même avec une période offerte', () {
      expect(plusStatusOf(_e(phase: 'free')), PlusStatus.hidden);
      expect(plusStatusOf(_e(phase: 'free', period: _period(-3, 27))),
          PlusStatus.hidden);
    });

    test('grâce, puis abonnement payé pendant la grâce', () {
      expect(plusStatusOf(_e(phase: 'grace', graceUntil: _at(18))),
          PlusStatus.grace);
      expect(
        plusStatusOf(_e(
          phase: 'grace',
          graceUntil: _at(18),
          upcoming: _period(18, 383, plan: 'plus_annuel'),
        )),
        PlusStatus.scheduled,
      );
    });

    test('payant : à vendre, actif, ou terminé', () {
      expect(plusStatusOf(_e()), PlusStatus.upgrade);
      expect(plusStatusOf(_e(period: _period(-3, 27))), PlusStatus.active);
      expect(plusStatusOf(_e(lapsedAt: _at(-4))), PlusStatus.lapsed);
    });
  });

  group('Régime essai', () {
    Map<String, dynamic> trial({required bool active, int endsInDays = 40}) =>
        {'endsAt': _at(endsInDays), 'active': active};

    test('essai en cours : tout est ouvert, avec son décompte', () {
      expect(plusStatusOf(_e(model: 2, trial: trial(active: true))),
          PlusStatus.trial);
      // La grâce du payant qui s'allume est, pour ce régime, l'essai.
      expect(
          plusStatusOf(_e(model: 2, phase: 'grace', trial: trial(active: true))),
          PlusStatus.trial);
    });

    test('essai fini, rien n\'a pris le relais : réception seule', () {
      expect(
          plusStatusOf(_e(model: 2, trial: trial(active: false, endsInDays: -3))),
          PlusStatus.restricted);
    });

    test('un abonnement qui a pris fin reste « terminé », pas « essai fini »', () {
      expect(
          plusStatusOf(_e(
            model: 2,
            trial: trial(active: false, endsInDays: -200),
            lapsedAt: _at(-5),
          )),
          PlusStatus.lapsed);
    });

    test('abonné, ou abonnement payé pendant l\'essai : comme d\'habitude', () {
      expect(
          plusStatusOf(_e(
            model: 2,
            trial: trial(active: false, endsInDays: -3),
            period: _period(-3, 360, plan: 'plus_annuel'),
          )),
          PlusStatus.active);
      expect(
          plusStatusOf(_e(
            model: 2,
            trial: trial(active: true),
            upcoming: _period(40, 405, plan: 'plus_annuel'),
          )),
          PlusStatus.scheduled);
    });

    test('payant éteint : rien à montrer, essai ou pas', () {
      expect(
          plusStatusOf(_e(model: 2, phase: 'free', trial: trial(active: true))),
          PlusStatus.hidden);
    });

    test('régime Alanya Plus : les états d\'avant, inchangés', () {
      expect(plusStatusOf(_e()), PlusStatus.upgrade);
      expect(plusStatusOf(_e(phase: 'grace', graceUntil: _at(18))), PlusStatus.grace);
    });
  });

  group('Échéances', () {
    test('jours restants arrondis au-dessus', () {
      expect(plusDaysLeft(_now.add(const Duration(hours: 25)), _now), 2);
      expect(plusDaysLeft(_now.add(const Duration(hours: 1)), _now), 1);
      expect(plusDaysLeft(_now.subtract(const Duration(hours: 1)), _now), 0);
    });

    test('relance à J-7 au mois, à J-30 à l\'année', () {
      PlusPeriod p(int from, int to) =>
          PlusPeriod.fromJson(_period(from, to));
      expect(plusEndsSoon(p(-25, 5), _now), isTrue);
      expect(plusEndsSoon(p(-20, 10), _now), isFalse);
      expect(plusEndsSoon(p(-345, 20), _now), isTrue);
      expect(plusEndsSoon(p(-300, 65), _now), isFalse);
    });
  });

  group('Période suivante — même règle que le serveur', () {
    test('sans rien en cours : maintenant', () {
      expect(plusNextPeriodStart(_e(), _now), _now);
    });

    test('à la suite de l\'abonnement en cours ou à venir', () {
      expect(plusNextPeriodStart(_e(period: _period(-3, 27)), _now),
          DateTime.parse(_at(27)));
      expect(
        plusNextPeriodStart(
            _e(phase: 'grace', upcoming: _period(18, 383), graceUntil: _at(18)),
            _now),
        DateTime.parse(_at(383)),
      );
    });

    test('jamais avant la fin de la grâce', () {
      expect(
        plusNextPeriodStart(_e(phase: 'grace', graceUntil: _at(18)), _now),
        DateTime.parse(_at(18)),
      );
    });

    test('jamais avant la fin de l\'essai : payer pendant l\'essai ne le consomme pas', () {
      final e = _e(model: 2, trial: {'endsAt': _at(40), 'active': true});
      expect(plusNextPeriodStart(e, _now), DateTime.parse(_at(40)));
      // Essai fini : maintenant.
      final over = _e(model: 2, trial: {'endsAt': _at(-3), 'active': false});
      expect(plusNextPeriodStart(over, _now), _now);
      // Hors régime essai, une fin d'essai éventuelle n'entre pas en compte.
      final plus = _e(trial: {'endsAt': _at(40), 'active': true});
      expect(plusNextPeriodStart(plus, _now), _now);
      // Un abonnement déjà posé plus loin reste devant.
      final chained = _e(
        model: 2,
        trial: {'endsAt': _at(40), 'active': true},
        upcoming: _period(40, 405, plan: 'plus_annuel'),
      );
      expect(plusNextPeriodStart(chained, _now), DateTime.parse(_at(405)));
    });

    test('ajout de mois, jour ramené à la fin du mois', () {
      expect(plusAddMonths(DateTime.utc(2027, 1, 31), 1),
          DateTime.utc(2027, 2, 28));
      expect(plusAddMonths(DateTime.utc(2028, 1, 31), 1),
          DateTime.utc(2028, 2, 29));
      expect(plusAddMonths(DateTime.utc(2026, 10, 10, 9), 12),
          DateTime.utc(2027, 10, 10, 9));
      expect(plusAddMonths(DateTime.utc(2026, 11, 30), 3),
          DateTime.utc(2027, 2, 28));
    });
  });
}
