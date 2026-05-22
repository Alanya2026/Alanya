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

  ChatProvider({required TalkyApiClient api}) : _api = api {
    repository = ChatRepository(api: _api);
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
    if (isToday) return 'Vu(e) à $hm';
    if (isYesterday) return 'Vu(e) hier à $hm';
    return 'Vu(e) le ${ls.day}/${ls.month}';
  }
 
  Stream<List<LocalConversation>> watchConversations() => repository.watchConversations();
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      repository.watchMessages(conversationID);
 
  Future<void> bind(int myId) async {
    repository.bind(myId);
    if (!_bound) {
      _bound = true;
      _api.onSocketEvent(SocketEvents.presenceUpdated, _onPresenceUpdated); 
      _api.onSocketEvent(SocketEvents.authVerified, _onSocketReady);
    }
    await refreshConversations();
    await repository.flushOutbox();
  }

  void _onSocketReady(dynamic _) {
    repository.flushOutbox();
    refreshConversations();
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
