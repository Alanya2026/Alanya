import 'dart:async';

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

/// Upsert batch de messages entrants. Retourne les conversID affectées.
typedef UpsertIncomingBatch = Future<Set<int>> Function(
  List<Map<String, dynamic>> jsons, {
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
    required UpsertIncomingBatch upsertIncomingBatch,
    required ConvToCompanion convToCompanion,
    required ParseDate parseDate,
    required Future<void> Function(int convId) recompute,
    required Future<void> Function(Set<int> convIds) recomputeMany,
  })  : _api = api,
        _dao = dao,
        _myId = myId,
        _upsertServerMsg = upsertServerMsg,
        _upsertIncomingBatch = upsertIncomingBatch,
        _convToCompanion = convToCompanion,
        _parseDate = parseDate,
        _recompute = recompute,
        _recomputeMany = recomputeMany;

  final ChatApi _api;
  final ChatDao _dao;
  final int Function() _myId;
  final UpsertServerMsg _upsertServerMsg;
  final UpsertIncomingBatch _upsertIncomingBatch;
  final ConvToCompanion _convToCompanion;
  final ParseDate _parseDate;
  final Future<void> Function(int convId) _recompute;
  final Future<void> Function(Set<int> convIds) _recomputeMany;

  Future<void> syncConversations() async {
    try {
      final raw = await _api.getConversations();
      final localById = {
        for (final c in await _dao.getAllConversations()) c.conversID: c,
      };

      final entries = <({Conversation conv, Map<String, dynamic> json})>[];
      final serverAts = <int, DateTime?>{};
      for (final j in raw.whereType<Map<String, dynamic>>()) {
        final conv = Conversation.fromJson(j);
        entries.add((conv: conv, json: j));
        serverAts[conv.conversID] = _parseDate(conv.lastMessageAt);
      }

      final pendingIds =
          await _dao.conversationIdsWithPendingNewerThan(serverAts);

      // Convs dont l'aperçu/unread serveur ≠ local (candidats recompute).
      final mergeChangedIds = <int>{};
      // Serveur en avance : recompute pré-delta interdit (écraserait l'aperçu).
      final serverAheadIds = <int>{};

      final companions = <LocalConversationsCompanion>[];
      for (final e in entries) {
        final local = localById[e.conv.conversID];
        final pending = pendingIds.contains(e.conv.conversID);
        final serverAt = serverAts[e.conv.conversID];

        if (ConversationMerge.previewOrUnreadDiffers(
          local: local,
          server: e.conv,
          parseDate: _parseDate,
        )) {
          mergeChangedIds.add(e.conv.conversID);
        }
        if (ConversationMerge.serverPreviewAhead(
          local: local,
          serverAt: serverAt,
          hasLocalPendingNewer: pending,
        )) {
          serverAheadIds.add(e.conv.conversID);
        }

        companions.add(ConversationMerge.mergeConversation(
          server: e.conv,
          fromServer: _convToCompanion(e.conv, e.json),
          local: local,
          myId: _myId(),
          hasLocalPendingNewer: pending,
        ));
      }
      final serverIds = companions.map((c) => c.conversID.value).toSet();
      await _dao.upsertConversations(companions);
      await _dao.deleteConversationsNotIn(serverIds);

      // Pré-delta : recompute ciblé (pas recomputeAll) — convs modifiées
      // par le merge, hors celles où le serveur est en avance sur le local.
      final preDeltaRecompute = <int>{
        ...mergeChangedIds.difference(serverAheadIds),
        ...pendingIds,
      };
      if (preDeltaRecompute.isNotEmpty) {
        await _recomputeMany(preDeltaRecompute);
      }

      // Delta : syncGlobalDelta recalcule déjà les convs touchées par page.
      // Couvre le cas « aperçu serveur plus récent » une fois les msgs ingestés.
      final deltaAffected = await syncGlobalDelta();
      // Sur DB fraîche, syncGlobalDelta ne fait rien. Précharge en arrière-plan.
      unawaited(bootstrapEmptyConversationMessages());

      final pendingOnly = pendingIds.difference(deltaAffected);
      if (pendingOnly.isNotEmpty) {
        await _recomputeMany(pendingOnly);
      }
    } catch (e) {
      debugPrint('[ConversationSync] syncConversations échouée: $e');
    }
  }

  /// Précharge les messages des conversations qui ont un aperçu serveur mais
  /// aucun message local confirmé (install fraîche, logout, sync à l'ouverture
  /// manqué). Utilise POST /messages/sync avec curseur 0 (= msgID > 0).
  Future<void> bootstrapEmptyConversationMessages() async {
    if (_myId() == 0) return;
    var guard = 0;
    while (guard++ < 20) {
      final cursors = await _emptyConversationBootstrapCursors();
      if (cursors.isEmpty) return;
      debugPrint(
        '[ConversationSync] bootstrap ${cursors.length} conv(s) sans messages locaux',
      );
      try {
        final resp = await _api.syncMessagesGlobal(cursors);
        final msgs = (resp['messages'] as List?) ?? const [];
        if (msgs.isNotEmpty) {
          final maps = <Map<String, dynamic>>[];
          for (final raw in msgs) {
            if (raw is! Map) continue;
            maps.add(Map<String, dynamic>.from(raw));
          }
          final affected =
              await _ingestSyncMessages(maps, prefetchMedia: true);
          if (affected.isNotEmpty) {
            await _recomputeMany(affected);
          }
        }
        if (resp['hasMore'] != true) break;
      } catch (e) {
        debugPrint('[ConversationSync] bootstrap global échoué: $e');
        break;
      }
    }

    // Filet : sync individuel pour les conv encore vides (API globale saturée).
    final convs = await _dao.getAllConversations();
    for (final c in convs) {
      if (c.lastMessageAt == null) continue;
      if (await _dao.maxServerMsgId(c.conversID) > 0) continue;
      await syncMessages(c.conversID);
    }
  }

  Future<Map<int, int>> _emptyConversationBootstrapCursors() async {
    final out = <int, int>{};
    final convs = await _dao.getAllConversations();
    for (final c in convs) {
      if (c.lastMessageAt == null) continue;
      if (await _dao.maxServerMsgId(c.conversID) > 0) continue;
      out[c.conversID] = 0;
    }
    return out;
  }

  /// Sync delta GLOBALE. Retourne les conversID dont des messages ont été
  /// upsertés (pour un recompute ciblé côté appelant).
  Future<Set<int>> syncGlobalDelta() async {
    final allAffected = <int>{};
    if (_myId() == 0) return allAffected;
    var guard = 0;
    while (guard++ < 20) {
      final cursors = await _dao.conversationCursors();
      if (cursors.isEmpty) return allAffected;
      final resp = await _api.syncMessagesGlobal(cursors);
      final msgs = (resp['messages'] as List?) ?? const [];
      if (msgs.isEmpty) return allAffected;
      final maps = <Map<String, dynamic>>[];
      for (final raw in msgs) {
        if (raw is! Map) continue;
        maps.add(Map<String, dynamic>.from(raw));
      }
      final affected = await _ingestSyncMessages(maps, prefetchMedia: true);
      allAffected.addAll(affected);
      // Recompute par page pour que l'UI (watch) avance pendant la pagination.
      if (affected.isNotEmpty) {
        await _recomputeMany(affected);
      }
      if (resp['hasMore'] != true) return allAffected;
    }
    return allAffected;
  }

  /// Partition incoming (batch) / outgoing (upsert individuel pour matching
  /// optimiste). Retourne les conversID touchées.
  Future<Set<int>> _ingestSyncMessages(
    List<Map<String, dynamic>> maps, {
    bool prefetchMedia = false,
  }) async {
    if (maps.isEmpty) return {};
    final myId = _myId();
    final incoming = <Map<String, dynamic>>[];
    final outgoing = <Map<String, dynamic>>[];
    for (final j in maps) {
      final sender = _toInt(j['senderID']);
      if (myId != 0 && sender == myId) {
        outgoing.add(j);
      } else {
        incoming.add(j);
      }
    }

    final affected = <int>{};
    if (incoming.isNotEmpty) {
      affected.addAll(
        await _upsertIncomingBatch(incoming, prefetchMedia: prefetchMedia),
      );
    }
    for (final j in outgoing) {
      await _upsertServerMsg(j, prefetchMedia: false);
      final cid = _toInt(j['conversationID']);
      if (cid != 0) affected.add(cid);
    }
    return affected;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> syncMessages(
    int conversationID, {
    bool delta = false,
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
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
        final maps = raw.whereType<Map<String, dynamic>>().toList();
        await _ingestSyncMessages(maps, prefetchMedia: true);
        await _recompute(conversationID);
        return;
      } catch (e) {
        debugPrint(
          '[ConversationSync] syncMessages($conversationID) échouée '
          '(tentative $attempt/$maxAttempts): $e',
        );
        if (attempt == maxAttempts) return;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }

  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) async {
    try {
      final oldest = await _dao.minServerMsgId(conversationID);
      if (oldest == 0) {
        // Après logout/re-login la DB est vide ; si le sync initial a échoué,
        // le scroll vers le haut doit quand même déclencher un premier fetch.
        await syncMessages(conversationID);
        final loaded = await _dao.minServerMsgId(conversationID);
        return loaded == 0 ? 0 : 1;
      }
      final raw = await _api.getMessages(
        conversationID,
        limit: limit,
        before: oldest,
      );
      final list = raw.whereType<Map<String, dynamic>>().toList();
      await _ingestSyncMessages(list, prefetchMedia: true);
      return list.length;
    } catch (e) {
      debugPrint('[ConversationSync] loadOlderMessages échouée: $e');
      return 0;
    }
  }
}
