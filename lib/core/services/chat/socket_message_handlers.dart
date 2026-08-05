import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../alanya_media_export_service.dart';
import '../media_cache_service.dart';
import '../media_download_preferences.dart';
import '../notifications/badge_sync_service.dart';
import 'chat_api.dart';
import 'message_ack_watchdog.dart';
import 'message_sound_service.dart';
import 'message_path_tracer.dart';
import 'receipt_service.dart';

typedef UpsertServerMsgFn = Future<bool> Function(
  Map<String, dynamic> json, {
  bool prefetchMedia,
});

/// Handlers socket `message:*`.
/// Refus serveur DÉFINITIFS : réessayer échouera à l'identique tant que la
/// situation n'a pas changé (le verrou levé, le membre réintégré, le blocage
/// retiré). Un échec réseau, lui, n'est pas dans cette liste et reste
/// légitimement réessayable.
const Set<String> kTerminalSendFailures = {
  'GROUP_ADMINS_ONLY',
  'NOT_A_MEMBER',
  'BLOCKED_BY_SENDER',
  'CONVERSATION_NOT_FOUND',
  'OFFICIAL_READONLY',
};

class SocketMessageHandlers {
  SocketMessageHandlers({
    required ChatApi api,
    required ChatDao dao,
    required AppDatabase db,
    required int Function() myId,
    required int Function() activeConversationID,
    required bool Function() appInForeground,
    required Future<void> Function(int conversationID) recompute,
    required UpsertServerMsgFn upsertServerMsg,
    required ReceiptService receipts,
    required MediaCacheService mediaCache,
    required void Function() scheduleListCatchUp,
    MessageAckWatchdog? ackWatchdog,
  })  : _api = api,
        _dao = dao,
        _db = db,
        _myId = myId,
        _activeConversationID = activeConversationID,
        _appInForeground = appInForeground,
        _recompute = recompute,
        _upsertServerMsg = upsertServerMsg,
        _receipts = receipts,
        _mediaCache = mediaCache,
        _scheduleListCatchUp = scheduleListCatchUp,
        _ackWatchdog = ackWatchdog;

  final ChatApi _api;
  final ChatDao _dao;

  /// Réactions en attente de confirmation HTTP (`msgID:userID`).
  final Set<String> _pendingReactionKeys = {};

  /// msgID pour lesquels le son d'envoi a déjà été joué (anti-doublon si un
  /// ack `messageSent` est reçu plusieurs fois).
  final Set<int> _sentSoundMsgIds = {};

  Set<String> get pendingReactionKeys => Set.unmodifiable(_pendingReactionKeys);

  String _reactionKey(int msgID, int userID) => '$msgID:$userID';
  final AppDatabase _db;
  final int Function() _myId;
  final int Function() _activeConversationID;
  final bool Function() _appInForeground;
  final Future<void> Function(int conversationID) _recompute;
  final UpsertServerMsgFn _upsertServerMsg;
  final ReceiptService _receipts;
  final MediaCacheService _mediaCache;
  final void Function() _scheduleListCatchUp;
  final MessageAckWatchdog? _ackWatchdog;

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

