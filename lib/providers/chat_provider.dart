import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/db/app_database.dart';
import '../core/db/chat_dao.dart';
import '../core/services/chat_repository.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';
 
class PresenceInfo {
  final bool online;
  final DateTime? lastSeen;
  const PresenceInfo({required this.online, this.lastSeen});
}
 
class ChatProvider extends ChangeNotifier {
  final TalkyApiClient _api;
  late final ChatRepository repository;

  final Map<int, PresenceInfo> _presence = {};
  bool _bound = false;
  Timer? _refreshDebounce;

  ChatProvider({required TalkyApiClient api, AppDatabase? database}) : _api = api {
    repository = ChatRepository(api: _api, database: database);
  }

  PresenceInfo? presenceOf(int userID) => _presence[userID];
 
  String presenceLabel(int userID) {
    final p = _presence[userID];
    if (p == null) return '';
    if (p.online) return 'En ligne';
    final ls = p.lastSeen?.toLocal();
    if (ls == null) return 'Hors ligne';
    final now = DateTime.now();
    final hm = '${ls.hour.toString().padLeft(2, '0')}:${ls.minute.toString().padLeft(2, '0')}';
    final isToday = ls.year == now.year && ls.month == now.month && ls.day == now.day;
    final yest = now.subtract(const Duration(days: 1));
    final isYesterday = ls.year == yest.year && ls.month == yest.month && ls.day == yest.day;
    if (isToday) return 'Vu à $hm';
    if (isYesterday) return 'Vu hier à $hm';
    return 'Vu le ${ls.day}/${ls.month}';
  }
 
  Stream<List<LocalConversation>> watchConversations() => repository.watchConversations();
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      repository.watchMessages(conversationID);

  /// Outbox réactif (compteur pour le badge sur l'onglet Discussions).
  Stream<int> pendingMessagesCount() async* {
    yield (await repository.dao.pendingMessages()).length;
    await for (final _ in repository.watchConversations()) {
      // Le badge se rafraîchit indirectement quand la liste de conv change
      // (envoi, ack, échec). Coût négligeable.
      yield (await repository.dao.pendingMessages()).length;
    }
  }
 
  Future<void> bind(int myId) async {
    await repository.bind(myId);
    if (!_bound) {
      _bound = true;
      _api.onSocketEvent(SocketEvents.presenceUpdated, _onPresenceUpdated);
      _api.onSocketEvent(SocketEvents.authVerified, _onSocketReady);
      _api.onSocketEvent(SocketEvents.messageReceived, _onConversationChanged);
      _api.onSocketEvent(SocketEvents.messageSent, _onConversationChanged);
      _api.onSocketEvent(SocketEvents.messageUpdated, _onConversationChanged);
      _api.onSocketEvent(SocketEvents.messageDeleted, _onConversationChanged);
      _api.onSocketEvent(SocketEvents.messageStatus, _onConversationChanged);
      _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationChanged);
    }
    await refreshConversations();
    await repository.flushOutbox();
  }

  /// Réinitialise l'état (listeners + présence) pour autoriser un nouveau
  /// `bind` après un logout dans la même session d'app.
  void unbind() {
    if (_bound) {
      _bound = false;
      _api.removeSocketListener(SocketEvents.presenceUpdated, _onPresenceUpdated);
      _api.removeSocketListener(SocketEvents.authVerified, _onSocketReady);
      _api.removeSocketListener(SocketEvents.messageReceived, _onConversationChanged);
      _api.removeSocketListener(SocketEvents.messageSent, _onConversationChanged);
      _api.removeSocketListener(SocketEvents.messageUpdated, _onConversationChanged);
      _api.removeSocketListener(SocketEvents.messageDeleted, _onConversationChanged);
      _api.removeSocketListener(SocketEvents.messageStatus, _onConversationChanged);
      _api.removeSocketListener(SocketEvents.conversationCreated, _onConversationChanged);
    }
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    repository.unbind();
    _presence.clear();
    notifyListeners();
  }

  Future<void> _onSocketReady(dynamic _) async {
    try {
      // Ordre critique : on flush l'outbox + accusés de lecture AVANT de
      // re-fetcher la liste, sinon le unreadCount serveur peut revenir > 0
      // et faire flickr le badge alors qu'on l'a déjà marqué lu offline.
      await repository.flushOutbox();
      await refreshConversations();
      await repository.resyncActiveConversation();
      repository.rejoinActiveRoom();
    } catch (e) {
      debugPrint('[ChatProvider] _onSocketReady: $e');
    }
  }

  void _onConversationChanged(dynamic _) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      refreshConversations();
    });
  }
 
  Future<void> refreshConversations() async {
    await repository.syncConversations();
    await _seedPresenceFromCache();
  }

  Future<void> _seedPresenceFromCache() async {
    final convs = await repository.dao.watchConversations().first;
    for (final c in convs) {
      for (final p in decodeParticipants(c.participantsJson)) {
        final uid = _toInt(p['alanyaID']);
        if (uid == 0 || _presence.containsKey(uid)) continue;
        _presence[uid] = PresenceInfo(
          online: p['is_online'] == 1 || p['is_online'] == true,
          lastSeen: DateTime.tryParse(p['last_seen']?.toString() ?? ''),
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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
