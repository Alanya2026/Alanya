import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class StatusProvider extends ChangeNotifier {
  final TalkyApiClient _api;

  StatusProvider({required TalkyApiClient api}) : _api = api;

  int _myId = 0;
  bool _bound = false;

  // alanyaID auteur → liste de ses statuts (croissant chronologique)
  final LinkedHashMap<int, List<Statut>> _byAuthor = LinkedHashMap();
  List<Statut> _mine = [];

  final Set<int> _seenIds = {};
  final Map<int, List<StatutView>> _viewsCache = {};

  bool _loading = false;
  Timer? _purgeTimer;

  Map<int, List<Statut>> get byAuthor => _byAuthor;
  List<Statut> get mine => _mine;
  bool get loading => _loading;

  bool hasUnseenFrom(int authorId) {
    final list = _byAuthor[authorId];
    if (list == null) return false;
    return list.any((s) => !_seenIds.contains(s.id));
  }

  int unseenCount(int authorId) =>
      _byAuthor[authorId]?.where((s) => !_seenIds.contains(s.id)).length ?? 0;

  int totalCount(int authorId) => _byAuthor[authorId]?.length ?? 0;

  /// Initialise les listeners socket et restaure la liste des "vus" persistés
  Future<void> bind(int myId) async {
    _myId = myId;
    if (!_bound) {
      _bound = true;
      _api.onSocketEvent(SocketEvents.statusCreated, _onStatusCreated);
      _api.onSocketEvent(SocketEvents.statusViewed, _onStatusViewed);
      _api.onSocketEvent(SocketEvents.statusLiked, _onStatusLiked);
      _api.onSocketEvent(SocketEvents.statusUnliked, _onStatusUnliked);
      _api.onSocketEvent(SocketEvents.statusDeleted, _onStatusDeleted);
      await _loadSeenIds();
      _purgeTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _purgeExpired(),
      );
    }
    await refresh();
  }

  void unbind() {
    if (!_bound) return;
    _bound = false;
    _api.offSocketEvent(SocketEvents.statusCreated);
    _api.offSocketEvent(SocketEvents.statusViewed);
    _api.offSocketEvent(SocketEvents.statusLiked);
    _api.offSocketEvent(SocketEvents.statusUnliked);
    _api.offSocketEvent(SocketEvents.statusDeleted);
    _purgeTimer?.cancel();
    _purgeTimer = null;
  }

  @override
  void dispose() {
    unbind();
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────────

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getStatuts(),
        _api.getMyStatuts(),
      ]);
      final others = results[0]
          .map((e) => Statut.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => !s.isExpired)
          .toList();
      _mine = results[1]
          .map((e) => Statut.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => !s.isExpired)
          .toList();

      _byAuthor.clear();
      for (final s in others) {
        _byAuthor.putIfAbsent(s.alanyaID, () => []).add(s);
        if (s.seenByMe) _seenIds.add(s.id);
      }

      // Trier les listes par date (ASC) pour le viewer auto-advance
      for (final list in _byAuthor.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _mine.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      debugPrint('[StatusProvider] refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Mutations ──────────────────────────────────────────────────

  Future<Statut?> createText({
    required String text,
    String? backgroundColor,
  }) async {
    try {
      final res =
          await _api.createStatut(text: text, backgroundColor: backgroundColor);
      final s = Statut.fromJson(Map<String, dynamic>.from(res));
      _mine.add(s);
      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[StatusProvider] createText error: $e');
      rethrow;
    }
  }

  Future<Statut?> createImage({required File imageFile}) async {
    try {
      final url = await _api.uploadAvatar(imageFile);
      final mediaUrl = url['url'] as String?;
      final res = await _api.createStatut(mediaUrl: mediaUrl, type: 1);
      final s = Statut.fromJson(Map<String, dynamic>.from(res));
      _mine.add(s);
      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[StatusProvider] createImage error: $e');
      rethrow;
    }
  }

  Future<Statut?> createVideo({required File videoFile}) async {
    try {
      final url = await _api.uploadAvatar(videoFile);
      final mediaUrl = url['url'] as String?;
      final res = await _api.createStatut(mediaUrl: mediaUrl, type: 2);
      final s = Statut.fromJson(Map<String, dynamic>.from(res));
      _mine.add(s);
      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[StatusProvider] createVideo error: $e');
      rethrow;
    }
  }

  Future<void> deleteStatut(int id) async {
    try {
      await _api.deleteStatut(id);
      _mine.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] deleteStatut error: $e');
      rethrow;
    }
  }

  Future<void> viewStatut(int id) async {
    try {
      await _api.viewStatut(id);
      _seenIds.add(id);
      // Mettre à jour l'état local
      for (final list in _byAuthor.values) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id) {
            list[i] = list[i].copyWith(seenByMe: true, viewedBy: list[i].viewedBy + 1);
            break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] viewStatut error: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(int id) async {
    try {
      final current =
          _byAuthor.values.expand((l) => l).firstWhere((s) => s.id == id);
      if (current.likedByMe) {
        await _api.unlikeStatut(id);
      } else {
        await _api.likeStatut(id);
      }
      // Mettre à jour l'état local
      for (final list in _byAuthor.values) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id) {
            final newLiked = !current.likedByMe;
            list[i] = list[i].copyWith(
              likedByMe: newLiked,
              likedBy: list[i].likedBy + (newLiked ? 1 : -1),
            );
            break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] toggleLike error: $e');
      rethrow;
    }
  }

  Future<List<StatutView>> getViews(int id) async {
    if (_viewsCache.containsKey(id)) {
      return _viewsCache[id]!;
    }
    try {
      final raw = await _api.getStatutViews(id);
      final views = raw
          .map((e) => StatutView.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _viewsCache[id] = views;
      return views;
    } catch (e) {
      debugPrint('[StatusProvider] getViews error: $e');
      return [];
    }
  }

  // ── Socket listeners ────────────────────────────────────────────

  void _onStatusCreated(dynamic event) {
    try {
      if (event is! Map) return;
      final s = Statut.fromJson(Map<String, dynamic>.from(event));
      if (s.alanyaID == _myId) {
        _mine.add(s);
      } else {
        _byAuthor.putIfAbsent(s.alanyaID, () => []).add(s);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _onStatusCreated error: $e');
    }
  }

  void _onStatusViewed(dynamic event) {
    try {
      if (event is! Map) return;
      final id = event['statutID'] as int?;
      if (id == null) return;
      for (final list in _byAuthor.values) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id) {
            list[i] = list[i].copyWith(viewedBy: list[i].viewedBy + 1);
            break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _onStatusViewed error: $e');
    }
  }

  void _onStatusLiked(dynamic event) {
    try {
      if (event is! Map) return;
      final id = event['statutID'] as int?;
      if (id == null) return;
      for (final list in _byAuthor.values) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id) {
            list[i] = list[i].copyWith(likedBy: list[i].likedBy + 1);
            break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _onStatusLiked error: $e');
    }
  }

  void _onStatusUnliked(dynamic event) {
    try {
      if (event is! Map) return;
      final id = event['statutID'] as int?;
      if (id == null) return;
      for (final list in _byAuthor.values) {
        for (int i = 0; i < list.length; i++) {
          if (list[i].id == id) {
            list[i] = list[i].copyWith(likedBy: list[i].likedBy - 1);
            break;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _onStatusUnliked error: $e');
    }
  }

  void _onStatusDeleted(dynamic event) {
    try {
      if (event is! Map) return;
      final id = event['ID'] as int?;
      if (id == null) return;
      for (final list in _byAuthor.values) {
        list.removeWhere((s) => s.id == id);
      }
      _mine.removeWhere((s) => s.id == id);
      _viewsCache.remove(id);
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _onStatusDeleted error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  void _purgeExpired() {
    bool changed = false;
    for (final list in _byAuthor.values) {
      final before = list.length;
      list.removeWhere((s) => s.isExpired);
      if (list.length != before) changed = true;
    }
    final before = _mine.length;
    _mine.removeWhere((s) => s.isExpired);
    if (_mine.length != before) changed = true;

    if (changed) notifyListeners();
  }

  Future<void> _loadSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('status_seen_ids_$_myId');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _seenIds.addAll(list.cast<int>());
      }
    } catch (e) {
      debugPrint('[StatusProvider] _loadSeenIds error: $e');
    }
  }

  Future<void> _persistSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('status_seen_ids_$_myId', jsonEncode(_seenIds.toList()));
    } catch (e) {
      debugPrint('[StatusProvider] _persistSeenIds error: $e');
    }
  }
}
