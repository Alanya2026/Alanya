import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../db/chat_dao.dart';
import 'media_cache_service.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

// ─────────────────────────────────────────────────────────────────────
//  ChatRepository — source de vérité unique pour les chats.
//
//  Principe offline-first : l'UI lit/écrit TOUJOURS la base locale via
//  les streams du DAO. Le repository synchronise avec le serveur (REST +
//  Socket.IO) en arrière-plan et applique les events temps réel.
// ─────────────────────────────────────────────────────────────────────
class ChatRepository {
  final AppDatabase _db;
  final ChatDao _dao;
  final TalkyApiClient _api;
  final MediaCacheService _mediaCache = MediaCacheService();

  int _myId = 0;
  bool _listenersBound = false;

  ChatRepository._(this._api, this._db) : _dao = ChatDao(_db);

  MediaCacheService get mediaCache => _mediaCache;

  /// Construit le repository avec une unique instance de DB partagée.
  factory ChatRepository({required TalkyApiClient api, AppDatabase? database}) {
    return ChatRepository._(api, database ?? AppDatabase());
  }

  AppDatabase get db => _db;
  ChatDao get dao => _dao;
  int get myId => _myId;

  // ── Streams réactifs consommés par l'UI ────────────────────────────
  Stream<List<LocalConversation>> watchConversations() => _dao.watchConversations();
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      _dao.watchMessages(conversationID);

  // ── Cycle de vie ───────────────────────────────────────────────────
  void bind(int myId) {
    if (myId == 0) return; // jamais lier avec un ID invalide
    _myId = myId;

    // Purge des messages fantômes (senderID=0) + doublons hérités.
    _dao.purgeGhostMessages();
    _dao.purgeDuplicateOptimistics();
    _dao.purgeDuplicateByMsgId();

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

  // ── Synchronisation serveur → DB locale ────────────────────────────
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

  /// Charge l'historique d'une conversation. `delta=true` ne récupère que
  /// les messages plus récents que le dernier connu localement.
  Future<void> syncMessages(int conversationID, {bool delta = false}) async {
    try {
      final raw = await _api.getMessages(conversationID, limit: 50);
      for (final j in raw.whereType<Map<String, dynamic>>()) {
        await _upsertServerMsg(j); // dédoublonne les optimistes non confirmés
      }
    } catch (e) {
      debugPrint('[ChatRepo] syncMessages($conversationID) échouée: $e');
    }
  }

  /// Charge une page d'anciens messages (avant le plus ancien connu).
  /// Renvoie le nombre de messages récupérés (0 = plus rien à charger).
  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) async {
    try {
      final oldest = await _dao.minServerMsgId(conversationID);
      if (oldest == 0) return 0;
      final raw = await _api.getMessages(conversationID, limit: limit, before: oldest);
      final list = raw.whereType<Map<String, dynamic>>().toList();
      for (final j in list) {
        await _upsertServerMsg(j);
      }
      return list.length;
    } catch (e) {
      debugPrint('[ChatRepo] loadOlderMessages échouée: $e');
      return 0;
    }
  }

