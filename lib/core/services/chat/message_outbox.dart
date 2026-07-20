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
  })  : _api = api,
        _dao = dao,
        _db = db,
        _sender = sender,
        _pendingReads = pendingReads;

  final ChatApi _api;
  final ChatDao _dao;
  final AppDatabase _db;
  final MessageSender _sender;
  final Set<int> _pendingReads;

  Future<void> flushOutbox() async {
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

    // Horloge coincée : pending depuis > 5 min malgré des retries → failed
    // (l'utilisateur peut relancer via le menu). Avec idempotence serveur,
    // les retries antérieurs n'ont pas créé de doublons.
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
}
