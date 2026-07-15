import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
 
class ChatDao {
  final AppDatabase db;
  ChatDao(this.db);

  /// Liste réactive des conversations, épinglées d'abord puis par date.
  Stream<List<LocalConversation>> watchConversations() {
    return (db.select(db.localConversations)
          ..orderBy([
            (c) => OrderingTerm(expression: c.isPinned, mode: OrderingMode.desc),
            (c) => OrderingTerm(expression: c.lastMessageAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Suivi réactif d'une conversation isolée (header de chat_detail, etc.).
  Stream<LocalConversation?> watchConversation(int conversID) {
    return (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(conversID)))
        .watchSingleOrNull();
  }

  Future<void> upsertConversation(LocalConversationsCompanion conv) {
    return db.into(db.localConversations).insertOnConflictUpdate(conv);
  }

  Future<void> upsertConversations(List<LocalConversationsCompanion> convs) async {
    await db.batch((b) {
      for (final c in convs) {
        b.insert(db.localConversations, c, onConflict: DoUpdate((_) => c));
      }
    });
  }

  Future<void> deleteConversation(int conversID) async {
    await (db.delete(db.localConversations)..where((c) => c.conversID.equals(conversID))).go();
    await (db.delete(db.localMessages)..where((m) => m.conversationID.equals(conversID))).go();
  }

  Future<void> deleteConversations(List<int> conversIDs) async {
    if (conversIDs.isEmpty) return;
    if (conversIDs.length == 1) return deleteConversation(conversIDs.first);
    await (db.delete(db.localConversations)..where((c) => c.conversID.isIn(conversIDs))).go();
    await (db.delete(db.localMessages)..where((m) => m.conversationID.isIn(conversIDs))).go();
  }

  Future<void> setUnread(int conversID, int count) {
    return (db.update(db.localConversations)..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(unreadCount: Value(count)));
  }

  Future<void> setPinned(int conversID, bool pinned) {
    return (db.update(db.localConversations)..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(isPinned: Value(pinned)));
  }

  Future<void> setPinnedMany(List<int> conversIDs, bool pinned) {
    if (conversIDs.isEmpty) return Future.value();
    if (conversIDs.length == 1) return setPinned(conversIDs.first, pinned);
    return (db.update(db.localConversations)..where((c) => c.conversID.isIn(conversIDs)))
        .write(LocalConversationsCompanion(isPinned: Value(pinned)));
  }

  Future<void> setArchived(int conversID, bool archived) {
    return (db.update(db.localConversations)..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(isArchived: Value(archived)));
  }

  Future<void> setArchivedMany(List<int> conversIDs, bool archived) {
    if (conversIDs.isEmpty) return Future.value();
    if (conversIDs.length == 1) return setArchived(conversIDs.first, archived);
    return (db.update(db.localConversations)..where((c) => c.conversID.isIn(conversIDs)))
        .write(LocalConversationsCompanion(isArchived: Value(archived)));
  }

  // MESSAGES 

  /// Messages d'une conversation (anciens → récents).
  /// Les messages soft-deletés ([isDeleted]=1) sont conservés pour afficher
  /// « Ce message a été supprimé ». Les messages supprimés « pour moi » via
  /// [deletedForID] sont en revanche masqués pour cet utilisateur uniquement.
  Stream<List<LocalMessage>> watchMessages(int conversationID, int myId) {
    return (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
          ..orderBy([(m) => OrderingTerm(expression: m.sendAt)]))
        .watch();
  }

  Future<void> upsertMessage(LocalMessagesCompanion msg) {
    return db.into(db.localMessages).insertOnConflictUpdate(msg);
  }

  Future<void> upsertMessages(List<LocalMessagesCompanion> msgs) async {
    await db.batch((b) {
      for (final m in msgs) {
        b.insert(db.localMessages, m, onConflict: DoUpdate((_) => m));
      }
    });
  }

  /// Plus grand `msgID` confirmé d'une conversation (curseur de delta-sync).
  Future<int> maxServerMsgId(int conversationID) async {
    final q = db.selectOnly(db.localMessages)
      ..addColumns([db.localMessages.msgID.max()])
      ..where(db.localMessages.conversationID.equals(conversationID));
    final row = await q.getSingleOrNull();
    return row?.read(db.localMessages.msgID.max()) ?? 0;
  }

  /// Plus petit `msgID` confirmé (>0) d'une conversation (curseur "load more").
  Future<int> minServerMsgId(int conversationID) async {
    final expr = db.localMessages.msgID.min();
    final q = db.selectOnly(db.localMessages)
      ..addColumns([expr])
      ..where(db.localMessages.conversationID.equals(conversationID) &
          db.localMessages.msgID.isBiggerThanValue(0));
    final row = await q.getSingleOrNull();
    return row?.read(expr) ?? 0;
  }

  /// Messages en attente d'envoi (outbox), du plus ancien au plus récent.
  /// Filtre les lignes émises il y a moins de [cooldown] (backoff côté client)
  /// pour ne pas spammer le serveur en cas de race auth/connect.
  /// Exclut les messages supprimés (isDeleted) pour éviter qu'ils soient
  /// ré-émis par le flushOutbox après suppression locale.
  Future<List<LocalMessage>> pendingMessages({
    Duration cooldown = const Duration(seconds: 5),
  }) {
    final threshold = DateTime.now().subtract(cooldown);
    return (db.select(db.localMessages)
          ..where((m) =>
              m.syncPending.equals(true) &
              m.isDeleted.equals(false) &
              (m.lastEmittedAt.isNull() |
                  m.lastEmittedAt.isSmallerThanValue(threshold)))
          ..orderBy([(m) => OrderingTerm(expression: m.sendAt)]))
        .get();
  }

  /// Marque un message comme « tout juste émis » pour le backoff outbox.
  Future<void> touchEmitted(String clientId) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(lastEmittedAt: Value(DateTime.now())));
  }

  /// Remet un message échoué en file d'envoi (reset backoff, statut sending).
  Future<void> retryFailed(String clientId) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(const LocalMessagesCompanion(
      status: Value(0),
      syncPending: Value(true),
      lastEmittedAt: Value(null),
    ));
  }

 
  Future<void> confirmMessage({
    required String clientId,
    required int msgID,
    required int status,
    DateTime? sendAt,
  }) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(
      msgID: Value(msgID),
      status: Value(status),
      sendAt: sendAt != null ? Value(sendAt) : const Value.absent(),
      syncPending: const Value(false),
    ));
  }

  Future<void> updateStatusByServerId(int msgID, int status, {DateTime? readAt}) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID))).write(
      LocalMessagesCompanion(
        status: Value(status),
        readAt: readAt != null ? Value(readAt) : const Value.absent(),
      ),
    );
  }

  /// Marque comme lus tous les messages reçus d'une conversation.
  Future<void> markConversationRead(int conversationID, int myId) {
    return (db.update(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(myId).not() &
              m.status.isSmallerThanValue(3)))
        .write(const LocalMessagesCompanion(status: Value(3)));
  }

    /// Atomically mark all messages in a conversation as read and reset unread
    /// counter. This prevents races where an incoming message increments the
    /// unread count while we reset it.
    Future<void> markConversationReadAtomic(int conversationID, int myId) async {
      await db.transaction(() async {
    await (db.update(db.localMessages)
      ..where((m) =>
          m.conversationID.equals(conversationID) &
          m.senderID.equals(myId).not() &
          m.status.isSmallerThanValue(3)))
        .write(const LocalMessagesCompanion(status: Value(3)));

    await (db.update(db.localConversations)..where((c) => c.conversID.equals(conversationID)))
        .write(const LocalConversationsCompanion(unreadCount: Value(0)));
      });
    }

  /// Fait monter le statut de MES messages envoyés dans une conversation,
  /// et pose l'horodatage précis reçu dans l'évènement socket
  /// `message:status`. [at] est l'instant exact (serveur) de la remise/lecture.
  /// Le fuseau horaire n'a pas besoin d'être repassé ici : il est déjà
  /// connu via `messageTz`, fixé une seule fois à l'envoi du message.
  /// status 2=livré → deliveredAt ; status 3=lu → readAt.
  Future<void> bumpMyMessagesStatus(
    int conversationID,
    int myId,
    int status, {
    DateTime? at,
  }) {
    var companion = LocalMessagesCompanion(status: Value(status));
    if (status == 2) {
      companion = companion.copyWith(
        deliveredAt: at != null ? Value(at) : const Value.absent(),
      );
    } else if (status == 3) {
      companion = companion.copyWith(
        readAt: at != null ? Value(at) : const Value.absent(),
      );
    }
    final query = db.update(db.localMessages)
      ..where((m) =>
          m.conversationID.equals(conversationID) &
          m.senderID.equals(myId) &
          m.status.isSmallerThanValue(status));
    final future = query.write(companion);
    if (status == 3 && at != null) {
      // "Lu" implique forcément "livré" : si la conversation était déjà
      // ouverte côté destinataire, l'appli saute directement au statut "lu"
      // sans jamais émettre d'accusé "livré" séparé — deliveredAt resterait
      // sinon null pour toujours. Le serveur applique le même COALESCE.
      return future.then((_) => (db.update(db.localMessages)
            ..where((m) =>
                m.conversationID.equals(conversationID) &
                m.senderID.equals(myId) &
                m.status.equals(3) &
                m.deliveredAt.isNull()))
          .write(LocalMessagesCompanion(deliveredAt: Value(at))));
    }
    return future;
  }

  /// Monte le statut affiché sur l'aperçu de conversation, uniquement si le
  /// dernier message est le mien (accusé ✓ / ✓✓ / ✓✓ bleu). Jamais en arrière.
  Future<void> bumpConvLastStatusIfMine(int conversID, int myId, int status) {
    return (db.update(db.localConversations)
          ..where((c) =>
              c.conversID.equals(conversID) &
              c.lastMessageSenderID.equals(myId) &
              (c.lastMessageStatus.isNull() |
                  c.lastMessageStatus.isSmallerThanValue(status))))
        .write(LocalConversationsCompanion(lastMessageStatus: Value(status)));
  }

  /// Aligne `lastMessageStatus` sur le statut réel de mon dernier message
  /// (évite l'écart liste vs conversation quand l'aperçu cache est stale).
  Future<void> reconcileLastMessageStatus(int conversID, int myId) async {
    final conv = await (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(conversID)))
        .getSingleOrNull();
    if (conv == null || conv.lastMessageSenderID != myId) return;

    final latestMine = await (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversID) &
              m.senderID.equals(myId) &
              m.isDeleted.equals(false))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (latestMine == null) return;

    final cached = conv.lastMessageStatus ?? 0;
    if (latestMine.status > cached) {
      await (db.update(db.localConversations)
            ..where((c) =>
                c.conversID.equals(conversID) &
                c.lastMessageSenderID.equals(myId)))
          .write(LocalConversationsCompanion(
        lastMessageStatus: Value(latestMine.status),
      ));
    }
  }

  Future<void> reconcileAllLastMessageStatuses(int myId) async {
    if (myId == 0) return;
    final convs = await (db.select(db.localConversations)
          ..where((c) => c.lastMessageSenderID.equals(myId)))
        .get();
    for (final conv in convs) {
      await reconcileLastMessageStatus(conv.conversID, myId);
    }
  }

  Future<List<LocalConversation>> getAllConversations() {
    return db.select(db.localConversations).get();
  }

  /// Marque un message comme définitivement échoué. Sort de l'outbox : il ne sera
  /// pas retenté automatiquement. L'utilisateur peut relancer via [retryFailed].
  Future<void> markFailed(String clientId) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(const LocalMessagesCompanion(status: Value(4), syncPending: Value(false)));
  }

  /// Incrémente le compteur de retry pour un message identifié par `clientId`.
  Future<void> incrementRetryCount(String clientId) async {
    final row = await (db.select(db.localMessages)..where((m) => m.clientId.equals(clientId))).getSingleOrNull();
    final current = row?.retryCount ?? 0;
    await (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
      .write(LocalMessagesCompanion(retryCount: Value(current + 1)));
  }

  /// Variante de soft-delete « pour moi seulement » : pose `deletedForID = userId`
  /// sans toucher au flag `isDeleted` (la cellule reste visible côté l'autre device).
  Future<void> softDeleteForUser(int msgID, int userId) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(deletedForID: Value(userId)));
  }

  Future<void> updateContentByServerId(int msgID, String content) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(content: Value(content), isEdited: const Value(true)));
  }

  Future<void> softDeleteByServerId(int msgID) {
    return softDeleteManyByServerId([msgID]);
  }

  Future<void> softDeleteManyByServerId(List<int> msgIDs) {
    if (msgIDs.isEmpty) return Future.value();
    if (msgIDs.length == 1) {
      return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgIDs.first)))
          .write(const LocalMessagesCompanion(isDeleted: Value(true)));
    }
    return db.batch((batch) {
      for (final id in msgIDs) {
        batch.update(
          db.localMessages,
          const LocalMessagesCompanion(isDeleted: Value(true)),
          where: (m) => m.msgID.equals(id),
        );
      }
    });
  }

  Future<void> softDeleteManyForUser(List<int> msgIDs, int userId) {
    if (msgIDs.isEmpty) return Future.value();
    if (msgIDs.length == 1) {
      return softDeleteForUser(msgIDs.first, userId);
    }
    return db.batch((batch) {
      for (final id in msgIDs) {
        batch.update(
          db.localMessages,
          LocalMessagesCompanion(deletedForID: Value(userId)),
          where: (m) => m.msgID.equals(id),
        );
      }
    });
  }

  /// Supprime les messages en attente de confirmation (msgID = 0) dans une
  /// conversation. Utilisé quand l'utilisateur supprime un message juste après
  /// l'avoir envoyé, avant que le serveur n'assigne le msgID définitif.
  Future<void> softDeletePendingMessages(
    int conversationID,
    int userId, {
    bool forAll = false,
  }) {
    if (forAll) {
      return (db.update(db.localMessages)
            ..where((m) =>
                m.conversationID.equals(conversationID) &
                m.senderID.equals(userId) &
                m.msgID.equals(0)))
          .write(const LocalMessagesCompanion(isDeleted: Value(true)));
    }
    return (db.update(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(userId) &
              m.msgID.equals(0)))
        .write(LocalMessagesCompanion(deletedForID: Value(userId)));
  }

  Future<void> setLocalMediaPath(int msgID, String path) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(localMediaPath: Value(path)));
  }

  Future<void> clearLocalMediaPath(int msgID) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(const LocalMessagesCompanion(localMediaPath: Value(null)));
  }

  /// Messages vocaux (type 3) d'une conversation, pour réconciliation des chemins locaux.
  Future<List<LocalMessage>> getVoiceMessages(int conversationID) {
    return (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) & m.type.equals(3)))
        .get();
  }

  /// Marque un média vue unique comme consommé : pose `viewedAt` et efface
  /// toute trace exploitable (URL réseau + chemin local) pour empêcher toute
  /// ré-ouverture.
  Future<void> markViewedByServerId(int msgID) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(
      viewedAt: Value(DateTime.now()),
      mediaUrl: const Value(null),
      localMediaPath: const Value(null),
    ));
  }

  /// (Dés)épingle un message identifié par son msgID serveur.
  Future<void> setMessagePinnedByServerId(int msgID, bool pinned) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(isPinned: Value(pinned)));
  }

  /// Flux réactif des messages épinglés d'une conversation (récents d'abord),
  /// pour alimenter la bannière « Message épinglé ». Exclut les messages
  /// supprimés et ceux masqués « pour moi ».
  Stream<List<LocalMessage>> watchPinnedMessages(int conversationID, int myId) {
    return (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.isPinned.equals(true) &
              m.isDeleted.equals(false) &
              (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> clearAll() async {
    await db.delete(db.localMessages).go();
    await db.delete(db.localConversations).go();
  }

  /// Supprime les conversations (et leurs messages) absentes de [keepIds].
  /// Appelé après un sync serveur réussi pour retirer les entrées obsolètes.
  Future<void> deleteConversationsNotIn(Set<int> keepIds) async {
    if (keepIds.isEmpty) {
      await clearAll();
      return;
    }
    await (db.delete(db.localMessages)
          ..where((m) => m.conversationID.isNotIn(keepIds)))
        .go();
    await (db.delete(db.localConversations)
          ..where((c) => c.conversID.isNotIn(keepIds)))
        .go();
  }

 
  /// Purge agressive : ne supprime que les optimistes vraiment fantômes
  /// (msgID=0 ET senderID=0 ET plus dans l'outbox). On évite de jeter des
  /// confirmations serveur dont le `senderID` aurait été corrompu.
  Future<int> purgeGhostMessages() {
      final onHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      return (db.delete(db.localMessages)
        ..where((m) =>
        m.clientId.like('c_%') &
        m.msgID.equals(0) &
        m.syncPending.equals(false) &
        m.sendAt.isSmallerThanValue(onHourAgo)))
      .go();
  }

 
  Future<void> purgeDuplicateOptimistics() async {
    // Charger uniquement les optimistes et confirmations séparément pour éviter
    // de charger toute la table et faire des deletes sériels.
    final optimistics = await (db.select(db.localMessages)
          ..where((m) => m.msgID.equals(0)))
        .get();

    String sig(LocalMessage m) =>
        '${m.conversationID}|${m.senderID}|${m.content ?? ''}|${m.type}|${m.mediaName ?? ''}';

    final confirmedRows = await (db.select(db.localMessages)
          ..where((m) => m.msgID.isBiggerThanValue(0)))
        .get();
    final confirmed = confirmedRows.map(sig).toSet();

    final idsToDelete = <String>[];
    for (final m in optimistics) {
      if (confirmed.contains(sig(m))) idsToDelete.add(m.clientId);
    }

    if (idsToDelete.isNotEmpty) {
      for (final clientId in idsToDelete) {
        await (db.delete(db.localMessages)..where((t) => t.clientId.equals(clientId))).go();
      }
    }
  }

  /// Garantit qu'un même msgID (>0) n'a qu'une seule ligne  
  Future<void> purgeDuplicateByMsgId() async {
    final confirmed = await (db.select(db.localMessages)
          ..where((m) => m.msgID.isBiggerThanValue(0)))
        .get();

    final byMsg = <int, List<LocalMessage>>{};
    for (final m in confirmed) {
      (byMsg[m.msgID] ??= []).add(m);
    }

    final idsToDelete = <String>[];
    for (final entry in byMsg.entries) {
      if (entry.value.length < 2) continue;
      entry.value.sort((a, b) {
        final aSrv = a.clientId.startsWith('srv_') ? 0 : 1;
        final bSrv = b.clientId.startsWith('srv_') ? 0 : 1;
        return aSrv.compareTo(bSrv);
      });
      for (final m in entry.value.skip(1)) {
        idsToDelete.add(m.clientId);
      }
    }

    if (idsToDelete.isNotEmpty) {
      for (final clientId in idsToDelete) {
        await (db.delete(db.localMessages)..where((t) => t.clientId.equals(clientId))).go();
      }
    }
  }
}

// ── Helpers de (dé)sérialisation des participants ──────────────────────
String encodeParticipants(List<dynamic> participants) => jsonEncode(participants);

List<Map<String, dynamic>> decodeParticipants(String json) {
  try {
    final list = jsonDecode(json) as List;
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (_) {
    return [];
  }
}
