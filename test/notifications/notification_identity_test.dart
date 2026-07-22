import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/notifications/notification_identity.dart';

void main() {
  test('notificationIdForConversation is stable', () {
    expect(
      NotificationIdentity.notificationIdForConversation(42),
      NotificationIdentity.notificationIdForConversation(42),
    );
    expect(
      NotificationIdentity.notificationIdForConversation(1),
      isNot(NotificationIdentity.notificationIdForConversation(2)),
    );
    expect(
      NotificationIdentity.notificationIdForConversation(42) & 0x80000000,
      0,
    );
  });

  test('tagForConversation format', () {
    expect(NotificationIdentity.tagForConversation(99), 'conv_99');
  });
}