  static String? _clientIdFromJson(Map<String, dynamic> j) {
    final v = j['clientId'] ?? j['clientID'];
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Future<void> onMessageReceived(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final senderID0 = _toInt(json['senderID']);
    final clientId = _clientIdFromJson(json) ?? 'srv_${_toInt(json['msgID'])}';
    MessagePathTracer.mark(clientId, 'event_received', role: 'receiver', startIfMissing: true);

    final isNew = await _upsertServerMsg(json);
    MessagePathTracer.mark(clientId, 'local_upsert_done', role: 'receiver');
    // Si le même événement est reçu plusieurs fois, on évite de regonfler
    // unread/accusés/notifications. Le message est déjà à jour via l'upsert.
    if (!isNew) return;
    if (senderID0 == _myId()) return;

    final convID = _toInt(json['conversationID']);
    final isViewOnce =
        json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    final isActive =
        convID != 0 && convID == _activeConversationID() && _appInForeground();

    // Retour sonore de réception : uniquement si le message arrive dans la
    // discussion actuellement ouverte (sinon rien — en arrière-plan / autre
    // conversation, c'est la notification qui signale).
    if (isActive) {
      MessageSoundService.instance.playReceived();
    }

    // Conversation ouverte ET app au premier plan → message lu immédiatement.
    if (isActive) {
      await _dao.markConversationRead(convID, _myId());
    }

    // Accusé avant le recalcul d'aperçu (chemin critique).
    if (convID != 0 && _api.isSocketReady) {
      _receipts.emitDeliveredOrRead(convID, isActive: isActive);
      MessagePathTracer.mark(clientId, 'receipt_emit', role: 'receiver');
    }
    unawaited(_recompute(convID).then((_) {
      MessagePathTracer.mark(clientId, 'recompute_done', role: 'receiver');
    }));

    // Filet de sécurité : si la conversation n'existe pas encore en local,
    // `recompute` n'a rien pu faire (message orphelin) — on rattrape la liste
    // via HTTP pour récupérer la conversation (participants, aperçu, tri).
    // On planifie aussi un rattrapage coalescé dans tous les cas pour se
    // resynchroniser après un éventuel event manqué (micro-déconnexion).
    _scheduleListCatchUp();

    final mtype = _toInt(json['type']);
    final mediaUrl = json['mediaUrl']?.toString();
    final msgID = _toInt(json['msgID']);
    // Auto-download des médias reçus (pas les miens — déjà return plus haut).
    if (mediaUrl != null &&
        msgID != 0 &&
        !isViewOnce &&
        MediaDownloadPreferences.isAutoDownloadEnabled) {
      final mediaName = json['mediaName']?.toString();
      if (mtype == 1 || mtype == 2) {
        _cacheMedia(
          msgID,
          mediaUrl,
          type: mtype,
          mediaName: mediaName,
        );
      } else if (mtype == 4) {
        // Fichiers : auto-cache si < 5 MB (sinon ouverture manuelle).
        _cacheMedia(
          msgID,
          mediaUrl,
          maxBytes: 5 * 1024 * 1024,
          type: 4,
          mediaName: mediaName,
        );
      }
    }
  }

  Future<void> _cacheMedia(
    int msgID,
    String url, {
    int? maxBytes,
    required int type,
    String? mediaName,
  }) async {
    // Re-vérifie : la préférence a pu être coupée entre le test et l'appel.
    if (!MediaDownloadPreferences.isAutoDownloadEnabled) return;
    final path = await _mediaCache.ensureCached(url, maxBytes: maxBytes);
    if (path == null) return;
    await _dao.setLocalMediaPath(msgID, path);
    await AlanyaMediaExportService.instance.exportIfNeeded(
      msgID: msgID,
      type: type,
      localPath: path,
      isViewOnce: false,
      isMine: false,
      mediaName: mediaName,
    );
  }

  Future<void> onMessageStatus(dynamic data) async {
    if (data is! Map) return;
    final convID = _toInt(data['conversationID']);
    final status = _toInt(data['status']);
    final byUserID = _toInt(data['byUserID']);
    if (convID == 0 || status == 0 || byUserID == _myId()) return;
    final at = _parseDate(data['at']);
    await _dao.bumpMyMessagesStatus(
      convID,
      _myId(),
      status,
      at: at,
    );
    // Trace status pour les messages confirmés de cette conv (best-effort).
    if (status == 2 || status == 3) {
      MessagePathTracer.mark(
        'conv_$convID',
        status == 2 ? 'status_delivered' : 'status_read',
        role: 'sender',
        startIfMissing: true,
      );
    }
    unawaited(_recompute(convID));
  }

  Future<void> onMessageSent(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final msgID = _toInt(json['msgID']);
    if (msgID == 0) return;
    final clientId = _clientIdFromJson(json);
    if (clientId != null) {
      MessagePathTracer.ackReceived(clientId);
      _ackWatchdog?.cancel(clientId);
    }
    // Son d'envoi : joué quand le SERVEUR confirme l'envoi (une seule fois par
    // message), pas au tap. `Set.add` renvoie false si déjà présent.
    if (_sentSoundMsgIds.add(msgID)) {
      MessageSoundService.instance.playSent();
    }
    await _upsertServerMsg(json);
    final convID = _toInt(json['conversationID']);
    if (convID == 0) return;
    unawaited(_recompute(convID));
  }

  /// Aligne le badge non-lus sur les autres appareils du même compte.
  /// Ne propage pas de accusé de lecture au correspondant.
  Future<void> onInboxSync(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final convID = _toInt(json['conversationID']);
    if (convID == 0) return;
    final unread = json['unreadCount'];
    if (unread == 0 || unread == '0') {
      await _dao.markConversationReadAtomic(convID, _myId());
    } else {
      await _recompute(convID);
    }
    if (_myId() != 0) {
      await BadgeSyncService.syncFromDao(_dao);
    }
  }

  Future<void> onMessageSendFailed(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final clientId = _clientIdFromJson(json);
    if (clientId == null || clientId.isEmpty) return;
    debugPrint(
      '[SocketHandlers] message:send_failed clientId=$clientId '
      'code=${json['code']} msg=${json['message']}',
    );
    final code = json['code']?.toString();
    await _dao.markFailed(
      clientId,
      failureCode: kTerminalSendFailures.contains(code) ? code : null,
    );
  }

  /// (Dés)épingle un message. Optimistic : on écrit localement d'abord pour un
  /// retour instantané, puis on confirme côté serveur (rollback en cas d'échec).
  Future<void> setMessagePinned(int msgID, bool pinned) async {
    if (msgID == 0) return;
    await _dao.setMessagePinnedByServerId(msgID, pinned);
    try {
      await _api.pinMessage(msgID, pinned);
    } catch (e) {
      await _dao.setMessagePinnedByServerId(msgID, !pinned);
      rethrow;
    }
  }

  void onMessagePinned(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id == 0) return;
    final pinned = data['isPinned'] == 1 || data['isPinned'] == true;
    _dao.setMessagePinnedByServerId(id, pinned);
  }

