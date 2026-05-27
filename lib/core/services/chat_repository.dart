import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../db/chat_dao.dart';
import 'media_cache_service.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';  
class ChatRepository {
  final AppDatabase _db;
  final ChatDao _dao;
  final TalkyApiClient _api;
  final MediaCacheService _mediaCache = MediaCacheService();

  int _myId = 0;
  bool _listenersBound = false;

  /// Conversation actuellement ouverte à l'écran (0 = aucune). Un message reçu
  /// pour cette conversation est marqué lu immédiatement et n'incrémente pas
  /// l'unread (l'utilisateur le voit en direct).
  int _activeConversationID = 0;

  /// Lectures à confirmer au serveur dès la reconnexion (lecture hors-ligne).
  final Set<int> _pendingReads = {};

  void setActiveConversation(int conversationID) =>
      _activeConversationID = conversationID;
  void clearActiveConversation(int conversationID) {
    if (_activeConversationID == conversationID) _activeConversationID = 0;
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
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      _dao.watchMessages(conversationID, _myId);
 
  void bind(int myId) {
    if (myId == 0) return; 
    _myId = myId;

    _dao.purgeGhostMessages();
    _dao.purgeDuplicateOptimistics();
    _dao.purgeDuplicateByMsgId();
    // Best-effort eviction LRU au démarrage (non-bloquant).
    _mediaCache.evictIfNeeded();

    if (_listenersBound) return;
    _listenersBound = true;

    _api.onSocketEvent(SocketEvents.messageReceived, _onMessageReceived);
    _api.onSocketEvent(SocketEvents.messageSent, _onMessageSent);
    _api.onSocketEvent(SocketEvents.messageUpdated, _onMessageUpdated);
    _api.onSocketEvent(SocketEvents.messageDeleted, _onMessageDeleted);
    _api.onSocketEvent(SocketEvents.messageStatus, _onMessageStatus);
    _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationCreated);
  }

  void _onConversationCreated(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    _dao.upsertConversation(_convToCompanion(Conversation.fromJson(json), json));
  }
 
  Future<void> syncConversations() async {
    try {
      final raw = await _api.getConversations();
      final companions = raw
          .whereType<Map<String, dynamic>>()
          .map((j) => _convToCompanion(Conversation.fromJson(j), j))
          .toList();
      await _dao.upsertConversations(companions);
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
      content: Value(content),
      type: const Value(0),
      status: const Value(0),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isStatusReply: Value(isStatusReply),
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
    );
  }

