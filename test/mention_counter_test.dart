import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';

import 'fakes/chat_test_harness.dart';

/// Le compteur du bouton de saut est entièrement DÉRIVÉ du cache local : aucun
/// champ serveur, aucune requête réseau. Il suit `countUnread`, donc il tombe
/// quand les messages passent en lu — jamais au moment du saut, ce qui le rend
/// incapable de devenir négatif ou de se désynchroniser.
void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
  });

  tearDown(() async => h.tearDown());

  /// [mentions] null = message sans aucune mention.
  Future<void> seedMessage({
    required int msgID,
    required int senderID,
    List<int>? mentions,
    int status = 1,
    int type = 0,
    bool isDeleted = false,
    int? deletedForID,
  }) {
    return h.db.into(h.db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: 'c$msgID',
            conversationID: ChatTestHarness.convId,
            senderID: senderID,
            sendAt: DateTime.utc(2026, 7, 26, 10, msgID),
            msgID: Value(msgID),
            status: Value(status),
            type: Value(type),
            isDeleted: Value(isDeleted),
            deletedForID: Value(deletedForID),
            mentionsJson: Value(encodeMentions(mentions)),
          ),
        );
  }

  Future<List<int>> compteur() =>
      h.dao.unreadMentionMsgIds(ChatTestHarness.convId, ChatTestHarness.myId);

  test('compte les mentions non lues qui me ciblent', () async {
    await seedMessage(msgID: 1, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    await seedMessage(msgID: 2, senderID: ChatTestHarness.otherId);
    await seedMessage(msgID: 3, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);

    expect(await compteur(), [1, 3]);
  });

  test('ordre du plus ancien au plus récent — le sens de lecture', () async {
    await seedMessage(msgID: 5, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    await seedMessage(msgID: 2, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    await seedMessage(msgID: 9, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);

    // Trié par sendAt, que le seed fait croître avec msgID.
    expect(await compteur(), [2, 5, 9]);
  });

  test('mention visant quelqu\'un d\'autre → non comptée', () async {
    await seedMessage(msgID: 1, senderID: ChatTestHarness.otherId, mentions: [99]);
    expect(await compteur(), isEmpty);
  });

  test('mention dans MON propre message → non comptée', () async {
    await seedMessage(
      msgID: 1,
      senderID: ChatTestHarness.myId,
      mentions: [ChatTestHarness.myId],
    );
    expect(await compteur(), isEmpty);
  });

  test('message déjà lu (status 3) → non compté', () async {
    await seedMessage(
      msgID: 1,
      senderID: ChatTestHarness.otherId,
      mentions: [ChatTestHarness.myId],
      status: 3,
    );
    expect(await compteur(), isEmpty);
  });

  test('message lu ensuite → le compteur décroît de lui-même', () async {
    await seedMessage(msgID: 1, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    await seedMessage(msgID: 2, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    expect(await compteur(), hasLength(2));

    await (h.db.update(h.db.localMessages)
          ..where((m) => m.msgID.equals(1)))
        .write(const LocalMessagesCompanion(status: Value(3)));

    expect(await compteur(), [2]);
  });

  test('message supprimé → non compté', () async {
    await seedMessage(
      msgID: 1,
      senderID: ChatTestHarness.otherId,
      mentions: [ChatTestHarness.myId],
      isDeleted: true,
    );
    await seedMessage(
      msgID: 2,
      senderID: ChatTestHarness.otherId,
      mentions: [ChatTestHarness.myId],
      deletedForID: ChatTestHarness.myId,
    );
    expect(await compteur(), isEmpty);
  });

  // Un message système porte le senderID de l'acteur : sans exclusion il
  // pourrait entrer dans le décompte comme n'importe quel message entrant.
  test('message système → jamais compté, même avec des mentions', () async {
    await seedMessage(
      msgID: 1,
      senderID: ChatTestHarness.otherId,
      mentions: [ChatTestHarness.myId],
      type: kSystemMessageType,
    );
    expect(await compteur(), isEmpty);
  });

  test('message non confirmé (msgID 0) → écarté, on ne peut pas y sauter',
      () async {
    await h.db.into(h.db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: 'pending',
            conversationID: ChatTestHarness.convId,
            senderID: ChatTestHarness.otherId,
            sendAt: DateTime.utc(2026, 7, 26, 11),
            status: const Value(1),
            mentionsJson: Value(encodeMentions([ChatTestHarness.myId])),
          ),
        );
    expect(await compteur(), isEmpty);
  });

  test('aucune mention → liste vide, le bouton reste masqué', () async {
    await seedMessage(msgID: 1, senderID: ChatTestHarness.otherId);
    expect(await compteur(), isEmpty);
  });

  test('myId inconnu (auth pas encore hydratée) → liste vide', () async {
    await seedMessage(msgID: 1, senderID: ChatTestHarness.otherId, mentions: [ChatTestHarness.myId]);
    expect(await h.dao.unreadMentionMsgIds(ChatTestHarness.convId, 0), isEmpty);
  });

  // LE bug rapporté : le bouton « @ » n'apparaissait jamais parce que les
  // messages venant du SERVEUR n'écrivaient jamais mentionsJson. Ces tests
  // passent par le vrai chemin d'ingestion, pas par un insert direct.
  group('ingestion serveur', () {
    Map<String, dynamic> msgServeur({
      required int msgID,
      Object? mentions,
      int senderID = ChatTestHarness.otherId,
    }) =>
        {
          'msgID': msgID,
          'clientId': 'srv$msgID',
          'conversationID': ChatTestHarness.convId,
          'senderID': senderID,
          'content': 'coucou',
          'type': 0,
          'status': 1,
          'sendAt': DateTime.utc(2026, 7, 26, 12, msgID).toIso8601String(),
          if (mentions != null) 'mentions': mentions,
        };

    test('message reçu avec mentions → compté (c\'était le bug)', () async {
      h.api.emit('message:received',
          msgServeur(msgID: 1, mentions: [ChatTestHarness.myId]));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await compteur(), [1],
          reason: 'mentionsJson non hydraté depuis le payload serveur');
    });

    test('liste déjà parsée par le pilote MySQL → prise en charge', () async {
      // mysql2 rend une colonne JSON déjà décodée : c'est une List, pas une
      // chaîne JSON.
      h.api.emit('message:received',
          msgServeur(msgID: 2, mentions: <dynamic>[ChatTestHarness.myId, 99]));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await compteur(), [2]);
    });

    test('mentions transmises en chaîne JSON → prises en charge', () async {
      h.api.emit('message:received',
          msgServeur(msgID: 3, mentions: '[${ChatTestHarness.myId}]'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await compteur(), [3]);
    });

    test('message reçu sans mention → non compté', () async {
      h.api.emit('message:received', msgServeur(msgID: 4));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await compteur(), isEmpty);
    });

    test('marqueur « all » d\'un grand groupe → me concerne', () async {
      h.api.emit('message:received', msgServeur(msgID: 5, mentions: '"all"'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await compteur(), [5],
          reason: 'un @Tous non déplié doit rester visible');
    });
  });

  group('mentionsUser', () {
    test('liste contenant mon id → vrai', () {
      expect(mentionsUser('[45,7]', 7), isTrue);
      expect(mentionsUser('[45,46]', 7), isFalse);
    });

    // decodeMentions renvoie [] sur le marqueur : un test par `contains`
    // manquerait entièrement le @Tous des grands groupes.
    test('marqueur « all » → vrai pour tout le monde', () {
      expect(mentionsUser('"all"', 7), isTrue);
      expect(mentionsUser('"all"', 99), isTrue);
    });

    test('null, vide ou illisible → faux, sans lever', () {
      expect(mentionsUser(null, 7), isFalse);
      expect(mentionsUser('', 7), isFalse);
      expect(mentionsUser('{{', 7), isFalse);
      expect(mentionsUser('{"a":1}', 7), isFalse);
    });

    test('myId inconnu → faux même sur un marqueur all', () {
      expect(mentionsUser('"all"', 0), isFalse);
    });
  });

  group('encodeMentions / decodeMentions', () {
    // On n'écrit pas `[]` : la requête du compteur filtre sur IS NOT NULL.
    test('liste vide ou nulle → null en base', () {
      expect(encodeMentions(null), isNull);
      expect(encodeMentions([]), isNull);
    });

    test('aller-retour conservé', () {
      expect(decodeMentions(encodeMentions([45, 46])), [45, 46]);
    });

    test('JSON illisible → liste vide, sans lever', () {
      expect(decodeMentions('pas du json'), isEmpty);
      expect(decodeMentions('{"a":1}'), isEmpty);
      expect(decodeMentions(null), isEmpty);
      expect(decodeMentions(''), isEmpty);
    });

    test('ids transmis en chaînes → normalisés', () {
      expect(decodeMentions('["45",46,"zz"]'), [45, 46]);
    });
  });
}
