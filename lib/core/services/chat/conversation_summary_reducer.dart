import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../utils/media_album.dart';
import 'conversation_merge.dart';

/// Source unique de vérité pour l'état dérivé d'une conversation :
/// `lastMessage*`, `lastMessageStatus`, `unreadCount`.
///
/// Après **toute** mutation de la table `messages`, appeler [recompute].
class ConversationSummaryReducer {
  ConversationSummaryReducer(this._db, this._dao);

  final AppDatabase _db;
  final ChatDao _dao;

  /// Recalcule aperçu + unread + statut à partir des messages locaux.
  ///
  /// Fallback : si aucun message local visible, conserve `unreadCount` / aperçu
  /// déjà présents (valeur serveur d'une liste fraîche) sauf si [serverUnread]
  /// est fourni pour initialiser.
  Future<void> recompute(
    int conversID,
    int myId, {
    int? serverUnread,
  }) async {
    if (conversID == 0) return;

    await _db.transaction(() async {
      final conv = await (_db.select(_db.localConversations)
            ..where((c) => c.conversID.equals(conversID)))
          .getSingleOrNull();
      if (conv == null) return;

      final latest = await (_db.select(_db.localMessages)
            ..where((m) =>
                m.conversationID.equals(conversID) &
                (m.deletedForID.isNull() | m.deletedForID.equals(myId).not()))
            ..orderBy([
              (m) =>
                  OrderingTerm(expression: m.sendAt, mode: OrderingMode.desc),
              (m) =>
                  OrderingTerm(expression: m.msgID, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();

      // Aucun message local : fallback serveur / conserver l'existant.
      if (latest == null) {
        if (serverUnread != null && serverUnread != conv.unreadCount) {
          await (_db.update(_db.localConversations)
                ..where((c) => c.conversID.equals(conversID)))
              .write(LocalConversationsCompanion(
            unreadCount: Value(serverUnread),
          ));
        }
        return;
      }

      // Ne pas écraser un envoi optimiste plus récent que le dernier confirmé.
      if (latest.msgID > 0 &&
          await _dao.hasPendingNewerThan(conversID, latest.sendAt)) {
        // Unread toujours dérivé (même pendant pending).
        final unread = await _dao.countUnread(conversID, myId);
        if (unread != conv.unreadCount) {
          await (_db.update(_db.localConversations)
                ..where((c) => c.conversID.equals(conversID)))
              .write(LocalConversationsCompanion(unreadCount: Value(unread)));
        }
        return;
      }

      final mine = myId != 0 && latest.senderID == myId;
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
      final unread = await _dao.countUnread(conversID, myId);

      final needsUpdate = conv.lastMessageSenderID != latest.senderID ||
          conv.lastMessageType != latest.type ||
          conv.lastMessage != preview ||
          conv.lastMessageAt != latest.sendAt ||
          conv.lastMessageStatus != desiredStatus ||
          conv.unreadCount != unread;

      if (!needsUpdate) return;

      await (_db.update(_db.localConversations)
            ..where((c) => c.conversID.equals(conversID)))
          .write(LocalConversationsCompanion(
        lastMessage: Value(preview),
        lastMessageSenderID: Value(latest.senderID),
        lastMessageType: Value(latest.type),
        lastMessageAt: Value(latest.sendAt),
        lastMessageStatus: Value(desiredStatus),
        unreadCount: Value(unread),
      ));
    });
  }

  Future<void> recomputeAll(int myId) async {
    if (myId == 0) return;
    final convs = await _db.select(_db.localConversations).get();
    for (final conv in convs) {
      await recompute(conv.conversID, myId);
    }
  }

  /// Recalcule uniquement les conversations listées (évite O(n) systématique).
  Future<void> recomputeMany(Set<int> conversIDs, int myId) async {
    if (myId == 0 || conversIDs.isEmpty) return;
    for (final id in conversIDs) {
      if (id == 0) continue;
      await recompute(id, myId);
    }
  }
}
