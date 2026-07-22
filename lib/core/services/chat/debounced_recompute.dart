import 'dart:async';

/// Coalescence des recalculs d'aperçu / unread par conversation.
///
/// Plusieurs mutations proches (envoi + ack + status) ne déclenchent qu'un
/// seul [recompute] après [window] (défaut 30 ms).
///
/// [schedule] retourne un [Future] qui se complète quand le recompute a
/// réellement tourné (tous les appelants coalescés partagent le même Future).
class DebouncedRecompute {
  DebouncedRecompute(
    this._recompute, {
    this.window = const Duration(milliseconds: 30),
  });

  final Future<void> Function(int conversationID) _recompute;
  final Duration window;

  final Map<int, Timer> _timers = {};
  final Map<int, Completer<void>> _pending = {};

  /// Planifie un recompute (annule le timer précédent pour cette conv).
  Future<void> schedule(int conversationID) {
    if (conversationID == 0) return Future<void>.value();
    _timers[conversationID]?.cancel();
    final completer =
        _pending.putIfAbsent(conversationID, Completer<void>.new);
    _timers[conversationID] = Timer(window, () {
      _timers.remove(conversationID);
      final c = _pending.remove(conversationID);
      unawaited(_run(conversationID, c));
    });
    return completer.future;
  }

  /// Exécute immédiatement (annule le debounce en cours).
  Future<void> flushNow(int conversationID) async {
    if (conversationID == 0) return;
    _timers.remove(conversationID)?.cancel();
    final c = _pending.remove(conversationID);
    await _run(conversationID, c);
  }

  Future<void> _run(int conversationID, Completer<void>? c) async {
    try {
      await _recompute(conversationID);
      if (c != null && !c.isCompleted) c.complete();
    } catch (e, st) {
      if (c != null && !c.isCompleted) c.completeError(e, st);
      rethrow;
    }
  }

  /// Annule tous les timers (unbind / dispose).
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete();
    }
    _pending.clear();
  }
}
