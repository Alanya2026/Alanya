import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/chat/message_ack_watchdog.dart';

import 'fakes/fake_chat_api.dart';

void main() {
  late FakeChatApi api;
  late AppDatabase db;
  late ChatDao dao;

  setUp(() async {
    api = FakeChatApi(socketReady: true);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('timeout → confirm via HTTP si found', () async {
    const clientId = 'c_ack_1';
    const convId = 42;
    await db.into(db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: clientId,
            conversationID: convId,
            senderID: 1,
            sendAt: DateTime.now().toUtc(),
            syncPending: const Value(true),
            status: const Value(0),
          ),
        );

    api.messageStatusByClientId[clientId] = {
      'found': true,
      'msgID': 999,
      'status': 1,
      'conversationID': convId,
      'sendAt': DateTime.now().toUtc().toIso8601String(),
    };

    var recomputeCalls = 0;
    final wd = MessageAckWatchdog(
      api: api,
      dao: dao,
      recompute: (_) async {
        recomputeCalls++;
      },
      timeout: const Duration(milliseconds: 50),
    );

    wd.arm(clientId, convId);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final row = await (db.select(db.localMessages)
          ..where((m) => m.clientId.equals(clientId)))
        .getSingle();
    expect(row.msgID, 999);
    expect(row.syncPending, isFalse);
    expect(recomputeCalls, 1);
    expect(api.forceReconnectCalls, 0);
    wd.dispose();
  });

  test('timeout → forceReconnect si absent serveur', () async {
    const clientId = 'c_ack_2';
    const convId = 43;
    await db.into(db.localMessages).insert(
          LocalMessagesCompanion.insert(
            clientId: clientId,
            conversationID: convId,
            senderID: 1,
            sendAt: DateTime.now().toUtc(),
            syncPending: const Value(true),
            status: const Value(0),
          ),
        );

    final wd = MessageAckWatchdog(
      api: api,
      dao: dao,
      recompute: (_) async {},
      timeout: const Duration(milliseconds: 50),
    );

    wd.arm(clientId, convId);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(api.forceReconnectCalls, 1);
    wd.dispose();
  });

  test('cancel avant expiry → pas de reconcile', () async {
    const clientId = 'c_ack_3';
    final wd = MessageAckWatchdog(
      api: api,
      dao: dao,
      recompute: (_) async {},
      timeout: const Duration(milliseconds: 80),
    );
    wd.arm(clientId, 1);
    wd.cancel(clientId);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(api.forceReconnectCalls, 0);
    expect(api.httpLog.where((e) => e.startsWith('getMessageStatus')), isEmpty);
    wd.dispose();
  });
}
