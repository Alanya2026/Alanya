import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class StatusProvider extends ChangeNotifier {
  final TalkyApiClient _api;

  StatusProvider({required TalkyApiClient api}) : _api = api;

  int _myId = 0;
  bool _bound = false;

  // LinkedHashMap: alanyaID auteur → liste de ses statuts (chronologique)
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
      await refresh();

      // Purge expired every 5 minutes
      _purgeTimer = Timer.periodic(
        Duration(minutes: 5),
        (_) => _purgeExpired(),
      );
    }
  }

  Future<void> unbind() async {
    _purgeTimer?.cancel();
    _bound = false;
  }

  Future<void> _loadSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('status_seen_ids_$_myId') ?? '[]';
      final ids = (jsonDecode(json) as List).cast<int>();
      _seenIds.addAll(ids);
    } catch (_) {}
  }

  Future<void> _saveSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'status_seen_ids_$_myId',
        jsonEncode(_seenIds.toList()),
      );
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      _loading = true;
      notifyListeners();

      // Get all statuses + filter mine
      final data = await _api.getStatuts();
      final all = (data as List)
          .map((json) => Statut.fromJson(json as Map<String, dynamic>))
          .toList();

      _byAuthor.clear();
      _mine = [];

      for (final s in all) {
        if (s.alanyaID == _myId) {
          _mine.add(s);
        } else {
          _byAuthor.putIfAbsent(s.alanyaID, () => []).add(s);
        }
      }

      _purgeExpired();
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createText(String text, {String? backgroundColor}) async {
    final res = await _api.createStatut(
      text: text,
      backgroundColor: backgroundColor,
      type: 0,
    );
    final s = Statut.fromJson(res);
    _mine.add(s);
    notifyListeners();
  }

  Future<void> createImage(File file) async {
    // Upload first
    final uploadRes = await _api.uploadMedia(file);
    final mediaUrl = uploadRes['url'] as String;

    final res = await _api.createStatut(mediaUrl: mediaUrl, type: 1);
    final s = Statut.fromJson(res);
    _mine.add(s);
    notifyListeners();
  }

  Future<void> createVideo(File file) async {
    // Upload first
    final uploadRes = await _api.uploadMedia(file);
    final mediaUrl = uploadRes['url'] as String;

    final res = await _api.createStatut(mediaUrl: mediaUrl, type: 2);
    final s = Statut.fromJson(res);
    _mine.add(s);
    notifyListeners();
  }

  Future<void> deleteStatut(int id) async {
    await _api.deleteStatut(id);
    _mine.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> viewStatut(int id) async {
    if (!_seenIds.contains(id)) {
      _seenIds.add(id);
      await _saveSeenIds();
      await _api.viewStatut(id);
      notifyListeners();
    }
  }

  Future<void> toggleLike(int id) async {
    try {
      final s = _findStatut(id);
      if (s == null) return;

      if (!s.likedByMe) {
        await _api.likeStatut(id);
        // Create new Statut with updated likedByMe and likedBy count
        final idx = _mine.indexWhere((x) => x.id == id);
        if (idx >= 0) {
          _mine[idx] = _mine[idx].copyWith(
            likedByMe: true,
            likedBy: s.likedBy + 1,
          );
        } else {
          // Update in byAuthor
          for (final list in _byAuthor.values) {
            final idx2 = list.indexWhere((x) => x.id == id);
            if (idx2 >= 0) {
              list[idx2] = list[idx2].copyWith(
                likedByMe: true,
                likedBy: s.likedBy + 1,
              );
              break;
            }
          }
        }
      } else {
        await _api.unlikeStatut(id);
        final idx = _mine.indexWhere((x) => x.id == id);
        if (idx >= 0) {
          _mine[idx] = _mine[idx].copyWith(
            likedByMe: false,
            likedBy: math.max(0, s.likedBy - 1),
          );
        } else {
          for (final list in _byAuthor.values) {
            final idx2 = list.indexWhere((x) => x.id == id);
            if (idx2 >= 0) {
              list[idx2] = list[idx2].copyWith(
                likedByMe: false,
                likedBy: math.max(0, s.likedBy - 1),
              );
              break;
            }
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<List<StatutView>> getViews(int id) async {
    if (_viewsCache.containsKey(id)) {
      return _viewsCache[id]!;
    }

    final data = await _api.getStatutViews(id);
    final views = (data as List)
        .map((json) => StatutView.fromJson(json as Map<String, dynamic>))
        .toList();

    _viewsCache[id] = views;
    return views;
  }

  Statut? _findStatut(int id) {
    for (final list in _byAuthor.values) {
      final s = list.firstWhere(
        (x) => x.id == id,
        orElse: () => null as Statut,
      );
      if (s != null) return s;
    }
    return _mine.firstWhere((x) => x.id == id, orElse: () => null as Statut);
  }

  void _purgeExpired() {
    final now = DateTime.now();
    _byAuthor.removeWhere((_, list) {
      list.removeWhere((s) => DateTime.parse(s.expiredAt).isBefore(now));
      return list.isEmpty;
    });
    _mine.removeWhere((s) => DateTime.parse(s.expiredAt).isBefore(now));
  }

  // Socket listeners
  void _onStatusCreated(dynamic data) {
    try {
      final s = Statut.fromJson(data as Map<String, dynamic>);
      _byAuthor.putIfAbsent(s.alanyaID, () => []).add(s);
      notifyListeners();
    } catch (_) {}
  }

  void _onStatusViewed(dynamic data) {
    try {
      final id = data['statusId'] as int;
      final s = _findStatut(id);
      if (s != null) {
        final idx = _mine.indexWhere((x) => x.id == id);
        if (idx >= 0) {
          _mine[idx] = _mine[idx].copyWith(viewedBy: s.viewedBy + 1);
        } else {
          for (final list in _byAuthor.values) {
            final idx2 = list.indexWhere((x) => x.id == id);
            if (idx2 >= 0) {
              list[idx2] = list[idx2].copyWith(viewedBy: s.viewedBy + 1);
              break;
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onStatusLiked(dynamic data) {
    try {
      final id = data['statusId'] as int;
      final s = _findStatut(id);
      if (s != null) {
        final idx = _mine.indexWhere((x) => x.id == id);
        if (idx >= 0) {
          _mine[idx] = _mine[idx].copyWith(likedBy: s.likedBy + 1);
        } else {
          for (final list in _byAuthor.values) {
            final idx2 = list.indexWhere((x) => x.id == id);
            if (idx2 >= 0) {
              list[idx2] = list[idx2].copyWith(likedBy: s.likedBy + 1);
              break;
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onStatusUnliked(dynamic data) {
    try {
      final id = data['statusId'] as int;
      final s = _findStatut(id);
      if (s != null) {
        final idx = _mine.indexWhere((x) => x.id == id);
        if (idx >= 0) {
          _mine[idx] = _mine[idx].copyWith(likedBy: math.max(0, s.likedBy - 1));
        } else {
          for (final list in _byAuthor.values) {
            final idx2 = list.indexWhere((x) => x.id == id);
            if (idx2 >= 0) {
              list[idx2] = list[idx2].copyWith(likedBy: math.max(0, s.likedBy - 1));
              break;
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onStatusDeleted(dynamic data) {
    try {
      final id = data['statusId'] as int;
      _byAuthor.forEach((_, list) => list.removeWhere((s) => s.id == id));
      _mine.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    unbind();
    super.dispose();
  }
}
