import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';

import 'fakes/chat_test_harness.dart';

void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
  });

  tearDown(() async {
    await h.tearDown();
  });

  Map<String, dynamic> convJson({
    required int id,
    String? lastMessage,
    String? lastMessageAt,
    int unread = 0,
  }) {
    return {
      'conversID': id,
      'isGroup': false,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'lastMessageSenderID': ChatTestHarness.otherId,
      'lastMessageType': 0,
      'unreadCount': unread,
      'isPinned': false,
      'isArchived': false,
      'participants': [
        {'alanyaID': ChatTestHarness.myId, 'nom': 'me', 'is_online': 1},
        {'alanyaID': ChatTestHarness.otherId, 'nom': 'other', 'is_online': 0},
      ],
    };
  }

  test('2 syncConversations parallèles → 1 seul GET /conversations', () async {
    h.api.conversations = [
      convJson(id: ChatTestHarness.convId, lastMessage: 'hi'),
    ];

    await Future.wait([
      h.repo.syncConversations(force: true),
      h.repo.syncConversations(force: true),
    ]);

    final gets =
        h.api.httpLog.where((e) => e == 'getConversations').length;
    expect(gets, 1);
  });

  test('sync non forcé dans le cooldown → skip HTTP', () async {
    h.api.conversations = [
      convJson(id: ChatTestHarness.convId, lastMessage: 'a'),
    ];
    await h.repo.syncConversations(force: true);
    h.api.httpLog.clear();

    await h.repo.syncConversations(force: false);
    expect(
      h.api.httpLog.where((e) => e == 'getConversations'),
      isEmpty,
    );
  });

  test('force:true ignore le cooldown', () async {
    h.api.conversations = [
      convJson(id: ChatTestHarness.convId, lastMessage: 'a'),
    ];
    await h.repo.syncConversations(force: true);
    h.api.httpLog.clear();

    await h.repo.syncConversations(force: true);
    expect(
      h.api.httpLog.where((e) => e == 'getConversations').length,
      1,
    );
  });

  test('sync delta batch upsert messages entrants', () async {
    // Message local confirmé → curseur actif pour syncGlobalDelta.
    await h.db.into(h.db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: 'srv_1',
            msgID: const Value(1),
            conversationID: ChatTestHarness.convId,
            senderID: ChatTestHarness.otherId,
            content: const Value('old'),
            sendAt: DateTime.utc(2026, 1, 1),
          ),
        );

    h.api.globalSyncResult = [
      for (var i = 2; i <= 5; i++)
        {
          'msgID': i,
          'conversationID': ChatTestHarness.convId,
          'senderID': ChatTestHarness.otherId,
          'content': 'm$i',
          'type': 0,
          'status': 1,
          'sendAt': DateTime.utc(2026, 1, i).toIso8601String(),
        },
    ];

    await h.repo.syncGlobalDelta();
    await h.pumpEventQueue();

    final msgs = await h.messages();
    expect(msgs.map((m) => m.msgID).toSet(), {1, 2, 3, 4, 5});
    final conv = await h.conv();
    expect(conv?.lastMessage, 'm5');
    expect(conv?.unreadCount, greaterThanOrEqualTo(4));
  });
}