  /// Aperçu canonique pour les messages média : on respecte le `content` saisi
  /// s'il existe, sinon on retombe sur l'emoji + libellé de type. Évite que
  /// l'aperçu de conv affiche un nom de fichier brut (`IMG_2026.jpg`).
  static String _previewForMedia(int type, String? content, String? mediaName) {
    if (content != null && content.trim().isNotEmpty) return content;
    switch (type) {
      case 1:
        return '📷 Photo';
      case 2:
        return '🎥 Vidéo';
      case 3:
        return '🎵 Audio';
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
    String? localMediaPath,
    String? content,
  }) async {
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId,
      sendAt: now,
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaUrl: Value(mediaUrl),
      mediaName: Value(mediaName),
      mediaDuration: Value(mediaDuration),
      localMediaPath: Value(localMediaPath),
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(
        conversationID, _previewForMedia(type, content, mediaName), type, now,
        senderID: _myId, status: 0);

    _emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaDuration: mediaDuration,
    );
  }

  Future<void> sendMediaFile({
    required int conversationID,
    required int type, // 1=image 2=vidéo 3=audio 4=fichier
    required File file,
    String? mediaName,
    int? mediaDuration,
    String? content,
  }) async {
    if (_myId == 0) {
      debugPrint('[ChatRepo] sendMediaFile ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();
    final name = mediaName ?? file.path.split('/').last;

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId,
      sendAt: now,
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaName: Value(name),
      mediaDuration: Value(mediaDuration),
      localMediaPath: Value(file.path),
      pendingUploadPath: Value(file.path),
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(
        conversationID, _previewForMedia(type, content, name), type, now,
        senderID: _myId, status: 0);

    try {
      final res = await _api.uploadMedia(file);
      final url = res['url'] as String?;
      if (url == null) throw Exception('upload sans url');

      await (_db.update(_db.localMessages)..where((m) => m.clientId.equals(clientId)))
          .write(LocalMessagesCompanion(
        mediaUrl: Value(url),
        pendingUploadPath: const Value(null),
        status: const Value(1), // envoyé (message:sent affinera ensuite)
      ));

      _emitSend(
        clientId: clientId,
        conversationID: conversationID,
        content: content,
        type: type,
        mediaUrl: url,
        mediaName: name,
        mediaDuration: mediaDuration,
      );
    } catch (e) {
      debugPrint('[ChatRepo] upload média échoué: $e');
      // Erreur réseau (timeout / socket coupé) → laisser en pending pour rejeu
      // par flushOutbox à la reconnexion. Erreur fatale (4xx/5xx serveur) →
      // markFailed pour ne pas tourner en boucle.
      if (_isTransientNetworkError(e)) {
        debugPrint('[ChatRepo] upload différé — pending intact pour rejeu');
      } else {
        await _dao.markFailed(clientId);
      }
    }
  }

  bool _isTransientNetworkError(Object e) {
    if (e is TalkyException) {
      // statusCode 0 = pas de réponse HTTP (offline / timeout). 5xx aussi
      // raisonnable à retenter. 4xx = erreur cliente, on abandonne.
      return e.statusCode == 0 || (e.statusCode >= 500 && e.statusCode < 600);
    }
    return true; // exceptions Dart inattendues : on est prudent et on retente
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
        final file = File(m.pendingUploadPath!);
        if (!file.existsSync()) {
          debugPrint('[ChatRepo] flush: fichier disparu pour ${m.clientId} → failed');
          await _dao.markFailed(m.clientId);
          continue;
        }
        try {
          final res = await _api.uploadMedia(file);
          final url = res['url'] as String?;
          if (url == null) throw Exception('upload sans url');
          await (_db.update(_db.localMessages)..where((x) => x.clientId.equals(m.clientId)))
              .write(LocalMessagesCompanion(
            mediaUrl: Value(url),
            pendingUploadPath: const Value(null),
            status: const Value(1),
          ));
          _emitSend(
            clientId: m.clientId,
            conversationID: m.conversationID,
            content: m.content,
            type: m.type,
            mediaUrl: url,
            mediaName: m.mediaName,
            mediaDuration: m.mediaDuration,
            replyToID: m.replyToID,
            replyToContent: m.replyToContent,
          );
        } catch (e) {
          debugPrint('[ChatRepo] flush upload échoué pour ${m.clientId}: $e');
          if (!_isTransientNetworkError(e)) {
            await _dao.markFailed(m.clientId);
          }
          // On laisse tomber la suite pour ce message, on retentera plus tard.
        }
      } else {
        _emitSend(
          clientId: m.clientId,
          conversationID: m.conversationID,
          content: m.content,
          type: m.type,
          mediaUrl: m.mediaUrl,
          mediaName: m.mediaName,
          mediaDuration: m.mediaDuration,
          replyToID: m.replyToID,
          replyToContent: m.replyToContent,
        );
      }
    }
    // Rejoue les accusés de lecture émis hors-ligne.
    if (_api.isSocketReady && _pendingReads.isNotEmpty) {
      for (final convID in _pendingReads.toList()) {
        _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
      }
      _pendingReads.clear();
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

  /// Supprime un message :
  ///  - [forAll]=true : soft delete partagé (`isDeleted=1`), le bubble devient
  ///    « Ce message a été supprimé » côté tous les participants.
  ///  - [forAll]=false : suppression locale uniquement, on pose `deletedForID`
  ///    sur l'utilisateur courant pour le masquer pour lui seul.
  Future<void> deleteMessage(int msgID, {bool forAll = false}) async {
    if (forAll) {
      await _dao.softDeleteByServerId(msgID);
    } else {
      await _dao.softDeleteForUser(msgID, _myId);
    }
    try {
      await _api.deleteMessage(msgID, forAll: forAll);
    } catch (e) {
      debugPrint('[ChatRepo] deleteMessage échouée: $e');
    }
  }

  /// Remet un message échoué en file d'envoi (déclenché par l'utilisateur via
  /// le menu contextuel). Le prochain `flushOutbox` le rejoue.
  Future<void> retryMessage(String clientId) async {
    await _dao.retryFailed(clientId);
    if (_api.isSocketReady) {
      await flushOutbox();
    }
  }

  Future<void> markAsRead(int conversationID) async {
    await _dao.markConversationRead(conversationID, _myId);
    await _dao.setUnread(conversationID, 0);
    if (_api.isSocketReady) {
      _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': conversationID});
    } else {
      // Hors-ligne ou socket non-authentifié : on rejouera la lecture à la
      // reconnexion (sinon le serveur garde unread>0 et un futur sync ramènerait
      // le message comme non-lu).
      _pendingReads.add(conversationID);
    }
    _api.markConversationAsRead(conversationID).ignore();
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


  Future<void> _upsertServerMsg(
    Map<String, dynamic> json, {
    bool prefetchMedia = false,
  }) async {
    final msgID = _toInt(json['msgID']);
    final convID = _toInt(json['conversationID']);
    if (msgID == 0) {
      await _dao.upsertMessage(_msgJsonToCompanion(json));
      return;
    }

    final srvKey = 'srv_$msgID';
    final clientId = json['clientId']?.toString();
    final content = json['content']?.toString();
    final mediaName = json['mediaName']?.toString();
    bool wasNew = false;
    await _db.transaction(() async {
      String? carriedLocalPath;
      final candidates = await (_db.select(_db.localMessages)
            ..where((m) {
              final sameOtherKey = m.msgID.equals(msgID) & m.clientId.equals(srvKey).not();
              final optimisticBase = m.conversationID.equals(convID) & m.msgID.equals(0);
              Expression<bool> optimistic;
              if (clientId != null && clientId.isNotEmpty) {
                optimistic = optimisticBase & m.clientId.equals(clientId);
              } else if (content != null && content.isNotEmpty) {
                optimistic = optimisticBase & m.content.equals(content);
              } else {
                optimistic = optimisticBase & m.mediaName.equals(mediaName ?? '');
              }
              return sameOtherKey | optimistic;
            }))
          .get();

      // Si aucun candidat n'existait avec ce msgID confirmé, c'est un message
      // nouveau pour la base locale → on déclenchera l'auto-cache du média.
      wasNew = candidates.every((m) => m.msgID != msgID);

      for (final m in candidates) {
        carriedLocalPath ??= m.localMediaPath;
        await (_db.delete(_db.localMessages)..where((x) => x.clientId.equals(m.clientId))).go();
      }

      // PK toujours normalisée à `srv_<msgID>` : le clientId du JSON (présent sur
      // `message:sent`) ne sert qu'au matching de l'optimiste ci-dessus, jamais de
      // clé stockée. Sinon `message:received` (→ srv_X) et `message:sent` (→ c_X)
      // créeraient DEUX lignes pour le même msgID = doublon chez l'émetteur.
      var companion = _msgJsonToCompanion(json).copyWith(clientId: Value(srvKey));
      if (carriedLocalPath != null) {
        companion = companion.copyWith(localMediaPath: Value(carriedLocalPath));
      }
      await _dao.upsertMessage(companion);
    });

    // Préfetch média (images/audio toujours, fichiers < 5 Mo) pour rendre
    // l'historique consultable offline. On ne déclenche que pour les messages
    // réellement nouveaux afin d'éviter de recharger l'identique à chaque sync.
    if (prefetchMedia && wasNew) {
      final mtype = _toInt(json['type']);
      final mediaUrl = json['mediaUrl']?.toString();
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        if (mtype == 1 || mtype == 3) {
          _cacheMedia(msgID, mediaUrl);
        } else if (mtype == 4) {
          _cacheMedia(msgID, mediaUrl, maxBytes: 5 * 1024 * 1024);
        }
      }
    }
  }

  Future<void> _onMessageReceived(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final senderID0 = _toInt(json['senderID']);

    await _upsertServerMsg(json);
    if (senderID0 == _myId) return;

    final convID = _toInt(json['conversationID']);
    final type = _toInt(json['type']);
    final preview = _previewForMedia(
      type,
      json['content']?.toString(),
      json['mediaName']?.toString(),
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

    if (convID != 0 && _api.isSocketConnected) {
      // Conversation ouverte → "lu" (✓✓ bleu) ; sinon "livré".
      _api.sendSocketEvent(
        isActive ? SocketEvents.messageRead : SocketEvents.messageDelivered,
        {'conversationID': convID},
      );
    }
    final mtype = _toInt(json['type']);
    final mediaUrl = json['mediaUrl']?.toString();
    final msgID = _toInt(json['msgID']);
    if (mediaUrl != null && msgID != 0) {
      if (mtype == 1 || mtype == 3) {
        // Images, audio : auto-cache toujours.
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

  void _onMessageStatus(dynamic data) {
    if (data is! Map) return;
    final convID = _toInt(data['conversationID']);
    final status = _toInt(data['status']);
    final byUserID = _toInt(data['byUserID']);
    if (convID == 0 || status == 0 || byUserID == _myId) return;
    _dao.bumpMyMessagesStatus(convID, _myId, status);
    // Reflète l'accusé (✓✓ / ✓✓ bleu) sur l'aperçu si le dernier message est le mien.
    _dao.bumpConvLastStatusIfMine(convID, _myId, status);
  }

  Future<void> _onMessageSent(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final msgID = _toInt(json['msgID']);
    if (msgID == 0) return;
    await _upsertServerMsg(json);
    // Mon message est confirmé "envoyé" → ✓ sur l'aperçu.
    final convID = _toInt(json['conversationID']);
    final status = _toInt(json['status'], fallback: 1);
    if (convID != 0) _dao.bumpConvLastStatusIfMine(convID, _myId, status);
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
    if (id != 0) _dao.softDeleteByServerId(id);
  }

  void _emitSend({
    required String clientId,
    required int conversationID,
    String? content,
    required int type,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
  }) {
    // Garde stricte : tant que le socket n'est pas authentifié, le serveur
    // ignore l'emit silencieusement. On laisse la ligne `syncPending=true` ;
    // `flushOutbox` la rejouera quand `auth:verified` aura déclenché _onSocketReady.
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
      if (replyToID != null) 'replyToID': replyToID,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (isStatusReply != 0) 'isStatusReply': isStatusReply,
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
    final companion = LocalConversationsCompanion(
      conversID: Value(conversID),
      lastMessage: Value(preview.length > 200 ? preview.substring(0, 200) : preview),
      lastMessageAt: Value(at),
      lastMessageType: Value(type),
      lastMessageSenderID:
          senderID != null ? Value(senderID) : const Value.absent(),
      lastMessageStatus: status != null ? Value(status) : const Value.absent(),
    );
    await _db.into(_db.localConversations).insertOnConflictUpdate(companion);
    if (fromOther) {
      final current = await (_db.select(_db.localConversations)
            ..where((c) => c.conversID.equals(conversID)))
          .getSingleOrNull();
      await _dao.setUnread(conversID, (current?.unreadCount ?? 0) + 1);
    }
  }

  LocalConversationsCompanion _convToCompanion(Conversation c, Map<String, dynamic> raw) {
    return LocalConversationsCompanion(
      conversID: Value(c.conversID),
      isGroup: Value(c.isGroup),
      groupName: Value(c.groupName),
      groupPhoto: Value(c.groupPhoto),
      lastMessage: Value(c.lastMessage),
      lastMessageAt: Value(_parseDate(c.lastMessageAt)),
      lastMessageSenderID: Value(c.lastMessageSenderID),
      lastMessageType: Value(c.lastMessageType),
      lastMessageStatus: Value(c.lastMessageStatus),
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
      deliveredAt: Value(_parseDate(j['deliveredAt'])),
      readAt: Value(_parseDate(j['readAt'])),
      mediaUrl: Value(j['mediaUrl']?.toString()),
      mediaName: Value(j['mediaName']?.toString()),
      mediaDuration: Value(j['mediaDuration'] == null ? null : _toInt(j['mediaDuration'])),
      replyToID: Value(j['replyToID'] == null ? null : _toInt(j['replyToID'])),
      replyToContent: Value(j['replyToContent']?.toString()),
      isEdited: Value(j['isEdited'] == 1 || j['isEdited'] == true),
      editedAt: Value(_parseDate(j['editedAt'])),
      isDeleted: Value(j['isDeleted'] == 1 || j['isDeleted'] == true),
      deletedForID: Value(j['deletedForID'] == null ? null : _toInt(j['deletedForID'])),
      isStatusReply: Value(_toInt(j['isStatusReply'])),
      senderNom: Value(j['sender_nom']?.toString()),
      senderPseudo: Value(j['sender_pseudo']?.toString()),
      senderAvatar: Value(j['sender_avatar']?.toString()),
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
