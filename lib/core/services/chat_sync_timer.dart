import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chat_repository.dart';

/// Flush périodique de l'outbox (retries + stuck-sending) et rattrapage léger
/// si le socket ne livre plus les events.
class ChatSyncTimer {
  final ChatRepository _repo;
  Timer? _retryTimer;

  /// Intervalle court : rattrape les acks perdus sans attendre 5 minutes.
  static const Duration interval = Duration(seconds: 75);

  ChatSyncTimer(this._repo);

  void start() {
    if (_retryTimer != null) return;
    _retryTimer = Timer.periodic(interval, (_) async {
      try {
        debugPrint('[ChatSyncTimer] Periodic flushOutbox tick');
        await _repo.flushOutbox();
        // Filet léger : delta messages si socket down, sync liste complète
        // seulement si le dernier sync est vieux (> 5 min).
        if (!_repo.isSocketReady || _repo.needsPeriodicListSync) {
          if (_repo.needsPeriodicListSync) {
            await _repo.syncConversations(force: false);
          } else {
            await _repo.syncGlobalDelta();
          }
        }
      } catch (e) {
        debugPrint('[ChatSyncTimer] periodic tick failed: $e');
      }
    });
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
