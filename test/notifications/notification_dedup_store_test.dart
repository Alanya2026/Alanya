import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/notifications/notification_dedup_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationDedupStore.clearForTest();
  });

  test('tryReserve then markShown prevents duplicate', () async {
    expect(
      await NotificationDedupStore.tryReserve(msgID: 100),
      isTrue,
    );
    expect(
      await NotificationDedupStore.tryReserve(msgID: 100),
      isFalse,
    );
    expect(await NotificationDedupStore.isAlreadyHandled(msgID: 100), isFalse);

    await NotificationDedupStore.markShown(msgID: 100);
    expect(await NotificationDedupStore.isAlreadyHandled(msgID: 100), isTrue);
    expect(
      await NotificationDedupStore.tryReserve(msgID: 100),
      isFalse,
    );
  });

  test('eventId fallback when msgID absent', () async {
    expect(
      await NotificationDedupStore.tryReserve(eventId: 'notif_abc'),
      isTrue,
    );
    expect(
      await NotificationDedupStore.tryReserve(eventId: 'notif_abc'),
      isFalse,
    );
  });

  test('releaseReservation allows retry after failed display', () async {
    expect(await NotificationDedupStore.tryReserve(msgID: 50), isTrue);
    await NotificationDedupStore.releaseReservation(msgID: 50);
    expect(await NotificationDedupStore.tryReserve(msgID: 50), isTrue);
  });

  test('markCancelled blocks re-display', () async {
    await NotificationDedupStore.tryReserve(msgID: 77);
    await NotificationDedupStore.markCancelled(msgID: 77);
    expect(await NotificationDedupStore.isAlreadyHandled(msgID: 77), isTrue);
    expect(await NotificationDedupStore.tryReserve(msgID: 77), isFalse);
  });

  test('different conversations different msgIDs independent', () async {
    expect(await NotificationDedupStore.tryReserve(msgID: 1), isTrue);
    expect(await NotificationDedupStore.tryReserve(msgID: 2), isTrue);
  });

  test('reserved blocks second tryReserve before shown', () async {
    expect(await NotificationDedupStore.tryReserve(msgID: 888), isTrue);
    expect(await NotificationDedupStore.tryReserve(msgID: 888), isFalse);
  });
}
