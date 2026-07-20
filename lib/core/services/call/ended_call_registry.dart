import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Registre cross-isolate des callId déjà terminés.
///
/// Persiste dans SharedPreferences pour que l'isolate FCM background
/// ignore un push `call` arrivé après `call_ended` (course FCM).
class EndedCallRegistry {
  EndedCallRegistry._();

  static const _prefsKey = 'ended_call_ids_v1';
  static const ttl = Duration(seconds: 120);

  /// Marque [callId] comme terminé (no-op si vide).
  static Future<void> markEnded(String? callId) async {
    final id = callId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _read(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;
      _prune(map, now);
      map[id] = now + ttl.inMilliseconds;
      await prefs.setString(_prefsKey, jsonEncode(map));
      debugPrint('[EndedCallRegistry] markEnded callId=$id');
    } catch (e) {
      debugPrint('[EndedCallRegistry] markEnded error: $e');
    }
  }

  /// true si [callId] a été marqué terminé et que le TTL n'est pas expiré.
  static Future<bool> isEnded(String? callId) async {
    final id = callId?.trim() ?? '';
    if (id.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _read(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = map[id];
      if (expiry == null) return false;
      if (expiry <= now) {
        map.remove(id);
        await prefs.setString(_prefsKey, jsonEncode(map));
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[EndedCallRegistry] isEnded error: $e');
      return false;
    }
  }

  static Map<String, int> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      for (final e in decoded.entries) {
        final v = e.value;
        final expiry = v is int ? v : int.tryParse(v.toString());
        if (expiry != null) out[e.key.toString()] = expiry;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static void _prune(Map<String, int> map, int nowMs) {
    map.removeWhere((_, expiry) => expiry <= nowMs);
  }
}
