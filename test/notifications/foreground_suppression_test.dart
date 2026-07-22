import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/local_notification_helper.dart';
import 'package:talky_flutter/core/services/notifications/notification_prefs_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Foreground suppression + lifecycle prefs', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPrefsCache.clear();
    });

    test('active conversation suppresses only that conversation', () async {
      await LocalNotificationHelper.setActiveConversationId(7);
      expect(await LocalNotificationHelper.shouldSuppressMessage(7), isTrue);
      expect(await LocalNotificationHelper.shouldSuppressMessage(8), isFalse);
    });

    test('switching active conversation updates suppression', () async {
      await LocalNotificationHelper.setActiveConversationId(1);
      expect(await LocalNotificationHelper.shouldSuppressMessage(1), isTrue);
      await LocalNotificationHelper.setActiveConversationId(2);
      expect(await LocalNotificationHelper.shouldSuppressMessage(1), isFalse);
      expect(await LocalNotificationHelper.shouldSuppressMessage(2), isTrue);
    });
  });

  group('NotificationPrefsCache privacy', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPrefsCache.clear();
    });

    test('default preview is full when cache empty', () async {
      await NotificationPrefsCache.load();
      expect(NotificationPrefsCache.previewMode, 'full');
    });

    test('cached previewMode generic is readable', () async {
      await NotificationPrefsCache.applyFromServer({
        'messagesEnabled': true,
        'previewMode': 'generic',
        'soundEnabled': true,
      });
      expect(NotificationPrefsCache.previewMode, 'generic');
      expect(
        NotificationPrefsCache.sanitizeBodyForDisplay('Secret'),
        'Nouveau message',
      );
      expect(NotificationPrefsCache.hideContentOnLockscreen, isTrue);
    });
  });
}
