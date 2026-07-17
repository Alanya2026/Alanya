import 'package:flutter/foundation.dart';

import '../../providers/chat_provider.dart';
import '../../providers/status_provider.dart';

/// Rattrapage REST quand le WebSocket ne livre pas les événements temps réel.
class RealtimeSyncService {
  final ChatProvider _chat;
  final StatusProvider _status;

  RealtimeSyncService({
    required ChatProvider chat,
    required StatusProvider status,
  })  : _chat = chat,
        _status = status;

  /// Synchronise conversations, messages (delta) et statuts depuis l'API.
  Future<void> catchUp({int? conversationId}) async {
    try {
      await _chat.repository.flushOutbox();
      await _chat.repository.flushReceiptsCatchUp();
      await _chat.refreshConversations();
      if (conversationId != null && conversationId > 0) {
        await _chat.repository.syncMessages(conversationId, delta: true);
      }
      await _chat.repository.resyncActiveConversation();
      await _status.refresh();
    } catch (e, st) {
      debugPrint('[RealtimeSync] catchUp échoué: $e\n$st');
    }
  }

  /// Rafraîchit uniquement les statuts (complément après reconnexion socket).
  Future<void> refreshStatuses() async {
    try {
      await _status.refresh();
    } catch (e, st) {
      debugPrint('[RealtimeSync] refreshStatuses échoué: $e\n$st');
    }
  }
}
