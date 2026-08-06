import 'dart:io';

/// Port réseau utilisé par le module chat (HTTP + socket).
///
/// Découple [ChatRepository] de [TalkyApiClient] pour permettre un fake en
/// mémoire dans les tests. Les méthodes listées ici sont le sous-ensemble
/// réellement consommé par le repo / sync / receipts.
abstract class ChatApi {
  bool get isSocketReady;

  void onSocketEvent(String event, void Function(dynamic) callback);
  void sendSocketEvent(String event, dynamic data);
  void removeSocketListener(String event, void Function(dynamic) callback);

  /// Teardown + reconnect même si le socket paraît prêt (zombie TCP).
  Future<bool> forceReconnect();

  Future<List<dynamic>> getConversations();

  Future<List<dynamic>> getMessages(
    int conversID, {
    int limit = 50,
    int? before,
    int? after,
  });

  /// Sync delta globale multi-conversations (curseur par conv).
  /// [cursors] = { conversID: dernierMsgIDLocal }. Renvoie
  /// `{ 'messages': List, 'hasMore': bool }`.
  Future<Map<String, dynamic>> syncMessagesGlobal(
    Map<int, int> cursors, {
    int limit = 300,
  });

  Future<Map<String, dynamic>> uploadMedia(
    File file, {
    void Function(double progress)? onProgress,
  });

  Future<void> markConversationAsRead(int conversID);

  /// Accusé de remise HTTP (rejeu des accusés déposés par la couche push).
  Future<void> markConversationDelivered(int conversID);

  Future<Map<String, dynamic>> editMessage(int msgID, String content);

  Future<void> deleteMessages(List<int> msgIDs, {bool forAll = false});

  Future<Map<String, dynamic>> batchForward({
    required List<int> sourceMsgIDs,
    required List<int> targetConversationIDs,
    String? caption,
  });

  Future<void> pinMessage(int msgID, bool pinned);

  Future<void> markViewed(int msgID);

  Future<void> setReaction(int msgID, String emoji);

  Future<void> removeReaction(int msgID);

  Future<List<dynamic>> getReactions(int conversID);

  Future<void> deleteConversations(List<int> conversationIDs);

  Future<void> updateConversation(
    int conversID, {
    bool? isPinned,
    bool? isArchived,
  });

  Future<void> updateConversationsBatch(
    List<int> conversationIDs, {
    bool? isPinned,
    bool? isArchived,
  });

  /// Rattrapage outbox HTTP (clientId → msgID serveur).
  Future<Map<String, dynamic>> getMessageStatusByClientId(String clientId);

  /// Messages sortants status=1 côté serveur (réconciliation).
  Future<List<dynamic>> getPendingOutgoingMessages();

  // ── GROUPES ───────────────────────────────────────────────────────
  //
  // Ces méthodes passaient auparavant en direct des écrans vers
  // TalkyApiClient. Elles remontent ici pour que le repository soit le seul
  // chemin d'écriture vers Drift (sinon la réponse HTTP et la trame socket
  // s'écrivent en concurrence sur la même ligne) — et pour être testables.
  //
  // Toutes renvoient la conversation enrichie, à upserter telle quelle.

  Future<Map<String, dynamic>> getConversation(int conversID);

  Future<Map<String, dynamic>> updateGroupInfo(
    int conversID, {
    String? groupName,
    String? groupPhoto,
    String? description,
  });

  Future<Map<String, dynamic>> updateGroupSettings(
    int conversID, {
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? hideHistoryForNewMembers,
    bool? onlyAdminsCanAddMembers,
  });

  Future<Map<String, dynamic>> ackGroupJoin(
    int conversID, {
    int? msgID,
  });

  Future<Map<String, dynamic>> addParticipants(
    int conversID,
    List<int> participantIDs,
  );

  /// Retire un membre. Idempotent : un membre déjà parti renvoie
  /// `{ alreadyGone: true }` et non une erreur.
  Future<Map<String, dynamic>> removeParticipant(int conversID, int userId);

  /// Promeut (1) ou rétrograde (0) un membre. Réservé au propriétaire.
  Future<Map<String, dynamic>> setParticipantRole(
    int conversID,
    int userId,
    int role,
  );

  Future<void> leaveGroup(int conversID);

  Future<Map<String, dynamic>> updateConversationMute(
    int conversID, {
    bool unmute,
    bool muteForever,
    DateTime? mutedUntil,
    bool? mentionsOnly,
  });
}
