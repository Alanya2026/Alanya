import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chat_repository.dart';

/// Flush périodique de l'outbox (retries + stuck-sending).
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
      } catch (e) {
        debugPrint('[ChatSyncTimer] flushOutbox failed: $e');
      }
    });
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
