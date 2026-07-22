import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local des préférences notifications (preview, etc.) pour l'affichage client.
class NotificationPrefsCache {
  NotificationPrefsCache._();

  static const _previewModeKey = 'notif_preview_mode';

  static String _previewMode = 'full';

  static String get previewMode => _previewMode;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _previewMode = prefs.getString(_previewModeKey) ?? 'full';
  }

  static Future<void> setPreviewMode(String mode) async {
    _previewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_previewModeKey, mode);
  }

  static Future<void> applyFromServer(Map<String, dynamic> prefs) async {
    final mode = prefs['previewMode']?.toString();
    if (mode == 'full' || mode == 'name_only' || mode == 'generic') {
      await setPreviewMode(mode!);
    }
  }

  /// Masque le corps pour l'affichage local selon la préférence.
  static String sanitizeBodyForDisplay(String body) {
    switch (_previewMode) {
      case 'name_only':
      case 'generic':
        return 'Nouveau message';
      default:
        return body;
    }
  }

  static bool get hideContentOnLockscreen =>
      _previewMode == 'generic' || _previewMode == 'name_only';

  static Future<void> clear() async {
    _previewMode = 'full';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_previewModeKey);
    debugPrint('[NotificationPrefsCache] cleared');
  }
}
