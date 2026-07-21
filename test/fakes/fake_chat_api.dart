import 'dart:async';
import 'dart:io';

import 'package:talky_flutter/core/services/chat/chat_api.dart';

/// Fake [ChatApi] en mémoire pour tests : socket = map de listeners + file
/// d'events émis ; HTTP = stubs configurables.
class FakeChatApi implements ChatApi {
  FakeChatApi({this.socketReady = true});

  bool socketReady;

  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final List<({String event, dynamic data})> sentEvents = [];
  final List<String> httpLog = [];

  /// Réponses HTTP configurables.
  List<dynamic> conversations = const [];
  final Map<int, List<dynamic>> messagesByConv = {};
  Map<String, dynamic> uploadResult = const {'url': 'https://cdn.test/m.jpg'};
  Object? uploadError;
  Object? markReadError;
  Object? editError;
  Object? deleteError;

  /// Incrémente à chaque `message:send` pour fabriquer des msgID uniques.
  int nextMsgId = 1000;

  /// Si true, [sendSocketEvent] pour `message:send` émule automatiquement
  /// un ack `message:sent` (idempotence clientId).
  bool autoAckSend = false;

  @override
  bool get isSocketReady => socketReady;

  int forceReconnectCalls = 0;

  @override
  Future<bool> forceReconnect() async {
    forceReconnectCalls++;
    return socketReady;
  }

  @override
  void onSocketEvent(String event, void Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  @override
  void removeSocketListener(String event, void Function(dynamic) callback) {
    _listeners[event]?.remove(callback);
  }

  @override
  void sendSocketEvent(String event, dynamic data) {
    sentEvents.add((event: event, data: data));
    if (autoAckSend &&
        event == 'message:send' &&
        data is Map &&
        socketReady) {
      final map = Map<String, dynamic>.from(data);
      final clientId = map['clientId']?.toString();
      final convID = map['conversationID'];
      final msgID = nextMsgId++;
      // Émet après le return pour laisser l'appelant finir.
      scheduleMicrotask(() {
        emit('message:sent', {
          'msgID': msgID,
          'clientId': clientId,
          'conversationID': convID,
          'senderID': map['senderID'] ?? 0,
          'content': map['content'],
          'type': map['type'] ?? 0,
          'status': 1,
          'sendAt': DateTime.now().toUtc().toIso8601String(),
          if (map['mediaUrl'] != null) 'mediaUrl': map['mediaUrl'],
          if (map['mediaName'] != null) 'mediaName': map['mediaName'],
          if (map['isViewOnce'] != null) 'isViewOnce': map['isViewOnce'],
        });
      });
    }
  }

  /// Déclenche manuellement un event socket vers les listeners enregistrés.
  void emit(String event, dynamic data) {
    final list = List<void Function(dynamic)>.from(_listeners[event] ?? const []);
    for (final cb in list) {
      cb(data);
    }
  }

  List<({String event, dynamic data})> eventsNamed(String event) =>
      sentEvents.where((e) => e.event == event).toList();

  @override
  Future<List<dynamic>> getConversations() async {
    httpLog.add('getConversations');
    return conversations;
  }

  @override
  Future<List<dynamic>> getMessages(
    int conversID, {
    int limit = 50,
    int? before,
    int? after,
  }) async {
    httpLog.add('getMessages:$conversID');
    return messagesByConv[conversID] ?? const [];
  }

  /// Réponse configurable pour la sync delta globale. Par défaut : delta par
  /// conversation dérivée de [messagesByConv] (messages avec msgID > curseur).
  List<dynamic>? globalSyncResult;

  @override
  Future<Map<String, dynamic>> syncMessagesGlobal(
    Map<int, int> cursors, {
    int limit = 300,
  }) async {
    httpLog.add('syncMessagesGlobal:${cursors.length}');
    if (globalSyncResult != null) {
      return {'messages': globalSyncResult, 'hasMore': false};
    }
    final out = <dynamic>[];
    cursors.forEach((convId, cursor) {
      for (final m in (messagesByConv[convId] ?? const [])) {
        final mid = m is Map ? (m['msgID'] as int? ?? 0) : 0;
        if (mid > cursor) out.add(m);
      }
    });
    out.sort((a, b) => ((a['msgID'] as int? ?? 0)).compareTo(b['msgID'] as int? ?? 0));
    return {'messages': out, 'hasMore': false};
  }

  @override
  Future<Map<String, dynamic>> uploadMedia(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    httpLog.add('uploadMedia');
    if (uploadError != null) throw uploadError!;
    onProgress?.call(1.0);
    return Map<String, dynamic>.from(uploadResult);
  }

  @override
  Future<void> markConversationAsRead(int conversID) async {
    httpLog.add('markConversationAsRead:$conversID');
    if (markReadError != null) throw markReadError!;
  }

  @override
  Future<Map<String, dynamic>> editMessage(int msgID, String content) async {
    httpLog.add('editMessage:$msgID');
    if (editError != null) throw editError!;
    return {'msgID': msgID, 'content': content};
  }

  @override
  Future<void> deleteMessages(List<int> msgIDs, {bool forAll = false}) async {
    httpLog.add('deleteMessages:${msgIDs.join(",")}:$forAll');
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<Map<String, dynamic>> batchForward({
    required List<int> sourceMsgIDs,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    httpLog.add('batchForward');
    return {'ok': true};
  }

  @override
  Future<void> pinMessage(int msgID, bool pinned) async {
    httpLog.add('pinMessage:$msgID:$pinned');
  }

  @override
  Future<void> markViewed(int msgID) async {
    httpLog.add('markViewed:$msgID');
  }

  @override
  Future<void> deleteConversations(List<int> conversationIDs) async {
    httpLog.add('deleteConversations');
  }

  @override
  Future<void> updateConversation(
    int conversID, {
    bool? isPinned,
    bool? isArchived,
  }) async {
    httpLog.add('updateConversation:$conversID');
  }

  @override
  Future<void> updateConversationsBatch(
    List<int> conversationIDs, {
    bool? isPinned,
    bool? isArchived,
  }) async {
    httpLog.add('updateConversationsBatch');
  }
}
