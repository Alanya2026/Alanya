import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../db/chat_dao.dart';
import '../../utils/app_log.dart';
import 'chat_api.dart';
import 'message_path_tracer.dart';

/// Timeout d'ack par message : si pas de `message:sent` sous [timeout],
/// tente un GET status HTTP puis forceReconnect si absent.
class MessageAckWatchdog {
  MessageAckWatchdog({
    required ChatApi api,
    required ChatDao dao,
    required Future<void> Function(int conversationID) recompute,
    this.timeout = const Duration(seconds: 10),
  })  : _api = api,
        _dao = dao,
        _recompute = recompute;

  final ChatApi _api;
  final ChatDao _dao;
  final Future<void> Function(int conversationID) _recompute;
  final Duration timeout;

  final Map<String, Timer> _timers = {};
  final Map<String, int> _convByClient = {};

  /// Arme un timer après émission socket réussie.
  void arm(String clientId, int conversationID) {
    if (clientId.isEmpty) return;
    cancel(clientId);
    _convByClient[clientId] = conversationID;
    _timers[clientId] = Timer(timeout, () => unawaited(_onExpired(clientId)));
  }

  /// Annule quand `message:sent` / confirmMessage arrive.
  void cancel(String clientId) {
    _timers.remove(clientId)?.cancel();
    _convByClient.remove(clientId);
  }

  Future<void> _onExpired(String clientId) async {
    _timers.remove(clientId);
    final convID = _convByClient.remove(clientId) ?? 0;

    // Déjà confirmé localement (race) → no-op.
    final row = await (_dao.db.select(_dao.db.localMessages)
          ..where((m) => m.clientId.equals(clientId)))
        .getSingleOrNull();
    if (row == null || !row.syncPending || row.msgID > 0) {
      return;
    }

    AppLog.i('MsgAck', 'timeout clientId=$clientId → reconcile HTTP');
    MessagePathTracer.mark(clientId, 'ack_timeout');

    try {
      final st = await _api.getMessageStatusByClientId(clientId);
      if (st['found'] == true) {
        final msgID = _toInt(st['msgID']);
        if (msgID != 0) {
          await _dao.confirmMessage(
            clientId: clientId,
            msgID: msgID,
            status: _toInt(st['status'], fallback: 1),
            sendAt: _parseDate(st['sendAt']),
          );
          MessagePathTracer.ackReceived(clientId);
          final c = convID != 0 ? convID : row.conversationID;
          await _recompute(c);
          return;
        }
      }
    } catch (e) {
      debugPrint('[MessageAckWatchdog] reconcile HTTP $clientId: $e');
    }

    // Absent côté serveur → reconnect pour débloquer un socket zombie.
    AppLog.i('MsgAck', 'absent server → forceReconnect clientId=$clientId');
    await _api.forceReconnect();
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _convByClient.clear();
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
