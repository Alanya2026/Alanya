import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/db/app_database.dart';
import '../core/services/local_cache_repository.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class StatusProvider extends ChangeNotifier {
  final TalkyApiClient _api;
  final LocalCacheRepository? _cache;
  StatusProvider({required TalkyApiClient api, LocalCacheRepository? cache})
      : _api = api,
        _cache = cache;

  int _myId = 0;
  bool _bound = false;
  // alanyaID auteur → liste de ses statuts (ordre chronologique ASC)
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

  /// Initialise les listeners socket et restaure la liste des "vus" persistée.
  Future<void> bind(int myId) async {
    _myId = myId;
    if (!_bound) {
      _bound = true;
      _api.onSocketEvent(SocketEvents.statusCreated, _onStatusCreated);
      _api.onSocketEvent(SocketEvents.statusViewed,  _onStatusViewed);
      _api.onSocketEvent(SocketEvents.statusLiked,   _onStatusLiked);
      _api.onSocketEvent(SocketEvents.statusUnliked, _onStatusUnliked);
      _api.onSocketEvent(SocketEvents.statusDeleted, _onStatusDeleted);
      await _loadSeenIds();
      _purgeTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _purgeExpired(),
      );
    }
    // Hydrate depuis le cache local pour un affichage instantané (offline-safe)
    await _hydrateFromCache();
    await refresh();
  }

  /// Charge les statuts non expirés depuis Drift et alimente _byAuthor / _mine.
  Future<void> _hydrateFromCache() async {
    if (_cache == null) return;
    try {
      final rows = await _cache.watchStatuses().first;
      if (rows.isEmpty) return;
      _byAuthor.clear();
      _mine.clear();
      for (final r in rows) {
        final s = _localToStatut(r);
        if (s.isExpired) continue;
        if (r.isMine) {
          _mine.add(s);
        } else {
          _byAuthor.putIfAbsent(s.alanyaID, () => []).add(s);
        }
      }
      for (final list in _byAuthor.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _mine.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] _hydrateFromCache error: $e');
    }
  }

  Statut _localToStatut(LocalStatuse r) => Statut(
        id: r.idStatut,
        alanyaID: r.authorID,
        type: r.type,
        text: r.textContent,
        mediaUrl: r.mediaUrl,
        mediaDurationMs: r.mediaDurationMs,
        backgroundColor: r.backgroundColor,
        createdAt: r.createdAt.toIso8601String(),
        expiredAt: r.expiresAt.toIso8601String(),
        viewedBy: 0,
        likedBy: 0,
        likedByMe: false,
        seenByMe: _seenIds.contains(r.idStatut),
        nom: r.authorNom,
        avatarUrl: r.authorAvatar,
      );

  void unbind() {
    if (!_bound) return;
    _bound = false;
    _api.removeSocketListener(SocketEvents.statusCreated, _onStatusCreated);
    _api.removeSocketListener(SocketEvents.statusViewed, _onStatusViewed);
    _api.removeSocketListener(SocketEvents.statusLiked, _onStatusLiked);
    _api.removeSocketListener(SocketEvents.statusUnliked, _onStatusUnliked);
    _api.removeSocketListener(SocketEvents.statusDeleted, _onStatusDeleted);
    _purgeTimer?.cancel();
    _purgeTimer = null;
    // Purge l'état en mémoire pour ne pas exposer les statuts d'un compte
    // à l'utilisateur suivant en cas de logout/login dans la même session.
    _byAuthor.clear();
    _mine.clear();
    _seenIds.clear();
    _viewsCache.clear();
    _myId = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    unbind();
    super.dispose();
  }

  // ── Loading ──────────────────────────────────────────────────────────

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
      // Trier par date ASC pour le viewer auto-advance
      for (final list in _byAuthor.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _mine.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // Persiste dans Drift pour lecture offline au prochain démarrage.
      if (_cache != null) {
        for (final s in others) {
          await _cache.upsertStatus(s, isMine: false);
        }
        for (final s in _mine) {
          await _cache.upsertStatus(s, isMine: true);
        }
      }
    } catch (e) {
      debugPrint('[StatusProvider] refresh error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Mutations ────────────────────────────────────────────────────────

  Future<Statut?> createText({
    required String text,
    required String backgroundColor,
  }) async {
    try {
      final json = await _api.createStatut(
        text: text,
        backgroundColor: backgroundColor,
        type: 0,
      );
      final s = Statut.fromJson(json);
      _mine.add(s);
      await _cache?.upsertStatus(s, isMine: true);
      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[StatusProvider] createText error: $e');
      return null;
    }
  }

  Future<Statut?> createMedia({
    required File file,
    required int type, // 1=image, 2=video, 3=audio
    String? caption,
    int? mediaDurationMs,
  }) async {
    try {
      final upload = await _api.uploadMedia(file);
      final url = upload['url'] as String?;
      if (url == null) throw Exception('Upload sans URL');
      final json = await _api.createStatut(
        text: (caption?.isNotEmpty ?? false) ? caption : null,
        mediaUrl: url,
        type: type,
        mediaDurationMs: mediaDurationMs,
      );
      final s = Statut.fromJson(json);
      _mine.add(s);
      await _cache?.upsertStatus(s, isMine: true);
      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[StatusProvider] createMedia error: $e');
      return null;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _api.deleteStatut(id);
      _mine.removeWhere((s) => s.id == id);
      _viewsCache.remove(id);
      await _cache?.deleteStatusById(id);
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusProvider] delete error: $e');
    }
  }

  Future<void> markViewed(int id) async {
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);
    await _saveSeenIds();
    notifyListeners();
    try {
      await _api.viewStatut(id);
    } catch (e) {
      debugPrint('[StatusProvider] markViewed error: $e');
    }
  }

  Future<void> toggleLike(int id) async {
    final s = _findInOthers(id);
    if (s == null) return;
    final wasLiked = s.likedByMe;
    // Optimistic update
    _replaceInOthers(s.copyWith(
      likedByMe: !wasLiked,
      likedBy: (s.likedBy + (wasLiked ? -1 : 1)).clamp(0, 1 << 30),
    ));
    notifyListeners();
    try {
      if (wasLiked) {
        await _api.unlikeStatut(id);
      } else {
        await _api.likeStatut(id);
      }
    } catch (e) {
      // Revert on error
      _replaceInOthers(s);
      notifyListeners();
      debugPrint('[StatusProvider] toggleLike error: $e');
    }
  }

  Future<List<StatutView>> getViews(int id, {bool force = false}) async {
    // 1) Cache mémoire si présent et pas forcé.
    if (!force && _viewsCache.containsKey(id)) return _viewsCache[id]!;
    // 2) Cache persistant (SharedPreferences) en l'absence du cache mémoire.
    if (!_viewsCache.containsKey(id)) {
      final loaded = await _loadViewsForStatus(id);
      if (loaded != null) _viewsCache[id] = loaded;
    }
    // 3) Fetch API + persiste pour la prochaine fois.
    try {
      final list = await _api.getStatutViews(id);
      final views = list
          .map((e) => StatutView.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _viewsCache[id] = views;
      _saveViewsForStatus(id, views);
      return views;
    } catch (e) {
      debugPrint('[StatusProvider] getViews error: $e');
      return _viewsCache[id] ?? [];
    }
  }

  // ── Persistance vues (SharedPreferences) ────────────────────────────

  static String _viewsKey(int statutId) => 'status_views_$statutId';

  Future<List<StatutView>?> _loadViewsForStatus(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_viewsKey(id));
      if (raw == null) return null;
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return list
          .whereType<Map>()
          .map((e) => StatutView.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveViewsForStatus(int id, List<StatutView> views) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = views
          .map((v) => {
                'statutID': v.statutID,
                'alanyaID': v.alanyaID,
                'nom': v.nom,
                'pseudo': v.pseudo,
                'avatar_url': v.avatarUrl,
                'seenAt': v.seenAt,
                'liked': v.liked ? 1 : 0,
                'likedAt': v.likedAt,
              })
          .toList();
      await prefs.setString(_viewsKey(id), jsonEncode(json));
    } catch (_) {}
  }

  // ── Socket handlers ──────────────────────────────────────────────────

  void _onStatusCreated(dynamic data) {
    if (data == null) return;
    final s = Statut.fromJson(Map<String, dynamic>.from(data));
    if (s.alanyaID == _myId) return;
    final list = _byAuthor.putIfAbsent(s.alanyaID, () => []);
    if (!list.any((e) => e.id == s.id)) {
      list.add(s);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _cache?.upsertStatus(s, isMine: false);
      notifyListeners();
    }
  }

  void _onStatusViewed(dynamic data) {
    if (data == null) return;
    final m = Map<String, dynamic>.from(data);
    final statutID = m['statutID'] as int?;
    final viewer = m['viewer'] as Map?;
    final seenAt = m['seenAt']?.toString() ?? '';
    if (statutID == null || viewer == null) return;
    // Incrémente le compteur sur mon statut
    final idx = _mine.indexWhere((s) => s.id == statutID);
    if (idx >= 0) {
      _mine[idx] = _mine[idx].copyWith(viewedBy: _mine[idx].viewedBy + 1);
    }
    // Ajoute dans le cache des vues si chargé
    final cache = _viewsCache[statutID];
    if (cache != null) {
      final v = Map<String, dynamic>.from(viewer);
      v['statutID'] = statutID;
      v['seenAt'] = seenAt;
      v['liked'] = 0;
      if (!cache.any((x) => x.alanyaID == v['alanyaID'])) {
        cache.insert(0, StatutView.fromJson(v));
      }
    }
    notifyListeners();
  }

  void _onStatusLiked(dynamic data) {
    if (data == null) return;
    final m = Map<String, dynamic>.from(data);
    final statutID = m['statutID'] as int?;
    final viewer = m['viewer'] as Map?;
    final likedAt = m['likedAt']?.toString();
    if (statutID == null || viewer == null) return;
    final idx = _mine.indexWhere((s) => s.id == statutID);
    if (idx >= 0) {
      _mine[idx] = _mine[idx].copyWith(likedBy: _mine[idx].likedBy + 1);
    }
    final cache = _viewsCache[statutID];
    if (cache != null) {
      final viewerID = viewer['alanyaID'];
      final pos = cache.indexWhere((x) => x.alanyaID == viewerID);
      if (pos >= 0) {
        cache[pos] = cache[pos].copyWith(liked: true, likedAt: likedAt);
      } else {
        final v = Map<String, dynamic>.from(viewer);
        v['statutID'] = statutID;
        v['seenAt'] = likedAt ?? '';
        v['liked'] = 1;
        v['likedAt'] = likedAt;
        cache.insert(0, StatutView.fromJson(v));
      }
    }
    notifyListeners();
  }

  void _onStatusUnliked(dynamic data) {
    if (data == null) return;
    final m = Map<String, dynamic>.from(data);
    final statutID = m['statutID'] as int?;
    final viewerID = m['alanyaID'] as int?;
    if (statutID == null || viewerID == null) return;
    final idx = _mine.indexWhere((s) => s.id == statutID);
    if (idx >= 0) {
      final cur = _mine[idx];
      _mine[idx] = cur.copyWith(
        likedBy: (cur.likedBy - 1).clamp(0, 1 << 30),
      );
    }
    final cache = _viewsCache[statutID];
    if (cache != null) {
      final pos = cache.indexWhere((x) => x.alanyaID == viewerID);
      if (pos >= 0) {
        cache[pos] = cache[pos].copyWith(liked: false, likedAt: null);
      }
    }
    notifyListeners();
  }

  void _onStatusDeleted(dynamic data) {
    if (data == null) return;
    final m = Map<String, dynamic>.from(data);
    final id = m['ID'] as int?;
    final authorID = m['alanyaID'] as int?;
    if (id == null || authorID == null) return;
    final list = _byAuthor[authorID];
    if (list != null) {
      list.removeWhere((s) => s.id == id);
      if (list.isEmpty) _byAuthor.remove(authorID);
    }
    _mine.removeWhere((s) => s.id == id);
    _viewsCache.remove(id);
    _cache?.deleteStatusById(id);
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Statut? _findInOthers(int id) {
    for (final list in _byAuthor.values) {
      for (final s in list) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  void _replaceInOthers(Statut s) {
    final list = _byAuthor[s.alanyaID];
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == s.id);
    if (idx >= 0) list[idx] = s;
  }

  void _purgeExpired() {
    final keysToRemove = <int>[];
    _byAuthor.forEach((authorId, list) {
      list.removeWhere((s) => s.isExpired);
      if (list.isEmpty) keysToRemove.add(authorId);
    });
    for (final k in keysToRemove) {
      _byAuthor.remove(k);
    }
    _mine.removeWhere((s) => s.isExpired);
    notifyListeners();
  }

  // ── Seen persistence ─────────────────────────────────────────────────

  static const _seenKey = 'status_seen_ids';

  Future<void> _loadSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_seenKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is List) {
        _seenIds.addAll(list.whereType<int>());
      }
    } catch (_) {}
  }

  Future<void> _saveSeenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Limite à 1000 derniers ids vus
      final ids = _seenIds.toList();
      if (ids.length > 1000) {
        ids.removeRange(0, ids.length - 1000);
        _seenIds
          ..clear()
          ..addAll(ids);
      }
      await prefs.setString(_seenKey, jsonEncode(ids));
    } catch (_) {}
  }
}
