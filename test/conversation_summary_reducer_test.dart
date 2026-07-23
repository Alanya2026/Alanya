import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/chat/conversation_summary_reducer.dart';

void main() {
  late AppDatabase db;
  late ChatDao dao;
  late ConversationSummaryReducer reducer;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatDao(db);
    reducer = ConversationSummaryReducer(db, dao);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedConv(int id, {int unread = 0}) async {
    await db.into(db.localConversations).insert(
          LocalConversationsCompanion.insert(
            conversID: Value(id),
            isGroup: const Value(false),
            unreadCount: Value(unread),
            participantsJson: const Value('[]'),
          ),
        );
  }

  test('recomputeMany ne touche que les IDs listés', () async {
    const myId = 7;
    await seedConv(1, unread: 9);
    await seedConv(2, unread: 9);

    final now = DateTime.now().toUtc();
    await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: 'srv_1',
          msgID: const Value(1),
          conversationID: 1,
          senderID: 9,
          content: const Value('hello'),
          sendAt: now,
          status: const Value(1),
        ));

    await reducer.recomputeMany({1}, myId);

    final c1 = await (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(1)))
        .getSingle();
    final c2 = await (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(2)))
        .getSingle();

    expect(c1.lastMessage, 'hello');
    expect(c1.unreadCount, 1);
    expect(c2.unreadCount, 9); // inchangé
  });

  test('recomputeMany set vide = no-op', () async {
    await seedConv(1, unread: 3);
    await reducer.recomputeMany({}, 7);
    final c = await (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(1)))
        .getSingle();
    expect(c.unreadCount, 3);
  });
}
