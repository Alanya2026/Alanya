import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart';

/// Miroir JWT + base URL pour actions notification natives iOS/Android (app tuée).
class NotificationNativeCredentialsStore {
  NotificationNativeCredentialsStore._();

  static const tokenKey = 'notif_action_access_token';
  static const apiBaseKey = 'notif_action_api_base';

  static Future<void> syncNativeCredentials(String? accessToken) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken == null || accessToken.isEmpty) {
        await prefs.remove(tokenKey);
      } else {
        await prefs.setString(tokenKey, accessToken);
      }
      await prefs.setString(apiBaseKey, TalkyApiClient.baseUrl);
    } catch (e) {
      debugPrint('[NotificationNativeCredentialsStore] sync error: $e');
    }
  }

  static Future<void> clearNativeCredentials() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(apiBaseKey);
    } catch (e) {
      debugPrint('[NotificationNativeCredentialsStore] clear error: $e');
    }
  }
}
