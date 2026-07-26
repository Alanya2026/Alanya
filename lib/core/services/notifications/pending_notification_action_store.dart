import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Une action de notification en attente de rejeu (contrat JSON partagé avec
/// `NotificationActionQueue` côté Kotlin : `kind`, `conversationId`, `text`,
/// `clientId`, `ts`, `attempts`).
class PendingNotificationAction {
  const PendingNotificationAction({
    required this.kind,
    required this.conversationId,
    this.text,
    this.clientId,
    required this.ts,
    required this.attempts,
  });

  final String kind;
  final int conversationId;
  final String? text;
  final String? clientId;
  final int ts;
  final int attempts;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'conversationId': conversationId,
        if (text != null && text!.isNotEmpty) 'text': text,
        if (clientId != null && clientId!.isNotEmpty) 'clientId': clientId,
        'ts': ts,
        'attempts': attempts,
      };

  static PendingNotificationAction? fromJson(Map<String, dynamic> j) {
    final kind = '${j['kind'] ?? ''}';
    final convId = int.tryParse('${j['conversationId']}');
    if (convId == null || convId <= 0) return null;
    if (kind != PendingNotificationActionStore.kindReply &&
        kind != PendingNotificationActionStore.kindRead) {
      return null;
    }
    final clientId = j['clientId']?.toString();
    // Un reply sans clientId est irrécupérable : sans clé d'idempotence, le
    // rejouer risquerait un doublon chez le destinataire. On le laisse tomber.
    if (kind == PendingNotificationActionStore.kindReply &&
        (clientId == null || clientId.isEmpty)) {
      return null;
    }
    return PendingNotificationAction(
      kind: kind,
      conversationId: convId,
      text: j['text']?.toString(),
      clientId: clientId,
      ts: j['ts'] is int ? j['ts'] as int : int.tryParse('${j['ts']}') ?? 0,
      attempts: j['attempts'] is int
          ? j['attempts'] as int
          : int.tryParse('${j['attempts']}') ?? 0,
    );
  }
}

/// File persistante des actions de notification (réponse rapide, marquer lu)
/// déposées par la couche native quand son POST direct a échoué — réseau
/// coupé, refresh token mort, process tué en plein vol.
///
/// Écrite par `NotificationActionQueue` (Kotlin) via `FlutterSharedPreferences`
/// et le préfixe `flutter.` ; rejouée ici par
/// `ChatRepository.flushPendingNotificationActions`.
class PendingNotificationActionStore {
  PendingNotificationActionStore._();

  static const prefsKey = 'pending_notif_actions_v1';

  static const kindReply = 'reply';
  static const kindRead = 'read';

  /// Au-delà, l'action n'a plus de sens : l'app aura resynchronisé avant.
  static const Duration maxAge = Duration(hours: 24);
  static const int maxEntries = 50;

  /// Tentatives au-delà desquelles une entrée est abandonnée (natif + Dart).
  static const int maxAttempts = 5;

  /// Actions en attente, les plus anciennes d'abord. Purge les périmées et
  /// celles à bout de tentatives au passage.
  static Future<List<PendingNotificationAction>> takeAll() async {
    if (kIsWeb) return const [];
    try {
      final prefs = await _freshPrefs();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
      final actions = <PendingNotificationAction>[];
      for (final entry in _decode(raw)) {
        final action = PendingNotificationAction.fromJson(entry);
        if (action == null) continue;
        if (action.ts < cutoff) continue;
        if (action.attempts > maxAttempts) continue;
        actions.add(action);
      }
      return actions;
    } catch (e) {
      debugPrint('[PendingNotificationActionStore] takeAll error: $e');
      return const [];
    }
  }

  static Future<void> remove(PendingNotificationAction action) async {
    if (kIsWeb) return;
    try {
      final prefs = await _freshPrefs();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list =
          _decode(raw).where((e) => !_matches(e, action)).toList();
      await prefs.setString(prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingNotificationActionStore] remove error: $e');
    }
  }

  /// Échec transitoire : incrémente `attempts`, abandonne au-delà du plafond.
  static Future<void> bumpAttempts(PendingNotificationAction action) async {
    if (kIsWeb) return;
    try {
      final prefs = await _freshPrefs();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = <Map<String, dynamic>>[];
      for (final e in _decode(raw)) {
        if (_matches(e, action)) {
          final attempts = (int.tryParse('${e['attempts']}') ?? 0) + 1;
          if (attempts > maxAttempts) continue;
          list.add({...e, 'attempts': attempts});
        } else {
          list.add(e);
        }
      }
      await prefs.setString(prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingNotificationActionStore] bumpAttempts error: $e');
    }
  }

  /// Purge complète — logout / changement de compte : les actions d'un compte
  /// ne doivent jamais être rejouées avec le token d'un autre.
  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      final prefs = await _freshPrefs();
      await prefs.remove(prefsKey);
    } catch (e) {
      debugPrint('[PendingNotificationActionStore] clear error: $e');
    }
  }

  /// `reload()` obligatoire : `SharedPreferences` côté Dart est un cache
  /// mémoire, et le natif écrit le fichier pendant que l'isolate est vivant
  /// (app en arrière-plan — le cas nominal). Sans lui, la file est invisible.
  static Future<SharedPreferences> _freshPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  /// Un `reply` se reconnaît à son `clientId`, un `read` à sa conversation —
  /// même règle que `NotificationActionQueue.matches` côté Kotlin.
  static bool _matches(Map<String, dynamic> e, PendingNotificationAction a) {
    if ('${e['kind'] ?? ''}' != a.kind) return false;
    if (a.kind == kindReply && a.clientId != null && a.clientId!.isNotEmpty) {
      return e['clientId']?.toString() == a.clientId;
    }
    return int.tryParse('${e['conversationId']}') == a.conversationId;
  }

  static List<Map<String, dynamic>> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
