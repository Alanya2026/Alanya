import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/notifications/notification_buffer_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> memory;

  setUp(() {
    memory = {};
    NotificationBufferStore.resetAppendChainForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return memory[key];
        case 'write':
          final args = call.arguments as Map;
          memory[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          memory.remove(call.arguments['key'] as String);
          return null;
        case 'deleteAll':
          memory.clear();
          return null;
        case 'containsKey':
          return memory.containsKey(call.arguments['key'] as String);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('append grows buffer across sequential calls', () async {
    final first = await NotificationBufferStore.append(
      conversationId: 42,
      sender: 'Alice',
      body: 'Salut',
    );
    expect(first, hasLength(1));
    expect(first.first['body'], 'Salut');

    final second = await NotificationBufferStore.append(
      conversationId: 42,
      sender: 'Alice',
      body: 'Tu es là ?',
    );
    expect(second, hasLength(2));
    expect(second.first['body'], 'Salut');
    expect(second.last['body'], 'Tu es là ?');

    final persisted = await NotificationBufferStore.read(42);
    expect(persisted, hasLength(2));
  });

  test('append serializes concurrent calls per conversation', () async {
    final results = await Future.wait([
      NotificationBufferStore.append(
        conversationId: 7,
        sender: 'Bob',
        body: '1',
      ),
      NotificationBufferStore.append(
        conversationId: 7,
        sender: 'Bob',
        body: '2',
      ),
      NotificationBufferStore.append(
        conversationId: 7,
        sender: 'Bob',
        body: '3',
      ),
    ]);

    expect(results.every((buffer) => buffer.isNotEmpty), isTrue);
    final finalBuffer = await NotificationBufferStore.read(7);
    expect(finalBuffer, hasLength(3));

    final bodies = finalBuffer.map((m) => m['body']).toList();
    expect(bodies, containsAll(['1', '2', '3']));

    final raw = memory['notif_buf_7'];
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List;
    expect(decoded, hasLength(3));
  });
}
