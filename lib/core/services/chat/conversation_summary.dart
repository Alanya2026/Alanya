import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../utils/media_album.dart';

/// Mise à jour de l'aperçu conversation (lastMessage*).
class ConversationSummary {
  ConversationSummary(this._db);

  final AppDatabase _db;

  Future<void> bump({
    required int conversID,
    required String preview,
    required int type,
    required DateTime at,
    required int activeConversationID,
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
      // Nouveau dernier message : si aucun statut fourni, on efface les ✓
      // (sinon un message entrant gardait les accusés de mon ancien envoi).
      lastMessageStatus: status != null
          ? Value(status)
          : (senderID != null ? const Value(null) : const Value.absent()),
      // Envoi local ou message reçu dans le chat actif → badge à 0 tout de suite.
      // (fromOther=true uniquement hors écran : le +1 unread est géré plus bas.)
      unreadCount: fromOther ? const Value.absent() : const Value(0),
    );
    await _db.into(_db.localConversations).insertOnConflictUpdate(companion);
    if (fromOther && conversID != activeConversationID) {
      await _db.transaction(() async {
        final current = await (_db.select(_db.localConversations)
              ..where((c) => c.conversID.equals(conversID)))
            .getSingleOrNull();
        final next = (current?.unreadCount ?? 0) + 1;
        await (_db.update(_db.localConversations)
              ..where((c) => c.conversID.equals(conversID)))
            .write(LocalConversationsCompanion(unreadCount: Value(next)));
      });
    }
  }
}
