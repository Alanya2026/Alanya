import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../../talky_api_client.dart';
import '../../../talky_models.dart';
import 'conversation_merge.dart';

typedef UpsertServerMsg = Future<bool> Function(
  Map<String, dynamic> json, {
  bool prefetchMedia,
});

typedef ConvToCompanion = LocalConversationsCompanion Function(
  Conversation c,
  Map<String, dynamic> raw,
);

typedef ParseDate = DateTime? Function(dynamic v);

/// Sync HTTP conversations / messages avec merge monotonic.
class ConversationSync {
  ConversationSync({
    required TalkyApiClient api,
    required ChatDao dao,
    required int Function() myId,
    required UpsertServerMsg upsertServerMsg,
    required ConvToCompanion convToCompanion,
    required ParseDate parseDate,
  })  : _api = api,
        _dao = dao,
        _myId = myId,
        _upsertServerMsg = upsertServerMsg,
        _convToCompanion = convToCompanion,
        _parseDate = parseDate;

  final TalkyApiClient _api;
  final ChatDao _dao;
  final int Function() _myId;
  final UpsertServerMsg _upsertServerMsg;
  final ConvToCompanion _convToCompanion;
  final ParseDate _parseDate;

  Future<void> syncConversations() async {
    try {
      final raw = await _api.getConversations();
      final localById = {
        for (final c in await _dao.getAllConversations()) c.conversID: c,
      };
      final companions = <LocalConversationsCompanion>[];
      for (final j in raw.whereType<Map<String, dynamic>>()) {
        final conv = Conversation.fromJson(j);
        final local = localById[conv.conversID];
        final serverAt = _parseDate(conv.lastMessageAt);
        final pendingNewer = local != null &&
            await _dao.hasPendingNewerThan(conv.conversID, serverAt);
        companions.add(ConversationMerge.mergeConversation(
          server: conv,
          fromServer: _convToCompanion(conv, j),
          local: local,
          myId: _myId(),
          hasLocalPendingNewer: pendingNewer,
        ));
      }
      final serverIds = companions.map((c) => c.conversID.value).toSet();
      await _dao.upsertConversations(companions);
      await _dao.deleteConversationsNotIn(serverIds);
      await _dao.reconcileAllLastMessageStatuses(_myId());
    } catch (e) {
      debugPrint('[ConversationSync] syncConversations échouée: $e');
    }
  }

  Future<void> syncMessages(int conversationID, {bool delta = false}) async {
    try {
      List<dynamic> raw;
      if (delta) {
        final last = await _dao.maxServerMsgId(conversationID);
        raw = await _api.getMessages(
          conversationID,
          limit: 50,
          after: last > 0 ? last : null,
        );
      } else {
        raw = await _api.getMessages(conversationID, limit: 50);
      }
      for (final j in raw.whereType<Map<String, dynamic>>()) {
        await _upsertServerMsg(j, prefetchMedia: true);
      }
      await _dao.reconcileLastMessageStatus(conversationID, _myId());
    } catch (e) {
      debugPrint('[ConversationSync] syncMessages($conversationID) échouée: $e');
    }
  }

  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) async {
    try {
      final oldest = await _dao.minServerMsgId(conversationID);
      if (oldest == 0) return 0;
      final raw = await _api.getMessages(
        conversationID,
        limit: limit,
        before: oldest,
      );
      final list = raw.whereType<Map<String, dynamic>>().toList();
      for (final j in list) {
        await _upsertServerMsg(j, prefetchMedia: true);
      }
      return list.length;
    } catch (e) {
      debugPrint('[ConversationSync] loadOlderMessages échouée: $e');
      return 0;
    }
  }
}