  // ── Envoi optimiste (offline-first) ────────────────────────────────
  Future<void> sendText({
    required int conversationID,
    required String content,
    int? replyToID,
    String? replyToContent,
  }) async {
    if (_myId == 0) {
      debugPrint('[ChatRepo] sendText ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now();

    // 1. Écriture locale immédiate (status=sending, syncPending).
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
      syncPending: const Value(true),
    ));
    _bumpConversationSummary(conversationID, content, 0, now);

    // 2. Tentative d'envoi temps réel.
    _emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: 0,
      replyToID: replyToID,
      replyToContent: replyToContent,
    );
  }

  /// Envoi d'un média déjà uploadé (url connue).
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
    final now = DateTime.now();

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
    _bumpConversationSummary(conversationID, content ?? mediaName ?? 'Média', type, now);

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

  /// Envoi d'un média depuis un fichier local : affichage optimiste immédiat
  /// (chemin local), upload en arrière-plan, puis diffusion temps réel.
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
    final now = DateTime.now();
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
    _bumpConversationSummary(conversationID, content ?? name, type, now);

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
      await _dao.markFailed(clientId);
    }
  }

  /// Renvoie tous les messages en attente (appelé à la reconnexion socket).
  Future<void> flushOutbox() async {
    final pending = await _dao.pendingMessages();
    for (final m in pending) {
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

  /// Modifie un message texte (le mien). Applique localement puis serveur.
  Future<void> editMessage(int msgID, String content) async {
    await _dao.updateContentByServerId(msgID, content);
    try {
      await _api.editMessage(msgID, content);
    } catch (e) {
      debugPrint('[ChatRepo] editMessage échouée: $e');
    }
  }

  /// Supprime un message (pour moi ou pour tous). Application locale immédiate.
  Future<void> deleteMessage(int msgID, {bool forAll = false}) async {
    await _dao.softDeleteByServerId(msgID);
    try {
      await _api.deleteMessage(msgID, forAll: forAll);
    } catch (e) {
      debugPrint('[ChatRepo] deleteMessage échouée: $e');
    }
  }

  Future<void> markAsRead(int conversationID) async {
    await _dao.markConversationRead(conversationID, _myId);
    await _dao.setUnread(conversationID, 0);
    // Notifie l'émetteur en temps réel (✓✓ bleu) + persiste côté serveur.
    if (_api.isSocketConnected) {
      _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': conversationID});
    }
    _api.markConversationAsRead(conversationID).ignore();
  }

  // ── Insertion robuste d'un message serveur ─────────────────────────
  // Avant d'insérer, si le message est le MIEN et confirmé (msgID>0), on
  // supprime la ligne optimiste correspondante (par clientId si fourni par
  // message:sent, sinon par contenu) → plus de doublon côté émetteur, même
  // si le backend ne renvoie pas le clientId. Préserve le chemin média local.
  Future<void> _upsertServerMsg(Map<String, dynamic> json) async {
    final msgID = _toInt(json['msgID']);
    final convID = _toInt(json['conversationID']);
    if (msgID == 0) {
      // Message serveur sans ID (ne devrait pas arriver) → insertion simple.
      await _dao.upsertMessage(_msgJsonToCompanion(json));
      return;
    }

    final srvKey = 'srv_$msgID';
    final clientId = json['clientId']?.toString();
    final content = json['content']?.toString();
    final mediaName = json['mediaName']?.toString();

    // Toute la fusion se fait dans UNE transaction : drift ne notifie le
    // stream qu'à la fin → aucun état intermédiaire "double" affiché.
    await _db.transaction(() async {
      String? carriedLocalPath;

      // 1. Lignes à supprimer :
      //    - autre clé portant le même msgID (doublon confirmé hérité)
      //    - ligne optimiste (msgID=0) correspondante. Une ligne msgID=0
      //      n'existe QUE pour mes propres envois → pas de garde senderID :
      //      match par clientId si fourni, sinon par contenu/média.
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

      for (final m in candidates) {
        carriedLocalPath ??= m.localMediaPath;
        await (_db.delete(_db.localMessages)..where((x) => x.clientId.equals(m.clientId))).go();
      }

      var companion = _msgJsonToCompanion(json);
      if (carriedLocalPath != null) {
        companion = companion.copyWith(localMediaPath: Value(carriedLocalPath));
      }
      await _dao.upsertMessage(companion);
    });
  }

  // ── Handlers Socket.IO ─────────────────────────────────────────────
  Future<void> _onMessageReceived(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final senderID0 = _toInt(json['senderID']);

    await _upsertServerMsg(json);

    // Le reste (résumé, accusé, cache) ne concerne que les messages reçus
    // des AUTRES ; mes propres messages ont déjà été traités optimistiquement.
    if (senderID0 == _myId) return;

    final convID = _toInt(json['conversationID']);
    final content = (json['content'] ?? json['mediaName'] ?? 'Média').toString();
    final type = json['type'] ?? 0;
    final at = _parseDate(json['sendAt']) ?? DateTime.now();
    _bumpConversationSummary(convID, content, type, at, fromOther: true);

    // Accusé de réception → l'émetteur passe en "livré" (✓✓).
    if (convID != 0 && _api.isSocketConnected) {
      _api.sendSocketEvent(SocketEvents.messageDelivered, {'conversationID': convID});
    }

    // Auto-cache des médias consultables hors-ligne (images & vocaux).
    final mtype = _toInt(json['type']);
    final mediaUrl = json['mediaUrl']?.toString();
    final msgID = _toInt(json['msgID']);
    if (mediaUrl != null && msgID != 0 && (mtype == 1 || mtype == 3)) {
      _cacheMedia(msgID, mediaUrl);
    }
  }

  Future<void> _cacheMedia(int msgID, String url) async {
    final path = await _mediaCache.ensureCached(url);
    if (path != null) await _dao.setLocalMediaPath(msgID, path);
  }

  /// `message:status` : l'autre a livré (2) ou lu (3) MES messages.
  void _onMessageStatus(dynamic data) {
    if (data is! Map) return;
    final convID = _toInt(data['conversationID']);
    final status = _toInt(data['status']);
    final byUserID = _toInt(data['byUserID']);
    if (convID == 0 || status == 0 || byUserID == _myId) return;
    _dao.bumpMyMessagesStatus(convID, _myId, status);
  }

  Future<void> _onMessageSent(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    if (_toInt(json['msgID']) == 0) return;
    // Même chemin robuste : supprime l'optimiste (par clientId) et insère la
    // ligne serveur, identique à une resync → aucun doublon.
    await _upsertServerMsg(json);
  }

  void _onMessageUpdated(dynamic data) {
    if (data is! Map) return;
    // Mettre à jour PAR msgID (mes messages ont un clientId local, pas srv_).
    final id = _toInt(data['msgID']);
    final content = data['content']?.toString();
    if (id != 0 && content != null) _dao.updateContentByServerId(id, content);
  }

  void _onMessageDeleted(dynamic data) {
    if (data is! Map) return;
    final id = _toInt(data['msgID']);
    if (id != 0) _dao.softDeleteByServerId(id);
  }

  // ── Helpers internes ───────────────────────────────────────────────
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
  }) {
    if (!_api.isSocketConnected) return; // restera dans l'outbox
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
    });
  }

  Future<void> _bumpConversationSummary(
    int conversID,
    String preview,
    int type,
    DateTime at, {
    bool fromOther = false,
  }) async {
    final companion = LocalConversationsCompanion(
      conversID: Value(conversID),
      lastMessage: Value(preview.length > 200 ? preview.substring(0, 200) : preview),
      lastMessageAt: Value(at),
      lastMessageType: Value(type),
    );
    // insertOnConflictUpdate ne mettrait à jour que ces champs si la conv
    // existe déjà ; sinon crée une ligne minimale (sera enrichie au sync).
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
      readAt: Value(_parseDate(j['readAt'])),
      mediaUrl: Value(j['mediaUrl']?.toString()),
      mediaName: Value(j['mediaName']?.toString()),
      mediaDuration: Value(j['mediaDuration'] == null ? null : _toInt(j['mediaDuration'])),
      replyToID: Value(j['replyToID'] == null ? null : _toInt(j['replyToID'])),
      replyToContent: Value(j['replyToContent']?.toString()),
      isEdited: Value(j['isEdited'] == 1 || j['isEdited'] == true),
      isDeleted: Value(j['isDeleted'] == 1 || j['isDeleted'] == true),
      isStatusReply: Value(_toInt(j['isStatusReply'])),
      senderNom: Value(j['sender_nom']?.toString()),
      senderPseudo: Value(j['sender_pseudo']?.toString()),
      senderAvatar: Value(j['sender_avatar']?.toString()),
      syncPending: const Value(false),
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
