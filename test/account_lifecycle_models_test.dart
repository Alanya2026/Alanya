import 'package:talky_flutter/talky_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountDeletionSchedule', () {
    test('fromJson parses scheduledAt and graceDays', () {
      final schedule = AccountDeletionSchedule.fromJson({
        'scheduledAt': '2026-08-09T12:00:00.000Z',
        'graceDays': 7,
      });
      expect(schedule.graceDays, 7);
      expect(schedule.scheduledAt.toUtc().year, 2026);
    });
  });

  group('MyMediaPage', () {
    test('fromJson maps items and nextCursor', () {
      final page = MyMediaPage.fromJson({
        'items': [
          {
            'msgID': 10,
            'conversationID': 2,
            'type': 1,
            'mediaUrl': 'https://example.com/a.jpg',
          },
        ],
        'nextCursor': 10,
      });
      expect(page.items.length, 1);
      expect(page.items.first.isVideo, isFalse);
      expect(page.nextCursor, 10);
    });
  });
}
