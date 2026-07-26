import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/talky_models.dart';

import 'fakes/chat_test_harness.dart';

/// Les deux trames de groupe sont là où se logent les courses : elles écrivent
/// la même ligne Drift que le sync HTTP, et l'une d'elles concerne quelqu'un
/// qui vient de perdre son droit de la recevoir.
void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
    // On requalifie la conversation semée en groupe, avec un état
    // par-utilisateur non trivial : c'est lui qu'une trame partielle ne doit
    // jamais écraser.
    await h.db.update(h.db.localConversations).write(
          LocalConversationsCompanion(
            isGroup: const Value(true),
            groupName: const Value('Projet Vitrine'),
            unreadCount: const Value(4),
            isPinned: const Value(true),
            lastMessage: const Value('dernier message'),
            myRole: const Value(GroupRole.admin),
            metaUpdatedAt: Value(DateTime.utc(2026, 7, 26, 10)),
          ),
        );
  });

  tearDown(() async => h.tearDown());

  Map<String, dynamic> trameUpdated({
    String nom = 'Nouveau nom',
    String? updatedAt = '2026-07-26T11:00:00.000Z',
    List<Map<String, dynamic>>? participants,
  }) {
    return {
      'conversID': ChatTestHarness.convId,
      'isGroup': 1,
      'GroupName': nom,
      'description': 'une description',
      'onlyAdminsCanSend': 0,
      'onlyAdminsCanEditInfo': 0,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'participants': participants ??
          [
            {'alanyaID': ChatTestHarness.myId, 'nom': 'Moi', 'role': 1},
            {'alanyaID': ChatTestHarness.otherId, 'nom': 'Marc', 'role': 0},
          ],
    };
  }

  group('conversation:updated', () {
    test('nom mis à jour sans écraser unread, isPinned ni aperçu', () async {
      h.api.emit(SocketEvents.conversationUpdated, trameUpdated());
      await Future<void>.delayed(Duration.zero);

      final c = await h.conv();
      expect(c!.groupName, 'Nouveau nom');
      expect(c.description, 'une description');
      // Les champs par-utilisateur ne sont PAS dans la trame : les recopier
      // depuis un payload qui ne les contient pas remettrait le badge à zéro.
      expect(c.unreadCount, 4, reason: 'badge fantôme : unread écrasé');
      expect(c.isPinned, isTrue, reason: 'épinglage perdu');
      expect(c.lastMessage, 'dernier message', reason: 'aperçu écrasé');
      expect(c.myRole, GroupRole.admin, reason: 'mon rôle écrasé');
    });

    test('trame plus ancienne que le local → ignorée', () async {
      h.api.emit(
        SocketEvents.conversationUpdated,
        trameUpdated(nom: 'Nom périmé', updatedAt: '2026-07-26T09:00:00.000Z'),
      );
      await Future<void>.delayed(Duration.zero);

      final c = await h.conv();
      expect(c!.groupName, 'Projet Vitrine',
          reason: 'une trame réordonnée a ressuscité un ancien nom');
    });

    test('trame de même horodatage → ignorée (pas de réécriture inutile)',
        () async {
      h.api.emit(
        SocketEvents.conversationUpdated,
        trameUpdated(nom: 'Doublon', updatedAt: '2026-07-26T10:00:00.000Z'),
      );
      await Future<void>.delayed(Duration.zero);

      expect((await h.conv())!.groupName, 'Projet Vitrine');
    });

    test('trame sans updatedAt → appliquée (pas de garde possible)', () async {
      h.api.emit(
        SocketEvents.conversationUpdated,
        trameUpdated(nom: 'Sans horodatage', updatedAt: null),
      );
      await Future<void>.delayed(Duration.zero);

      expect((await h.conv())!.groupName, 'Sans horodatage');
    });

    test('le rôle des participants voyage bien dans la trame', () async {
      h.api.emit(
        SocketEvents.conversationUpdated,
        trameUpdated(participants: [
          {'alanyaID': ChatTestHarness.myId, 'nom': 'Moi', 'role': 2},
          {'alanyaID': ChatTestHarness.otherId, 'nom': 'Marc', 'role': 1},
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      final parts = decodeParticipants((await h.conv())!.participantsJson);
      final marc = parts.firstWhere(
          (p) => p['alanyaID'] == ChatTestHarness.otherId);
      expect(marc['role'], 1,
          reason: 'une promotion doit être visible en direct dans la fiche');
    });

    test('conversID absent ou nul → aucune écriture', () async {
      h.api.emit(SocketEvents.conversationUpdated, {'GroupName': 'Fantôme'});
      await Future<void>.delayed(Duration.zero);

      expect((await h.conv())!.groupName, 'Projet Vitrine');
    });
  });

  group('group:participant:removed', () {
    test('quand c\'est moi → la conversation est supprimée localement',
        () async {
      h.api.emit(SocketEvents.groupParticipantRemoved, {
        'conversID': ChatTestHarness.convId,
        'alanyaID': ChatTestHarness.myId,
        'removedBy': ChatTestHarness.otherId,
        'reason': 'kicked',
      });
      await Future<void>.delayed(Duration.zero);

      // C'est ce `null` que la fiche groupe et l'écran de discussion
      // interprètent comme « sors d'ici » : c'est le SEUL chemin qui prévient
      // l'exclu, qui ne reçoit plus conversation:updated.
      expect(await h.conv(), isNull);
    });

    test('quand c\'est un autre → la conversation est conservée', () async {
      h.api.emit(SocketEvents.groupParticipantRemoved, {
        'conversID': ChatTestHarness.convId,
        'alanyaID': ChatTestHarness.otherId,
        'removedBy': ChatTestHarness.myId,
        'reason': 'kicked',
      });
      await Future<void>.delayed(Duration.zero);

      final c = await h.conv();
      expect(c, isNotNull);
      expect(c!.unreadCount, 4, reason: 'le retrait d\'un tiers ne touche à rien');
    });

    test('mon propre départ (reason: left) → supprimée aussi', () async {
      h.api.emit(SocketEvents.groupParticipantRemoved, {
        'conversID': ChatTestHarness.convId,
        'alanyaID': ChatTestHarness.myId,
        'removedBy': ChatTestHarness.myId,
        'reason': 'left',
      });
      await Future<void>.delayed(Duration.zero);

      expect(await h.conv(), isNull);
    });

    test('charge incomplète → aucune suppression', () async {
      h.api.emit(SocketEvents.groupParticipantRemoved, {'reason': 'kicked'});
      h.api.emit(SocketEvents.groupParticipantRemoved,
          {'conversID': ChatTestHarness.convId});
      await Future<void>.delayed(Duration.zero);

      expect(await h.conv(), isNotNull,
          reason: 'une trame tronquée ne doit jamais faire disparaître un chat');
    });
  });

  group('opérations de groupe via le repository', () {
    test('updateGroupInfo écrit la réponse serveur en cache', () async {
      h.api.conversationById[ChatTestHarness.convId] = {
        'conversID': ChatTestHarness.convId,
        'isGroup': 1,
        'GroupName': 'Projet Vitrine',
        'participants': const [],
      };

      await h.repo.updateGroupInfo(ChatTestHarness.convId,
          groupName: 'Renommé', description: 'nouvelle description');

      final c = await h.conv();
      expect(c!.groupName, 'Renommé');
      expect(c.description, 'nouvelle description');
      expect(h.api.httpLog, contains('updateGroupInfo:${ChatTestHarness.convId}'));
    });

    // Online-only et sans écriture optimiste : un retrait appliqué localement
    // puis refusé par le serveur ferait croire l'action faite.
    test('un refus serveur ne modifie rien localement', () async {
      h.api.groupError = Exception('403 GROUP_ADMIN_REQUIRED');

      await expectLater(
        h.repo.setParticipantRole(ChatTestHarness.convId,
            ChatTestHarness.otherId, GroupRole.admin),
        throwsA(isA<Exception>()),
      );

      final parts = decodeParticipants((await h.conv())!.participantsJson);
      expect(parts.any((p) => p['role'] == GroupRole.admin), isFalse);
    });

    test('leaveGroup ne supprime en local qu\'après un aller-retour réussi',
        () async {
      h.api.groupError = Exception('réseau coupé');
      await expectLater(
        h.repo.leaveGroup(ChatTestHarness.convId),
        throwsA(isA<Exception>()),
      );
      expect(await h.conv(), isNotNull,
          reason: 'la conversation a disparu alors que le départ a échoué');

      h.api.groupError = null;
      await h.repo.leaveGroup(ChatTestHarness.convId);
      expect(await h.conv(), isNull);
    });

    test('setMentionsOnly n\'écrit que les colonnes de sourdine', () async {
      await h.repo.setMentionsOnly(ChatTestHarness.convId, true);

      final c = await h.conv();
      expect(c!.mentionsOnly, isTrue);
      // La réponse de /mute ne porte pas la conversation entière : passer par
      // le companion complet aurait vidé tout le reste.
      expect(c.groupName, 'Projet Vitrine');
      expect(c.unreadCount, 4);
    });
  });
}
