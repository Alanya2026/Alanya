import '../../db/chat_dao.dart';
import 'launcher_badge_service.dart';

/// Synchronise le badge launcher avec le total non lu Drift.
class BadgeSyncService {
  BadgeSyncService._();

  static Future<void> syncFromDao(ChatDao dao) async {
    try {
      final total = await dao.countTotalUnread();
      await LauncherBadgeService.setCount(total);
    } catch (e) {
      // Best-effort — ne pas bloquer le flux message.
    }
  }

  static Future<void> clear() => LauncherBadgeService.clear();
}
