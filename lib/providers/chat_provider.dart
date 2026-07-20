import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/db/app_database.dart';
import '../core/db/chat_dao.dart';
import '../core/services/chat_repository.dart';
import '../core/services/chat_sync_timer.dart';
import '../core/utils/forward_message.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';
import '../core/theme/locale_controller.dart';
 
class PresenceInfo {
  final bool online;
  final DateTime? lastSeen;
  const PresenceInfo({required this.online, this.lastSeen});
}

class TypingInfo {
  final int userID;
  final DateTime updatedAt;
  const TypingInfo({required this.userID, required this.updatedAt});
}
 
class ChatProvider extends ChangeNotifier {
  final TalkyApiClient _api;
  late final ChatRepository repository;
  ChatSyncTimer? _syncTimer;

  final Map<int, PresenceInfo> _presence = {};
  final Map<int, TypingInfo> _typing = {};
  final Map<int, Timer> _typingExpiry = {};
  bool _bound = false;
  Timer? _refreshDebounce;

  /// Hook optionnel après reconnexion socket (ex. refresh statuts).
  Future<void> Function()? onSocketReadyHook;

  ChatProvider({required TalkyApiClient api, AppDatabase? database}) : _api = api {
    repository = ChatRepository(api: _api, database: database);
    _syncTimer = ChatSyncTimer(repository);
  }

  PresenceInfo? presenceOf(int userID) => _presence[userID];

  /// Indique si un interlocuteur est en train d'écrire dans [conversationID].
  /// Pour les discussions 1-1, [partnerUserId] filtre sur l'autre participant.
  bool isPartnerTyping(int conversationID, {int? partnerUserId}) {
    final info = _typing[conversationID];
    if (info == null) return false;
    if (info.userID == repository.myId) return false;
    if (DateTime.now().difference(info.updatedAt) > const Duration(seconds: 4)) {
      return false;
    }
    if (partnerUserId != null && info.userID != partnerUserId) return false;
    return true;
  }
 
  String presenceLabel(int userID) {
    final p = _presence[userID];
    if (p == null) return '';
    if (p.online) return LocaleController.instance.l10n.online;
    final ls = p.lastSeen?.toLocal();
    if (ls == null) return LocaleController.instance.l10n.offline;
    final now = DateTime.now();
    final hm = '${ls.hour.toString().padLeft(2, '0')}:${ls.minute.toString().padLeft(2, '0')}';
    final isToday = ls.year == now.year && ls.month == now.month && ls.day == now.day;
    final yest = now.subtract(const Duration(days: 1));
    final isYesterday = ls.year == yest.year && ls.month == yest.month && ls.day == yest.day;
    if (isToday) return LocaleController.instance.l10n.seenAt(hm);
    if (isYesterday) return LocaleController.instance.l10n.seenYesterdayAt(hm);
    return LocaleController.instance.l10n.seenOnDate(ls.day, ls.month);
  }
 
  Stream<List<LocalConversation>> watchConversations() => repository.watchConversations();
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      repository.watchMessages(conversationID);

