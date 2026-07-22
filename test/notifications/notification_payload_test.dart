import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/notifications/notification_payload.dart';

void main() {
  group('NotificationPayload.fromMap — v2', () {
    test('direct message', () {
      final p = NotificationPayload.fromMap({
        'schemaVersion': '2',
        'eventId': 'notif_1',
        'type': 'message',
        'msgID': '123',
        'clientId': 'c_abc',
        'conversationId': '45',
        'senderId': '10',
        'senderName': 'Alice',
        'title': 'Alice',
        'body': 'Bonjour',
        'msgType': '0',
        'isGroup': '0',
        'sentAt': '2026-07-22T12:00:00.000Z',
        'unreadTotal': '5',
      });

      expect(p.isV2, isTrue);
      expect(p.msgID, 123);
      expect(p.conversationId, 45);
      expect(p.senderId, 10);
      expect(p.senderName, 'Alice');
      expect(p.body, 'Bonjour');
      expect(p.isGroup, isFalse);
      expect(p.unreadTotal, 5);
      expect(p.eventId, 'notif_1');
      expect(p.sentAt, isNotNull);
    });

    test('group message', () {
      final p = NotificationPayload.fromMap({
        'schemaVersion': '2',
        'type': 'message',
        'msgID': '1',
        'conversationId': '2',
        'senderId': '3',
        'senderName': 'Bob',
        'title': 'Equipe',
        'body': 'Bob: Hello',
        'isGroup': '1',
        'groupName': 'Equipe',
      });

      expect(p.isGroup, isTrue);
      expect(p.groupName, 'Equipe');
      expect(p.title, 'Equipe');
    });

    test('media msgType', () {
      final p = NotificationPayload.fromMap({
        'type': 'message',
        'msgType': '1',
        'body': '📷 Photo',
        'conversationId': '1',
      });
      expect(p.msgType, 1);
    });
  });

  group('NotificationPayload.fromMap — legacy', () {
    test('legacy payload with callerId', () {
      final p = NotificationPayload.fromMap({
        'type': 'message',
        'title': 'Alice',
        'body': 'Salut',
        'conversationId': '7',
        'callerId': '99',
      });

      expect(p.isV2, isFalse);
      expect(p.schemaVersion, '1');
      expect(p.conversationId, 7);
      expect(p.legacyCallerId, 99);
      expect(p.senderId, 99);
      expect(p.eventId, isEmpty);
    });

    test('incomplete payload does not throw', () {
      expect(() => NotificationPayload.fromMap(null), returnsNormally);
      expect(() => NotificationPayload.fromMap({}), returnsNormally);

      final p = NotificationPayload.fromMap({});
      expect(p.type, 'message');
      expect(p.schemaVersion, '1');
    });

    test('numeric values converted from strings', () {
      final p = NotificationPayload.fromMap({
        'conversationId': 42,
        'msgID': 100,
      });
      expect(p.conversationId, 42);
      expect(p.msgID, 100);
      expect(p.eventId, 'legacy_msg_100');
    });
  });

  group('NotificationPayload.toDataMap', () {
    test('round-trips raw keys', () {
      final p = NotificationPayload.fromMap({
        'type': 'message',
        'conversationId': '5',
        'body': 'Hi',
      });
      expect(p.toDataMap()['conversationId'], '5');
    });
  });
}
