import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../../talky_models.dart';
import 'chat_api.dart';
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
    required ChatApi api,
    required ChatDao dao,
    required int Function() myId,
    required UpsertServerMsg upsertServerMsg,
    required ConvToCompanion convToCompanion,
    required ParseDate parseDate,
    required Future<void> Function(int convId) recompute,
    required Future<void> Function() recomputeAll,
  })  : _api = api,
        _dao = dao,
        _myId = myId,
        _upsertServerMsg = upsertServerMsg,
        _convToCompanion = convToCompanion,
        _parseDate = parseDate,
        _recompute = recompute,
        _recomputeAll = recomputeAll;

  final ChatApi _api;
  final ChatDao _dao;
  final int Function() _myId;
  final UpsertServerMsg _upsertServerMsg;
  final ConvToCompanion _convToCompanion;
  final ParseDate _parseDate;
  final Future<void> Function(int convId) _recompute;
  final Future<void> Function() _recomputeAll;

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
      await _recomputeAll();
      // Rapatrie les corps de messages manqués (source unique de vérité :
      // curseur par conversation). Garantit badge + aperçu + fil corrects
      // sans dépendre de la fiabilité du WebSocket.
      await syncGlobalDelta();
    } catch (e) {
      debugPrint('[ConversationSync] syncConversations échouée: $e');
    }
  }

  /// Sync delta GLOBALE, server-authoritative, basée sur un curseur PAR
  /// conversation. Récupère en une requête (paginée) tous les messages
  /// `msgID > curseur_local` de toutes les conversations connues, les upsert et
  /// recalcule l'état dérivé (aperçu, non-lus, statut).
  ///
  /// C'est LE filet de correction : quel que soit l'état du socket
  /// (arrière-plan, micro-déconnexion, event perdu), un passage ici remet le
  /// client à jour, sans trou. Le push socket `message:received` reste, mais
  /// n'est plus qu'une optimisation de latence.
  ///
  /// Idempotent, borné : uniquement les conversations ayant déjà des messages
  /// locaux (le premier chargement d'une conv se fait à l'ouverture). La
  /// pagination reconstruit les curseurs depuis le local à chaque tour → aucun
  /// message n'est sauté même si un seul tour ne suffit pas.
  Future<void> syncGlobalDelta() async {
    if (_myId() == 0) return;
    var guard = 0;
    while (guard++ < 20) {
      final cursors = await _dao.conversationCursors();
      if (cursors.isEmpty) return;
      final resp = await _api.syncMessagesGlobal(cursors);
      final msgs = (resp['messages'] as List?) ?? const [];
      if (msgs.isEmpty) return;
      final affected = <int>{};
      for (final raw in msgs) {
        if (raw is! Map) continue;
        final j = Map<String, dynamic>.from(raw);
        await _upsertServerMsg(j, prefetchMedia: true);
        final cid = _toInt(j['conversationID']);
        if (cid != 0) affected.add(cid);
      }
      for (final c in affected) {
        await _recompute(c);
      }
      if (resp['hasMore'] != true) return;
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
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
      await _recompute(conversationID);
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
