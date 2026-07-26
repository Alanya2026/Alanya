import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// File persistante des accusés de remise déposés par la couche push native.
///
/// Quand l'app est fermée, `DeliveryAckHelper` (Android) envoie directement le
/// `POST /messages/delivered`. Si ce POST échoue — réseau coupé, token
/// irrécupérable — l'accusé atterrit ici et Flutter le rejoue à la prochaine
/// ouverture. Clés lues côté natif via `FlutterSharedPreferences` et le préfixe
/// `flutter.`.
class PendingDeliveryAckStore {
  PendingDeliveryAckStore._();

  static const prefsKey = 'pending_delivery_acks_v1';

  /// Au-delà, l'accusé n'a plus d'intérêt : la resynchronisation de l'app aura
  /// pris le relais.
  static const Duration maxAge = Duration(hours: 24);
  static const int maxEntries = 50;

  /// `reload()` obligatoire : `SharedPreferences` côté Dart est un cache
  /// mémoire, et le natif écrit le fichier pendant que l'isolate est vivant
  /// (app en arrière-plan — le cas nominal). Sans lui, un accusé en échec
  /// n'était jamais rejoué, et `remove()` réécrivait la liste depuis le cache
  /// périmé en effaçant les entrées ajoutées nativement entre-temps.
  static Future<SharedPreferences> _freshPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  /// Conversations en attente d'accusé, les plus anciennes d'abord.
  /// Les entrées périmées sont purgées au passage.
  static Future<List<int>> takeAll() async {
    if (kIsWeb) return const [];
    try {
      final prefs = await _freshPrefs();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
      final ids = <int>[];
      for (final entry in _decode(raw)) {
        final ts = entry['ts'];
        if (ts is int && ts < cutoff) continue;
        final convId = int.tryParse('${entry['conversationId']}');
        if (convId != null && convId > 0 && !ids.contains(convId)) {
          ids.add(convId);
        }
      }
      return ids;
    } catch (e) {
      debugPrint('[PendingDeliveryAckStore] takeAll error: $e');
      return const [];
    }
  }

  static Future<void> remove(int conversationId) async {
    if (kIsWeb) return;
    try {
      final prefs = await _freshPrefs();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = _decode(raw)
          .where((e) => int.tryParse('${e['conversationId']}') != conversationId)
          .toList();
      await prefs.setString(prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingDeliveryAckStore] remove error: $e');
    }
  }

  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (e) {
      debugPrint('[PendingDeliveryAckStore] clear error: $e');
    }
  }

  /// Utilisé par les tests et par un éventuel chemin Dart (iOS), où l'accusé
  /// n'est pas déposé par du code natif.
  @visibleForTesting
  static Future<void> enqueue(int conversationId) async {
    if (kIsWeb || conversationId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      final list = raw == null || raw.isEmpty
          ? <Map<String, dynamic>>[]
          : _decode(raw)
              .where((e) =>
                  int.tryParse('${e['conversationId']}') != conversationId)
              .toList();
      list.add({
        'conversationId': conversationId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      while (list.length > maxEntries) {
        list.removeAt(0);
      }
      await prefs.setString(prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PendingDeliveryAckStore] enqueue error: $e');
    }
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
