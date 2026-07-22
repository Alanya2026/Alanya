import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// États de déduplication pour une clé notification.
enum NotificationDedupState {
  reserved,
  shown,
  cancelled,
}

/// Store persistant borné pour éviter les doublons socket/FCM/redémarrage.
class NotificationDedupStore {
  NotificationDedupStore._();

  static const _prefsKey = 'notif_dedup_v1';
  static const defaultTtl = Duration(hours: 48);
  static const maxEntries = 1000;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Clé prioritaire msgID, fallback eventId.
  static String? primaryKey({int? msgID, String? eventId}) {
    if (msgID != null && msgID > 0) return 'message:$msgID';
    if (eventId != null && eventId.isNotEmpty) return 'event:$eventId';
    return null;
  }

  static Future<Map<String, dynamic>> _loadMap() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(Map<String, dynamic> map) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  static void _prune(Map<String, dynamic> map, DateTime now) {
    final cutoff = now.subtract(defaultTtl).millisecondsSinceEpoch;
    map.removeWhere((_, v) {
      if (v is! Map) return true;
      final updated = v['updatedAt'] as int? ?? 0;
      return updated < cutoff;
    });
    if (map.length <= maxEntries) return;
    final sorted = map.entries.toList()
      ..sort((a, b) {
        final au = (a.value as Map)['updatedAt'] as int? ?? 0;
        final bu = (b.value as Map)['updatedAt'] as int? ?? 0;
        return au.compareTo(bu);
      });
    final toRemove = sorted.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      map.remove(sorted[i].key);
    }
  }

  static NotificationDedupState? _parseState(String? raw) {
    switch (raw) {
      case 'reserved':
        return NotificationDedupState.reserved;
      case 'shown':
        return NotificationDedupState.shown;
      case 'cancelled':
        return NotificationDedupState.cancelled;
      default:
        return null;
    }
  }

  static String _stateName(NotificationDedupState state) => state.name;

  /// Retourne true si la clé est déjà traitée (shown ou cancelled).
  static Future<bool> isAlreadyHandled({
    int? msgID,
    String? eventId,
  }) async {
    final key = primaryKey(msgID: msgID, eventId: eventId);
    if (key == null) return false;
    final map = await _loadMap();
    final entry = map[key];
    if (entry is! Map) return false;
    final state = _parseState(entry['state'] as String?);
    return state == NotificationDedupState.shown ||
        state == NotificationDedupState.cancelled;
  }

  /// Réserve une clé avant affichage. False si déjà reserved/shown/cancelled.
  static Future<bool> tryReserve({
    int? msgID,
    String? eventId,
  }) async {
    final key = primaryKey(msgID: msgID, eventId: eventId);
    if (key == null) return true; // pas de clé → laisser passer

    final map = await _loadMap();
    _prune(map, DateTime.now());
    final entry = map[key];
    if (entry is Map) {
      final state = _parseState(entry['state'] as String?);
      if (state == NotificationDedupState.shown ||
          state == NotificationDedupState.cancelled ||
          state == NotificationDedupState.reserved) {
        return false;
      }
    }
    map[key] = {
      'state': _stateName(NotificationDedupState.reserved),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveMap(map);
    return true;
  }

  static Future<void> markShown({int? msgID, String? eventId}) async {
    await _setState(
      msgID: msgID,
      eventId: eventId,
      state: NotificationDedupState.shown,
    );
  }

  static Future<void> markCancelled({int? msgID, String? eventId}) async {
    await _setState(
      msgID: msgID,
      eventId: eventId,
      state: NotificationDedupState.cancelled,
    );
  }

  /// Marque tous les msgID d'une conversation comme annulés (lecture).
  /// Voir [markCancelled] appelé par msgID en Phase 1.3.
  static Future<void> markConversationRead(int conversationId) async {
    // Réservé Phase 1.3 — annulation par liste de msgIDs.
  }

  static Future<void> _setState({
    int? msgID,
    String? eventId,
    required NotificationDedupState state,
  }) async {
    final key = primaryKey(msgID: msgID, eventId: eventId);
    if (key == null) return;
    final map = await _loadMap();
    _prune(map, DateTime.now());
    map[key] = {
      'state': _stateName(state),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveMap(map);
  }

  /// Libère une réservation si l'affichage a échoué.
  static Future<void> releaseReservation({int? msgID, String? eventId}) async {
    final key = primaryKey(msgID: msgID, eventId: eventId);
    if (key == null) return;
    final map = await _loadMap();
    final entry = map[key];
    if (entry is Map && entry['state'] == 'reserved') {
      map.remove(key);
      await _saveMap(map);
    }
  }

  /// Test helper — efface le store.
  static Future<void> clearForTest() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_prefsKey);
  }
}
