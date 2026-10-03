import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/billing/activation_code.dart';
import 'package:talky_flutter/core/services/billing/billing_models.dart';

/// Vecteurs calculés par le SERVEUR (Alanya-Backend, codeFormat.js
/// `checkSymbol`) : si ce test échoue, le téléphone et le serveur ne sont plus
/// d'accord sur ce qu'est un code valide.
const _serverCodes = [
  '0123456789ABCD1',
  'ZZZZZZZZZZZZZZW',
  '000000000000000',
  '7K2QXM9P4BT3VHN',
  'ABCDEFGHJKMNPQ9',
];

void main() {
  group('Le contrôle est celui du serveur', () {
    test('les codes que le serveur a produits sont acceptés', () {
      for (final code in _serverCodes) {
        final r = parseActivationCode(code);
        expect(r.canonical, code, reason: code);
        expect(r.issue, isNull);
      }
    });

    test('toute écriture qu\'un utilisateur peut taper redonne le même code', () {
      const code = '7K2QXM9P4BT3VHN';
      for (final typed in [
        '7K2QX-M9P4B-T3VHN',
        '7k2qx-m9p4b-t3vhn',
        '  7K2QX M9P4B T3VHN  ',
        '7K2QX.M9P4B.T3VHN',
        '7K2QXM9P4BT3VHN',
      ]) {
        expect(parseActivationCode(typed).canonical, code, reason: typed);
      }
    });

    test('les confusions usuelles sont corrigées : O→0, I et L→1', () {
      expect(parseActivationCode('O123456789ABCD1').canonical, '0123456789ABCD1');
      expect(parseActivationCode('0I23456789ABCD1').canonical, '0123456789ABCD1');
      expect(parseActivationCode('0l23456789ABCD1').canonical, '0123456789ABCD1');
    });
  });

  group('Refus', () {
    test('longueur ou symbole impossible', () {
      for (final bad in ['', 'ABC', 'A' * 16, '0123456789ABCDU', '0123456789ABCD#']) {
        expect(parseActivationCode(bad).issue, ActivationCodeIssue.format, reason: bad);
        expect(parseActivationCode(bad).canonical, isNull);
      }
    });

    test('une substitution d\'un seul symbole est toujours détectée', () {
      const code = '7K2QXM9P4BT3VHN';
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      for (var i = 0; i < code.length; i++) {
        for (final c in alphabet.split('')) {
          if (c == code[i]) continue;
          final typo = code.substring(0, i) + c + code.substring(i + 1);
          expect(parseActivationCode(typo).issue, ActivationCodeIssue.checksum,
              reason: 'faute en $i : ${code[i]}→$c');
        }
      }
    });
  });

  group('Mise en forme pendant la frappe', () {
    test('tirets tous les cinq, majuscules, quinze symboles au plus', () {
      expect(formatActivationInput(''), '');
      expect(formatActivationInput('7k2q'), '7K2Q');
      expect(formatActivationInput('7k2qxm'), '7K2QX-M');
      expect(formatActivationInput('7K2QXM9P4BT3VHN'), '7K2QX-M9P4B-T3VHN');
      expect(formatActivationInput('7K2QX-M9P4B-T3VHN-EXTRA'), '7K2QX-M9P4B-T3VHN');
    });

    test('les symboles impossibles disparaissent, les confusions se corrigent', () {
      expect(formatActivationInput('7K2#Q U'), '7K2Q');
      expect(formatActivationInput('OIL'), '011');
    });

    test('coller un code déjà formaté ne le déforme pas', () {
      expect(formatActivationInput('7K2QX-M9P4B-T3VHN'), '7K2QX-M9P4B-T3VHN');
    });
  });

  group('Adresse du site de paiement', () {
    test('seule la langue est ajoutée', () {
      expect(plusPayUri('https://pay.alanya237.com/abonnement', 'en').toString(),
          'https://pay.alanya237.com/abonnement?lang=en');
      expect(plusPayUri('https://pay.alanya237.com/', 'zh')!.queryParameters, {'lang': 'zh'});
    });

    test('une langue inconnue retombe sur le français', () {
      expect(plusPayUri('https://pay.alanya237.com/', 'de')!.queryParameters['lang'], 'fr');
    });

    test('un paramètre déjà présent est conservé', () {
      expect(plusPayUri('https://pay.alanya237.com/?ref=app', 'fr')!.queryParameters,
          {'ref': 'app', 'lang': 'fr'});
    });

    test('pas d\'adresse, ou pas en https : pas de bouton', () {
      expect(plusPayUri(null, 'fr'), isNull);
      expect(plusPayUri('', 'fr'), isNull);
      expect(plusPayUri('   ', 'fr'), isNull);
      expect(plusPayUri('http://pay.alanya237.com/', 'fr'), isNull);
      expect(plusPayUri('javascript:alert(1)', 'fr'), isNull);
      expect(plusPayUri('pay.alanya237.com', 'fr'), isNull);
    });
  });

  group('Résultat d\'une activation', () {
    final now = DateTime.utc(2026, 10, 3, 12);

    test('période qui commence maintenant', () {
      final r = RedeemResult.fromJson({
        'startsAt': '2026-10-03T12:00:05.000Z',
        'endsAt': '2027-10-03T12:00:05.000Z',
        'alreadyApplied': false,
      });
      expect(r.startsLater(now), isFalse);
      expect(r.endsAt, DateTime.utc(2027, 10, 3, 12, 0, 5));
    });

    test('période qui commence à la fin de l\'essai', () {
      final r = RedeemResult.fromJson({
        'startsAt': '2026-12-01T00:00:00.000Z',
        'endsAt': '2027-12-01T00:00:00.000Z',
      });
      expect(r.startsLater(now), isTrue);
      expect(r.alreadyApplied, isFalse);
    });

    test('rejouée par le même compte', () {
      expect(RedeemResult.fromJson({'alreadyApplied': true}).alreadyApplied, isTrue);
    });
  });

  group('L\'offre porte le régime et le site de paiement', () {
    test('régime essai', () {
      final o = PlusOffer.fromJson({
        'model': 2,
        'payUrl': 'https://pay.alanya237.com/',
        'phase': 'paid',
        'purchasable': true,
        'plans': [
          {'code': 'plus_annuel', 'durationMonths': 12, 'price': 1000, 'featured': true},
        ],
      });
      expect(o.model.name, 'trial');
      expect(o.payUrl, 'https://pay.alanya237.com/');
      expect(o.defaultPlan!.price, 1000);
    });

    test('sans mention : Alanya Plus, sans site', () {
      final o = PlusOffer.fromJson({'phase': 'paid'});
      expect(o.model.name, 'plus');
      expect(o.payUrl, isNull);
      expect(PlusOffer.fromJson({'payUrl': '  '}).payUrl, isNull);
    });
  });
}
