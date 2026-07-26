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

  // Mêmes vecteurs que NotificationIdentityTest (Kotlin) : si les deux hashs
  // divergent, l'annulation croisée natif ↔ Flutter (tag + id) casse en
  // silence — la notification postée par l'un devient inatteignable par
  // l'autre.
  test('vecteurs partagés avec le natif Android', () {
    expect(NotificationIdentity.notificationIdForConversation(1), 873244444);
    expect(NotificationIdentity.notificationIdForConversation(2), 923577301);
    expect(NotificationIdentity.notificationIdForConversation(42), 132351363);
    expect(NotificationIdentity.notificationIdForConversation(99), 352233207);
    expect(
      NotificationIdentity.notificationIdForConversation(123456),
      429242026,
    );
  });
}
