import 'package:flutter/foundation.dart';

import '../../db/chat_dao.dart';
import '../../../talky_api_client.dart';
import '../../../talky_models.dart';
import '../local_notification_helper.dart';

/// Accusés de lecture / livraison + catch-up hors ligne.
class ReceiptService {
  ReceiptService({
    required TalkyApiClient api,
    required ChatDao dao,
    required int Function() myId,
    required int Function() activeConversationID,
    required Map<int, int> pendingReadsRetry,
  })  : _api = api,
        _dao = dao,
        _myId = myId,
        _activeConversationID = activeConversationID,
        _pendingReadsRetry = pendingReadsRetry;

  final TalkyApiClient _api;
  final ChatDao _dao;
  final int Function() _myId;
  final int Function() _activeConversationID;
  final Map<int, int> _pendingReadsRetry;

  Future<void> markAsRead(int conversationID) async {
    final myId = _myId();
    await _dao.markConversationReadAtomic(conversationID, myId);
    await LocalNotificationHelper.cancelConversation(conversationID);
    if (_api.isSocketReady) {
      try {
        _api.sendSocketEvent(SocketEvents.messageRead, {
          'conversationID': conversationID,
        });
        _pendingReadsRetry.remove(conversationID);
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
