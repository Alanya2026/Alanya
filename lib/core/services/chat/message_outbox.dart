import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../../talky_models.dart';
import 'chat_api.dart';
import 'message_sender.dart';

/// Outbox / retry d'envoi hors-ligne.
class MessageOutbox {
  MessageOutbox({
    required ChatApi api,
    required ChatDao dao,
    required AppDatabase db,
    required MessageSender sender,
    required Set<int> pendingReads,
    required Future<void> Function(int conversationID) recompute,
  })  : _api = api,
        _dao = dao,
        _db = db,
        _sender = sender,
        _pendingReads = pendingReads,
        _recompute = recompute;

  final ChatApi _api;
  final ChatDao _dao;
  final AppDatabase _db;
  final MessageSender _sender;
  final Set<int> _pendingReads;
  final Future<void> Function(int conversationID) _recompute;

  /// Évite le flush imbriqué quand `forceReconnect` déclenche `auth:verified`.
  bool _flushInFlight = false;

  static const Duration _stalePendingBeforeReconnect = Duration(seconds: 25);

  Future<void> flushOutbox() async {
    if (_flushInFlight) return;
    _flushInFlight = true;
    try {
      await _flushOutboxBody();
    } finally {
      _flushInFlight = false;
    }
  }

  Future<void> _flushOutboxBody() async {
    // Pending sans ack depuis > 25s : socket probablement zombie → vrai
    // reconnect avant de ré-émettre (sinon touchEmitted tourne dans le vide).
    if (await _dao.hasStalePending(olderThan: _stalePendingBeforeReconnect)) {
      debugPrint('[MessageOutbox] pending stale → forceReconnect');
      await _api.forceReconnect();
    }

    await _reconcilePendingViaHttp();

    final pending = await _dao.pendingMessages();
    for (final m in pending) {
      final needsUpload = m.pendingUploadPath != null &&
          m.pendingUploadPath!.isNotEmpty &&
          (m.mediaUrl == null || m.mediaUrl!.isEmpty);

      if (needsUpload) {
        final file = await _sender.resolvePendingUploadFile(m);
        if (file == null) {
          debugPrint('[MessageOutbox] flush: fichier disparu pour ${m.clientId} → failed');
          await _dao.markFailed(m.clientId);
          continue;
        }
        try {
          await _sender.uploadAndEmit(
            clientId: m.clientId,
            conversationID: m.conversationID,
            file: file,
            type: m.type,
            content: m.content,
            mediaName: m.mediaName,
            mediaDuration: m.mediaDuration,
            replyToID: m.replyToID,
            replyToContent: m.replyToContent,
            isStatusReply: m.isStatusReply,
            isForwarded: m.isForwarded,
            isViewOnce: m.isViewOnce,
            clickSentAt: m.clickSentAt,
          );
        } catch (e) {
          await _sender.handleUploadFailure(m.clientId, e, 'flush upload échoué pour ${m.clientId}');
        }
      } else {
        // Média déjà uploadé (mediaUrl présent) ou message texte : réémettre
        // message:send. Sans cette branche, un upload HTTP réussi suivi d'un
        // emit socket ignoré (socket non prêt) reste bloqué indéfiniment.
        _sender.emitPendingMessage(m);
      }
    }

    // Horloge coincée : pending depuis > 2 min (âge sendAt) → failed.
    // Indépendant de lastEmittedAt pour ne pas être annulé par le flush périodique.
    final stuck = await _dao.stuckPendingMessages();
    for (final m in stuck) {
      debugPrint('[MessageOutbox] stuck pending → failed ${m.clientId}');
      await _dao.markFailed(m.clientId);
    }

    // Rejoue les accusés de lecture émis hors-ligne.
    if (_api.isSocketReady && _pendingReads.isNotEmpty) {
      for (final convID in _pendingReads.toList()) {
        _api.sendSocketEvent(SocketEvents.messageRead, {
          'conversationID': convID,
        });
      }
      _pendingReads.clear();
    }

    // Retry des messages marqués failed (status==4) avec retryCount < 3
    final failed = await (_db.select(_db.localMessages)
          ..where((m) => m.status.equals(4) & m.retryCount.isSmallerThanValue(3)))
        .get();
    for (final m in failed) {
      await _dao.incrementRetryCount(m.clientId);
      final needsUpload = m.pendingUploadPath != null &&
          m.pendingUploadPath!.isNotEmpty &&
          (m.mediaUrl == null || m.mediaUrl!.isEmpty);

      if (needsUpload) {
        final file = await _sender.resolvePendingUploadFile(m);
        if (file == null) {
          debugPrint('[MessageOutbox] retry: fichier disparu pour ${m.clientId} → keep failed');
          continue;
        }
        try {
          await _sender.uploadAndEmit(
            clientId: m.clientId,
            conversationID: m.conversationID,
            file: file,
            type: m.type,
            content: m.content,
            mediaName: m.mediaName,
            mediaDuration: m.mediaDuration,
            replyToID: m.replyToID,
            replyToContent: m.replyToContent,
            isStatusReply: m.isStatusReply,
            isForwarded: m.isForwarded,
            isViewOnce: m.isViewOnce,
            clickSentAt: m.clickSentAt,
          );
        } catch (e) {
          await _sender.handleUploadFailure(m.clientId, e, 'retry upload échoué pour ${m.clientId}');
        }
      } else {
        // Message texte ou média déjà uploadé : remettre en pending et réémettre
        await _dao.retryFailed(m.clientId);
        _sender.emitPendingMessage(m);
      }
    }
  }

  Future<void> retryMessage(String clientId) async {
    await _dao.retryFailed(clientId);
    if (_api.isSocketReady) {
      await flushOutbox();
    }
  }

  /// Confirme localement les pending déjà persistés côté serveur (ack socket perdu).
  Future<void> _reconcilePendingViaHttp() async {
    final pending = await _dao.pendingMessages();
    if (pending.isEmpty) return;

    for (final m in pending) {
      try {
        final st = await _api.getMessageStatusByClientId(m.clientId);
        if (st['found'] != true) continue;
        final msgID = _toInt(st['msgID']);
        if (msgID == 0) continue;
        await _dao.confirmMessage(
          clientId: m.clientId,
          msgID: msgID,
          status: _toInt(st['status'], fallback: 1),
          sendAt: _parseDate(st['sendAt']),
        );
        await _recompute(m.conversationID);
        debugPrint('[MessageOutbox] HTTP ack clientId=${m.clientId} msgID=$msgID');
      } catch (e) {
        debugPrint('[MessageOutbox] reconcile HTTP ${m.clientId}: $e');
      }
    }
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
