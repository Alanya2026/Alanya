import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// Synchronise le badge launcher avec le total non lu.
class LauncherBadgeService {
  LauncherBadgeService._();

  static bool _supportedChecked = false;
  static bool _supported = false;

  static Future<bool> _ensureSupported() async {
    if (_supportedChecked) return _supported;
    _supportedChecked = true;
    if (kIsWeb) return false;
    try {
      _supported = await AppBadgePlus.isSupported();
    } catch (_) {
      _supported = false;
    }
    return _supported;
  }

  static Future<void> setCount(int count) async {
    if (!await _ensureSupported()) return;
    try {
      if (count <= 0) {
        await AppBadgePlus.updateBadge(0);
      } else {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (e) {
      debugPrint('[LauncherBadge] setCount failed: $e');
    }
  }

  static Future<void> clear() => setCount(0);
}
