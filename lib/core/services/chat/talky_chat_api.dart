import 'dart:io';

import '../../../talky_api_client.dart';
import 'chat_api.dart';

/// Adaptateur : [TalkyApiClient] → [ChatApi].
///
/// Les endpoints chat/socket/media sont des extensions sur [TalkyApiClient] ;
/// elles ne satisfont pas `implements` Dart, d'où ce thin wrapper.
class TalkyChatApi implements ChatApi {
  TalkyChatApi(this._client);

  final TalkyApiClient _client;

  TalkyApiClient get client => _client;

  @override
  bool get isSocketReady => _client.isSocketReady;

  @override
  Future<bool> forceReconnect() => _client.forceReconnect();

  @override
  void onSocketEvent(String event, void Function(dynamic) callback) =>
      _client.onSocketEvent(event, callback);

  @override
  void sendSocketEvent(String event, dynamic data) =>
      _client.sendSocketEvent(event, data);

  @override
  void removeSocketListener(String event, void Function(dynamic) callback) =>
      _client.removeSocketListener(event, callback);

  @override
  Future<List<dynamic>> getConversations() => _client.getConversations();

  @override
  Future<List<dynamic>> getMessages(
    int conversID, {
    int limit = 50,
    int? before,
    int? after,
  }) =>
      _client.getMessages(
        conversID,
        limit: limit,
        before: before,
        after: after,
      );

  @override
  Future<Map<String, dynamic>> syncMessagesGlobal(
    Map<int, int> cursors, {
    int limit = 300,
  }) =>
      _client.syncMessagesGlobal(cursors, limit: limit);

  @override
  Future<Map<String, dynamic>> uploadMedia(
    File file, {
    void Function(double progress)? onProgress,
  }) =>
      _client.uploadMedia(file, onProgress: onProgress);

  @override
  Future<void> markConversationAsRead(int conversID) =>
      _client.markConversationAsRead(conversID);

  @override
  Future<Map<String, dynamic>> editMessage(int msgID, String content) =>
      _client.editMessage(msgID, content);

  @override
  Future<void> deleteMessages(List<int> msgIDs, {bool forAll = false}) =>
      _client.deleteMessages(msgIDs, forAll: forAll);

  @override
  Future<Map<String, dynamic>> batchForward({
    required List<int> sourceMsgIDs,
    required List<int> targetConversationIDs,
    String? caption,
  }) =>
      _client.batchForward(
        sourceMsgIDs: sourceMsgIDs,
        targetConversationIDs: targetConversationIDs,
        caption: caption,
      );

  @override
  Future<void> pinMessage(int msgID, bool pinned) =>
      _client.pinMessage(msgID, pinned);

  @override
  Future<void> markViewed(int msgID) => _client.markViewed(msgID);

  @override
  Future<void> deleteConversations(List<int> conversationIDs) =>
      _client.deleteConversations(conversationIDs);

  @override
  Future<void> updateConversation(
    int conversID, {
    bool? isPinned,
    bool? isArchived,
  }) =>
      _client.updateConversation(
        conversID,
        isPinned: isPinned,
        isArchived: isArchived,
      );

  @override
  Future<void> updateConversationsBatch(
    List<int> conversationIDs, {
    bool? isPinned,
    bool? isArchived,
  }) =>
      _client.updateConversationsBatch(
        conversationIDs,
        isPinned: isPinned,
        isArchived: isArchived,
      );

  @override
  Future<Map<String, dynamic>> getMessageStatusByClientId(String clientId) =>
      _client.getMessageStatusByClientId(clientId);

  @override
  Future<List<dynamic>> getPendingOutgoingMessages() =>
      _client.getPendingOutgoingMessages();
}
