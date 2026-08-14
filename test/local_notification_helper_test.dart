import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/local_notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationHelper.bodyFromPayload', () {
    test('normalizes album marker in body', () {
      const data = {
        'body': '__talky_album__|a|0|5|4|1',
        'msgType': '1',
      };
      expect(
        LocalNotificationHelper.bodyFromPayload(data),
        '📷 4 photos, 🎥 Vidéo',
      );
    });

    test('falls back to msgType when body empty', () {
      expect(
        LocalNotificationHelper.bodyFromPayload({'msgType': '2'}),
        '🎥 Vidéo',
      );
    });

    test('keeps plain text body', () {
      expect(
        LocalNotificationHelper.bodyFromPayload({'body': 'Salut'}),
        'Salut',
      );
    });
  });

  group('LocalNotificationHelper.bufferedDisplayBody', () {
    test('joins 1-1 messages with newlines', () {
      final buffer = [
        {'sender': 'Alice', 'body': 'Salut'},
        {'sender': 'Alice', 'body': 'Ça va ?'},
        {'sender': 'Alice', 'body': 'Tu es là ?'},
      ];
      expect(
        LocalNotificationHelper.bufferedDisplayBody(buffer, isGroup: false),
        'Salut\nÇa va ?\nTu es là ?',
      );
    });

    test('formats group messages as sender: body', () {
      final buffer = [
        {'sender': 'Alice', 'body': 'Hello'},
        {'sender': 'Bob', 'body': 'Hi'},
      ];
      expect(
        LocalNotificationHelper.bufferedDisplayBody(buffer, isGroup: true),
        'Alice: Hello\nBob: Hi',
      );
    });

    test('does not re-prefix a body that already has the sender', () {
      final buffer = [
        {'sender': 'Alice', 'body': 'Alice: Hello'},
        {'sender': 'Bob', 'body': 'Bob: Bob: Hi'},
      ];
      expect(
        LocalNotificationHelper.bufferedDisplayBody(buffer, isGroup: true),
        'Alice: Hello\nBob: Hi',
      );
    });

    test('returns empty string for empty buffer', () {
      expect(
        LocalNotificationHelper.bufferedDisplayBody([], isGroup: false),
        '',
      );
    });

    test('keeps single message', () {
      final buffer = [
        {'sender': 'Alice', 'body': 'Un seul'},
      ];
      expect(
        LocalNotificationHelper.bufferedDisplayBody(buffer, isGroup: false),
        'Un seul',
      );
    });
  });
}
