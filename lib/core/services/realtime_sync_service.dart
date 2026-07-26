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
  ///
  /// Respecte le cooldown de [ChatRepository.syncConversations] sauf si
  /// [force] est true (évite le 4e pipeline au resume immédiat après bind).
  Future<void> catchUp({int? conversationId, bool force = false}) async {
    try {
      await _chat.repository.flushOutbox();
      // Après l'outbox (pour ne pas passer derrière une rafale d'upload) mais
      // avant le reste : réponses rapides et « lu » déposés par la couche
      // native, invisibles de la base locale.
      await _chat.repository.flushPendingNotificationActions();
      // Messages reçus par push alors que l'app était fermée : leur accusé de
      // remise n'est pas déductible de la base locale, il n'y a que la file
      // native pour le retrouver.
      await _chat.repository.flushNativeDeliveryAcks();
      await _chat.repository.flushReceiptsCatchUp();
      await _chat.refreshConversations(force: force);
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
