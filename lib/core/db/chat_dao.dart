import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

// ─────────────────────────────────────────────────────────────────────
//  Couche d'accès aux données locales (drift). Toutes les lectures de
//  l'UI passent par des streams réactifs : dès qu'une ligne change en
//  base, l'écran se met à jour automatiquement.
// ─────────────────────────────────────────────────────────────────────
class ChatDao {
  final AppDatabase db;
  ChatDao(this.db);

  // ── CONVERSATIONS ──────────────────────────────────────────────────

  /// Liste réactive des conversations, épinglées d'abord puis par date.
  Stream<List<LocalConversation>> watchConversations() {
    return (db.select(db.localConversations)
          ..orderBy([
            (c) => OrderingTerm(expression: c.isPinned, mode: OrderingMode.desc),
            (c) => OrderingTerm(expression: c.lastMessageAt, mode: OrderingMode.desc),
          ]))
        .watch();
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

  Future<void> setUnread(int conversID, int count) {
    return (db.update(db.localConversations)..where((c) => c.conversID.equals(conversID)))
        .write(LocalConversationsCompanion(unreadCount: Value(count)));
  }

  // ── MESSAGES ───────────────────────────────────────────────────────

  /// Messages d'une conversation (anciens → récents), masque les supprimés.
  Stream<List<LocalMessage>> watchMessages(int conversationID) {
    return (db.select(db.localMessages)
          ..where((m) => m.conversationID.equals(conversationID) & m.isDeleted.equals(false))
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
  Future<List<LocalMessage>> pendingMessages() {
    return (db.select(db.localMessages)
          ..where((m) => m.syncPending.equals(true))
          ..orderBy([(m) => OrderingTerm(expression: m.sendAt)]))
        .get();
  }

  /// Confirme un message optimiste : remplace clientId par les infos serveur.
  Future<void> confirmMessage({
    required String clientId,
    required int msgID,
    required int status,
  }) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(LocalMessagesCompanion(
      msgID: Value(msgID),
      status: Value(status),
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

  /// Fait monter le statut de MES messages envoyés dans une conversation
  /// jusqu'à `status` (ex. tous → livré/lu). N'abaisse jamais un statut.
  Future<void> bumpMyMessagesStatus(int conversationID, int myId, int status) {
    return (db.update(db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversationID) &
              m.senderID.equals(myId) &
              m.status.isSmallerThanValue(status)))
        .write(LocalMessagesCompanion(status: Value(status)));
  }

  Future<void> markFailed(String clientId) {
    return (db.update(db.localMessages)..where((m) => m.clientId.equals(clientId)))
        .write(const LocalMessagesCompanion(status: Value(4), syncPending: Value(true)));
  }

  Future<void> updateContentByServerId(int msgID, String content) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(content: Value(content), isEdited: const Value(true)));
  }

  Future<void> softDeleteByServerId(int msgID) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(const LocalMessagesCompanion(isDeleted: Value(true)));
  }

  Future<void> setLocalMediaPath(int msgID, String path) {
    return (db.update(db.localMessages)..where((m) => m.msgID.equals(msgID)))
        .write(LocalMessagesCompanion(localMediaPath: Value(path)));
  }

  Future<void> clearAll() async {
    await db.delete(db.localMessages).go();
    await db.delete(db.localConversations).go();
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