  /// Pose/remplace ma réaction sur un message. Optimistic comme
  /// [setMessagePinned] : écriture locale immédiate, confirmation serveur,
  /// rollback vers l'état précédent (réaction antérieure ou aucune) en cas
  /// d'échec réseau.
  Future<void> setReaction(
    int msgID,
    String emoji, {
    int? conversationID,
  }) async {
    if (msgID == 0 || emoji.isEmpty) return;
    final myId = _myId();
    final convID = conversationID ?? await _conversationIdForMsg(msgID);
    if (convID == null) return;

    final previous = await (_db.select(_db.localMessageReactions)
          ..where((r) => r.msgID.equals(msgID) & r.userID.equals(myId)))
        .getSingleOrNull();

    await _dao.upsertReaction(
      msgID: msgID,
      userID: myId,
      conversationID: convID,
      emoji: emoji,
    );

    final pendingKey = _reactionKey(msgID, myId);
    _pendingReactionKeys.add(pendingKey);
    try {
      await _api.setReaction(msgID, emoji);
    } catch (e) {
      if (previous != null) {
        await _dao.upsertReaction(
          msgID: msgID,
          userID: myId,
          conversationID: convID,
          emoji: previous.emoji,
          reactedAt: previous.reactedAt,
        );
      } else {
        await _dao.deleteReaction(msgID, myId);
      }
      rethrow;
    } finally {
      _pendingReactionKeys.remove(pendingKey);
    }
  }

