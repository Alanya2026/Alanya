import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart';

/// File persistante des refus d'appel (cross-isolate / cold-start).
///
/// Clés aussi lues par le BroadcastReceiver Android natif
/// (`FlutterSharedPreferences` + préfixe `flutter.`).
class PendingCallRejectStore {
  PendingCallRejectStore._();

  static const prefsKey = 'pending_call_rejects_v1';
  static const tokenKey = 'call_reject_access_token';
  static const apiBaseKey = 'call_reject_api_base';

  /// Miroir du JWT + base URL pour le receiver Android (app tuée).
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
      debugPrint('[PendingCallRejectStore] syncNativeCredentials error: $e');
    }
  }

  static Future<void> clearNativeCredentials() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(apiBaseKey);
    } catch (e) {
      debugPrint('[PendingCallRejectStore] clearNativeCredentials error: $e');
    }
  }

  /// Enfile un refus. Déduplique sur (callerId, callId).
  static Future<void> enqueue({
    required String callerId,
    String? callId,
  }) async {
    final cid = callerId.trim();
    if (cid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _read(prefs);
      final call = (callId ?? '').trim();
      list.removeWhere((e) =>
          e['callerId'] == cid &&
          ((e['callId'] ?? '') == call || call.isEmpty || (e['callId'] ?? '').isEmpty));
      list.add({
        'callerId': cid,
        if (call.isNotEmpty) 'callId': call,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      // Garde les 20 plus récents.
      while (list.length > 20) {
        list.removeAt(0);
      }
      await prefs.setString(prefsKey, jsonEncode(list));
      debugPrint('[PendingCallRejectStore] enqueue caller=$cid callId=$call');
    } catch (e) {
      debugPrint('[PendingCallRejectStore] enqueue error: $e');
    }
  }

  static Future<List<Map<String, String>>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _read(prefs)
          .map((e) => {
                'callerId': (e['callerId'] ?? '').toString(),
                if ((e['callId'] ?? '').toString().isNotEmpty)
                  'callId': e['callId'].toString(),
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
      final before = list.length;
      list.removeWhere((e) {
        if (e['callerId'] != cid) return false;
        if (call.isEmpty) return true;
        final existing = (e['callId'] ?? '').toString();
        return existing.isEmpty || existing == call;
      });
      if (list.length != before) {
        await prefs.setString(prefsKey, jsonEncode(list));
        debugPrint('[PendingCallRejectStore] remove caller=$cid callId=$call');
      }
    } catch (e) {
      debugPrint('[PendingCallRejectStore] remove error: $e');
    }
  }

  static List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
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
}
