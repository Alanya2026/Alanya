import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/chat/chat_repository.dart';

import 'fake_chat_api.dart';

/// Harnais Drift mémoire + FakeChatApi + ChatRepository prêt pour tests.
class ChatTestHarness {
  late final FakeChatApi api;
  late final AppDatabase db;
  late final ChatDao dao;
  late final ChatRepository repo;

  static const int myId = 1;
  static const int otherId = 2;
  static const int convId = 10;

  Future<void> setUp({bool socketReady = true, bool autoAckSend = true}) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    api = FakeChatApi(socketReady: socketReady)..autoAckSend = autoAckSend;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatDao(db);
    repo = ChatRepository.forTesting(api: api, database: db);
    await repo.bind(myId);
    await _seedConversation();
  }

  Future<void> tearDown() async {
    repo.unbind();
    await db.close();
  }

  Future<void> _seedConversation() async {
    await db.into(db.localConversations).insert(
          LocalConversationsCompanion.insert(
            conversID: const Value(convId),
            isGroup: const Value(false),
            unreadCount: const Value(0),
            participantsJson: Value(
              encodeParticipants([
                {'userID': myId, 'username': 'me'},
                {'userID': otherId, 'username': 'other'},
              ]),
            ),
          ),
        );
  }

  Future<LocalConversation?> conv() =>
      (db.select(db.localConversations)
            ..where((c) => c.conversID.equals(convId)))
          .getSingleOrNull();

  Future<List<LocalMessage>> messages() =>
      (db.select(db.localMessages)
            ..where((m) => m.conversationID.equals(convId))
            ..orderBy([(m) => OrderingTerm(expression: m.sendAt)]))
          .get();

  /// Simule un message entrant via socket `message:received`.
  Future<void> receiveIncoming({
    required int msgID,
    required String content,
    int type = 0,
    DateTime? sendAt,
    int status = 1,
  }) async {
    final at = (sendAt ?? DateTime.now().toUtc()).toIso8601String();
    api.emit('message:received', {
      'msgID': msgID,
      'conversationID': convId,
      'senderID': otherId,
      'content': content,
      'type': type,
      'status': status,
      'sendAt': at,
    });
    await pumpEventQueue();
  }

  Future<void> pumpEventQueue({int times = 8}) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}
