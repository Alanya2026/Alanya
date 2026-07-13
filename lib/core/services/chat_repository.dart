import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../db/chat_dao.dart';
import '../utils/forward_message.dart';
import '../utils/backend_url.dart';
import '../utils/media_album.dart';
import '../utils/media_staging.dart';
import '../utils/upload_errors.dart';
import 'local_notification_helper.dart';
import 'media_cache_service.dart';
import 'video_thumbnail_service.dart';
import 'voice_asset_resolver.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';  
class ChatRepository {
  static const _deletedPreview = 'Ce message a été supprimé';

  final AppDatabase _db;
  final ChatDao _dao;
  final TalkyApiClient _api;
  final MediaCacheService _mediaCache = MediaCacheService();

  /// Progression d'upload éphémère par [clientId] (0.0–1.0).
  final ValueNotifier<Map<String, double>> uploadProgress =
      ValueNotifier<Map<String, double>>({});

  /// Uploads en cours par [clientId] — évite les uploads parallèles du même message.
  final Set<String> _inFlightUploads = {};

  int _myId = 0;
  bool _listenersBound = false;

  /// Conversation actuellement ouverte à l'écran (0 = aucune). Un message reçu
  /// pour cette conversation est marqué lu immédiatement et n'incrémente pas
  /// l'unread (l'utilisateur le voit en direct).
  int _activeConversationID = 0;

  /// Lectures à confirmer au serveur dès la reconnexion (lecture hors-ligne).
  final Set<int> _pendingReads = {};
  /// Retry tracker pour les lectures hors-ligne (conversationID -> retryCount)
  final Map<int, int> _pendingReadsRetry = {};

  void setActiveConversation(int conversationID) {
    _activeConversationID = conversationID;
    LocalNotificationHelper.setActiveConversationId(conversationID);
  }

  void clearActiveConversation(int conversationID) {
    if (_activeConversationID == conversationID) {
      _activeConversationID = 0;
      LocalNotificationHelper.setActiveConversationId(null);
    }
  }

  /// Synchronise la suppression push avec le cycle de vie de l'app.
  /// En arrière-plan, on ne bloque plus les notifs même si le chat est encore
  /// sur la pile de navigation.
  void syncPushSuppressionForLifecycle(bool appInForeground) {
    if (!appInForeground || _activeConversationID == 0) {
      LocalNotificationHelper.setActiveConversationId(null);
    } else {
      LocalNotificationHelper.setActiveConversationId(_activeConversationID);
    }
  }

  ChatRepository._(this._api, this._db) : _dao = ChatDao(_db);

