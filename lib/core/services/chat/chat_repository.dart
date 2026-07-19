import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../utils/forward_message.dart';
import '../../utils/backend_url.dart';
import '../../utils/contact_payload.dart';
import '../../utils/location_payload.dart';
import '../../utils/media_album.dart';
import '../alanya_media_export_service.dart';
import '../local_notification_helper.dart';
import '../media_cache_service.dart';
import '../media_download_preferences.dart';
import '../voice_asset_resolver.dart';
import '../../../talky_api_client.dart' hide ChatHttpApi;
import '../../../talky_models.dart';
import 'chat_api.dart';
import 'conversation_summary_reducer.dart';
import 'conversation_sync.dart';
import 'receipt_service.dart';
import 'message_outbox.dart';
import 'message_sender.dart';
import 'socket_message_handlers.dart';
import 'talky_chat_api.dart';

/// Facade messaging : sync, envoi, outbox, accusés, handlers socket.
class ChatRepository {
  final AppDatabase _db;
  final ChatDao _dao;
  final ChatApi _api;
  final MediaCacheService _mediaCache = MediaCacheService();
  late final ConversationSummaryReducer _reducer;
  late final ConversationSync _sync;
  late final ReceiptService _receipts;
  late final MessageSender _sender;
  late final MessageOutbox _outbox;
  late final SocketMessageHandlers _handlers;

  /// Progression d'upload éphémère par [clientId] (0.0–1.0).
  final ValueNotifier<Map<String, double>> uploadProgress =
      ValueNotifier<Map<String, double>>({});

  /// Uploads en cours par [clientId] — évite les uploads parallèles du même message.
  final Set<String> _inFlightUploads = {};

  int _myId = 0;
  bool _listenersBound = false;

  /// Rattrapage coalescé de la liste des conversations après un événement
  /// socket entrant. Filet de sécurité : garantit que la liste reflète la
  /// réalité même si `recompute` n'a pas pu agir (conversation encore absente
  /// en local, `conversation:created` perdu, event dédupliqué, etc.).
  /// Débouncé pour coalescer les rafales (une seule sync par fenêtre courte).
  Timer? _listCatchUpTimer;

  /// Conversation actuellement ouverte à l'écran (0 = aucune). Un message reçu
  /// pour cette conversation est marqué lu immédiatement et n'incrémente pas
  /// l'unread (l'utilisateur le voit en direct) — **uniquement si l'app est
  /// au premier plan** (sinon écran encore sur la pile mais téléphone verrouillé).
  int _activeConversationID = 0;

  /// False dès que l'app passe en arrière-plan / inactive.
  bool _appInForeground = true;

  /// True seulement si le chat est ouvert ET visible (pas en veille).
  bool get _isChatVisiblyActive =>
      _activeConversationID != 0 && _appInForeground;

  /// Lectures à confirmer au serveur dès la reconnexion (lecture hors-ligne).
  final Set<int> _pendingReads = {};
  /// Retry tracker pour les lectures hors-ligne (conversationID -> retryCount)
  final Map<int, int> _pendingReadsRetry = {};

  void setActiveConversation(int conversationID) {
    _activeConversationID = conversationID;
    if (_appInForeground) {
      LocalNotificationHelper.setActiveConversationId(conversationID);
    }
  }

  void clearActiveConversation(int conversationID) {
    if (_activeConversationID == conversationID) {
      _activeConversationID = 0;
      LocalNotificationHelper.setActiveConversationId(null);
    }
  }

  /// Synchronise la suppression push + le traitement « chat actif » avec le
  /// cycle de vie. En arrière-plan : on reçoit les notifs et on compte les
  /// non-lus (même si le ChatDetail est encore sur la pile).
  void syncPushSuppressionForLifecycle(bool appInForeground) {
    _appInForeground = appInForeground;
    if (!appInForeground || _activeConversationID == 0) {
      LocalNotificationHelper.setActiveConversationId(null);
    } else {
      LocalNotificationHelper.setActiveConversationId(_activeConversationID);
    }
  }

  ChatRepository._(this._api, this._db) : _dao = ChatDao(_db) {
    _reducer = ConversationSummaryReducer(_db, _dao);
    _sync = ConversationSync(
      api: _api,
      dao: _dao,
      myId: () => _myId,
      upsertServerMsg: _upsertServerMsg,
      convToCompanion: _convToCompanion,
      parseDate: _parseDate,
      recompute: (convId) => _reducer.recompute(convId, _myId),
      recomputeAll: () => _reducer.recomputeAll(_myId),
    );
    _receipts = ReceiptService(
      api: _api,
      dao: _dao,
      myId: () => _myId,
      activeConversationID: () =>
          _isChatVisiblyActive ? _activeConversationID : 0,
      pendingReadsRetry: _pendingReadsRetry,
      recompute: (convId) => _reducer.recompute(convId, _myId),
    );

    _sender = MessageSender(
      api: _api,
      dao: _dao,
      db: _db,
      myId: () => _myId,
      recompute: (id) => _reducer.recompute(id, _myId),
      uploadProgress: uploadProgress,
      inFlightUploads: _inFlightUploads,
    );
    _outbox = MessageOutbox(
      api: _api,
      dao: _dao,
      db: _db,
      sender: _sender,
      pendingReads: _pendingReads,
    );
    _handlers = SocketMessageHandlers(
      api: _api,
      dao: _dao,
      db: _db,
      myId: () => _myId,
      activeConversationID: () => _activeConversationID,
      appInForeground: () => _appInForeground,
      recompute: (id) => _reducer.recompute(id, _myId),
      upsertServerMsg: _upsertServerMsg,
      receipts: _receipts,
      mediaCache: _mediaCache,
      scheduleListCatchUp: scheduleListCatchUp,
    );
  }

