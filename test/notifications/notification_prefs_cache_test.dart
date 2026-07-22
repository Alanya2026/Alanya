import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/notifications/notification_prefs_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('sanitizeBodyForDisplay respects preview mode', () async {
    await NotificationPrefsCache.setPreviewMode('full');
    expect(
      NotificationPrefsCache.sanitizeBodyForDisplay('Hello'),
      'Hello',
    );

    await NotificationPrefsCache.setPreviewMode('generic');
    expect(
      NotificationPrefsCache.sanitizeBodyForDisplay('Hello'),
      'Nouveau message',
    );
    expect(NotificationPrefsCache.hideContentOnLockscreen, isTrue);

    await NotificationPrefsCache.clear();
  });
}
