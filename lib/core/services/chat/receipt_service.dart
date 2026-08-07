import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/chat_dao.dart';
import '../../../talky_models.dart';
import '../local_notification_helper.dart';
import '../notifications/badge_sync_service.dart';
import '../notifications/notification_dedup_store.dart';
import '../notifications/pending_delivery_ack_store.dart';
import 'chat_api.dart';

/// Accusés de lecture / livraison + catch-up hors ligne.
class ReceiptService {
  ReceiptService({
    required ChatApi api,
    required ChatDao dao,
    required int Function() myId,
    required int Function() activeConversationID,
    required Map<int, int> pendingReadsRetry,
    required Future<void> Function(int conversationID) recompute,
  })  : _api = api,
        _dao = dao,
        _myId = myId,
        _activeConversationID = activeConversationID,
        _pendingReadsRetry = pendingReadsRetry,
        _recompute = recompute;

  final ChatApi _api;
  final ChatDao _dao;
  final int Function() _myId;
  final int Function() _activeConversationID;
  final Map<int, int> _pendingReadsRetry;
  final Future<void> Function(int conversationID) _recompute;

  /// Lecture locale instantanée (badge Drift → 0) puis propagation réseau
  /// en arrière-plan pour ne pas bloquer l'UI.
  Future<void> markAsRead(int conversationID) async {
    await markAsReadLocal(conversationID);
    unawaited(_propagateRead(conversationID));
  }

  /// Uniquement le cache local + notifs (immédiat).
  /// Marque les incoming à status=3 puis dérive unread via recompute.
  Future<void> markAsReadLocal(int conversationID) async {
    final myId = _myId();
    final unreadMsgIds = await _dao.unreadIncomingMsgIds(conversationID, myId);
    await _dao.markConversationRead(conversationID, myId);
    await _recompute(conversationID);
    await LocalNotificationHelper.cancelConversation(conversationID);
    for (final msgID in unreadMsgIds) {
      await NotificationDedupStore.markCancelled(msgID: msgID);
    }
    await BadgeSyncService.syncFromDao(_dao);
  }

  Future<void> _propagateRead(int conversationID) async {
    // Socket OU HTTP, jamais les deux : le POST partait systématiquement même
    // quand le socket avait réussi — chaque marquage de lecture écrivait donc
    // deux fois les mêmes lignes côté serveur. Le fallback socket reste assuré
    // par _pendingReadsRetry / flushPendingReads.
    if (_api.isSocketReady) {
      try {
        _api.sendSocketEvent(SocketEvents.messageRead, {
          'conversationID': conversationID,
        });
        _pendingReadsRetry.remove(conversationID);
        return;
      } catch (e) {
        debugPrint('[ReceiptService] sendSocketEvent failed: $e');
        _pendingReadsRetry[conversationID] =
            (_pendingReadsRetry[conversationID] ?? 0) + 1;
      }
    } else {
      _pendingReadsRetry[conversationID] =
          (_pendingReadsRetry[conversationID] ?? 0);
    }
    try {
      await _api.markConversationAsRead(conversationID);
      _pendingReadsRetry.remove(conversationID);
    } catch (e) {
      debugPrint('[ReceiptService] markConversationAsRead HTTP failed: $e');
    }
  }

  Future<void> flushPendingReads() async {
    if (!_api.isSocketReady || _pendingReadsRetry.isEmpty) return;
    for (final convID in _pendingReadsRetry.keys.toList()) {
      try {
        _api.sendSocketEvent(SocketEvents.messageRead, {
          'conversationID': convID,
        });
        _pendingReadsRetry.remove(convID);
      } catch (e) {
        debugPrint('[ReceiptService] flushPendingReads failed for $convID: $e');
        _pendingReadsRetry[convID] = (_pendingReadsRetry[convID] ?? 0) + 1;
        if ((_pendingReadsRetry[convID] ?? 0) > 3) {
          _pendingReadsRetry.remove(convID);
        }
      }
    }
  }

  /// Rejoue les accusés de remise que la couche push native n'a pas réussi à
  /// envoyer (app fermée + réseau coupé, ou token irrécupérable).
  ///
  /// Passe par HTTP et non par le socket : au bootstrap le socket peut ne pas
  /// encore être prêt, et ces accusés ne doivent pas attendre un tour de plus.
  Future<void> flushNativeDeliveryAcks() async {
    if (_myId() == 0) return;
    final pending = await PendingDeliveryAckStore.takeAll();
    if (pending.isEmpty) return;
    debugPrint('[ReceiptService] 🔁 flushNativeDeliveryAcks count=${pending.length}');
    for (final convID in pending) {
      try {
        await _api.markConversationDelivered(convID);
        await PendingDeliveryAckStore.remove(convID);
      } catch (e) {
        debugPrint('[ReceiptService] delivery ack rejeu $convID: $e');
      }
    }
  }

  /// Catch-up accusés après reconnect / resume.
  Future<void> flushReceiptsCatchUp() async {
    final myId = _myId();
    if (!_api.isSocketReady || myId == 0) return;
    try {
      final needingDelivery = await _dao.conversationIdsNeedingDelivery(myId);
      final active = _activeConversationID();
      for (final convID in needingDelivery) {
        if (convID == active) continue;
        try {
          _api.sendSocketEvent(SocketEvents.messageDelivered, {
            'conversationID': convID,
          });
        } catch (e) {
          debugPrint('[ReceiptService] delivered catch-up $convID: $e');
        }
      }
      if (active != 0) {
        await markAsRead(active);
      }
    } catch (e) {
      debugPrint('[ReceiptService] flushReceiptsCatchUp: $e');
    }
  }

  void emitDeliveredOrRead(int conversationID, {required bool isActive}) {
    if (!_api.isSocketReady || conversationID == 0) return;
    _api.sendSocketEvent(
      isActive ? SocketEvents.messageRead : SocketEvents.messageDelivered,
      {'conversationID': conversationID},
    );
  }
}