  /// Planifie un rattrapage coalescé de la liste des conversations (débouncé).
  /// Sûr côté récepteur : `ConversationSync` protège les aperçus optimistes
  /// (via `hasLocalPendingNewer`) et redérive tout depuis les messages locaux.
  void scheduleListCatchUp() {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = Timer(const Duration(milliseconds: 600), () {
      if (_myId == 0) return;
      _sync.syncConversations();
    });
  }

  MediaCacheService get mediaCache => _mediaCache;

  factory ChatRepository({required TalkyApiClient api, AppDatabase? database}) {
    return ChatRepository._(TalkyChatApi(api), database ?? AppDatabase());
  }

  /// Constructeur de test : injecte un [ChatApi] (ex. FakeChatApi) + Drift mémoire.
  factory ChatRepository.forTesting({
    required ChatApi api,
    required AppDatabase database,
  }) {
    return ChatRepository._(api, database);
  }

  AppDatabase get db => _db;
  ChatDao get dao => _dao;
  int get myId => _myId;
  Stream<List<LocalConversation>> watchConversations() => _dao.watchConversations();
  Stream<LocalConversation?> watchConversation(int conversationID) =>
      _dao.watchConversation(conversationID);
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      _dao.watchMessages(conversationID, _myId);

  /// Flux des messages épinglés d'une conversation (pour la bannière).
  Stream<List<LocalMessage>> watchPinnedMessages(int conversationID) =>
      _dao.watchPinnedMessages(conversationID, _myId);
 
  /// Handler `auth:verified`. Méthode (et non lambda stockée) pour garder
  /// une référence stable utilisable par `removeSocketListener` au logout.
  Future<void> _onAuthVerified(dynamic _) async {
    try {
      rejoinActiveRoom();
      await flushReceiptsCatchUp();
      await resyncActiveConversation();
      await _receipts.flushPendingReads();
    } catch (e) {
      debugPrint('[ChatRepo] authVerified handler failed: $e');
    }
  }

