import 'package:flutter/foundation.dart';

/// Traces notification sans données sensibles (désactivé en release par défaut).
class NotificationDiagnostics {
  NotificationDiagnostics._();

  static bool enabled = !kReleaseMode;

  static void trace(
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    if (!enabled) return;
    final safe = <String, Object?>{'event': event, ..._sanitize(fields)};
    debugPrint('[NotifDiag] ${safe.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> fields) {
    final out = <String, Object?>{};
    for (final e in fields.entries) {
      final k = e.key;
      final v = e.value;
      if (v == null) continue;
      if (k == 'token' || k == 'fcmToken' || k == 'payload') {
        out[k] = _hashHint(v.toString());
        continue;
      }
      if (k == 'body' || k == 'content') {
        out['bodyPreview'] = _preview(v.toString());
        continue;
      }
      out[k] = v;
    }
    return out;
  }

  static String _hashHint(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}…${value.length}';
  }

  static String _preview(String body) {
    final t = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 32) return t;
    return '${t.substring(0, 29)}...';
  }

  // ── Événements canoniques ───────────────────────────────────────────

  static void pushForeground(Map<String, dynamic> data) =>
      trace('push_foreground', fields: _payloadFields(data));

  static void pushBackground(Map<String, dynamic> data) =>
      trace('push_background', fields: _payloadFields(data));

  static void socketReceived(Map<String, dynamic> data) =>
      trace('socket_received', fields: _payloadFields(data));

  static void displayed({required int conversationId, int? msgID, String? eventId}) =>
      trace('notification_displayed', fields: {
        'conversationId': conversationId,
        if (msgID != null && msgID > 0) 'msgID': msgID,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      });

  static void deduplicated({required String reason, int? msgID, String? eventId}) =>
      trace('notification_deduplicated', fields: {
        'reason': reason,
        if (msgID != null && msgID > 0) 'msgID': msgID,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      });

  static void cancelled({required int conversationId, String? reason}) =>
      trace('notification_cancelled', fields: {
        'conversationId': conversationId,
        if (reason != null) 'reason': reason,
      });

  static void tapAction({required String type, int? conversationId}) =>
      trace('notification_tap', fields: {
        'type': type,
        if (conversationId != null) 'conversationId': conversationId,
      });

  static void navigationResult({required bool success, String? detail}) =>
      trace('navigation_result', fields: {
        'success': success,
        if (detail != null) 'detail': detail,
      });

  static Map<String, Object?> _payloadFields(Map<String, dynamic> data) {
    return {
      'type': data['type']?.toString() ?? '',
      'conversationId': data['conversationId']?.toString() ?? '',
      'msgID': data['msgID']?.toString() ?? '',
      'eventId': data['eventId']?.toString() ?? '',
      if (data['body'] != null) 'body': data['body'].toString(),
    };
  }
}
