import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/local_notification_helper.dart';

void main() {
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
}