  Future<void> bind(int myId) async {
    if (myId == 0) return;
    _myId = myId;

    // Purges et éviction attendues au démarrage pour stabiliser la DB.
    await _dao.purgeGhostMessages();
    await _dao.purgeDuplicateOptimistics();
    await _dao.purgeDuplicateByMsgId();
    await _mediaCache.evictIfNeeded();

    if (_listenersBound) return;
    _listenersBound = true;

    _api.onSocketEvent(SocketEvents.messageReceived, _handlers.onMessageReceived);
    _api.onSocketEvent(SocketEvents.messageSent, _handlers.onMessageSent);
    _api.onSocketEvent(SocketEvents.messageSendFailed, _handlers.onMessageSendFailed);
    _api.onSocketEvent(SocketEvents.messageUpdated, _handlers.onMessageUpdated);
    _api.onSocketEvent(SocketEvents.messageDeleted, _handlers.onMessageDeleted);
    _api.onSocketEvent(SocketEvents.messagesDeleted, _handlers.onMessagesDeleted);
    _api.onSocketEvent(SocketEvents.messagePinned, _handlers.onMessagePinned);
    _api.onSocketEvent(SocketEvents.messageViewed, _handlers.onMessageViewed);
    _api.onSocketEvent(SocketEvents.messageStatus, _handlers.onMessageStatus);
    _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationCreated);
    _api.onSocketEvent(SocketEvents.authVerified, _onAuthVerified);
  }

  /// Détache les listeners socket et autorise un futur `bind` (cas logout/login
  /// dans la même session d'app). `disconnectSocket` aurait déjà vidé le
  /// registre côté API client, mais on remet le drapeau à zéro pour que la
  /// prochaine connexion repasse par l'enregistrement complet.
  void unbind() {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = null;
    if (!_listenersBound) return;
    _listenersBound = false;
    _api.removeSocketListener(SocketEvents.messageReceived, _handlers.onMessageReceived);
    _api.removeSocketListener(SocketEvents.messageSent, _handlers.onMessageSent);
    _api.removeSocketListener(SocketEvents.messageSendFailed, _handlers.onMessageSendFailed);
    _api.removeSocketListener(SocketEvents.messageUpdated, _handlers.onMessageUpdated);
    _api.removeSocketListener(SocketEvents.messageDeleted, _handlers.onMessageDeleted);
    _api.removeSocketListener(SocketEvents.messagesDeleted, _handlers.onMessagesDeleted);
    _api.removeSocketListener(SocketEvents.messagePinned, _handlers.onMessagePinned);
    _api.removeSocketListener(SocketEvents.messageViewed, _handlers.onMessageViewed);
    _api.removeSocketListener(SocketEvents.messageStatus, _handlers.onMessageStatus);
    _api.removeSocketListener(SocketEvents.conversationCreated, _onConversationCreated);
    _api.removeSocketListener(SocketEvents.authVerified, _onAuthVerified);
    _activeConversationID = 0;
    LocalNotificationHelper.setActiveConversationId(null);
    _pendingReads.clear();
    _pendingReadsRetry.clear();
    _myId = 0;
  }

  /// Efface conversations, messages et cache média (logout / changement de compte).
  Future<void> clearLocalSession() async {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = null;
    _activeConversationID = 0;
    LocalNotificationHelper.setActiveConversationId(null);
    _pendingReads.clear();
    _pendingReadsRetry.clear();
    await _dao.clearAll();
    await _mediaCache.clearAll();
  }

  void _onConversationCreated(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    _dao.upsertConversation(_convToCompanion(Conversation.fromJson(json), json));
  }
 
  Future<void> syncConversations() => _sync.syncConversations();

  /// Sync delta globale des messages (curseur par conversation). Rattrapage
  /// garanti et sans trou des messages manqués par le WebSocket.
  Future<void> syncGlobalDelta() => _sync.syncGlobalDelta();

  /// Charge l'historique d'une conversation.
  /// Si `delta == true`, ne récupère que les messages plus récents que le
  /// dernier confirmé en local (curseur `after` côté API).
  Future<void> syncMessages(int conversationID, {bool delta = false}) =>
      _sync.syncMessages(conversationID, delta: delta);

  /// Charge une page d'anciens messages
  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) =>
      _sync.loadOlderMessages(conversationID, limit: limit);


  static const int maxAlbumItems = MessageSender.maxAlbumItems;

  Future<void> sendText({
    required int conversationID,
    required String content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
  }) =>
      _sender.sendText(
        conversationID: conversationID,
        content: content,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
      );

  Future<void> sendLocation({
    required int conversationID,
    required LocationPayload location,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) =>
      _sender.sendLocation(
        conversationID: conversationID,
        location: location,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isForwarded: isForwarded,
      );

  Future<void> sendContact({
    required int conversationID,
    required ContactPayload contact,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) =>
      _sender.sendContact(
        conversationID: conversationID,
        contact: contact,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isForwarded: isForwarded,
      );

  Future<void> sendMedia({
    required int conversationID,
    required int type,
    required String mediaUrl,
    String? mediaName,
    int? mediaDuration,
    String? mediaThumb,
    String? localMediaPath,
    String? content,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) =>
      _sender.sendMedia(
        conversationID: conversationID,
        type: type,
        mediaUrl: mediaUrl,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        mediaThumb: mediaThumb,
        localMediaPath: localMediaPath,
        content: content,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
      );

  Future<void> sendMediaFile({
    required int conversationID,
    required int type,
    required File file,
    String? mediaName,
    int? mediaDuration,
    String? content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) =>
      _sender.sendMediaFile(
        conversationID: conversationID,
        type: type,
        file: file,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        content: content,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
      );

  Future<void> sendMediaAlbum({
    required int conversationID,
    required List<AlbumSendItem> items,
    String? content,
    bool isForwarded = false,
  }) =>
      _sender.sendMediaAlbum(
        conversationID: conversationID,
        items: items,
        content: content,
        isForwarded: isForwarded,
      );

  /// Transfère un album complet vers une ou plusieurs conversations.
  Future<ForwardResult> forwardAlbum({
    required List<LocalMessage> sourceItems,
    required List<int> targetConversationIDs,
  }) async {
    if (_myId == 0) {
      return const ForwardResult(
        succeeded: 0,
        failed: 0,
        errors: ['Utilisateur non connecté'],
      );
    }
    if (!canForwardAlbum(sourceItems)) {
      return const ForwardResult(
        succeeded: 0,
        failed: 1,
        errors: ['Cet album ne peut pas être transféré'],
      );
    }
    if (targetConversationIDs.isEmpty) {
      return const ForwardResult(succeeded: 0, failed: 0);
    }

    if (canBatchForwardOnServer(sourceItems)) {
      try {
        final sorted = _sortAlbumItems(sourceItems);
        final sourceMsgIDs = sorted.map((m) => m.msgID).toList();
        await _api.batchForward(
          sourceMsgIDs: sourceMsgIDs,
          targetConversationIDs: targetConversationIDs,
        );
        return ForwardResult(
          succeeded: targetConversationIDs.length,
          failed: 0,
        );
      } catch (e) {
        debugPrint('[ChatRepo] batch forward album échoué, fallback client: $e');
      }
    }

    var succeeded = 0;
    var failed = 0;
    final errors = <String>[];

    for (final convId in targetConversationIDs) {
      try {
        await _forwardAlbumToConversation(
          sourceItems: sourceItems,
          conversationID: convId,
        );
        succeeded++;
      } catch (e) {
        failed++;
        errors.add(e.toString());
        debugPrint('[ChatRepo] forward album vers $convId échoué: $e');
      }
    }

    return ForwardResult(succeeded: succeeded, failed: failed, errors: errors);
  }

  List<LocalMessage> _sortAlbumItems(List<LocalMessage> sourceItems) {
    final sorted = List<LocalMessage>.from(sourceItems)
      ..sort((a, b) {
        final ma = parseAlbumMarker(a.content);
        final mb = parseAlbumMarker(b.content);
        return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
      });
    return sorted;
  }

  Future<void> _forwardAlbumToConversation({
    required List<LocalMessage> sourceItems,
    required int conversationID,
  }) async {
    final sorted = _sortAlbumItems(sourceItems);

    if (sorted.length == 1) {
      await _forwardToConversation(source: sorted.first, conversationID: conversationID);
      return;
    }

    final freshAlbumId = newAlbumId();
    final total = sorted.length;
    final albumCaption = albumCaptionFromMessages(sorted);
    final counts = countAlbumMediaTypes(sorted);

    for (var i = 0; i < sorted.length; i++) {
      final source = sorted[i];
      final marker = reencodeAlbumMarkerForForward(
        newAlbumId: freshAlbumId,
        index: i,
        total: total,
        photoCount: counts.photos,
        videoCount: counts.videos,
        caption: albumCaption,
      );

      final url = source.mediaUrl;
      if (url != null && url.isNotEmpty) {
        await sendMedia(
          conversationID: conversationID,
          type: source.type,
          mediaUrl: url,
          mediaName: source.mediaName,
          mediaDuration: source.mediaDuration,
          mediaThumb: source.mediaThumb,
          localMediaPath: source.localMediaPath,
          content: marker,
          isForwarded: true,
        );
        continue;
      }

      final file = localMediaFileForForward(source);
      if (file == null) {
        throw StateError('Média indisponible pour le transfert');
      }

      await sendMediaFile(
        conversationID: conversationID,
        type: source.type,
        file: file,
        mediaName: source.mediaName,
        mediaDuration: source.mediaDuration,
        content: marker,
        isForwarded: true,
      );
    }
  }

  /// Transfère un message vers une ou plusieurs conversations.
  Future<ForwardResult> forwardMessage({
    required LocalMessage source,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    return forwardMessages(
      sources: [source],
      targetConversationIDs: targetConversationIDs,
      caption: caption,
    );
  }

  /// Transfère plusieurs messages vers une ou plusieurs conversations.
  Future<ForwardResult> forwardMessages({
    required List<LocalMessage> sources,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    if (_myId == 0) {
      return const ForwardResult(
        succeeded: 0,
        failed: 0,
        errors: ['Utilisateur non connecté'],
      );
    }
    if (sources.isEmpty || targetConversationIDs.isEmpty) {
      return const ForwardResult(succeeded: 0, failed: 0);
    }
    if (!sources.every(canForwardMessage)) {
      return const ForwardResult(
        succeeded: 0,
        failed: 1,
        errors: ['Un ou plusieurs messages ne peuvent pas être transférés'],
      );
    }

    if (sources.length >= 2 && isCompleteAlbumSelection(sources)) {
      return forwardAlbum(
        sourceItems: sources,
        targetConversationIDs: targetConversationIDs,
      );
    }

    if (canBatchForwardOnServer(sources)) {
      try {
        final sourceMsgIDs = _sortForwardSources(sources).map((m) => m.msgID).toList();
        await _api.batchForward(
          sourceMsgIDs: sourceMsgIDs,
          targetConversationIDs: targetConversationIDs,
          caption: caption,
        );
        return ForwardResult(
          succeeded: targetConversationIDs.length,
          failed: 0,
        );
      } catch (e) {
        debugPrint('[ChatRepo] batch forward échoué, fallback client: $e');
      }
    }

    var succeeded = 0;
    var failed = 0;
    final errors = <String>[];

    for (final convId in targetConversationIDs) {
      try {
        for (var i = 0; i < sources.length; i++) {
          final source = sources[i];
          await _forwardToConversation(
            source: source,
            conversationID: convId,
            caption: i == 0 ? caption : null,
          );
        }
        succeeded++;
      } catch (e) {
        failed++;
        errors.add(e.toString());
        debugPrint('[ChatRepo] forward vers $convId échoué: $e');
      }
    }

    return ForwardResult(succeeded: succeeded, failed: failed, errors: errors);
  }

  List<LocalMessage> _sortForwardSources(List<LocalMessage> sources) {
    final sorted = List<LocalMessage>.from(sources)
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
    return sorted;
  }

  Future<void> _forwardToConversation({
    required LocalMessage source,
    required int conversationID,
    String? caption,
  }) async {
    final effectiveCaption = resolveForwardCaption(source, caption);

    if (source.type == 0) {
      await sendText(
        conversationID: conversationID,
        content: source.content!.trim(),
        isForwarded: true,
      );
      return;
    }

    if (source.type == 5) {
      final loc = LocationPayload.tryParse(source.content);
      if (loc == null) {
        throw StateError('Position invalide pour le transfert');
      }
      await sendLocation(
        conversationID: conversationID,
        location: loc,
        isForwarded: true,
      );
      return;
    }

    if (source.type == 7) {
      final contact = ContactPayload.tryParse(source.content);
      if (contact == null) {
        throw StateError('Contact invalide pour le transfert');
      }
      await sendContact(
        conversationID: conversationID,
        contact: contact,
        isForwarded: true,
      );
      return;
    }

    final url = source.mediaUrl;
    if (url != null && url.isNotEmpty) {
      await sendMedia(
        conversationID: conversationID,
        type: source.type,
        mediaUrl: url,
        mediaName: source.mediaName,
        mediaDuration: source.mediaDuration,
        mediaThumb: source.mediaThumb,
        localMediaPath: source.localMediaPath,
        content: effectiveCaption,
        isForwarded: true,
      );
      return;
    }

    final file = localMediaFileForForward(source);
    if (file == null) {
      throw StateError('Média indisponible pour le transfert');
    }

    await sendMediaFile(
      conversationID: conversationID,
      type: source.type,
      file: file,
      mediaName: source.mediaName,
      mediaDuration: source.mediaDuration,
      content: effectiveCaption,
      isForwarded: true,
    );
  }

  /// Renvoie tous les messages en attente (appelé à la reconnexion socket).
  /// Gère AUSSI les uploads de fichier qui n'ont pas pu aboutir : si un
  /// message porte `pendingUploadPath` sans `mediaUrl`, on relance l'upload
  /// avant l'émission du message:send.
  Future<void> flushOutbox() => _outbox.flushOutbox();

  Future<void> editMessage(int msgID, String content) async {
    await _dao.updateContentByServerId(msgID, content);
    // Aperçu à jour si c'était le dernier message.
    final convID = await _conversationIdForMsg(msgID);
    if (convID != null) await _recomputeSummary(convID);
    try {
      await _api.editMessage(msgID, content);
    } catch (e) {
      debugPrint('[ChatRepo] editMessage échouée: $e');
    }
  }

  Future<int?> _conversationIdForMsg(int msgID) async {
    if (msgID == 0) return null;
    final row = await (_db.select(_db.localMessages)
          ..where((m) => m.msgID.equals(msgID))
          ..limit(1))
        .getSingleOrNull();
    return row?.conversationID;
  }

  /// Supprime un ou plusieurs messages (délègue au batch si nécessaire).
  /// [conversationID] sert à rafraîchir l'aperçu.
  /// Pour les optimistes (msgID=0), passer [clientIds] — jamais « tous les pending ».
  Future<void> deleteMessage(
    int msgID, {
    bool forAll = false,
    int? conversationID,
    String? clientId,
  }) async {
    await deleteMessages(
      msgID > 0 ? [msgID] : const [],
      forAll: forAll,
      conversationID: conversationID,
      clientIds: clientId != null && clientId.isNotEmpty ? [clientId] : null,
    );
  }

  Future<void> deleteMessages(
    List<int> msgIDs, {
    bool forAll = false,
    int? conversationID,
    List<String>? clientIds,
  }) async {
    // Collecte les conversationID affectées pour rafraîchir les aperçus.
    final affectedConvIDs = <int>{};
    if (conversationID != null) affectedConvIDs.add(conversationID);

    // 1. Messages confirmés (msgID > 0)
    final serverIds = msgIDs.where((id) => id > 0).toSet().toList();
    if (serverIds.isNotEmpty) {
      // Récupère les conversationID avant suppression.
      for (final id in serverIds) {
        final msg = await (_db.select(_db.localMessages)
              ..where((m) => m.msgID.equals(id))
              ..limit(1))
            .getSingleOrNull();
        if (msg != null) affectedConvIDs.add(msg.conversationID);
      }
      if (forAll) {
        await _dao.softDeleteManyByServerId(serverIds);
      } else {
        await _dao.softDeleteManyForUser(serverIds, _myId);
      }
      try {
        await _api.deleteMessages(serverIds, forAll: forAll);
      } catch (e) {
        debugPrint('[ChatRepo] deleteMessages échouée: $e');
      }
    }

    // 2. Messages en attente (msgID = 0) — ciblés par clientId uniquement.
    final pendingIds = (clientIds ?? const <String>[])
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    if (pendingIds.isNotEmpty) {
      for (final cid in pendingIds) {
        final row = await (_db.select(_db.localMessages)
              ..where((m) => m.clientId.equals(cid))
              ..limit(1))
            .getSingleOrNull();
        if (row != null) affectedConvIDs.add(row.conversationID);
      }
      await _dao.softDeletePendingByClientIds(
        pendingIds,
        _myId,
        forAll: forAll,
      );
    }

    // 3. Réaligner l'aperçu de chaque conversation sur son dernier message réel
    //    (et non forcer « supprimé » : si le message effacé n'était pas le
    //    dernier, l'aperçu doit rester le vrai dernier message).
    for (final convId in affectedConvIDs) {
      await _recomputeSummary(convId);
    }
  }

  Future<void> retryMessage(String clientId) => _outbox.retryMessage(clientId);

  Future<void> setConversationPinned(int conversID, bool pinned) async {
    await _dao.setPinned(conversID, pinned);
    try {
      await _api.updateConversation(conversID, isPinned: pinned);
    } catch (e) {
      await _dao.setPinned(conversID, !pinned);
      rethrow;
    }
  }

  Future<void> setConversationsPinned(List<int> conversIDs, bool pinned) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.setPinnedMany(ids, pinned);
    try {
      await _api.updateConversationsBatch(ids, isPinned: pinned);
    } catch (e) {
      debugPrint('[ChatRepo] setConversationsPinned échouée: $e');
      await syncConversations();
      rethrow;
    }
  }

  Future<void> setConversationArchived(int conversID, bool archived) async {
    await _dao.setArchived(conversID, archived);
    try {
      await _api.updateConversation(conversID, isArchived: archived);
    } catch (e) {
      await _dao.setArchived(conversID, !archived);
      rethrow;
    }
  }

  Future<void> setConversationsArchived(List<int> conversIDs, bool archived) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.setArchivedMany(ids, archived);
    try {
      await _api.updateConversationsBatch(ids, isArchived: archived);
    } catch (e) {
      debugPrint('[ChatRepo] setConversationsArchived échouée: $e');
      await syncConversations();
      rethrow;
    }
  }

  Future<void> deleteConversations(List<int> conversIDs) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.deleteConversations(ids);
    try {
      await _api.deleteConversations(ids);
    } catch (e) {
      debugPrint('[ChatRepo] deleteConversations échouée: $e');
      await syncConversations();
      rethrow;
    }
  }

  Future<void> markAsRead(int conversationID) =>
      _receipts.markAsRead(conversationID);

  /// Re-sync de la conversation actuellement à l'écran après reconnexion.
  /// Évite à l'utilisateur de quitter/rouvrir la conv pour voir les messages
  /// reçus pendant la coupure. Ne marque lu que si l'app est au premier plan.
  Future<void> resyncActiveConversation() async {
    if (_activeConversationID == 0) return;
    if (_myId == 0) return;
    final convID = _activeConversationID;
    await syncMessages(convID, delta: true);
    if (!_appInForeground) return;
    await _dao.markConversationRead(convID, _myId);
    await _recomputeSummary(convID);
    try {
      _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
    } catch (_) {
      _pendingReadsRetry[convID] = (_pendingReadsRetry[convID] ?? 0);
    }
  }

  /// Ré-émet `joinConversation` pour la conv active après reconnexion (les
  /// rooms socket.io sont volatiles, le serveur ne les restaure pas).
  void rejoinActiveRoom() {
    if (_activeConversationID == 0) return;
    if (!_api.isSocketReady) return;
    _api.sendSocketEvent(
      SocketEvents.joinConversation,
      {'conversationID': _activeConversationID},
    );
  }

  Future<void> flushReceiptsCatchUp() => _receipts.flushReceiptsCatchUp();


  /// Upsert un message serveur et renvoie `true` s'il était nouveau en local.
  Future<bool> _upsertServerMsg(
    Map<String, dynamic> json, {
    bool prefetchMedia = false,
  }) async {
    final msgID = _toInt(json['msgID']);
    final convID = _toInt(json['conversationID']);
    if (msgID == 0) {
      await _dao.upsertMessage(_msgJsonToCompanion(json));
      return true;
    }

    final srvKey = 'srv_$msgID';
    final clientId = _clientIdFromJson(json);
    final content = json['content']?.toString();
    final mediaName = json['mediaName']?.toString();
    final serverAt = _parseDate(json['sendAt']);
    bool wasNew = false;
    await _db.transaction(() async {
      String? carriedLocalPath;
      DateTime? carriedClickSentAt;

      // Création d'un prédicat optimiste plus strict pour éviter d'associer
      // par erreur un message d'un autre utilisateur ayant le même contenu.
      var candidates = await (_db.select(_db.localMessages)
            ..where((m) {
              // Ligne déjà confirmée avec le même msgID mais clé différente
              final sameOtherKey =
                  m.msgID.equals(msgID) & m.clientId.equals(srvKey).not();

              // Base optimiste : même conversation et msgID==0
              final optimisticBase =
                  m.conversationID.equals(convID) & m.msgID.equals(0);

              // Match prioritaire par clientId si fourni par le serveur
              Expression<bool> optimistic = const Constant(false);
              if (clientId != null && clientId.isNotEmpty) {
                optimistic = optimisticBase & m.clientId.equals(clientId);
              } else if (content != null && content.isNotEmpty) {
                // Pour matcher sur le contenu, restreindre au messages dont
                // l'émetteur local est bien l'utilisateur courant (évite collisions)
                optimistic = optimisticBase &
                    m.content.equals(content) &
                    m.senderID.equals(_myId);
              } else if (mediaName != null && mediaName.isNotEmpty) {
                optimistic = optimisticBase &
                    m.mediaName.equals(mediaName) &
                    m.senderID.equals(_myId);
              }

              return sameOtherKey | optimistic;
            }))
          .get();

      // Fallback contenu/mediaName : ne garder qu'1 candidat récent (±5 s),
      // jamais supprimer plusieurs optimistes pour un seul ack serveur.
      if ((clientId == null || clientId.isEmpty) && candidates.isNotEmpty) {
        final confirmed = candidates.where((m) => m.msgID == msgID).toList();
        final optimistics = candidates.where((m) => m.msgID == 0).toList();
        if (optimistics.length > 1) {
          optimistics.sort((a, b) => b.sendAt.compareTo(a.sendAt));
          LocalMessage? best;
          if (serverAt != null) {
            for (final o in optimistics) {
              final delta = o.sendAt.difference(serverAt).abs();
              if (delta <= const Duration(seconds: 5)) {
                best = o;
                break;
              }
            }
          }
          best ??= optimistics.first;
          candidates = [...confirmed, best];
        }
      }

      // Nouveau message local si aucun candidat avec ce msgID confirmé
      wasNew = candidates.every((m) => m.msgID != msgID);

      String? carriedMediaThumb;
      for (final m in candidates) {
        carriedLocalPath ??= m.localMediaPath;
        carriedClickSentAt ??= m.clickSentAt;
        carriedMediaThumb ??= m.mediaThumb;
        await (_db.delete(_db.localMessages)
              ..where((x) => x.clientId.equals(m.clientId)))
            .go();
      }

      // Insère une seule ligne normalisée `srv_<msgID>` (clé primaire stable).
      var companion =
          _msgJsonToCompanion(json).copyWith(clientId: Value(srvKey));
      if (carriedLocalPath != null) {
        companion = companion.copyWith(localMediaPath: Value(carriedLocalPath));
      }
      if (carriedClickSentAt != null) {
        companion = companion.copyWith(clickSentAt: Value(carriedClickSentAt));
      }
      // Préserve la vignette locale si le serveur (non migré) ne l'a pas renvoyée.
      if (carriedMediaThumb != null && !companion.mediaThumb.present) {
        companion = companion.copyWith(mediaThumb: Value(carriedMediaThumb));
      }

      debugPrint(
          '[ChatRepo] _upsertServerMsg msgID=$msgID conv=$convID candidates=${candidates.length} wasNew=$wasNew');
      await _dao.upsertMessage(companion);
    });

    // Préfetch médias reçus si auto-download activé (images, vidéos, fichiers < 5 Mo).
    // Les vues uniques ne sont jamais mises en cache. Les vocaux restent manuels.
    final isViewOnce = json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    final senderID = _toInt(json['senderID']);
    final isMine = senderID != 0 && senderID == _myId;
    if (prefetchMedia &&
        wasNew &&
        !isViewOnce &&
        !isMine &&
        MediaDownloadPreferences.isAutoDownloadEnabled) {
      final mtype = _toInt(json['type']);
      final mediaUrl = json['mediaUrl']?.toString();
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        final mediaName = json['mediaName']?.toString();
        if (mtype == 1 || mtype == 2) {
          _cacheMedia(
            msgID,
            mediaUrl,
            type: mtype,
            isMine: false,
            isViewOnce: false,
            mediaName: mediaName,
          );
        } else if (mtype == 4) {
          _cacheMedia(
            msgID,
            mediaUrl,
            maxBytes: 5 * 1024 * 1024,
            type: 4,
            isMine: false,
            isViewOnce: false,
            mediaName: mediaName,
          );
        }
      }
    }
    return wasNew;
  }

  /// Télécharge un média reçu vers le cache app, met à jour [localMediaPath],
  /// puis exporte vers l'album/dossier Alanya (sauf vue unique / message mien).
  Future<String?> ensureReceivedMediaLocal({
    required int msgID,
    required String mediaUrl,
    required int type,
    required bool isMine,
    required bool isViewOnce,
    String? mediaName,
    String? existingLocalPath,
    int? maxBytes,
    void Function(double? progress)? onProgress,
  }) async {
    if (isViewOnce) return null;

    String? path = (existingLocalPath != null &&
            File(existingLocalPath).existsSync())
        ? existingLocalPath
        : null;

    if (path == null) {
      if (mediaUrl.isEmpty) return null;
      if (onProgress != null) {
        path = await _mediaCache.downloadWithProgress(
          mediaUrl,
          onProgress: onProgress,
          maxBytes: maxBytes,
        );
      } else {
        path = await _mediaCache.ensureCached(mediaUrl, maxBytes: maxBytes);
      }
      if (path == null) return null;
      if (msgID != 0) {
        await _dao.setLocalMediaPath(msgID, path);
      }
    }

    await AlanyaMediaExportService.instance.exportIfNeeded(
      msgID: msgID,
      type: type,
      localPath: path,
      isViewOnce: isViewOnce,
      isMine: isMine,
      mediaName: mediaName,
    );
    return path;
  }

  Future<void> _cacheMedia(
    int msgID,
    String url, {
    int? maxBytes,
    required int type,
    required bool isMine,
    required bool isViewOnce,
    String? mediaName,
  }) async {
    if (!MediaDownloadPreferences.isAutoDownloadEnabled) return;
    await ensureReceivedMediaLocal(
      msgID: msgID,
      mediaUrl: url,
      type: type,
      isMine: isMine,
      isViewOnce: isViewOnce,
      mediaName: mediaName,
      maxBytes: maxBytes,
    );
  }

  /// Lie un fichier déjà présent dans le cache disque au message (legacy auto-cache).
  Future<String?> adoptCachedVoicePath({
    required int msgID,
    required String mediaUrl,
  }) async {
    final resolved = await VoiceAssetResolver(
      mediaCache: _mediaCache,
      dao: _dao,
    ).resolve(
      serverMsgId: msgID,
      isMe: false,
      mediaUrl: mediaUrl,
    );
    return resolved?.path;
  }

  /// Réconcilie les chemins locaux des messages vocaux d'une conversation.
  Future<void> reconcileVoiceLocalPaths(int conversationId) async {
    final messages = await _dao.getVoiceMessages(conversationId);
    final resolver = VoiceAssetResolver(mediaCache: _mediaCache, dao: _dao);
    for (final m in messages) {
      if (m.msgID == 0) continue;
      final isMe = m.senderID == _myId;
      await resolver.resolve(
        serverMsgId: m.msgID,
        isMe: isMe,
        dbPath: m.localMediaPath,
        pendingPath: isMe ? m.pendingUploadPath : null,
        mediaUrl: m.mediaUrl,
      );
    }
  }

  /// Téléchargement manuel d'un message vocal reçu, avec progression.
  Future<String?> downloadVoiceMessage({
    required int msgID,
    required String mediaUrl,
    void Function(double? progress)? onProgress,
  }) async {
    if (msgID == 0) return null;
    final path = await _mediaCache.downloadWithProgress(
      mediaUrl,
      onProgress: onProgress,
      maxBytes: 15 * 1024 * 1024,
    );
    if (path != null) await _dao.setLocalMediaPath(msgID, path);
    return path;
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


  /// Signale au serveur qu'un média à vue unique a été consulté, puis marque
  /// le message consommé localement (efface toute trace ré-ouvrable).
  Future<void> markViewed(int msgID) async {
    if (msgID == 0) return;
    await _dao.markViewedByServerId(msgID);
    try {
      await _api.markViewed(msgID);
    } catch (e) {
      debugPrint('[ChatRepo] markViewed échouée: $e');
    }
  }


  Future<void> _recomputeSummary(int conversID) {
    return _reducer.recompute(conversID, _myId);
  }

  LocalConversationsCompanion _convToCompanion(Conversation c, Map<String, dynamic> raw) {
    return LocalConversationsCompanion(
      conversID: Value(c.conversID),
      isGroup: Value(c.isGroup),
      groupName: Value(c.groupName),
      groupPhoto: Value(c.groupPhoto),
      lastMessage: Value(
        c.lastMessage == null
            ? null
            : normalizeConversationPreview(c.lastMessage),
      ),
      lastMessageAt: Value(_parseDate(c.lastMessageAt)),
      lastMessageSenderID: Value(c.lastMessageSenderID),
      lastMessageType: Value(c.lastMessageType),
      lastMessageStatus: c.lastMessageStatus != null
          ? Value(c.lastMessageStatus)
          : const Value.absent(),
      unreadCount: Value(c.unreadCount),
      isPinned: Value(c.isPinned),
      isArchived: Value(c.isArchived),
      participantsJson: Value(encodeParticipants(raw['participants'] as List? ?? [])),
    );
  }

  LocalMessagesCompanion _msgJsonToCompanion(Map<String, dynamic> j) {
    final rawClient = _clientIdFromJson(j);
    final clientId = (rawClient != null && rawClient.isNotEmpty)
        ? rawClient
        : 'srv_${_toInt(j['msgID'])}';
    return LocalMessagesCompanion(
      clientId: Value(clientId),
      msgID: Value(_toInt(j['msgID'])),
      conversationID: Value(_toInt(j['conversationID'])),
      senderID: Value(_toInt(j['senderID'])),
      content: Value(j['content']?.toString()),
      type: Value(_toInt(j['type'])),
      status: Value(_toInt(j['status'], fallback: 1)),
      sendAt: Value(_parseDate(j['sendAt']) ?? DateTime.now()),
      // clickSentAt est désormais synchronisé avec le serveur (persisté à
      // l'envoi) : on l'hydrate depuis le JSON pour que le destinataire le
      // voie aussi. `_upsertServerMsg` conserve en priorité la valeur locale
      // déjà connue le cas échéant (même valeur, capturée avant l'aller-retour).
      clickSentAt: Value(_parseDate(j['clickSentAt'])),
      messageTz: Value(j['messageTz']?.toString()),
      messageTzOffset: Value(j['messageTzOffset'] == null ? null : _toInt(j['messageTzOffset'])),
      deliveredAt: Value(_parseDate(j['deliveredAt'])),
      readAt: Value(_parseDate(j['readAt'])),
      mediaUrl: Value(normalizeBackendUrl(j['mediaUrl']?.toString())),
      mediaName: Value(j['mediaName']?.toString()),
      mediaDuration: Value(j['mediaDuration'] == null ? null : _toInt(j['mediaDuration'])),
      // Vignette base64 : on ne l'écrase que si le serveur en fournit une
      // (backend non migré ⇒ champ absent ⇒ on préserve la valeur locale).
      mediaThumb: j['mediaThumb'] == null
          ? const Value.absent()
          : Value(j['mediaThumb'].toString()),
      replyToID: j['replyToID'] == null
          ? const Value.absent()
          : Value(_toInt(j['replyToID'])),
      // Préserve la citation locale si le serveur renvoie null (ID non résolu).
      replyToContent: (j['replyToContent'] == null ||
              j['replyToContent'].toString().trim().isEmpty)
          ? const Value.absent()
          : Value(j['replyToContent'].toString()),
      isEdited: Value(j['isEdited'] == 1 || j['isEdited'] == true),
      editedAt: Value(_parseDate(j['editedAt'])),
      // Ces champs ne doivent JAMAIS être écrasés par le sync serveur.
      // isDeleted est set par softDeleteMany* (action locale) ou via socket.
      // deletedForID est purement local (suppression « pour moi »).
      isDeleted: const Value.absent(),
      deletedForID: const Value.absent(),
      isStatusReply: Value(_toInt(j['isStatusReply'])),
      isForwarded: Value(j['isForwarded'] == 1 || j['isForwarded'] == true),
      isPinned: Value(j['isPinned'] == 1 || j['isPinned'] == true),
      isViewOnce: Value(j['isViewOnce'] == 1 || j['isViewOnce'] == true),
      // On ne pose viewedAt QUE si le serveur confirme la vue. Sinon on laisse
      // la colonne intacte (Value.absent) : un média déjà ouvert localement le
      // reste, même si une resync arrive avant que le serveur ait persisté /view.
      viewedAt: (j['isViewOnce'] == 1 || j['isViewOnce'] == true) && _toInt(j['viewedByMe']) > 0
          ? Value(DateTime.now())
          : const Value.absent(),
      senderNom: Value(j['sender_nom']?.toString()),
      senderPseudo: Value(j['sender_pseudo']?.toString()),
      senderAvatar: Value(normalizeBackendUrl(j['sender_avatar']?.toString())),
      syncPending: const Value(false),
      lastEmittedAt: const Value(null),
    );
  }


  static String? _clientIdFromJson(Map<String, dynamic> j) {
    final v = j['clientId'] ?? j['clientID'];
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return s;
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

