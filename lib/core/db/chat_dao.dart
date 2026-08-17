import 'dart:convert';

import 'package:drift/drift.dart';

import '../services/chat/conversation_merge.dart';
import '../services/translation/translation_state.dart';
import '../utils/call_log_preview.dart';
import '../utils/media_album.dart';
import '../utils/system_event_payload.dart';
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
    await (db.delete(db.localMessageReactions)..where((r) => r.conversationID.equals(conversID))).go();
  }

  /// Purge les messages antérieurs à [cutoff] (historique masqué / ré-ajout).
  ///
  /// Retourne le nombre de lignes effacées — l'appelant peut re-syncer si > 0.
  Future<int> deleteMessagesBefore(int conversID, DateTime cutoff) {
    return (db.delete(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversID) &
              m.sendAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> deleteConversations(List<int> conversIDs) async {
    if (conversIDs.isEmpty) return;
    if (conversIDs.length == 1) return deleteConversation(conversIDs.first);
    await (db.delete(db.localConversations)..where((c) => c.conversID.isIn(conversIDs))).go();
    await (db.delete(db.localMessages)..where((m) => m.conversationID.isIn(conversIDs))).go();
    await (db.delete(db.localMessageReactions)..where((r) => r.conversationID.isIn(conversIDs))).go();
  }

  /// @Deprecated('Unread dérivé via ConversationSummaryReducer / countUnread')
  Future<void> setUnread(int conversID, int count) {
    return (db.update(db.localConversations)..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(unreadCount: Value(count)));
  }

  /// Nombre de messages entrants non lus : `senderID != myId`, `status < 3`,
  /// non soft-deleted pour moi. Source de vérité pour `unreadCount` dérivé.
  Future<int> countUnread(int conversationID, int myId) async {
    if (myId == 0) return 0;
    final countExp = db.localMessages.clientId.count();
    final q = db.selectOnly(db.localMessages)
      ..addColumns([countExp])
      ..where(db.localMessages.conversationID.equals(conversationID) &
          db.localMessages.senderID.equals(myId).not() &
          db.localMessages.status.isSmallerThanValue(3) &
          db.localMessages.isDeleted.equals(false) &
          // Les messages système (« X a ajouté Y ») portent le senderID de
          // l'acteur : sans cette exclusion, l'action d'un tiers gonflerait le
          // badge alors que le serveur n'incrémente jamais l'unread pour eux.
          db.localMessages.type.equals(kSystemMessageType).not() &
          (db.localMessages.deletedForID.isNull() |
              db.localMessages.deletedForID.equals(myId).not()));
    final row = await q.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  /// Ids des messages non lus qui me mentionnent, du plus ancien au plus
  /// récent — l'ordre du bouton de saut, qui remonte le fil dans le sens de
  /// lecture.
  ///
  /// Entièrement dérivé du cache local : aucun champ serveur, aucune requête
  /// réseau. Le compteur suit donc `countUnread` — il tombe quand les messages
  /// passent en lu, pas au moment du saut, et ne peut pas devenir négatif.
  ///
  /// Le filtrage JSON se fait en Dart : la liste de mentions non lues d'une
  /// conversation est courte, et SQLite sans extension JSON1 garantie ne peut
  /// pas indexer `mentionsJson` de toute façon.
  Future<List<int>> unreadMentionMsgIds(int conversationID, int myId) async {
    if (myId == 0) return const [];
    final rows = await (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(myId).not() &
              m.status.isSmallerThanValue(3) &
              m.isDeleted.equals(false) &
              m.type.equals(kSystemMessageType).not() &
              m.mentionsJson.isNotNull() &
              (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
          ..orderBy([(m) => OrderingTerm.asc(m.sendAt)]))
        .get();

    final ids = <int>[];
    for (final m in rows) {
      if (m.msgID > 0 && mentionsUser(m.mentionsJson, myId)) {
        ids.add(m.msgID);
      }
    }
    return ids;
  }

  /// Le plus ancien message non lu — celui où la conversation doit s'ouvrir.
  ///
  /// Même définition du « non lu » que [countUnread], pour que le séparateur
  /// et le badge ne puissent pas se contredire.
  ///
  /// À appeler AVANT `markConversationRead` : ce dernier passe tout en
  /// `status = 3` et l'information disparaît. C'est pour ça que l'écran en
  /// prend un instantané figé à l'ouverture.
  ///
  /// `msgID` départage deux `sendAt` identiques — une rafale de messages peut
  /// partager la milliseconde, et `watchMessages` n'ordonne que par `sendAt`.
  Future<LocalMessage?> firstUnreadMessage(int conversationID, int myId) {
    if (myId == 0) return Future.value(null);
    return (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(myId).not() &
              m.status.isSmallerThanValue(3) &
              m.isDeleted.equals(false) &
              m.type.equals(kSystemMessageType).not() &
              (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
          ..orderBy([
            (m) => OrderingTerm.asc(m.sendAt),
            (m) => OrderingTerm.asc(m.msgID),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Total non lus toutes conversations (badge launcher).
  Future<int> countTotalUnread() async {
    final rows = await db.select(db.localConversations).get();
    return rows.fold<int>(0, (sum, c) => sum + c.unreadCount);
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
  /// le placeholder supprimé (sentinelle Drift + l10n à l'affichage).
  /// Ceux supprimés « pour moi » via [deletedForID] sont masqués pour cet
  /// utilisateur uniquement.
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

  /// Curseur par conversation pour la sync delta globale : pour chaque
  /// conversation ayant au moins un message confirmé (`msgID > 0`), son plus
  /// grand `msgID` local. Les conversations sans message confirmé sont exclues
  /// (leur premier chargement se fait à l'ouverture, pas via le delta global).
  Future<Map<int, int>> conversationCursors() async {
    final maxExpr = db.localMessages.msgID.max();
    final q = db.selectOnly(db.localMessages)
      ..addColumns([db.localMessages.conversationID, maxExpr])
      ..where(db.localMessages.msgID.isBiggerThanValue(0))
      ..groupBy([db.localMessages.conversationID]);
    final rows = await q.get();
    final out = <int, int>{};
    for (final r in rows) {
      final convId = r.read(db.localMessages.conversationID);
      final maxId = r.read(maxExpr);
      if (convId != null && maxId != null && maxId > 0) {
        out[convId] = maxId;
      }
    }
    return out;
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

  /// IDs serveur des messages entrants non lus (< status 3).
  Future<List<int>> unreadIncomingMsgIds(int conversationID, int myId) async {
    final rows = await (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(myId).not() &
              m.status.isSmallerThanValue(3)))
        .get();
    return rows
        .map((m) => m.msgID)
        .where((id) => id > 0)
        .toList();
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

    /// Marque comme lus tous les messages reçus d'une conversation et remet
    /// le badge à 0. Préférer [markConversationRead] +
    /// [ConversationSummaryReducer.recompute] (unread dérivé).
    Future<void> markConversationReadAtomic(int conversationID, int myId) async {
      await db.transaction(() async {
        await (db.update(db.localMessages)
              ..where((m) =>
                  m.conversationID.equals(conversationID) &
                  m.senderID.equals(myId).not() &
                  m.status.isSmallerThanValue(3)))
            .write(const LocalMessagesCompanion(status: Value(3)));

        await (db.update(db.localConversations)
              ..where((c) => c.conversID.equals(conversationID)))
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
          // Ne pas marquer « livré/lu » les envois encore non confirmés
          // (sinon ✓✓ bleu sur une vidéo jamais arrivée chez le destinataire).
          m.msgID.isBiggerThanValue(0) &
          m.syncPending.equals(false) &
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
                m.msgID.isBiggerThanValue(0) &
                m.syncPending.equals(false) &
                m.status.equals(3) &
                m.deliveredAt.isNull()))
          .write(LocalMessagesCompanion(deliveredAt: Value(at))));
    }
    return future;
  }

  /// Monte le statut affiché sur l'aperçu de conversation, uniquement si le
  /// dernier message est le mien (accusé ✓ / ✓✓ / ✓✓ bleu). Jamais en arrière.
  /// @Deprecated('Utiliser ConversationSummaryReducer.recompute')
  Future<void> bumpConvLastStatusIfMine(int conversID, int myId, int status) {
    return (db.update(db.localConversations)
          ..where((c) =>
              c.conversID.equals(conversID) &
              c.lastMessageSenderID.equals(myId) &
              (c.lastMessageStatus.isNull() |
                  c.lastMessageStatus.isSmallerThanValue(status))))
        .write(LocalConversationsCompanion(lastMessageStatus: Value(status)));
  }

  /// Aligne `lastMessage*` sur le dernier message local réel
  /// (évite l'écart liste vs conversation quand l'aperçu cache est stale).
  ///
  /// Important : met à jour **aussi** le texte d'aperçu et efface
  /// `lastMessageStatus` si le dernier message n'est pas le mien — sinon on
  /// peut afficher les ✓ à côté d'un message entrant (senderID remis à moi
  /// sans réaligner le texte).
  /// @Deprecated('Utiliser ConversationSummaryReducer.recompute')
  Future<void> reconcileLastMessageStatus(int conversID, int myId) async {
    final conv = await (db.select(db.localConversations)
          ..where((c) => c.conversID.equals(conversID)))
        .getSingleOrNull();
    if (conv == null) return;

    // Dernier message visible pour moi : on garde les messages « supprimés pour
    // tous » (isDeleted) car ils s'affichent comme placeholder « supprimé »,
    // mais on exclut ceux supprimés « pour moi » (deletedForID == myId).
    final latest = await (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversID) &
              (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc),
            (m) => OrderingTerm(expression: m.msgID, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (latest == null) return;

    // Ne pas écraser un envoi optimiste plus récent que le dernier confirmé.
    if (latest.msgID > 0 &&
        await hasPendingNewerThan(conversID, latest.sendAt)) {
      return;
    }

    // Même garde que dans `ConversationSummaryReducer` : un journal d'appel plus
    // récent que le dernier message est le dernier élément de la conversation.
    // Sans elle, les deux écrivains se disputeraient l'aperçu à chaque synchro.
    if (isCallLogPreviewType(conv.lastMessageType) &&
        conv.lastMessageAt != null &&
        !conv.lastMessageAt!.isBefore(latest.sendAt)) {
      return;
    }

    final mine = latest.senderID == myId;
    final preview = normalizeConversationPreview(
      latest.isDeleted
          ? ConversationMerge.deletedPreview
          : ConversationMerge.previewForMedia(
              latest.type,
              latest.content,
              latest.mediaName,
              isViewOnce: latest.isViewOnce,
            ),
    );
    final desiredStatus = mine ? latest.status : null;
    final desiredUnread = mine ? 0 : conv.unreadCount;

    final needsUpdate = conv.lastMessageSenderID != latest.senderID ||
        conv.lastMessageType != latest.type ||
        conv.lastMessage != preview ||
        conv.lastMessageAt != latest.sendAt ||
        conv.lastMessageStatus != desiredStatus ||
        (mine && conv.unreadCount != 0);

    if (!needsUpdate) return;

    await (db.update(db.localConversations)
          ..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(
      lastMessage: Value(preview),
      lastMessageSenderID: Value(latest.senderID),
      lastMessageType: Value(latest.type),
      lastMessageAt: Value(latest.sendAt),
      lastMessageStatus: Value(desiredStatus),
      unreadCount: Value(desiredUnread),
    ));
  }

  Future<void> reconcileAllLastMessageStatuses(int myId) async {
    if (myId == 0) return;
    final convs = await db.select(db.localConversations).get();
    for (final conv in convs) {
      await reconcileLastMessageStatus(conv.conversID, myId);
    }
  }

  /// True si un message optimiste (pending) est plus récent que [serverLastAt].
  Future<bool> hasPendingNewerThan(int conversID, DateTime? serverLastAt) async {
    final pending = await (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversID) &
              m.syncPending.equals(true) &
              m.isDeleted.equals(false))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (pending == null) return false;
    if (serverLastAt == null) return true;
    return pending.sendAt.isAfter(serverLastAt);
  }

  /// Batch de [hasPendingNewerThan] : 1 SELECT pour toutes les conversations.
  /// Retourne les conversID dont un pending local est plus récent que
  /// [serverLastAtByConv].
  Future<Set<int>> conversationIdsWithPendingNewerThan(
    Map<int, DateTime?> serverLastAtByConv,
  ) async {
    if (serverLastAtByConv.isEmpty) return {};
    final pending = await (db.select(db.localMessages)
          ..where((m) =>
              m.syncPending.equals(true) &
              m.isDeleted.equals(false) &
              m.conversationID.isIn(serverLastAtByConv.keys)))
        .get();
    if (pending.isEmpty) return {};

    final maxPendingAt = <int, DateTime>{};
    for (final m in pending) {
      final prev = maxPendingAt[m.conversationID];
      if (prev == null || m.sendAt.isAfter(prev)) {
        maxPendingAt[m.conversationID] = m.sendAt;
      }
    }

    final out = <int>{};
    for (final e in maxPendingAt.entries) {
      final serverAt = serverLastAtByConv[e.key];
      if (serverAt == null || e.value.isAfter(serverAt)) {
        out.add(e.key);
      }
    }
    return out;
  }

  /// Conversations où j'ai des messages entrants pas encore livrés (status &lt; 2).
  Future<List<int>> conversationIdsNeedingDelivery(int myId) async {
    final rows = await (db.selectOnly(db.localMessages)
          ..addColumns([db.localMessages.conversationID])
          ..where(db.localMessages.senderID.equals(myId).not() &
              db.localMessages.status.isSmallerThanValue(2) &
              db.localMessages.isDeleted.equals(false) &
              db.localMessages.msgID.isBiggerThanValue(0))
          ..groupBy([db.localMessages.conversationID]))
        .get();
    return rows
        .map((r) => r.read(db.localMessages.conversationID))
        .whereType<int>()
        .toList();
  }

  Future<List<LocalConversation>> getAllConversations() {
    return db.select(db.localConversations).get();
  }

  /// Marque un message comme définitivement échoué. Sort de l'outbox : il ne sera
  /// pas retenté automatiquement. L'utilisateur peut relancer via [retryFailed].
  /// Marque un envoi en échec. [failureCode] n'est renseigné que pour un REFUS
  /// serveur définitif : c'est lui qui permet de ne pas proposer un
  /// « réessayer » condamné à échouer.
  Future<void> markFailed(String clientId, {String? failureCode}) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(
      status: const Value(4),
      syncPending: const Value(false),
      failureCode: Value(failureCode),
    ));
  }

  /// True s'il existe au moins un message encore en outbox (horloge).
  Future<bool> hasSyncPending() async {
    final row = await (db.select(db.localMessages)
          ..where((m) =>
              m.syncPending.equals(true) &
              m.isDeleted.equals(false) &
              m.status.equals(0))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// True si un pending est dans l'outbox depuis plus de [olderThan]
  /// (basé sur [sendAt], indépendant de [lastEmittedAt]).
  Future<bool> hasStalePending({
    Duration olderThan = const Duration(seconds: 25),
  }) async {
    final sendThreshold = DateTime.now().toUtc().subtract(olderThan);
    final row = await (db.select(db.localMessages)
          ..where((m) =>
              m.syncPending.equals(true) &
              m.isDeleted.equals(false) &
              m.status.equals(0) &
              m.sendAt.isSmallerThanValue(sendThreshold))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Messages syncPending depuis trop longtemps (horloge coincée).
  /// Basé uniquement sur l'âge [sendAt] — pas sur [lastEmittedAt], sinon le
  /// flush périodique qui rafraîchit lastEmittedAt empêche à jamais le fail.
  Future<List<LocalMessage>> stuckPendingMessages({
    Duration olderThan = const Duration(minutes: 2),
  }) {
    final sendThreshold = DateTime.now().toUtc().subtract(olderThan);
    return (db.select(db.localMessages)
          ..where((m) =>
              m.syncPending.equals(true) &
              m.isDeleted.equals(false) &
              m.status.equals(0) &
              m.sendAt.isSmallerThanValue(sendThreshold)))
        .get();
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

  /// Supprime des messages en attente ciblés par [clientIds] (pas toute la conv).
  Future<void> softDeletePendingByClientIds(
    List<String> clientIds,
    int userId, {
    bool forAll = false,
  }) {
    if (clientIds.isEmpty) return Future.value();
    if (forAll) {
      return (db.update(db.localMessages)
            ..where((m) =>
                m.clientId.isIn(clientIds) &
                m.senderID.equals(userId) &
                m.msgID.equals(0)))
          .write(const LocalMessagesCompanion(
            isDeleted: Value(true),
            syncPending: Value(false),
          ));
    }
    return (db.update(db.localMessages)
          ..where((m) =>
              m.clientId.isIn(clientIds) &
              m.senderID.equals(userId) &
              m.msgID.equals(0)))
        .write(LocalMessagesCompanion(
          deletedForID: Value(userId),
          syncPending: const Value(false),
        ));
  }

  /// Supprime les messages en attente de confirmation (msgID = 0) dans une
  /// conversation. Préférer [softDeletePendingByClientIds] pour ne pas
  /// toucher tous les pending d'un coup.
  @Deprecated('Utiliser softDeletePendingByClientIds')
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

  // ── Traduction sur l'appareil ───────────────────────────────────────
  // Tout se clé sur `clientId` et non sur `msgID` : `msgID` vaut 0 tant que le
  // serveur n'a pas confirmé, donc y adosser une écriture toucherait d'un coup
  // tous les messages en attente d'accusé.

  /// Enregistre la traduction d'un message et le passe en
  /// [MessageTranslationState.done]. L'écriture réveille `watchMessages`, donc
  /// la bulle se met à jour d'elle-même.
  Future<void> setTranslation(
    String clientId, {
    required String content,
    required String sourceLang,
  }) {
    return (db.update(db.localMessages)
          ..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(
      translatedContent: Value(content),
      sourceLang: Value(sourceLang),
      translationState: const Value(MessageTranslationState.done),
    ));
  }

  /// Pose un état sans traduction (ignoré, modèle manquant, échec).
  Future<void> setTranslationState(String clientId, int state) {
    return (db.update(db.localMessages)
          ..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(translationState: Value(state)));
  }

  /// Messages d'une conversation restant à examiner, du plus récent au plus
  /// ancien : ce que l'utilisateur a sous les yeux se traduit avant ce qu'il a
  /// déjà dépassé en remontant le fil.
  Future<List<LocalMessage>> pendingTranslations(
    int conversationID, {
    int limit = 50,
  }) {
    return (db.select(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.translationState
                  .equals(MessageTranslationState.pending) &
              m.isDeleted.equals(false))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  /// Remet en file les messages bloqués faute de modèle, après installation
  /// d'une langue. On ne sait pas ici *quelle* langue manquait — l'état ne la
  /// mémorise pas — donc on relance tout le lot : le pipeline refiltrera, et
  /// ceux dont le modèle manque encore retomberont en
  /// [MessageTranslationState.missingModel] sans coût réseau.
  Future<void> retryMissingModelTranslations() {
    return (db.update(db.localMessages)
          ..where((m) => m.translationState
              .equals(MessageTranslationState.missingModel)))
        .write(const LocalMessagesCompanion(
      translationState: Value(MessageTranslationState.pending),
    ));
  }

  /// Efface toutes les traductions et remet chaque message à examiner.
  ///
  /// Appelé quand l'utilisateur change de langue de lecture : les traductions
  /// existantes visent l'ancienne langue et deviendraient trompeuses — une
  /// bulle affichant « traduit de l'anglais » dans une langue que l'utilisateur
  /// vient de quitter est pire qu'une bulle non traduite.
  Future<void> clearAllTranslations() {
    return db.update(db.localMessages).write(const LocalMessagesCompanion(
          translatedContent: Value(null),
          sourceLang: Value(null),
          translationState: Value(MessageTranslationState.pending),
        ));
  }

  /// Override de traduction d'une conversation : `null` quand elle suit le
  /// réglage global (ou quand la conversation n'est pas encore en cache).
  Future<int?> translateModeOf(int conversID) async {
    final row = await (db.selectOnly(db.localConversations)
          ..addColumns([db.localConversations.translateMode])
          ..where(db.localConversations.conversID.equals(conversID))
          ..limit(1))
        .getSingleOrNull();
    return row?.read(db.localConversations.translateMode);
  }

  /// Override de traduction d'une conversation (`null` = suit le global).
  Future<void> setConversationTranslateMode(int conversID, int? mode) {
    return (db.update(db.localConversations)
          ..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(translateMode: Value(mode)));
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

  // RÉACTIONS

  /// Réactions de toute la conversation (pas de stream par message : on
  /// regroupe côté écran via un `Map<msgID, List<LocalMessageReaction>>`,
  /// comme la présence/typing qui sont aussi tenues en mémoire par le
  /// provider plutôt qu'interrogées message par message).
  Stream<List<LocalMessageReaction>> watchReactions(int conversationID) {
    return (db.select(db.localMessageReactions)
          ..where((r) => r.conversationID.equals(conversationID)))
        .watch();
  }

  /// Pose/replace la réaction d'un utilisateur sur un message (upsert par PK
  /// composite `(msgID, userID)` : un nouvel emoji remplace l'ancien).
  Future<void> upsertReaction({
    required int msgID,
    required int userID,
    required int conversationID,
    required String emoji,
    DateTime? reactedAt,
  }) {
    return db.into(db.localMessageReactions).insertOnConflictUpdate(
          LocalMessageReactionsCompanion.insert(
            msgID: msgID,
            userID: userID,
            conversationID: conversationID,
            emoji: emoji,
            reactedAt: Value(reactedAt ?? DateTime.now()),
          ),
        );
  }

  Future<void> deleteReaction(int msgID, int userID) {
    return (db.delete(db.localMessageReactions)
          ..where((r) => r.msgID.equals(msgID) & r.userID.equals(userID)))
        .go();
  }

  /// Supprime toutes les réactions connues d'un message (utilisé quand le
  /// serveur renvoie l'état complet des réactions restantes après un retrait).
  Future<void> deleteReactionsForMessage(int msgID) {
    return (db.delete(db.localMessageReactions)..where((r) => r.msgID.equals(msgID))).go();
  }

  /// Remplace l'intégralité des réactions connues d'une conversation par
  /// [reactions] (hydratation initiale via `GET /conversations/:id/reactions`).
  /// Écrit dans une transaction pour ne jamais laisser un état partiel visible.
  Future<void> replaceReactionsForConversation(
    int conversationID,
    List<LocalMessageReactionsCompanion> reactions,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.localMessageReactions)
            ..where((r) => r.conversationID.equals(conversationID)))
          .go();
      if (reactions.isEmpty) return;
      await db.batch((b) => b.insertAll(db.localMessageReactions, reactions));
    });
  }

  /// Fusionne les réactions serveur sans effacer les écritures locales en cours
  /// ([preserveKeys] = `"msgID:userID"` pendant un PUT/DELETE HTTP).
  Future<void> mergeReactionsFromServer(
    int conversationID,
    List<LocalMessageReactionsCompanion> reactions, {
    Set<String> preserveKeys = const {},
  }) async {
    await db.transaction(() async {
      final serverKeys = <String>{};
      for (final reaction in reactions) {
        final msgID = reaction.msgID.value;
        final userID = reaction.userID.value;
        if (msgID == 0 || userID == 0 || reaction.emoji.value.isEmpty) continue;
        serverKeys.add('$msgID:$userID');
        await db.into(db.localMessageReactions).insertOnConflictUpdate(reaction);
      }

      final local = await (db.select(db.localMessageReactions)
            ..where((r) => r.conversationID.equals(conversationID)))
          .get();
      for (final row in local) {
        final key = '${row.msgID}:${row.userID}';
        if (serverKeys.contains(key) || preserveKeys.contains(key)) continue;
        await (db.delete(db.localMessageReactions)
              ..where((r) => r.msgID.equals(row.msgID) & r.userID.equals(row.userID)))
            .go();
      }
    });
  }

  Future<void> clearAll() async {
    await db.delete(db.localMessages).go();
    await db.delete(db.localConversations).go();
    await db.delete(db.localMessageReactions).go();
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

// ── Helpers de (dé)sérialisation des mentions ──────────────────────────
//
// Miroir de la colonne serveur `message.mentions` : `[45,46]`, ou `null` quand
// il n'y a aucune mention (on n'écrit pas `[]`, pour que la requête du
// compteur puisse filtrer sur `IS NOT NULL`).

String? encodeMentions(List<int>? ids) =>
    (ids == null || ids.isEmpty) ? null : jsonEncode(ids);

/// Marqueur d'un `@Tous` que le serveur n'a pas déplié (groupe > 256 membres),
/// pour ne pas alourdir chaque message de centaines d'ids.
const String kMentionAllMarker = 'all';

List<int> decodeMentions(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => (e is num) ? e.toInt() : int.tryParse('$e'))
        .whereType<int>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// Ce message me mentionne-t-il ?
///
/// À préférer à `decodeMentions(...).contains(myId)` : le marqueur « all »
/// n'est pas une liste, et un test par `contains` le manquerait entièrement —
/// un @Tous de grand groupe resterait invisible.
bool mentionsUser(String? json, int myId) {
  if (json == null || json.isEmpty || myId == 0) return false;
  try {
    final decoded = jsonDecode(json);
    if (decoded == kMentionAllMarker) return true;
    if (decoded is! List) return false;
    return decoded.any((e) {
      final id = (e is num) ? e.toInt() : int.tryParse('$e');
      return id == myId;
    });
  } catch (_) {
    return false;
  }
}
