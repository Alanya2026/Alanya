import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chat_repository.dart';

class ChatSyncTimer {
  final ChatRepository _repo;
  Timer? _retryTimer;

  ChatSyncTimer(this._repo);

  void start() {
    if (_retryTimer != null) return;
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
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
