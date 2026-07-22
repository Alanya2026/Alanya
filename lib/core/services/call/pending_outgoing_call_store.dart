import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot persistant d'un appel sortant (survie au kill process).
class OutgoingCallSnapshot {
  final String clientCallId;
  final String? serverCallId;
  final int remoteUserId;
  final String remoteUserName;
  final String? remoteUserPhoto;
  final bool isVideo;
  final String phase; // connecting | connected
  final int startedAtMs;

  const OutgoingCallSnapshot({
    required this.clientCallId,
    this.serverCallId,
    required this.remoteUserId,
    required this.remoteUserName,
    this.remoteUserPhoto,
    required this.isVideo,
    required this.phase,
    required this.startedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'clientCallId': clientCallId,
        if (serverCallId != null && serverCallId!.isNotEmpty)
          'serverCallId': serverCallId,
        'remoteUserId': remoteUserId,
        'remoteUserName': remoteUserName,
        if (remoteUserPhoto != null && remoteUserPhoto!.isNotEmpty)
          'remoteUserPhoto': remoteUserPhoto,
        'isVideo': isVideo,
        'phase': phase,
        'startedAtMs': startedAtMs,
      };

  factory OutgoingCallSnapshot.fromJson(Map<String, dynamic> json) {
    return OutgoingCallSnapshot(
      clientCallId: (json['clientCallId'] ?? '').toString(),
      serverCallId: json['serverCallId']?.toString(),
      remoteUserId: int.tryParse(json['remoteUserId']?.toString() ?? '') ?? 0,
      remoteUserName: (json['remoteUserName'] ?? '').toString(),
      remoteUserPhoto: json['remoteUserPhoto']?.toString(),
      isVideo: json['isVideo'] == true || json['isVideo'] == 'true',
      phase: (json['phase'] ?? 'connecting').toString(),
      startedAtMs: int.tryParse(json['startedAtMs']?.toString() ?? '') ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Persistance cross-isolate d'un appel sortant en cours.
class PendingOutgoingCallStore {
  PendingOutgoingCallStore._();

  static const _prefsKey = 'pending_outgoing_call_v1';
  static const ttl = Duration(hours: 2);

  static Future<void> save(OutgoingCallSnapshot snapshot) async {
    if (snapshot.clientCallId.trim().isEmpty || snapshot.remoteUserId <= 0) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = snapshot.toJson()
        ..['savedAtMs'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_prefsKey, jsonEncode(payload));
      debugPrint(
        '[PendingOutgoingCallStore] save callId=${snapshot.clientCallId} phase=${snapshot.phase}',
      );
    } catch (e) {
      debugPrint('[PendingOutgoingCallStore] save error: $e');
    }
  }

  static Future<OutgoingCallSnapshot?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = int.tryParse(decoded['savedAtMs']?.toString() ?? '');
      if (savedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - savedAt;
        if (age > ttl.inMilliseconds) {
          await clear();
          return null;
        }
      }
      return OutgoingCallSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('[PendingOutgoingCallStore] read error: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint('[PendingOutgoingCallStore] clear');
    } catch (e) {
      debugPrint('[PendingOutgoingCallStore] clear error: $e');
    }
  }
}
