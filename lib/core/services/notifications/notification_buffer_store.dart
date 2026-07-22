import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Buffer messages notification chiffré (remplace SharedPreferences en clair).
class NotificationBufferStore {
  NotificationBufferStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _maxMessages = 7;

  static Future<void> _appendChain = Future<void>.value();

  static String _key(int conversationId) => 'notif_buf_$conversationId';

  static Future<List<Map<String, String>>> read(int conversationId) async {
    final raw = await _storage.read(key: _key(conversationId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, String>>> append({
    required int conversationId,
    required String sender,
    required String body,
  }) async {
    final completer = Completer<List<Map<String, String>>>();
    final previous = _appendChain;
    _appendChain = previous.then((_) async {
      try {
        completer.complete(
          await _appendUnlocked(
            conversationId: conversationId,
            sender: sender,
            body: body,
          ),
        );
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<List<Map<String, String>>> _appendUnlocked({
    required int conversationId,
    required String sender,
    required String body,
  }) async {
    final messages = await read(conversationId);
    messages.add({
      'sender': sender,
      'body': body,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    final trimmed = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    await _storage.write(
      key: _key(conversationId),
      value: jsonEncode(trimmed),
    );
    return trimmed;
  }

  static Future<void> clear(int conversationId) async {
    final previous = _appendChain;
    _appendChain = previous.then((_) async {
      await _storage.delete(key: _key(conversationId));
    });
    await _appendChain;
  }

  /// Supprime les anciens buffers SharedPreferences en clair (migration 3.4).
  static Future<void> purgeLegacySharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('notif_msgs_') || k.startsWith('notif_buf_'),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  static Future<void> clearAll() async {
    try {
      await purgeLegacySharedPreferences();
    } catch (_) {}
  }

  /// Réinitialise la chaîne de verrou (tests uniquement).
  static void resetAppendChainForTest() {
    _appendChain = Future<void>.value();
  }
}
