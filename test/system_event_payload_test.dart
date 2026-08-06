import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

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

  // Le libellé est rendu dans la langue DU LECTEUR : le serveur ne stocke
  // jamais de phrase pré-rendue.
  group('SystemEventPayload.label', () {
    late AppLocalizations fr;
    late AppLocalizations en;

    setUp(() {
      fr = lookupAppLocalizations(const Locale('fr'));
      en = lookupAppLocalizations(const Locale('en'));
    });

    SystemEventPayload parse(Map<String, dynamic> p) =>
        SystemEventPayload.tryParse(encode(p))!;

    const me = 7;

    test('acteur tiers → phrase à la troisième personne', () {
      final p = parse({
        'e': 'member_added',
        'by': 12,
        'byName': 'Chris',
        'ids': [45],
        'names': ['Marc'],
      });
      expect(p.label(me, fr), 'Chris a ajouté Marc');
      expect(p.label(me, en), 'Chris added Marc');
    });

    // En français, substituer « Vous » à l'acteur donnerait « Vous a ajouté ».
    // D'où deux clés par événement plutôt qu'un placeholder.
    test('acteur = moi → formulation à la première personne, conjuguée', () {
      final p = parse({
        'e': 'member_added',
        'by': me,
        'byName': 'Moi',
        'ids': [45],
        'names': ['Marc'],
      });
      expect(p.label(me, fr), 'Vous avez ajouté Marc');
      expect(p.label(me, en), 'You added Marc');
    });

    test('plusieurs cibles → noms joints', () {
      final p = parse({
        'e': 'member_removed',
        'by': 12,
        'byName': 'Chris',
        'ids': [45, 46],
        'names': ['Marc', 'Léa'],
      });
      expect(p.label(me, fr), 'Chris a retiré Marc, Léa');
    });

    test('role_changed distingue promotion et rétrogradation', () {
      expect(
        parse({
          'e': 'role_changed',
          'by': 12,
          'byName': 'Chris',
          'ids': [45],
          'names': ['Marc'],
          'role': 1,
        }).label(me, fr),
        'Chris a nommé Marc administrateur',
      );
      expect(
        parse({
          'e': 'role_changed',
          'by': 12,
          'byName': 'Chris',
          'ids': [45],
          'names': ['Marc'],
          'role': 0,
        }).label(me, fr),
        "Chris a retiré les droits d'administrateur à Marc",
      );
    });

    test('settings_changed distingue le verrou et son sens', () {
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'send', 'on': 1})
            .label(me, fr),
        "Chris a réservé l'envoi aux administrateurs",
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'send', 'on': 0})
            .label(me, fr),
        'Chris a autorisé tout le monde à écrire',
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'edit', 'on': 1})
            .label(me, fr),
        'Chris a réservé la modification des infos aux administrateurs',
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'history', 'on': 1})
            .label(me, fr),
        "Chris a masqué l'historique pour les nouveaux membres",
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'history', 'on': 0})
            .label(me, fr),
        "Chris a rendu l'historique visible pour les nouveaux membres",
      );
      expect(
        parse({'e': 'settings_changed', 'by': me, 'byName': 'Moi', 'lock': 'history', 'on': 1})
            .label(me, fr),
        "Vous avez masqué l'historique pour les nouveaux membres",
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'add', 'on': 1})
            .label(me, fr),
        'Chris a réservé l\'ajout de membres aux administrateurs',
      );
      expect(
        parse({'e': 'settings_changed', 'by': 12, 'byName': 'Chris', 'lock': 'add', 'on': 0})
            .label(me, fr),
        'Chris a autorisé tout le monde à ajouter des membres',
      );
      expect(
        parse({'e': 'settings_changed', 'by': me, 'byName': 'Moi', 'lock': 'add', 'on': 1})
            .label(me, fr),
        'Vous avez réservé l\'ajout de membres aux administrateurs',
      );
    });

    test('member_left sans cible → phrase complète quand même', () {
      final p = parse({'e': 'member_left', 'by': 12, 'byName': 'Chris'});
      expect(p.label(me, fr), 'Chris a quitté le groupe');
      expect(p.label(12, fr), 'Vous avez quitté le groupe');
    });

    // Payload d'une version antérieure : on préfère une phrase générique à une
    // phrase amputée (« Chris a ajouté »).
    test('cibles manquantes → repli générique, jamais de phrase tronquée', () {
      final p = parse({'e': 'member_added', 'by': 12, 'byName': 'Chris', 'ids': [45]});
      expect(p.label(me, fr), 'Le groupe a été mis à jour');
    });

    test('nom d\'acteur vide → repli sur « expéditeur inconnu »', () {
      final p = parse({'e': 'member_left', 'by': 12, 'byName': '   '});
      expect(p.label(me, fr), contains(fr.unknownSender));
    });
  });

  group('SystemEventPayload.previewLabel', () {
    late AppLocalizations fr;

    setUp(() {
      fr = lookupAppLocalizations(const Locale('fr'));
    });

    SystemEventPayload parse(Map<String, dynamic> p) =>
        SystemEventPayload.tryParse(encode(p))!;

    test('member_added → aperçu court sans noms de cibles', () {
      final p = parse({
        'e': 'member_added',
        'by': 12,
        'byName': 'Chris',
        'ids': [45],
        'names': ['Marc'],
      });
      expect(p.previewLabel(fr), 'Chris a ajouté des membres');
    });

    test('group_created → aperçu avec nom du groupe', () {
      final p = parse({
        'e': 'group_created',
        'by': 12,
        'byName': 'Chris',
        'value': 'Projet Vitrine',
      });
      expect(p.previewLabel(fr), 'Chris a créé « Projet Vitrine »');
    });

    test('événement inconnu → repli générique', () {
      // previewLabel n'est appelé que sur des payloads déjà parsés (isKnown).
      expect(
        parse({'e': 'member_left', 'by': 12, 'byName': 'Chris'}).previewLabel(fr),
        'Chris a quitté le groupe',
      );
    });
  });
}
