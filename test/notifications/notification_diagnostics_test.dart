import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/notifications/notification_diagnostics.dart';

void main() {
  test('NotificationDiagnostics.trace does not throw when enabled', () {
    NotificationDiagnostics.enabled = true;
    expect(
      () => NotificationDiagnostics.displayed(
        conversationId: 1,
        msgID: 2,
        eventId: 'e1',
      ),
      returnsNormally,
    );
    expect(
      () => NotificationDiagnostics.deduplicated(reason: 'already_shown', msgID: 3),
      returnsNormally,
    );
  });

  test('pushForeground sanitizes body in trace fields', () {
    NotificationDiagnostics.enabled = true;
    expect(
      () => NotificationDiagnostics.pushForeground({
        'type': 'message',
        'conversationId': '5',
        'msgID': '10',
        'body': 'Secret message content here',
        'token': 'should-not-log-full',
      }),
      returnsNormally,
    );
  });
}