  MediaCacheService get mediaCache => _mediaCache; 
  factory ChatRepository({required TalkyApiClient api, AppDatabase? database}) {
    return ChatRepository._(api, database ?? AppDatabase());
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
      await resyncActiveConversation();
      await _flushPendingReads();
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

    _api.onSocketEvent(SocketEvents.messageReceived, _onMessageReceived);
    _api.onSocketEvent(SocketEvents.messageSent, _onMessageSent);
    _api.onSocketEvent(SocketEvents.messageUpdated, _onMessageUpdated);
    _api.onSocketEvent(SocketEvents.messageDeleted, _onMessageDeleted);
    _api.onSocketEvent(SocketEvents.messagesDeleted, _onMessagesDeleted);
    _api.onSocketEvent(SocketEvents.messagePinned, _onMessagePinned);
    _api.onSocketEvent(SocketEvents.messageViewed, _onMessageViewed);
    _api.onSocketEvent(SocketEvents.messageStatus, _onMessageStatus);
    _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationCreated);
    _api.onSocketEvent(SocketEvents.authVerified, _onAuthVerified);
  }

  /// Détache les listeners socket et autorise un futur `bind` (cas logout/login
  /// dans la même session d'app). `disconnectSocket` aurait déjà vidé le
  /// registre côté API client, mais on remet le drapeau à zéro pour que la
  /// prochaine connexion repasse par l'enregistrement complet.
  void unbind() {
    if (!_listenersBound) return;
    _listenersBound = false;
    _api.removeSocketListener(SocketEvents.messageReceived, _onMessageReceived);
    _api.removeSocketListener(SocketEvents.messageSent, _onMessageSent);
    _api.removeSocketListener(SocketEvents.messageUpdated, _onMessageUpdated);
    _api.removeSocketListener(SocketEvents.messageDeleted, _onMessageDeleted);
    _api.removeSocketListener(SocketEvents.messagesDeleted, _onMessagesDeleted);
    _api.removeSocketListener(SocketEvents.messagePinned, _onMessagePinned);
    _api.removeSocketListener(SocketEvents.messageViewed, _onMessageViewed);
    _api.removeSocketListener(SocketEvents.messageStatus, _onMessageStatus);
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
 
  Future<void> syncConversations() async {
    try {
      final raw = await _api.getConversations();
      final localById = {
        for (final c in await _dao.getAllConversations()) c.conversID: c,
      };
      final companions = raw
          .whereType<Map<String, dynamic>>()
          .map((j) {
            final conv = Conversation.fromJson(j);
            var companion = _convToCompanion(conv, j);
            if (_myId != 0 &&
                conv.lastMessageSenderID == _myId &&
                localById[conv.conversID]?.lastMessageSenderID == _myId) {
              final serverStatus = conv.lastMessageStatus ?? 0;
              final localStatus =
                  localById[conv.conversID]?.lastMessageStatus ?? 0;
              final merged = serverStatus > localStatus ? serverStatus : localStatus;
              if (merged > serverStatus) {
                companion = companion.copyWith(
                  lastMessageStatus: Value(merged),
                );
              }
            }
            // Préserve l'aperçu « Ce message a été supprimé » si déjà en local
            // pour ne pas écraser la suppression par l'ancien aperçu du serveur.
            final localLast = localById[conv.conversID]?.lastMessage;
            if (localLast == _deletedPreview &&
                companion.lastMessage.present &&
                companion.lastMessage.value != _deletedPreview) {
              companion = companion.copyWith(
                lastMessage: const Value(_deletedPreview),
              );
            }
            return companion;
          })
          .toList();
      final serverIds = companions.map((c) => c.conversID.value).toSet();
      await _dao.upsertConversations(companions);
      await _dao.deleteConversationsNotIn(serverIds);
      await _dao.reconcileAllLastMessageStatuses(_myId);
    } catch (e) {
      debugPrint('[ChatRepo] syncConversations échouée: $e');
    }
  }

  /// Charge l'historique d'une conversation.
  /// Si `delta == true`, ne récupère que les messages plus récents que le
  /// dernier confirmé en local (curseur `after` côté API).
  Future<void> syncMessages(int conversationID, {bool delta = false}) async {
    try {
      List<dynamic> raw;
      if (delta) {
        final last = await _dao.maxServerMsgId(conversationID);
        raw = await _api.getMessages(conversationID, limit: 50, after: last > 0 ? last : null);
      } else {
        raw = await _api.getMessages(conversationID, limit: 50);
      }
      for (final j in raw.whereType<Map<String, dynamic>>()) {
        await _upsertServerMsg(j, prefetchMedia: true);
      }
      await _dao.reconcileLastMessageStatus(conversationID, _myId);
    } catch (e) {
      debugPrint('[ChatRepo] syncMessages($conversationID) échouée: $e');
    }
  }

  /// Charge une page d'anciens messages
  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) async {
    try {
      final oldest = await _dao.minServerMsgId(conversationID);
      if (oldest == 0) return 0;
      final raw = await _api.getMessages(conversationID, limit: limit, before: oldest);
      final list = raw.whereType<Map<String, dynamic>>().toList();
      for (final j in list) {
        await _upsertServerMsg(j, prefetchMedia: true);
      }
      return list.length;
    } catch (e) {
      debugPrint('[ChatRepo] loadOlderMessages échouée: $e');
      return 0;
    }
  }

  Future<void> sendText({
    required int conversationID,
    required String content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
  }) async {
    if (_myId == 0) {
      debugPrint('[ChatRepo] sendText ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId,
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: const Value(0),
      status: const Value(0),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isStatusReply: Value(isStatusReply),
      isForwarded: Value(isForwarded),
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(conversationID, content, 0, now,
        senderID: _myId, status: 0);

    _emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: 0,
      replyToID: replyToID,
      replyToContent: replyToContent,
      isStatusReply: isStatusReply,
      isForwarded: isForwarded,
    );
  }

  /// Aperçu canonique pour les messages média : on respecte le `content` saisi
  /// s'il existe, sinon on retombe sur l'emoji + libellé de type. Évite que
  /// l'aperçu de conv affiche un nom de fichier brut (`IMG_2026.jpg`).
  ///
  /// Pour une vue unique, la légende reste réservée à la visionneuse.
  static String _previewForMedia(
    int type,
    String? content,
    String? mediaName, {
    bool isViewOnce = false,
  }) {
    if (!isViewOnce) {
      // Album : toujours le décompte photos/vidéos, jamais la légende.
      final marker = parseAlbumMarker(content);
      if (marker != null) return previewLabelForAlbumMarker(marker);
      if (content != null && content.trim().isNotEmpty) return content;
    }
    switch (type) {
      case 1:
        return isViewOnce ? '📷 Photo · Vue unique' : '📷 Photo';
      case 2:
        return isViewOnce ? '🎥 Vidéo · Vue unique' : '🎥 Vidéo';
      case 3:
        return isViewOnce ? '🎵 Audio · Vue unique' : '🎵 Audio';
      case 4:
        return mediaName?.isNotEmpty == true ? '📎 $mediaName' : '📎 Fichier';
      default:
        return mediaName ?? 'Média';
    }
  }


  Future<void> sendMedia({
    required int conversationID,
    required int type, // 1=image 2=vidéo 3=audio 4=fichier
    required String mediaUrl,
    String? mediaName,
    int? mediaDuration,
    String? mediaThumb,
    String? localMediaPath,
    String? content,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) async {
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();

    // Vidéo : réutilise la vignette fournie (transfert) sinon la génère depuis
    // le fichier local si disponible.
    mediaThumb ??= type == 2 && localMediaPath != null
        ? await VideoThumbnailService.base64ForFile(localMediaPath)
        : null;

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId,
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaUrl: Value(mediaUrl),
      mediaName: Value(mediaName),
      mediaDuration: Value(mediaDuration),
      mediaThumb: Value(mediaThumb),
      localMediaPath: Value(localMediaPath),
      isForwarded: Value(isForwarded),
      isViewOnce: Value(isViewOnce),
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(
        conversationID,
        _previewForMedia(type, content, mediaName, isViewOnce: isViewOnce),
        type,
        now,
        senderID: _myId,
        status: 0);

    _emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaDuration: mediaDuration,
      mediaThumb: mediaThumb,
      isForwarded: isForwarded,
      isViewOnce: isViewOnce,
    );
  }

  Future<void> sendMediaFile({
    required int conversationID,
    required int type, // 1=image 2=vidéo 3=audio 4=fichier
    required File file,
    String? mediaName,
    int? mediaDuration,
    String? content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) async {
    if (_myId == 0) {
      debugPrint('[ChatRepo] sendMediaFile ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();
    File uploadFile;
    try {
      uploadFile = file.path.contains('talky_outbox')
          ? file
          : await stageMediaFile(file);
    } catch (e) {
      debugPrint('[ChatRepo] sendMediaFile staging échoué: $e');
      return;
    }
    final name = mediaName ?? uploadFile.path.split('/').last;

    // Vidéo : génère une mini-vignette base64 transmise au destinataire (aperçu
    // instantané et hors ligne, sans télécharger la vidéo).
    final mediaThumb =
        type == 2 ? await VideoThumbnailService.base64ForFile(uploadFile.path) : null;

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId,
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaName: Value(name),
      mediaDuration: Value(mediaDuration),
      mediaThumb: Value(mediaThumb),
      localMediaPath: Value(uploadFile.path),
      pendingUploadPath: Value(uploadFile.path),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isStatusReply: Value(isStatusReply),
      isForwarded: Value(isForwarded),
      isViewOnce: Value(isViewOnce),
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(
        conversationID,
        _previewForMedia(type, content, name, isViewOnce: isViewOnce),
        type,
        now,
        senderID: _myId,
        status: 0);

    try {
      await _uploadAndEmit(
        clientId: clientId,
        conversationID: conversationID,
        file: uploadFile,
        type: type,
        content: content,
        mediaName: name,
        mediaDuration: mediaDuration,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
      );
    } catch (e) {
      await _handleUploadFailure(clientId, e, 'upload média échoué');
    }
  }

  /// Élément d'un album multi-médias (photo ou vidéo).
  static const int maxAlbumItems = 30;

  /// Envoie plusieurs photos/vidéos regroupées en album (marqueur dans `content`).
  ///
  /// [content] est la légende optionnelle (stockée sur le premier item).
  Future<void> sendMediaAlbum({
    required int conversationID,
    required List<AlbumSendItem> items,
    String? content,
    bool isForwarded = false,
  }) async {
    if (_myId == 0) {
      debugPrint('[ChatRepo] sendMediaAlbum ignoré : utilisateur non lié (myId=0)');
      return;
    }
    if (items.isEmpty) return;
    final caption = content?.trim();
    final effectiveCaption =
        caption != null && caption.isNotEmpty ? caption : null;
    if (items.length == 1) {
      final item = items.first;
      await sendMediaFile(
        conversationID: conversationID,
        type: item.type,
        file: item.file,
        mediaName: item.mediaName,
        mediaDuration: item.duration,
        content: effectiveCaption,
        isForwarded: isForwarded,
      );
      return;
    }

    final albumId = newAlbumId();
    final total = items.length;
    final now = DateTime.now().toUtc();
    final types = items.map((e) => e.type).toList();
    final preview = previewLabelForAlbumTypes(types);
    final counts = countAlbumMediaTypesFromTypes(types);

    final pending = <_PendingAlbumUpload>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final clientId = _newClientId();
      final name = item.mediaName ?? item.file.path.split('/').last;
      final marker = encodeAlbumMarker(
        albumId: albumId,
        index: i,
        total: total,
        photoCount: counts.photos,
        videoCount: counts.videos,
        caption: effectiveCaption,
      );

      final mediaThumb = item.type == 2
          ? await VideoThumbnailService.base64ForFile(item.file.path)
          : null;

      await _dao.upsertMessage(LocalMessagesCompanion.insert(
        clientId: clientId,
        conversationID: conversationID,
        senderID: _myId,
        sendAt: now,
        clickSentAt: Value(now),
        content: Value(marker),
        type: Value(item.type),
        status: const Value(0),
        mediaName: Value(name),
        mediaDuration: Value(item.duration),
        mediaThumb: Value(mediaThumb),
        localMediaPath: Value(item.file.path),
        pendingUploadPath: Value(item.file.path),
        isForwarded: Value(isForwarded),
        syncPending: const Value(true),
      ));

      pending.add(_PendingAlbumUpload(
        clientId: clientId,
        file: item.file,
        type: item.type,
        content: marker,
        mediaName: name,
        mediaDuration: item.duration,
        isForwarded: isForwarded,
      ));
    }

    _bumpConversationSummary(
      conversationID,
      preview,
      items.last.type,
      now,
      senderID: _myId,
      status: 0,
    );

    await _runConcurrent(pending, 3, (p) async {
      try {
        await _uploadAndEmit(
          clientId: p.clientId,
          conversationID: conversationID,
          file: p.file,
          type: p.type,
          content: p.content,
          mediaName: p.mediaName,
          mediaDuration: p.mediaDuration,
          isForwarded: p.isForwarded,
        );
      } catch (e) {
        await _handleUploadFailure(p.clientId, e, 'upload album item échoué');
      }
    });
  }

  void _setUploadProgress(String clientId, double? progress) {
    final next = Map<String, double>.from(uploadProgress.value);
    if (progress == null) {
      next.remove(clientId);
    } else {
      next[clientId] = progress.clamp(0.0, 1.0);
    }
    uploadProgress.value = next;
  }


  Future<File?> _resolvePendingUploadFile(LocalMessage m) async {
    final pending = m.pendingUploadPath;
    if (pending != null && pending.isNotEmpty) {
      final f = File(pending);
      if (f.existsSync()) return f;
    }
    final local = m.localMediaPath;
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (f.existsSync()) {
        try {
          return await stageMediaFile(f);
        } catch (e) {
          debugPrint('[ChatRepo] re-stage échoué: $e');
        }
      }
    }
    return null;
  }

  Future<void> _uploadAndEmit({
    required String clientId,
    required int conversationID,
    required File file,
    required int type,
    String? content,
    String? mediaName,
    int? mediaDuration,
    bool isForwarded = false,
    bool isViewOnce = false,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
  }) async {
    if (!_inFlightUploads.add(clientId)) {
      debugPrint('[ChatRepo] upload déjà en cours pour $clientId');
      return;
    }
    try {
      var attempt429 = 0;
      while (true) {
        try {
          final res = await _api.uploadMedia(
            file,
            onProgress: (p) => _setUploadProgress(clientId, p),
          );
          _setUploadProgress(clientId, null);
          final url = res['url'] as String?;
          if (url == null) throw Exception('upload sans url');

          await (_db.update(_db.localMessages)..where((m) => m.clientId.equals(clientId)))
              .write(LocalMessagesCompanion(
            mediaUrl: Value(url),
            pendingUploadPath: const Value(null),
          ));

          // Vignette base64 déjà générée et stockée à l'insertion (vidéos) :
          // on la relit pour la transmettre au destinataire.
          final row = await (_db.select(_db.localMessages)
                ..where((m) => m.clientId.equals(clientId)))
              .getSingleOrNull();

          _emitSend(
            clientId: clientId,
            conversationID: conversationID,
            content: content,
            type: type,
            mediaUrl: url,
            mediaName: mediaName,
            mediaDuration: mediaDuration,
            mediaThumb: row?.mediaThumb,
            replyToID: replyToID,
            replyToContent: replyToContent,
            isStatusReply: isStatusReply,
            isForwarded: isForwarded,
            isViewOnce: isViewOnce,
          );
          return;
        } catch (e) {
          _setUploadProgress(clientId, null);
          if (e is TalkyException && e.statusCode == 429 && attempt429 < 2) {
            attempt429++;
            await Future.delayed(Duration(seconds: attempt429 == 1 ? 2 : 5));
            continue;
          }
          rethrow;
        }
      }
    } finally {
      _inFlightUploads.remove(clientId);
    }
  }

  void _emitPendingMessage(LocalMessage m) {
    _emitSend(
      clientId: m.clientId,
      conversationID: m.conversationID,
      content: m.content,
      type: m.type,
      mediaUrl: m.mediaUrl,
      mediaName: m.mediaName,
      mediaDuration: m.mediaDuration,
      mediaThumb: m.mediaThumb,
      replyToID: m.replyToID,
      replyToContent: m.replyToContent,
      isStatusReply: m.isStatusReply,
      isForwarded: m.isForwarded,
      isViewOnce: m.isViewOnce,
    );
  }

  Future<void> _handleUploadFailure(
    String clientId,
    Object e,
    String logLabel,
  ) async {
    debugPrint('[ChatRepo] $logLabel: $e');
    if (isTransientUploadError(e)) {
      debugPrint('[ChatRepo] upload différé — pending intact pour rejeu');
    } else {
      await _dao.markFailed(clientId);
    }
  }

  Future<void> _runConcurrent<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) fn,
  ) async {
    if (items.isEmpty) return;
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index;
        if (i >= items.length) return;
        index++;
        await fn(items[i]);
      }
    }
    final workers = concurrency.clamp(1, items.length);
    await Future.wait(List.generate(workers, (_) => worker()));
  }

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
  Future<void> flushOutbox() async {
    final pending = await _dao.pendingMessages();
    for (final m in pending) {
      final needsUpload = m.pendingUploadPath != null &&
          m.pendingUploadPath!.isNotEmpty &&
          (m.mediaUrl == null || m.mediaUrl!.isEmpty);

      if (needsUpload) {
        final file = await _resolvePendingUploadFile(m);
        if (file == null) {
          debugPrint('[ChatRepo] flush: fichier disparu pour ${m.clientId} → failed');
          await _dao.markFailed(m.clientId);
          continue;
        }
        try {
          await _uploadAndEmit(
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
          );
        } catch (e) {
          await _handleUploadFailure(m.clientId, e, 'flush upload échoué pour ${m.clientId}');
        }
      } else {
        // Média déjà uploadé (mediaUrl présent) ou message texte : réémettre
        // message:send. Sans cette branche, un upload HTTP réussi suivi d'un
        // emit socket ignoré (socket non prêt) reste bloqué indéfiniment.
        _emitPendingMessage(m);
      }
    }
    // Rejoue les accusés de lecture émis hors-ligne.
    if (_api.isSocketReady && _pendingReads.isNotEmpty) {
      for (final convID in _pendingReads.toList()) {
        _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
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
        final file = await _resolvePendingUploadFile(m);
        if (file == null) {
          debugPrint('[ChatRepo] retry: fichier disparu pour ${m.clientId} → keep failed');
          continue;
        }
        try {
          await _uploadAndEmit(
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
          );
        } catch (e) {
          await _handleUploadFailure(m.clientId, e, 'retry upload échoué pour ${m.clientId}');
        }
      } else {
        // Message texte ou média déjà uploadé : remettre en pending et réémettre
        await _dao.retryFailed(m.clientId);
        _emitPendingMessage(m);
      }
    }
  }

  /// Modifie un message texte (le mien). Applique localement puis serveur.
  Future<void> editMessage(int msgID, String content) async {
    await _dao.updateContentByServerId(msgID, content);
    try {
      await _api.editMessage(msgID, content);
    } catch (e) {
      debugPrint('[ChatRepo] editMessage échouée: $e');
    }
  }

  /// Supprime un ou plusieurs messages (délègue au batch si nécessaire).
  /// [conversationID] est requis pour pouvoir supprimer les messages en attente
  /// de confirmation (msgID = 0).
  Future<void> deleteMessage(
    int msgID, {
    bool forAll = false,
    int? conversationID,
  }) async {
    await deleteMessages([msgID], forAll: forAll, conversationID: conversationID);
  }

  Future<void> deleteMessages(
    List<int> msgIDs, {
    bool forAll = false,
    int? conversationID,
  }) async {
    // Collecte les conversationID affectées pour rafraîchir les aperçus.
    final affectedConvIDs = <int>{};

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

    // 2. Messages en attente de confirmation (msgID = 0)
    //    On les marque localement. L'appel API sera fait après confirmation
    //    (via flushOutbox / confirmMessage qui détecte isDeleted).
    final hasPending = msgIDs.any((id) => id == 0);
    if (hasPending && conversationID != null) {
      affectedConvIDs.add(conversationID);
      await _dao.softDeletePendingMessages(
        conversationID,
        _myId,
        forAll: forAll,
      );
    }

    // 3. Rafraîchir l'aperçu de chaque conversation affectée.
    for (final convId in affectedConvIDs) {
      await _refreshConversationPreview(convId);
    }
  }

  /// Met à jour l'aperçu d'une conversation après suppression pour afficher
  /// « Ce message a été supprimé » (cohérent avec le rendu dans la discussion).
  Future<void> _refreshConversationPreview(int conversationID) async {
    await (_db.update(_db.localConversations)
          ..where((c) => c.conversID.equals(conversationID)))
        .write(const LocalConversationsCompanion(
      lastMessage: Value(_deletedPreview),
    ));
  }

  /// Remet un message échoué en file d'envoi (déclenché par l'utilisateur via
  /// le menu contextuel). Le prochain `flushOutbox` le rejoue.
  Future<void> retryMessage(String clientId) async {
    await _dao.retryFailed(clientId);
    if (_api.isSocketReady) {
      await flushOutbox();
    }
  }

  /// Met à jour l'épinglage côté serveur (conv_participants) puis localement.
  /// Optimistic : on écrit la valeur en cache d'abord pour un feedback instantané.
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

  Future<void> markAsRead(int conversationID) async {
    await _dao.markConversationReadAtomic(conversationID, _myId);
    await LocalNotificationHelper.cancelConversation(conversationID);
    if (_api.isSocketReady) {
      try {
        _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': conversationID});
        _pendingReadsRetry.remove(conversationID);
      } catch (e) {
        debugPrint('[ChatRepo] sendSocketEvent failed: $e');
        _pendingReadsRetry[conversationID] = (_pendingReadsRetry[conversationID] ?? 0) + 1;
      }
    } else {
      // Hors-ligne ou socket non-authentifié : stocker pour rejouer plus tard.
      _pendingReadsRetry[conversationID] = (_pendingReadsRetry[conversationID] ?? 0);
    }
    try {
      await _api.markConversationAsRead(conversationID);
    } catch (e) {
      debugPrint('[ChatRepo] markConversationAsRead HTTP failed: $e');
    }
  }

  /// Re-sync de la conversation actuellement à l'écran après reconnexion.
  /// Évite à l'utilisateur de quitter/rouvrir la conv pour voir les messages
  /// reçus pendant la coupure.
  Future<void> resyncActiveConversation() async {
    if (_activeConversationID == 0) return;
    await syncMessages(_activeConversationID, delta: true);
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

  Future<void> _flushPendingReads() async {
    if (!_api.isSocketReady || _pendingReadsRetry.isEmpty) return;
    for (final convID in _pendingReadsRetry.keys.toList()) {
      try {
        _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
        _pendingReadsRetry.remove(convID);
      } catch (e) {
        debugPrint('[ChatRepo] _flushPendingReads send failed for $convID: $e');
        _pendingReadsRetry[convID] = (_pendingReadsRetry[convID] ?? 0) + 1;
        if ((_pendingReadsRetry[convID] ?? 0) > 3) _pendingReadsRetry.remove(convID);
      }
    }
  }


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
    final clientId = json['clientId']?.toString();
    final content = json['content']?.toString();
    final mediaName = json['mediaName']?.toString();
    bool wasNew = false;
    await _db.transaction(() async {
      String? carriedLocalPath;
      DateTime? carriedClickSentAt;

      // Création d'un prédicat optimiste plus strict pour éviter d'associer
      // par erreur un message d'un autre utilisateur ayant le même contenu.
      final candidates = await (_db.select(_db.localMessages)
            ..where((m) {
              // Ligne déjà confirmée avec le même msgID mais clé différente
              final sameOtherKey = m.msgID.equals(msgID) & m.clientId.equals(srvKey).not();

              // Base optimiste : même conversation et msgID==0
              final optimisticBase = m.conversationID.equals(convID) & m.msgID.equals(0);

              // Match prioritaire par clientId si fourni par le serveur
              Expression<bool> optimistic = const Constant(false);
              if (clientId != null && clientId.isNotEmpty) {
                optimistic = optimisticBase & m.clientId.equals(clientId);
              } else if (content != null && content.isNotEmpty) {
                // Pour matcher sur le contenu, restreindre au messages dont
                // l'émetteur local est bien l'utilisateur courant (évite collisions)
                optimistic = optimisticBase & m.content.equals(content) & m.senderID.equals(_myId);
              } else if (mediaName != null && mediaName.isNotEmpty) {
                optimistic = optimisticBase & m.mediaName.equals(mediaName) & m.senderID.equals(_myId);
              }

              return sameOtherKey | optimistic;
            }))
          .get();

      // Nouveau message local si aucun candidat avec ce msgID confirmé
      wasNew = candidates.every((m) => m.msgID != msgID);

      String? carriedMediaThumb;
      for (final m in candidates) {
        carriedLocalPath ??= m.localMediaPath;
        carriedClickSentAt ??= m.clickSentAt;
        carriedMediaThumb ??= m.mediaThumb;
        await (_db.delete(_db.localMessages)..where((x) => x.clientId.equals(m.clientId))).go();
      }

      // Insère une seule ligne normalisée `srv_<msgID>` (clé primaire stable).
      var companion = _msgJsonToCompanion(json).copyWith(clientId: Value(srvKey));
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

      debugPrint('[ChatRepo] _upsertServerMsg msgID=$msgID conv=$convID candidates=${candidates.length} wasNew=$wasNew');
      await _dao.upsertMessage(companion);
    });

    // Préfetch média (images/audio toujours, fichiers < 5 Mo) pour rendre
    // l'historique consultable offline. On ne déclenche que pour les messages
    // réellement nouveaux afin d'éviter de recharger l'identique à chaque sync.
    // Exception : un média à vue unique ne doit JAMAIS être mis en cache local.
    final isViewOnce = json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    if (prefetchMedia && wasNew && !isViewOnce) {
      final mtype = _toInt(json['type']);
      final mediaUrl = json['mediaUrl']?.toString();
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        if (mtype == 1) {
          _cacheMedia(msgID, mediaUrl);
        } else if (mtype == 4) {
          _cacheMedia(msgID, mediaUrl, maxBytes: 5 * 1024 * 1024);
        }
      }
    }
    return wasNew;
  }

  Future<void> _onMessageReceived(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final senderID0 = _toInt(json['senderID']);

    final isNew = await _upsertServerMsg(json);
    // Si le même événement est reçu plusieurs fois, on évite de regonfler
    // unread/accusés/notifications. Le message est déjà à jour via l'upsert.
    if (!isNew) return;
    if (senderID0 == _myId) return;

    final convID = _toInt(json['conversationID']);
    final type = _toInt(json['type']);
    final isViewOnce =
        json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    final preview = _previewForMedia(
      type,
      json['content']?.toString(),
      json['mediaName']?.toString(),
      isViewOnce: isViewOnce,
    );
    final at = _parseDate(json['sendAt']) ?? DateTime.now().toUtc();
    final isActive = convID != 0 && convID == _activeConversationID;

    // Conversation ouverte → message lu immédiatement (pas de badge non-lu).
    _bumpConversationSummary(convID, preview, type, at,
        fromOther: !isActive, senderID: senderID0);
    if (isActive) {
      await _dao.markConversationRead(convID, _myId);
      await _dao.setUnread(convID, 0);
    }

    if (convID != 0 && _api.isSocketReady) {
      // Conversation ouverte → "lu" (✓✓ bleu) ; sinon "livré".
      _api.sendSocketEvent(
        isActive ? SocketEvents.messageRead : SocketEvents.messageDelivered,
        {'conversationID': convID},
      );
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

  Future<void> _onMessageStatus(dynamic data) async {
    if (data is! Map) return;
    final convID = _toInt(data['conversationID']);
    final status = _toInt(data['status']);
    final byUserID = _toInt(data['byUserID']);
    if (convID == 0 || status == 0 || byUserID == _myId) return;
    await _dao.bumpMyMessagesStatus(convID, _myId, status);
    await _dao.bumpConvLastStatusIfMine(convID, _myId, status);
    await _dao.reconcileLastMessageStatus(convID, _myId);
  }

  Future<void> _onMessageSent(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final msgID = _toInt(json['msgID']);
    if (msgID == 0) return;
    await _upsertServerMsg(json);
    final convID = _toInt(json['conversationID']);
    final status = _toInt(json['status'], fallback: 1);
    if (convID != 0) {
      await _dao.bumpConvLastStatusIfMine(convID, _myId, status);
      await _dao.reconcileLastMessageStatus(convID, _myId);
    }
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

  void _onMessagePinned(dynamic data) {
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
      debugPrint('[ChatRepo] markViewed échouée: $e');
    }
  }

  void _onMessageViewed(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id != 0) _dao.markViewedByServerId(id);
  }

  void _onMessageUpdated(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    final content = data['content']?.toString();
    if (id != 0 && content != null) _dao.updateContentByServerId(id, content);
  }

  void _onMessageDeleted(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id == 0) return;
    final all = data['all'] == true;
    final deletedForID = _toInt(data['deletedForID']);
    if (all) {
      _dao.softDeleteByServerId(id);
    } else if (deletedForID == _myId) {
      _dao.softDeleteForUser(id, _myId);
    }
  }

  void _onMessagesDeleted(dynamic data) {
    if (data is! Map) return;
    final rawIds = data['msgIDs'];
    if (rawIds is! List || rawIds.isEmpty) return;
    final ids = rawIds.map(_toInt).where((id) => id > 0).toList();
    if (ids.isEmpty) return;
    final all = data['all'] == true;
    final deletedForID = _toInt(data['deletedForID']);
    if (all) {
      _dao.softDeleteManyByServerId(ids);
    } else if (deletedForID == _myId) {
      _dao.softDeleteManyForUser(ids, _myId);
    }
  }

  void _emitSend({
    required String clientId,
    required int conversationID,
    String? content,
    required int type,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    String? mediaThumb,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) {
    // Garde stricte : tant que le socket n'est pas authentifié, le serveur
    // ignore l'emit silencieusement. On laisse la ligne `syncPending=true` ;
    // `flushOutbox` (texte ET média déjà uploadé) la rejouera quand
    // `auth:verified` aura déclenché _onSocketReady.
    if (!_api.isSocketReady) {
      debugPrint('[ChatRepo] _emitSend différé (socket non prêt) clientId=$clientId');
      return;
    }
    _api.sendSocketEvent(SocketEvents.messageSend, {
      'clientId': clientId,
      'conversationID': conversationID,
      if (content != null) 'content': content,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaName != null) 'mediaName': mediaName,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (mediaThumb != null) 'mediaThumb': mediaThumb,
      if (replyToID != null && replyToID > 0) 'replyToID': replyToID,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (isStatusReply != 0) 'isStatusReply': isStatusReply,
      if (isForwarded) 'isForwarded': 1,
      if (isViewOnce) 'isViewOnce': 1,
    });
    // Marque la ligne comme « tout juste émise » → backoff outbox.
    _dao.touchEmitted(clientId);
  }

  Future<void> _bumpConversationSummary(
    int conversID,
    String preview,
    int type,
    DateTime at, {
    bool fromOther = false,
    int? senderID,
    int? status,
  }) async {
    final normalized = normalizeConversationPreview(preview);
    final companion = LocalConversationsCompanion(
      conversID: Value(conversID),
      lastMessage: Value(
        normalized.length > 200 ? normalized.substring(0, 200) : normalized,
      ),
      lastMessageAt: Value(at),
      lastMessageType: Value(type),
      lastMessageSenderID:
          senderID != null ? Value(senderID) : const Value.absent(),
      lastMessageStatus: status != null ? Value(status) : const Value.absent(),
    );
    await _db.into(_db.localConversations).insertOnConflictUpdate(companion);
    if (fromOther) {
      // Only increment unread if the conversation is not currently active.
      if (conversID != _activeConversationID) {
        await _db.transaction(() async {
          final current = await (_db.select(_db.localConversations)
                ..where((c) => c.conversID.equals(conversID)))
              .getSingleOrNull();
          await _dao.setUnread(conversID, (current?.unreadCount ?? 0) + 1);
        });
      }
    }
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
    final clientId = j['clientId']?.toString() ?? 'srv_${_toInt(j['msgID'])}';
    return LocalMessagesCompanion(
      clientId: Value(clientId),
      msgID: Value(_toInt(j['msgID'])),
      conversationID: Value(_toInt(j['conversationID'])),
      senderID: Value(_toInt(j['senderID'])),
      content: Value(j['content']?.toString()),
      type: Value(_toInt(j['type'])),
      status: Value(_toInt(j['status'], fallback: 1)),
      sendAt: Value(_parseDate(j['sendAt']) ?? DateTime.now()),
      // clickSentAt n'existe que localement (heure du clic de l'expéditeur) :
      // on ne le renseigne jamais depuis le serveur, et on ne l'écrase pas.
      clickSentAt: const Value.absent(),
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
      replyToID: Value(j['replyToID'] == null ? null : _toInt(j['replyToID'])),
      replyToContent: Value(j['replyToContent']?.toString()),
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

  String _newClientId() =>
      'c_${_myId}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

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

class _PendingAlbumUpload {
  const _PendingAlbumUpload({
    required this.clientId,
    required this.file,
    required this.type,
    required this.content,
    required this.mediaName,
    this.mediaDuration,
    required this.isForwarded,
  });

  final String clientId;
  final File file;
  final int type;
  final String content;
  final String mediaName;
  final int? mediaDuration;
  final bool isForwarded;
}