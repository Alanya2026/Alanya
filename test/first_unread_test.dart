import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';

import 'fakes/chat_test_harness.dart';

/// `firstUnreadMessage` est lu UNE fois à l'ouverture, avant que `markAsRead`
/// n'efface les statuts. Sa définition du « non lu » doit rester identique à
/// celle de `countUnread`, sinon le séparateur et le badge se contrediraient.
void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
  });

  tearDown(() async => h.tearDown());

  Future<void> seed({
    required int msgID,
    int senderID = ChatTestHarness.otherId,
    int status = 1,
    int type = 0,
    bool isDeleted = false,
    int? deletedForID,
    DateTime? sendAt,
  }) {
    return h.db.into(h.db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: 'c$msgID',
            conversationID: ChatTestHarness.convId,
            senderID: senderID,
            sendAt: sendAt ?? DateTime.utc(2026, 7, 26, 10, msgID),
            msgID: Value(msgID),
            status: Value(status),
            type: Value(type),
            isDeleted: Value(isDeleted),
            deletedForID: Value(deletedForID),
          ),
        );
  }

  Future<int?> premier() async =>
      (await h.dao.firstUnreadMessage(ChatTestHarness.convId, ChatTestHarness.myId))
          ?.msgID;

  test('renvoie le PLUS ANCIEN non lu, pas le plus récent', () async {
    await seed(msgID: 1, status: 3); // déjà lu
    await seed(msgID: 2);
    await seed(msgID: 3);

    expect(await premier(), 2);
  });

  test('ordre par date, pas par ordre d\'insertion', () async {
    await seed(msgID: 9, sendAt: DateTime.utc(2026, 7, 26, 12));
    await seed(msgID: 4, sendAt: DateTime.utc(2026, 7, 26, 11));

    expect(await premier(), 4);
  });

  // `sendAt` peut être identique à la milliseconde sur une rafale, et
  // `watchMessages` n'ordonne que par `sendAt` : sans le msgID en second
  // critère, le séparateur se placerait au hasard dans la rafale.
  test('rafale à la même milliseconde → départagée par msgID', () async {
    final t = DateTime.utc(2026, 7, 26, 12);
    await seed(msgID: 7, sendAt: t);
    await seed(msgID: 5, sendAt: t);
    await seed(msgID: 6, sendAt: t);

    expect(await premier(), 5);
  });

  test('mes propres messages ne comptent pas', () async {
    await seed(msgID: 1, senderID: ChatTestHarness.myId);
    expect(await premier(), isNull);
  });

  test('tout est lu → null, la conversation s\'ouvre en bas', () async {
    await seed(msgID: 1, status: 3);
    await seed(msgID: 2, status: 3);

    expect(await premier(), isNull);
  });

  test('conversation vide → null', () async {
    expect(await premier(), isNull);
  });

  test('myId inconnu (auth pas encore hydratée) → null', () async {
    await seed(msgID: 1);
    expect(
      await h.dao.firstUnreadMessage(ChatTestHarness.convId, 0),
      isNull,
    );
  });

  // Même définition que countUnread : les trois exclusions doivent coïncider,
  // sans quoi le séparateur pourrait se poser sur un message que le badge ne
  // compte pas.
  group('définition du « non lu » alignée sur countUnread', () {
    test('message supprimé → ignoré', () async {
      await seed(msgID: 1, isDeleted: true);
      await seed(msgID: 2);

      expect(await premier(), 2);
      expect(
        await h.dao.countUnread(ChatTestHarness.convId, ChatTestHarness.myId),
        1,
      );
    });

    test('message supprimé pour moi → ignoré', () async {
      await seed(msgID: 1, deletedForID: ChatTestHarness.myId);
      await seed(msgID: 2);

      expect(await premier(), 2);
    });

    test('message système → ignoré', () async {
      await seed(msgID: 1, type: kSystemMessageType);
      await seed(msgID: 2);

      expect(await premier(), 2);
    });

    test('les deux requêtes s\'accordent sur un fil mixte', () async {
      await seed(msgID: 1, status: 3);
      await seed(msgID: 2, senderID: ChatTestHarness.myId);
      await seed(msgID: 3, type: kSystemMessageType);
      await seed(msgID: 4, isDeleted: true);
      await seed(msgID: 5);
      await seed(msgID: 6);

      expect(await premier(), 5);
      expect(
        await h.dao.countUnread(ChatTestHarness.convId, ChatTestHarness.myId),
        2,
      );
    });
  });
}
