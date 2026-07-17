import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../media_cache_service.dart';
import 'chat_api.dart';
import 'receipt_service.dart';

typedef UpsertServerMsgFn = Future<bool> Function(
  Map<String, dynamic> json, {
  bool prefetchMedia,
});

/// Handlers socket `message:*`.
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
        _scheduleListCatchUp = scheduleListCatchUp;

  final ChatApi _api;
  final ChatDao _dao;
  final AppDatabase _db;
  final int Function() _myId;
  final int Function() _activeConversationID;
  final bool Function() _appInForeground;
  final Future<void> Function(int conversationID) _recompute;
  final UpsertServerMsgFn _upsertServerMsg;
  final ReceiptService _receipts;
  final MediaCacheService _mediaCache;
  final void Function() _scheduleListCatchUp;

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

    final isNew = await _upsertServerMsg(json);
    // Si le même événement est reçu plusieurs fois, on évite de regonfler
    // unread/accusés/notifications. Le message est déjà à jour via l'upsert.
    if (!isNew) return;
    if (senderID0 == _myId()) return;

    final convID = _toInt(json['conversationID']);
    final isViewOnce =
        json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    final isActive =
        convID != 0 && convID == _activeConversationID() && _appInForeground();

    // Conversation ouverte ET app au premier plan → message lu immédiatement.
    if (isActive) {
      await _dao.markConversationRead(convID, _myId());
    }
    await _recompute(convID);

    // Filet de sécurité : si la conversation n'existe pas encore en local,
    // `recompute` n'a rien pu faire (message orphelin) — on rattrape la liste
    // via HTTP pour récupérer la conversation (participants, aperçu, tri).
    // On planifie aussi un rattrapage coalescé dans tous les cas pour se
    // resynchroniser après un éventuel event manqué (micro-déconnexion).
    _scheduleListCatchUp();

    if (convID != 0 && _api.isSocketReady) {
      _receipts.emitDeliveredOrRead(convID, isActive: isActive);
    }
    final mtype = _toInt(json['type']);
    final mediaUrl = json['mediaUrl']?.toString();
    final msgID = _toInt(json['msgID']);
    if (mediaUrl != null && msgID != 0 && !isViewOnce) {
      if (mtype == 1) {
        // Images : auto-cache. Audio (3) : téléchargement manuel dans le chat.
        _cacheMedia(msgID, mediaUrl);
      } else if (mtype == 4) {
        // Fichiers : auto-cache si < 5 MB (sinon coût data trop élevé,
        // ouverture manuelle redéclenchera ensureCached).
        _cacheMedia(msgID, mediaUrl, maxBytes: 5 * 1024 * 1024);
      }
      // Vidéos (mtype==2) : on-demand uniquement (déjà via tap → ensureCached).
    }
  }

  Future<void> _cacheMedia(int msgID, String url, {int? maxBytes}) async {
    final path = await _mediaCache.ensureCached(url, maxBytes: maxBytes);
    if (path != null) await _dao.setLocalMediaPath(msgID, path);
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
    await _recompute(convID);
  }

  Future<void> onMessageSent(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final msgID = _toInt(json['msgID']);
    if (msgID == 0) return;
    await _upsertServerMsg(json);
    final convID = _toInt(json['conversationID']);
    if (convID == 0) return;
    await _recompute(convID);
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
    await _dao.markFailed(clientId);
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
