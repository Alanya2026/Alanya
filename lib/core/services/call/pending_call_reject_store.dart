import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart';

/// File persistante des refus d'appel (cross-isolate / survie process kill).
///
/// Aussi miroir du token + base URL pour le BroadcastReceiver Android
/// (refus CallKit app tuée → POST /calls/reject sans Flutter).
class PendingCallRejectStore {
  PendingCallRejectStore._();

  static const _queueKey = 'pending_call_rejects_v1';
  static const _tokenKey = 'call_reject_access_token';
  static const _apiBaseKey = 'call_reject_api_base';
  static const _ttl = Duration(minutes: 5);

  /// Miroir credentials pour le receiver natif Android.
  static Future<void> syncNativeCredentials({
    required String? accessToken,
    String apiBase = TalkyApiClient.baseUrl,
  }) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken == null || accessToken.isEmpty) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, accessToken);
      }
      await prefs.setString(_apiBaseKey, apiBase);
    } catch (e) {
      debugPrint('[PendingCallRejectStore] syncNativeCredentials: $e');
    }
  }

  static Future<void> clearNativeCredentials() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_apiBaseKey);
    } catch (e) {
      debugPrint('[PendingCallRejectStore] clearNativeCredentials: $e');
    }
  }

  /// Ajoute un refus à la file (déduplique par callerId+callId).
  static Future<void> enqueue({
    required String callerId,
    String? callId,
  }) async {
    final cid = callerId.trim();
    if (cid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _read(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;
      _prune(list, now);
      final call = (callId ?? '').trim();
      list.removeWhere(
        (e) => e['callerId'] == cid && (e['callId'] ?? '') == call,
      );
      list.add({
        'callerId': cid,
        'callId': call,
        'ts': now,
      });
      await prefs.setString(_queueKey, jsonEncode(list));
      debugPrint('[PendingCallRejectStore] enqueue caller=$cid callId=$call');
    } catch (e) {
      debugPrint('[PendingCallRejectStore] enqueue error: $e');
    }
  }

  static Future<List<Map<String, String>>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _read(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;
      _prune(list, now);
      await prefs.setString(_queueKey, jsonEncode(list));
      return list
          .map((e) => {
                'callerId': (e['callerId'] ?? '').toString(),
                'callId': (e['callId'] ?? '').toString(),
              })
          .where((e) => e['callerId']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[PendingCallRejectStore] list error: $e');
      return [];
    }
  }

  static Future<void> remove({
    required String callerId,
    String? callId,
  }) async {
    final cid = callerId.trim();
    if (cid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _read(prefs);
      final call = (callId ?? '').trim();
      list.removeWhere((e) {
        if (e['callerId'] != cid) return false;
        if (call.isEmpty) return true;
        return (e['callId'] ?? '') == call;
      });
      await prefs.setString(_queueKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingCallRejectStore] remove error: $e');
    }
  }

  static List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void _prune(List<Map<String, dynamic>> list, int nowMs) {
    final minTs = nowMs - _ttl.inMilliseconds;
    list.removeWhere((e) {
      final ts = e['ts'];
      final n = ts is int ? ts : int.tryParse(ts?.toString() ?? '') ?? 0;
      return n < minTs;
    });
  }
}