  Future<void> bind(int myId) async {
    await repository.bind(myId);
    if (!_bound) {
      _bound = true;
      _api.onSocketEvent(SocketEvents.presenceUpdated, _onPresenceUpdated);
      _api.onSocketEvent(SocketEvents.authVerified, _onSocketReady);
      // Les événements message mettent à jour Drift via ChatRepository ;
      // pas de refetch HTTP ici (écrasait l'aperçu optimiste).
      _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationCreated);
      _api.onSocketEvent(SocketEvents.typingStarted, _onTypingStarted);
      _api.onSocketEvent(SocketEvents.typingStopped, _onTypingStopped);
    }
    await refreshConversations();
    await repository.flushOutbox();
    _syncTimer?.start();
  }

  /// Réinitialise l'état (listeners + présence) pour autoriser un nouveau
  /// `bind` après un logout dans la même session d'app.
  void unbind() {
    _syncTimer?.stop();
    if (_bound) {
      _bound = false;
      _api.removeSocketListener(SocketEvents.presenceUpdated, _onPresenceUpdated);
      _api.removeSocketListener(SocketEvents.authVerified, _onSocketReady);
      _api.removeSocketListener(SocketEvents.conversationCreated, _onConversationCreated);
      _api.removeSocketListener(SocketEvents.typingStarted, _onTypingStarted);
      _api.removeSocketListener(SocketEvents.typingStopped, _onTypingStopped);
    }
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    for (final t in _typingExpiry.values) {
      t.cancel();
    }
    _typingExpiry.clear();
    repository.unbind();
    _presence.clear();
    _typing.clear();
    notifyListeners();
  }

  /// Efface le cache local des discussions (logout / changement de compte).
  Future<void> clearLocalSession() async {
    await repository.clearLocalSession();
    notifyListeners();
  }

  Future<void> _onSocketReady(dynamic _) async {
    try {
      // Ordre critique : outbox + accusés AVANT re-fetch liste.
      await repository.flushOutbox();
      await repository.flushReceiptsCatchUp();
      await refreshConversations();
      await repository.resyncActiveConversation();
      repository.rejoinActiveRoom();
      await onSocketReadyHook?.call();
    } catch (e) {
      debugPrint('[ChatProvider] _onSocketReady: $e');
    }
  }

  void _onConversationCreated(dynamic _) {
    // Nouvelle conversation : un catch-up liste est légitime.
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      refreshConversations();
    });
  }
 
  Future<void> refreshConversations() async {
    await repository.syncConversations();
    await _seedPresenceFromCache();
  }

  Future<ForwardResult> forwardMessage({
    required LocalMessage source,
    required List<int> targetConversationIDs,
    String? caption,
  }) {
    return repository.forwardMessage(
      source: source,
      targetConversationIDs: targetConversationIDs,
      caption: caption,
    );
  }

  Future<ForwardResult> forwardMessages({
    required List<LocalMessage> sources,
    required List<int> targetConversationIDs,
    String? caption,
  }) {
    return repository.forwardMessages(
      sources: sources,
      targetConversationIDs: targetConversationIDs,
      caption: caption,
    );
  }

  Future<void> deleteMessages(
    List<int> msgIDs, {
    bool forAll = false,
    int? conversationID,
    List<String>? clientIds,
  }) {
    return repository.deleteMessages(
      msgIDs,
      forAll: forAll,
      conversationID: conversationID,
      clientIds: clientIds,
    );
  }

  Future<void> setConversationsPinned(List<int> conversIDs, bool pinned) {
    return repository.setConversationsPinned(conversIDs, pinned);
  }

  Future<void> setConversationsArchived(List<int> conversIDs, bool archived) {
    return repository.setConversationsArchived(conversIDs, archived);
  }

  Future<void> deleteConversations(List<int> conversIDs) {
    return repository.deleteConversations(conversIDs);
  }

  Future<ForwardResult> forwardAlbum({
    required List<LocalMessage> sourceItems,
    required List<int> targetConversationIDs,
  }) {
    return repository.forwardAlbum(
      sourceItems: sourceItems,
      targetConversationIDs: targetConversationIDs,
    );
  }

  Future<void> _seedPresenceFromCache() async {
    final convs = await repository.dao.watchConversations().first;
    for (final c in convs) {
      for (final p in decodeParticipants(c.participantsJson)) {
        final uid = _toInt(p['alanyaID']);
        if (uid == 0) continue;
        final cachedOnline = p['is_online'] == 1 || p['is_online'] == true;
        final lastSeenRaw = p['last_seen'];
        final lastSeen = lastSeenRaw != null
            ? DateTime.tryParse(lastSeenRaw.toString())
            : null;
        // Présence masquée côté serveur (ex. utilisateur qui m'a bloqué).
        if (!cachedOnline && lastSeenRaw == null) {
          _presence[uid] = const PresenceInfo(online: false, lastSeen: null);
          continue;
        }
        if (_presence.containsKey(uid)) continue;
        _presence[uid] = PresenceInfo(
          online: cachedOnline,
          lastSeen: lastSeen,
        );
      }
    }
    notifyListeners();
  }

  void _onPresenceUpdated(dynamic data) {
    if (data is! Map) return;
    final userID = _toInt(data['userID']);
    if (userID == 0) return;
    _presence[userID] = PresenceInfo(
      online: data['online'] == true,
      lastSeen: DateTime.tryParse(data['lastSeen']?.toString() ?? ''),
    );
    notifyListeners();
  }

  void _onTypingStarted(dynamic data) {
    if (data is! Map) return;
    final convId = _toInt(data['conversationID']);
    final userID = _toInt(data['userID']);
    if (convId == 0 || userID == 0 || userID == repository.myId) return;
    _typing[convId] = TypingInfo(userID: userID, updatedAt: DateTime.now());
    _scheduleTypingExpiry(convId);
    notifyListeners();
  }

  void _onTypingStopped(dynamic data) {
    if (data is! Map) return;
    final convId = _toInt(data['conversationID']);
    if (convId == 0) return;
    _typingExpiry[convId]?.cancel();
    _typingExpiry.remove(convId);
    _typing.remove(convId);
    notifyListeners();
  }

  void _scheduleTypingExpiry(int conversationID) {
    _typingExpiry[conversationID]?.cancel();
    _typingExpiry[conversationID] = Timer(const Duration(seconds: 4), () {
      _typingExpiry.remove(conversationID);
      _typing.remove(conversationID);
      notifyListeners();
    });
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
