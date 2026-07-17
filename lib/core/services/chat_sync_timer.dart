import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chat_repository.dart';

/// Flush périodique de l'outbox (retries + stuck-sending) et rattrapage de la
/// liste des conversations (filet si le socket ne livre plus les events).
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
        // Filet de sécurité côté récepteur : si le WebSocket a raté des
        // `message:received` (déconnexion silencieuse, room non rejointe après
        // reconnexion), la liste se resynchronise ici sans action utilisateur.
        // Merge-protégé : n'écrase pas les aperçus optimistes en cours.
        await _repo.syncConversations();
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
