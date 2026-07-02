import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste localement (par appareil) les éléments masqués par l'utilisateur :
/// - conversations supprimées « chez moi » (réapparaissent si un nouveau
///   message arrive : on compare `lastMessageAt` au timestamp de masquage),
/// - appels masqués de l'historique récent.
///
/// Aucune synchronisation serveur — réinstaller l'app remet tout à zéro.
class LocalHiddenStore extends ChangeNotifier {
  static const _kConvKey  = 'hidden_conv_at_v1';
  static const _kCallsKey = 'hidden_calls_v1';

  // conversID → timestamp UTC du masquage. Tant que `lastMessageAt` du serveur
  // est <= ce timestamp, la conv reste cachée. Un nouveau message la fait
  // ressortir naturellement.
  final Map<int, DateTime> _hiddenConvAt = {};
  final Set<int> _hiddenCalls = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kConvKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _hiddenConvAt.clear();
        decoded.forEach((k, v) {
          final id = int.tryParse(k);
          final ts = DateTime.tryParse(v.toString());
          if (id != null && ts != null) _hiddenConvAt[id] = ts;
        });
      }
      final calls = prefs.getStringList(_kCallsKey) ?? const [];
      _hiddenCalls
        ..clear()
        ..addAll(calls.map(int.tryParse).whereType<int>());
    } catch (e) {
      debugPrint('[LocalHiddenStore] load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistConv() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _hiddenConvAt.map((k, v) => MapEntry(k.toString(), v.toIso8601String()));
    await prefs.setString(_kConvKey, jsonEncode(encoded));
  }

  Future<void> _persistCalls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCallsKey, _hiddenCalls.map((e) => e.toString()).toList());
  }

  // ── Conversations ──────────────────────────────────────────────────

  /// `lastMessageAt` peut être null si la conv n'a aucun message ;
  /// dans ce cas elle reste masquée tant qu'il n'y a pas de nouveau message.
  bool isConversationHidden(int conversID, DateTime? lastMessageAt) {
    final hiddenAt = _hiddenConvAt[conversID];
    if (hiddenAt == null) return false;
    if (lastMessageAt == null) return true;
    return !lastMessageAt.toUtc().isAfter(hiddenAt);
  }

  Future<void> hideConversation(int conversID) async {
    _hiddenConvAt[conversID] = DateTime.now().toUtc();
    notifyListeners();
    await _persistConv();
  }

  Future<void> unhideConversation(int conversID) async {
    if (_hiddenConvAt.remove(conversID) == null) return;
    notifyListeners();
    await _persistConv();
  }

  // ── Appels ─────────────────────────────────────────────────────────

  bool isCallHidden(int idCall) => _hiddenCalls.contains(idCall);

  Future<void> hideCall(int idCall) async {
    if (!_hiddenCalls.add(idCall)) return;
    notifyListeners();
    await _persistCalls();
  }

  Future<void> unhideCall(int idCall) async {
    if (!_hiddenCalls.remove(idCall)) return;
    notifyListeners();
    await _persistCalls();
  }

  /// Réinitialise les masquages locaux (logout / changement de compte).
  Future<void> clearAll() async {
    _hiddenConvAt.clear();
    _hiddenCalls.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kConvKey);
      await prefs.remove(_kCallsKey);
    } catch (e) {
      debugPrint('[LocalHiddenStore] clearAll error: $e');
    }
  }
}
