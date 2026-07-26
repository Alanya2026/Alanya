import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';

/// Le `content` d'un message système est un JSON machine-lisible, jamais une
/// phrase pré-rendue : le fil doit s'afficher dans la langue du lecteur, pas
/// dans celle de l'acteur.
void main() {
  String encode(Map<String, dynamic> payload) => jsonEncode(payload);

  group('SystemEventPayload.tryParse', () {
    test('member_added → acteur, cibles et noms dénormalisés', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'member_added',
        'by': 12,
        'byName': 'Chris',
        'ids': [45, 46],
        'names': ['Marc', 'Léa'],
      }));

      expect(p, isNotNull);
      expect(p!.event, SystemEvent.memberAdded);
      expect(p.actorId, 12);
      expect(p.actorName, 'Chris');
      expect(p.targetIds, [45, 46]);
      expect(p.targetNames, ['Marc', 'Léa']);
      expect(p.targetLabel(separator: ', '), 'Marc, Léa');
    });

    test('group_renamed → le nouveau nom est dans value', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'group_renamed',
        'by': 1,
        'byName': 'Chris',
        'value': 'Projet Vitrine',
      }));

      expect(p!.event, SystemEvent.groupRenamed);
      expect(p.value, 'Projet Vitrine');
      expect(p.targetIds, isEmpty);
    });

    test('role_changed → le rôle attribué est exposé', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'role_changed',
        'by': 1,
        'byName': 'Chris',
        'ids': [45],
        'names': ['Marc'],
        'role': 1,
      }));

      expect(p!.role, 1);
      expect(p.targetLabel(separator: ', '), 'Marc');
    });

    test('settings_changed → verrou concerné et nouvel état', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'settings_changed',
        'by': 1,
        'byName': 'Chris',
        'lock': 'send',
        'on': 1,
      }));

      expect(p!.lock, 'send');
      expect(p.lockEnabled, isTrue);
    });

    // Compatibilité ascendante : une version future du serveur peut émettre un
    // événement que ce client ne connaît pas. Mieux vaut ne rien afficher que
    // du JSON brut dans une bulle.
    test('événement inconnu → null (compatibilité ascendante)', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'group_archived_by_alien',
        'by': 1,
        'byName': 'Chris',
      }));

      expect(p, isNull);
    });

    test('JSON invalide → null, sans lever', () {
      expect(SystemEventPayload.tryParse('pas du json'), isNull);
      expect(SystemEventPayload.tryParse('[1,2,3]'), isNull);
      expect(SystemEventPayload.tryParse(''), isNull);
      expect(SystemEventPayload.tryParse(null), isNull);
    });

    test('champ `e` absent ou non textuel → null', () {
      expect(SystemEventPayload.tryParse(encode({'by': 1})), isNull);
      expect(SystemEventPayload.tryParse(encode({'e': 7, 'by': 1})), isNull);
    });

    // Un payload écrit par une version antérieure peut ne pas porter `names`.
    // On veut un repli propre, pas une exception ni une phrase tronquée.
    test('noms absents → pas de plantage, hasTargetNames faux', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'member_removed',
        'by': 1,
        'byName': 'Chris',
        'ids': [45],
      }));

      expect(p, isNotNull);
      expect(p!.targetIds, [45]);
      expect(p.targetNames, isEmpty);
      expect(p.hasTargetNames, isFalse);
      expect(p.targetLabel(separator: ', '), '');
    });

    test('ids transmis en chaînes → normalisés en entiers', () {
      final p = SystemEventPayload.tryParse(encode({
        'e': 'member_added',
        'by': '12',
        'byName': 'Chris',
        'ids': ['45', 46, 'zz'],
      }));

      // 'zz' n'est pas un entier : on l'écarte au lieu de propager un null.
      expect(p!.targetIds, [45, 46]);
    });

    test('acteur absent → id 0 et nom vide, jamais null', () {
      final p = SystemEventPayload.tryParse(encode({'e': 'member_left'}));

      expect(p, isNotNull);
      expect(p!.actorId, 0);
      expect(p.actorName, '');
    });
  });

  group('kSystemMessageType', () {
    test('vaut 6 — le seul code libre entre localisation (5) et contact (7)', () {
      expect(kSystemMessageType, 6);
    });
  });
}
