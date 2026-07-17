import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';

void main() {
  group('ChatDao purges and atomic read', () {
    late AppDatabase db;
    late ChatDao dao;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = ChatDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('purgeGhostMessages removes old optimistics only', () async {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final recent = DateTime.now().toUtc();

      // Old optimistic (should be purged)
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_old',
        conversationID: 1,
        senderID: 0,
        sendAt: old,
        syncPending: const Value(false),
      ));

      // Recent optimistic (should remain)
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_new',
        conversationID: 1,
        senderID: 0,
        sendAt: recent,
        syncPending: const Value(false),
      ));

      await dao.purgeGhostMessages();
      final all = await db.select(db.localMessages).get();
      expect(all.map((e) => e.clientId), contains('c_new'));
      expect(all.map((e) => e.clientId), isNot(contains('c_old')));
    });

    test('purgeDuplicateOptimistics removes optimistics when confirmed exists', () async {
      final now = DateTime.now().toUtc();

      // Confirmed message
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'srv_100',
        msgID: const Value(100),
        conversationID: 2,
        senderID: 7,
        content: const Value('hello'),
        sendAt: now,
        syncPending: const Value(false),
      ));

      // Optimistic duplicate (should be removed)
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_dup',
        conversationID: 2,
        senderID: 7,
        content: const Value('hello'),
        sendAt: now,
        syncPending: const Value(false),
      ));

      await dao.purgeDuplicateOptimistics();
      final all = await db.select(db.localMessages).get();
      expect(all.any((m) => m.clientId == 'srv_100'), isTrue);
      expect(all.any((m) => m.clientId == 'c_dup'), isFalse);
    });

    test('purgeDuplicateByMsgId keeps srv_ prefixed row and deletes others', () async {
      final now = DateTime.now().toUtc();

      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'srv_1',
        msgID: const Value(1),
        conversationID: 3,
        senderID: 9,
        sendAt: now,
        syncPending: const Value(false),
      ));

      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_old_1',
        msgID: const Value(1),
        conversationID: 3,
        senderID: 9,
        sendAt: now,
        syncPending: const Value(false),
      ));

      await dao.purgeDuplicateByMsgId();
      final all = await db.select(db.localMessages).get();
      expect(all.where((m) => m.msgID == 1).length, 1);
      expect(all.any((m) => m.clientId == 'srv_1'), isTrue);
      expect(all.any((m) => m.clientId == 'c_old_1'), isFalse);
    });

    test('markConversationReadAtomic marks messages read and resets unread', () async {
      final now = DateTime.now().toUtc();
      const convId = 10;
      const myId = 42;

      // Insert conversation with unreadCount
      await db.into(db.localConversations).insert(LocalConversationsCompanion(
        conversID: const Value(convId),
        lastMessage: const Value('hi'),
        lastMessageAt: Value(now),
        unreadCount: const Value(5),
      ));

      // Message from other user
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_a',
        conversationID: convId,
        senderID: 1,
        sendAt: now,
        status: const Value(1),
      ));

      // Message from me (should not be changed)
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'c_b',
        conversationID: convId,
        senderID: myId,
        sendAt: now,
        status: const Value(1),
      ));

      await dao.markConversationReadAtomic(convId, myId);

      final msgs = await (db.select(db.localMessages)..where((m) => m.conversationID.equals(convId))).get();
      expect(msgs.firstWhere((m) => m.clientId == 'c_a').status, 3);
      expect(msgs.firstWhere((m) => m.clientId == 'c_b').status, 1);

      final conv = await (db.select(db.localConversations)..where((c) => c.conversID.equals(convId))).getSingle();
      expect(conv.unreadCount, 0);
    });

    test('bumpConvLastStatusIfMine updates null preview status', () async {
      final now = DateTime.now().toUtc();
      const convId = 30;
      const myId = 7;

      await db.into(db.localConversations).insert(LocalConversationsCompanion(
        conversID: const Value(convId),
        lastMessage: const Value('hello'),
        lastMessageAt: Value(now),
        lastMessageSenderID: const Value(myId),
      ));

      await dao.bumpConvLastStatusIfMine(convId, myId, 3);

      final conv = await (db.select(db.localConversations)
            ..where((c) => c.conversID.equals(convId)))
          .getSingle();
      expect(conv.lastMessageStatus, 3);
    });

    test('reconcileLastMessageStatus aligns preview with latest sent message', () async {
      final now = DateTime.now().toUtc();
      const convId = 31;
      const myId = 7;

      await db.into(db.localConversations).insert(LocalConversationsCompanion(
        conversID: const Value(convId),
        lastMessage: const Value('stale preview'),
        lastMessageAt: Value(now),
        lastMessageSenderID: const Value(myId),
        lastMessageStatus: const Value(1),
        unreadCount: const Value(3),
      ));

      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'srv_500',
        msgID: const Value(500),
        conversationID: convId,
        senderID: myId,
        sendAt: now,
        status: const Value(3),
        content: const Value('hello'),
      ));

      await dao.reconcileLastMessageStatus(convId, myId);

      final conv = await (db.select(db.localConversations)
            ..where((c) => c.conversID.equals(convId)))
          .getSingle();
      expect(conv.lastMessageStatus, 3);
      expect(conv.lastMessage, 'hello');
      expect(conv.unreadCount, 0);
    });

    test('bumpMyMessagesStatus sets readAt when status becomes read', () async {
      final now = DateTime.now().toUtc();
      const convId = 32;
      const myId = 7;

      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
        clientId: 'srv_600',
        msgID: const Value(600),
        conversationID: convId,
        senderID: myId,
        sendAt: now,
        status: const Value(1),
      ));

      await dao.bumpMyMessagesStatus(convId, myId, 3);

      final msg = await (db.select(db.localMessages)
            ..where((m) => m.clientId.equals('srv_600')))
          .getSingle();
      expect(msg.status, 3);
      expect(msg.readAt, isNot(isNull));
    });
  });
}