  /// Retire ma réaction. Optimistic avec rollback si le serveur refuse.
  Future<void> removeReaction(int msgID, {int? conversationID}) async {
    if (msgID == 0) return;
    final myId = _myId();
    final previous = await (_db.select(_db.localMessageReactions)
          ..where((r) => r.msgID.equals(msgID) & r.userID.equals(myId)))
        .getSingleOrNull();
    if (previous == null) return;

    await _dao.deleteReaction(msgID, myId);

    final pendingKey = _reactionKey(msgID, myId);
    _pendingReactionKeys.add(pendingKey);
    try {
      await _api.removeReaction(msgID);
    } catch (e) {
      await _dao.upsertReaction(
        msgID: msgID,
        userID: myId,
        conversationID: previous.conversationID,
        emoji: previous.emoji,
        reactedAt: previous.reactedAt,
      );
      rethrow;
    } finally {
      _pendingReactionKeys.remove(pendingKey);
    }
  }

  /// Événement socket entrant : une réaction a été posée ou retirée par un
  /// participant (moi y compris, depuis un autre appareil). `emoji`
  /// absent/vide signifie un retrait.
  Future<void> onMessageReaction(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final msgID = _toInt(json['msgID']);
    final userID = _toInt(json['userID']);
    if (msgID == 0 || userID == 0) return;
    final emoji = json['emoji']?.toString() ?? '';
    if (emoji.isEmpty) {
      await _dao.deleteReaction(msgID, userID);
      return;
    }
    var convID = _toInt(json['conversationID']);
    if (convID == 0) {
      convID = await _conversationIdForMsg(msgID) ?? 0;
      if (convID == 0) return;
    }
    await _dao.upsertReaction(
      msgID: msgID,
      userID: userID,
      conversationID: convID,
      emoji: emoji,
      reactedAt: _parseDate(json['reactedAt']),
    );
  }

  /// Signale au serveur qu'un média à vue unique a été consulté, puis marque
  /// le message consommé localement (efface toute trace ré-ouvrable).
  Future<void> markViewed(int msgID) async {
    if (msgID == 0) return;
    await _dao.markViewedByServerId(msgID);
    try {
      await _api.markViewed(msgID);
    } catch (e) {
      debugPrint('[SocketHandlers] markViewed échouée: $e');
    }
  }

  void onMessageViewed(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id != 0) _dao.markViewedByServerId(id);
  }

  Future<int?> _conversationIdForMsg(int msgID) async {
    if (msgID == 0) return null;
    final row = await (_db.select(_db.localMessages)
          ..where((m) => m.msgID.equals(msgID))
          ..limit(1))
        .getSingleOrNull();
    return row?.conversationID;
  }

  Future<void> _reconcilePreviewForMsgs(Iterable<int> msgIDs) async {
    final convIDs = <int>{};
    for (final id in msgIDs) {
      final c = await _conversationIdForMsg(id);
      if (c != null) convIDs.add(c);
    }
    for (final convID in convIDs) {
      await _recompute(convID);
    }
  }

  Future<void> onMessageUpdated(dynamic data) async {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    final content = data['content']?.toString();
    if (id == 0 || content == null) return;
    await _dao.updateContentByServerId(id, content);
    // L'aperçu doit refléter le nouveau contenu si c'était le dernier message.
    await _reconcilePreviewForMsgs([id]);
  }

  Future<void> onMessageDeleted(dynamic data) async {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id == 0) return;
    final all = data['all'] == true;
    final deletedForID = _toInt(data['deletedForID']);
    if (all) {
      await _dao.softDeleteByServerId(id);
    } else if (deletedForID == _myId()) {
      await _dao.softDeleteForUser(id, _myId());
    } else {
      return;
    }
    // Réaligne l'aperçu sur le dernier message réel restant.
    await _reconcilePreviewForMsgs([id]);
  }

  Future<void> onMessagesDeleted(dynamic data) async {
    if (data is! Map) return;
    final rawIds = data['msgIDs'];
    if (rawIds is! List || rawIds.isEmpty) return;
    final ids = rawIds.map(_toInt).where((id) => id > 0).toList();
    if (ids.isEmpty) return;
    final all = data['all'] == true;
    final deletedForID = _toInt(data['deletedForID']);
    if (all) {
      await _dao.softDeleteManyByServerId(ids);
    } else if (deletedForID == _myId()) {
      await _dao.softDeleteManyForUser(ids, _myId());
    } else {
      return;
    }
    await _reconcilePreviewForMsgs(ids);
  }

}
