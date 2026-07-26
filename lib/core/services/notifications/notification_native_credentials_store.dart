import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Purge de l'ancien miroir JWT des actions de notification.
///
/// Les clés `notif_action_*` ne sont plus écrites : le natif (Android comme
/// iOS) lit désormais le trio partagé `call_reject_*`, seul à porter un refresh
/// token et seul réécrit à chaque démarrage à froid. Ce store ne sert plus qu'à
/// retirer du disque l'access token en clair qui y restait — il est encore lu
/// en repli par le natif le temps d'une release, puis tout ceci pourra
/// disparaître.
class NotificationNativeCredentialsStore {
  NotificationNativeCredentialsStore._();

  static const tokenKey = 'notif_action_access_token';
  static const apiBaseKey = 'notif_action_api_base';

  static Future<void> purgeLegacyKeys() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(apiBaseKey);
    } catch (e) {
      debugPrint('[NotificationNativeCredentialsStore] purge error: $e');
    }
  }
}
