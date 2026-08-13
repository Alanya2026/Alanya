import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/trip_payload.dart';
import 'package:talky_flutter/talky_models.dart';

/// Contenu du message de type 9 — la carte de trajet.
///
/// Ce que ces tests protègent : **ne jamais afficher de JSON brut** dans une
/// bulle ou un aperçu, et ne jamais poser un pin à une coordonnée absurde.
/// Les deux se sont produits.
void main() {
  String carte(Map<String, dynamic> champs) => jsonEncode({
        'v': 1,
        'tripId': 7,
        'kind': TripKind.taxi,
        'state': TripState.active,
        ...champs,
      });

  group('TripCardPayload.tryParse', () {
    test('décode une carte complète', () {
      final p = TripCardPayload.tryParse(carte({
        'state': TripState.awaitingConfirm,
        'destLabel': 'Domicile',
        'note': 'Taxi jaune',
        'lastLat': 3.848,
        'lastLng': 11.5021,
      }));
      expect(p, isNotNull);
      expect(p!.tripId, 7);
      expect(p.state, TripState.awaitingConfirm);
      expect(p.destLabel, 'Domicile');
      expect(p.hasPoint, isTrue);
    });

    test('refuse une version future plutôt que de deviner', () {
      // Un client qui « fait au mieux » avec un format qu'il ne connaît pas
      // finit par afficher n'importe quoi. Mieux vaut un repli explicite.
      expect(TripCardPayload.tryParse('{"v":2,"tripId":7}'), isNull);
    });

    test('refuse un contenu illisible sans lever', () {
      for (final brut in ['', 'pas du json', '[]', '{"tripId":0}']) {
        expect(TripCardPayload.tryParse(brut), isNull, reason: brut);
      }
    });

    test('écarte une coordonnée hors domaine', () {
      // Une latitude à 91° ferait planter la projection de la carte. On rend
      // `null` : la vignette disparaît proprement au lieu de situer la personne
      // là où elle n'est pas.
      final p = TripCardPayload.tryParse(
          carte({'lastLat': 91.0, 'lastLng': 11.5}));
      expect(p!.lastLat, isNull);
      expect(p.hasPoint, isFalse);
    });

    test('un champ inconnu ne casse rien', () {
      // Le serveur peut enrichir la carte sans changer `v` : un client plus
      // ancien doit continuer de fonctionner.
      final p = TripCardPayload.tryParse(carte({'futurChamp': 'xyz'}));
      expect(p, isNotNull);
      expect(p!.state, TripState.active);
    });
  });

  group('fausse alerte', () {
    test('reconnue seulement sur une annulation', () {
      final p = TripCardPayload.tryParse(carte({
        'state': TripState.closedCancelled,
        'closeReason': 'false_alarm',
      }));
      expect(p!.isFalseAlarm, isTrue);
    });

    test('un arrêt ordinaire n\'est pas un démenti', () {
      final p = TripCardPayload.tryParse(carte({
        'state': TripState.closedCancelled,
        'closeReason': 'stopped_by_owner',
      }));
      expect(p!.isFalseAlarm, isFalse);
    });

    test('le motif seul ne suffit pas sur un état ouvert', () {
      // Sinon un trajet en cours pourrait s'annoncer comme démenti.
      final p = TripCardPayload.tryParse(carte({
        'state': TripState.active,
        'closeReason': 'false_alarm',
      }));
      expect(p!.isFalseAlarm, isFalse);
    });
  });
}
