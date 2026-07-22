import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/local_notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Push suppression — conversation active', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('shouldSuppressMessage when active conversation matches', () async {
      await LocalNotificationHelper.setActiveConversationId(42);
      expect(await LocalNotificationHelper.shouldSuppressMessage(42), isTrue);
      expect(await LocalNotificationHelper.shouldSuppressMessage(99), isFalse);
    });

    test('shouldSuppressMessage false when no active conversation', () async {
      await LocalNotificationHelper.setActiveConversationId(null);
      expect(await LocalNotificationHelper.shouldSuppressMessage(42), isFalse);
    });

    test('clearing active conversation lifts suppression', () async {
      await LocalNotificationHelper.setActiveConversationId(10);
      expect(await LocalNotificationHelper.shouldSuppressMessage(10), isTrue);
      await LocalNotificationHelper.setActiveConversationId(null);
      expect(await LocalNotificationHelper.shouldSuppressMessage(10), isFalse);
    });
  });
}
