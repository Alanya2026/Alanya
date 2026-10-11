import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart' show TalkyException;
import '../../db/app_database.dart';
import '../../utils/sticker_payload.dart';
import 'sticker_api.dart';
import 'sticker_cache.dart';
import 'sticker_features.dart';

/// Un sticker avec le code de son pack (pour fabriquer le payload d'envoi).
class StickerEntry {
  const StickerEntry(this.sticker, this.pack);
  final LocalSticker sticker;
  final LocalStickerPack? pack;

  String get packCode => pack?.code ?? '';

  /// Pack Plus dont le droit manque (valeur du serveur).
  bool get locked => pack?.locked ?? false;

  StickerPayload get payload => StickerPayload(
        version: StickerPayload.currentVersion,
        pack: packCode,
        sid: sticker.stickerId,
        emoji: sticker.emoji,
        w: sticker.width,
        h: sticker.height,
        animated: sticker.animated,
      );
}

/// Catalogue, packs installés, favoris et récents des stickers.
///
/// **Le serveur tranche** (droits, quotas, URLs) ; ce module ne fait que
/// refléter ses réponses dans Drift pour l'affichage hors ligne. Le client API
/// et l'horloge sont injectables : les tests le nourrissent avec les fixtures
/// du contrat. Rien ici dans `chat_repository.dart`.
class StickerRepository {
  StickerRepository({
    required AppDatabase db,
    required StickerApi api,
    StickerCache? cache,
    DateTime Function()? now,
    StickerFeatures? features,
  })  : _db = db,
        _api = api,
        _cache = cache,
        _now = now ?? DateTime.now,
        features = features ?? StickerFeatures() {
    _instance = this;
  }

  static StickerRepository? _instance;

  /// Dépôt courant de l'application, pour les services sans contexte (refus
  /// d'envoi reçu par socket). Nul hors application (tests sans module).
  static StickerRepository? get maybeInstance => _instance;

  /// Plafond des récents conservés.
  static const int maxRecents = 30;

  /// Clés SharedPreferences du catalogue/état : le module les oublie à la
  /// déconnexion pour que le compte suivant relise tout (jamais de 304 sur
  /// les packs d'un autre compte).
  static const String catalogEtagKey = 'stickers_catalog_etag';
  static const String catalogVersionKey = 'stickers_catalog_version';
  static const String meVersionKey = 'stickers_me_version';

  /// Codes des packs officiels vus **disparaître** (archivés, A14) ou refusés
  /// par le serveur : la fiche d'un sticker de ces packs masque « Ajouter à un
  /// pack », « Signaler » et « Voir le pack ». Un pack republié en sort dès
  /// qu'il revient au catalogue ou dans `/me`.
  static const String unavailablePacksKey = 'stickers_unavailable_packs';

  /// Code serveur d'un pack officiel archivé ou jamais publié (contrat §4).
  static const String packUnavailableCode = 'STICKER_PACK_UNAVAILABLE';

  final AppDatabase _db;
  final StickerApi _api;
  final StickerCache? _cache;
  final DateTime Function() _now;

  /// Fonctionnalités ouvertes à ce compte (`GET /me` → `features`, contrat
  /// §4c) : l'option « Sticker animé » n'apparaît que si `animated` est vrai.
  /// Partagé avec `StickerCreationRepository`.
  final StickerFeatures features;

  /// `false` quand le serveur a fermé le module (routes en 404 sans code) :
  /// l'interface masque alors l'onglet Stickers — rien n'est révélé.
  final ValueNotifier<bool> available = ValueNotifier<bool>(true);

  /// Branché par l'application sur la synchro de mes packs créés (V1b,
  /// `StickerCreationRepository.syncCreated`) : appelé à la fin de [refresh] et
  /// sur `stickers:sync` « packs ». Nul tant que la création n'est pas câblée.
  Future<void> Function()? afterSync;

  // ── Lecture réactive ────────────────────────────────────────────────

  /// Catalogue officiel, dans l'ordre du serveur.
  Stream<List<LocalStickerPack>> watchCatalog() => (_db.select(_db.localStickerPacks)
        ..where((p) => p.owned.equals(false))
        ..orderBy([(p) => OrderingTerm(expression: p.catalogPosition)]))
      .watch();

  /// Packs **installés** (catalogue officiel), dans l'ordre choisi par
  /// l'utilisateur. Mes packs créés (V1b) ont leur propre liste
  /// ([StickerCreationRepository.watchCreated]) : le réordonnancement d'ici ne
  /// les touche pas.
  Stream<List<LocalStickerPack>> watchInstalled() => (_db.select(_db.localStickerPacks)
        ..where((p) => p.installed.equals(true) & p.owned.equals(false))
        ..orderBy([(p) => OrderingTerm(expression: p.position)]))
      .watch();

  /// Les packs d'où l'on peut **envoyer** : installés, puis mes packs créés.
  Stream<List<LocalStickerPack>> watchTray() => (_db.select(_db.localStickerPacks)
        ..where((p) => p.installed.equals(true) | p.owned.equals(true))
        ..orderBy([
          (p) => OrderingTerm(expression: p.owned),
          (p) => OrderingTerm(expression: p.position),
        ]))
      .watch();

  Stream<List<LocalSticker>> watchStickers(int packId) => (_db.select(_db.localStickers)
        ..where((s) => s.packId.equals(packId))
        ..orderBy([(s) => OrderingTerm(expression: s.position)]))
      .watch();

  Stream<List<StickerEntry>> watchFavorites() {
    final q = _db.select(_db.localStickerFavorites).join([
      innerJoin(_db.localStickers,
          _db.localStickers.stickerId.equalsExp(_db.localStickerFavorites.stickerId)),
      innerJoin(_db.localStickerPacks,
          _db.localStickerPacks.packId.equalsExp(_db.localStickers.packId)),
    ])
      ..orderBy([OrderingTerm(expression: _db.localStickerFavorites.position)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            StickerEntry(r.readTable(_db.localStickers),
                r.readTable(_db.localStickerPacks)),
        ]);
  }

  Stream<List<StickerEntry>> watchRecents() {
    final q = _db.select(_db.localStickerRecents).join([
      innerJoin(_db.localStickers,
          _db.localStickers.stickerId.equalsExp(_db.localStickerRecents.stickerId)),
      innerJoin(_db.localStickerPacks,
          _db.localStickerPacks.packId.equalsExp(_db.localStickers.packId)),
    ])
      ..orderBy([
        OrderingTerm(
            expression: _db.localStickerRecents.usedAt, mode: OrderingMode.desc)
      ])
      ..limit(maxRecents);
    return q.watch().map((rows) => [
          for (final r in rows)
            StickerEntry(r.readTable(_db.localStickers),
                r.readTable(_db.localStickerPacks)),
        ]);
  }

  Stream<Set<int>> watchFavoriteIds() => _db
      .select(_db.localStickerFavorites)
      .watch()
      .map((rows) => {for (final r in rows) r.stickerId});

  /// Le sticker [stickerId] avec son pack, s'il est connu localement.
  Future<StickerEntry?> entryFor(int stickerId) async {
    final s = await (_db.select(_db.localStickers)
          ..where((t) => t.stickerId.equals(stickerId)))
        .getSingleOrNull();
    if (s == null) return null;
    final p = await (_db.select(_db.localStickerPacks)
          ..where((t) => t.packId.equals(s.packId)))
        .getSingleOrNull();
    return StickerEntry(s, p);
  }

  Future<LocalStickerPack?> packByCode(String code) => (_db.select(_db.localStickerPacks)
        ..where((p) => p.code.equals(code)))
      .getSingleOrNull();

  // ── Synchronisation ─────────────────────────────────────────────────

  DateTime? _lastRefresh;

  /// [refresh] au plus une fois par [every] : appelé à chaque ouverture du
  /// plateau sans multiplier les requêtes.
  Future<void> ensureFresh({Duration every = const Duration(minutes: 10)}) async {
    final last = _lastRefresh;
    if (last != null && _now().difference(last) < every) return;
    _lastRefresh = _now();
    await refresh();
  }

  /// Catalogue + état de l'utilisateur + stickers des packs installés.
  /// Silencieux hors ligne (le cache local reste affiché).
  Future<void> refresh() async {
    await features.restore();
    await syncCatalog();
    await syncMe();
    await syncInstalledPacks();
    await _afterSync();
  }

  Future<void> _afterSync() async {
    try {
      await afterSync?.call();
    } catch (e) {
      debugPrint('[StickerRepository] synchro des créations échouée : $e');
    }
  }

  /// `GET /catalog` avec ETag. 304 : rien à faire.
  ///
  /// Un pack officiel que le catalogue ne renvoie plus est **indisponible**
  /// (archivé, A14) : il quitte Drift, installé ou non, avec ses stickers, ses
  /// favoris et ses récents. Les messages déjà reçus ne dépendent pas de ces
  /// tables (`mediaUrl` recopiée) et restent affichés. [ignoreEtag] force la
  /// relecture complète (événement `stickers:sync` « catalog »).
  Future<void> syncCatalog({bool ignoreEtag = false}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Pas d'ETag si le cache local est vide (base restaurée ou purgée) : un
      // 304 laisserait le catalogue vide.
      final hasLocal = (await (_db.select(_db.localStickerPacks)..limit(1)).get())
          .isNotEmpty;
      final res = await _api.getCatalog(
          etag: hasLocal && !ignoreEtag ? prefs.getString(catalogEtagKey) : null);
      available.value = true;
      if (res.notModified) return;
      final body = res.body;
      if (body is! Map) return;
      final packs = body['packs'];
      if (packs is! List) return;
      final seenCodes = <String>{};
      List<LocalStickerPack> gone = const [];
      await _db.transaction(() async {
        var i = 0;
        final seen = <int>{};
        for (final raw in packs) {
          if (raw is! Map) continue;
          final id = _asInt(raw['id']);
          final code = raw['code'];
          if (id == null || id <= 0 || code is! String || code.isEmpty) continue;
          seen.add(id);
          seenCodes.add(code);
          // `insertOnConflictUpdate` sur les seules colonnes du catalogue :
          // `installed` et `position` (état utilisateur) ne sont pas touchés.
          await _db.into(_db.localStickerPacks).insert(
                LocalStickerPacksCompanion(
                  packId: Value(id),
                  code: Value(code),
                  name: Value(_str(raw['name']) ?? code),
                  description: Value(_str(raw['description'])),
                  coverUrl: Value(_str(raw['cover'])),
                  stickerCount: Value(_asInt(raw['count']) ?? 0),
                  isPremium: Value(raw['isPremium'] == true),
                  locked: Value(raw['locked'] == true),
                  version: Value(_asInt(raw['version']) ?? 1),
                  installedByDefault: Value(raw['installedByDefault'] == true),
                  catalogPosition: Value(i++),
                ),
                onConflict: DoUpdate(
                  (_) => LocalStickerPacksCompanion(
                    code: Value(code),
                    name: Value(_str(raw['name']) ?? code),
                    description: Value(_str(raw['description'])),
                    coverUrl: Value(_str(raw['cover'])),
                    stickerCount: Value(_asInt(raw['count']) ?? 0),
                    isPremium: Value(raw['isPremium'] == true),
                    locked: Value(raw['locked'] == true),
                    version: Value(_asInt(raw['version']) ?? 1),
                    installedByDefault:
                        Value(raw['installedByDefault'] == true),
                    catalogPosition: Value(i - 1),
                  ),
                ),
              );
        }
        // Un pack absent du catalogue est archivé (A14) : indisponible, même
        // installé. Garde-fou : une liste non vide dont aucune ligne n'est
        // lisible ne vide pas le plateau.
        if (packs.isNotEmpty && seen.isEmpty) return;
        gone = await (_db.select(_db.localStickerPacks)
              ..where((p) => p.owned.equals(false) & p.packId.isNotIn(seen)))
            .get();
        await _purgePacks(gone);
      });
      await _updateUnavailable(
          add: gone.map((p) => p.code), remove: seenCodes);
      if (res.etag != null) await prefs.setString(catalogEtagKey, res.etag!);
      final v = _asInt(body['version']);
      if (v != null) await prefs.setInt(catalogVersionKey, v);
    } on TalkyException catch (e) {
      _noteFailure(e);
    }
  }

  /// `GET /me` : packs installés (id, code, position) et favoris (ids).
  Future<void> syncMe() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _api.getMe();
      available.value = true;
      final body = res.body;
      if (body is! Map) return;
      // `features` (contrat §4c) : absent = fermé. Le serveur tranche.
      await features.apply(body['features']);
      final packs = body['packs'] is List ? body['packs'] as List : const [];
      final favs = body['favorites'] is List ? body['favorites'] as List : const [];
      final meCodes = <String>{};
      await _db.transaction(() async {
        await _db.update(_db.localStickerPacks).write(
            const LocalStickerPacksCompanion(installed: Value(false)));
        for (final raw in packs) {
          if (raw is! Map) continue;
          final id = _asInt(raw['id']);
          final code = raw['code'];
          if (id == null || id <= 0 || code is! String) continue;
          final pos = _asInt(raw['position']) ?? 0;
          meCodes.add(code);
          final exists = await (_db.select(_db.localStickerPacks)
                ..where((p) => p.packId.equals(id)))
              .getSingleOrNull();
          if (exists == null) {
            // Pack installé que le catalogue local ne connaît pas encore
            // (catalogue en retard) : ligne minimale. Un pack archivé n'est
            // jamais renvoyé par `/me` ; si le serveur le refuse ensuite
            // (`fetchPack`), la ligne est retirée.
            await _db.into(_db.localStickerPacks).insert(
                LocalStickerPacksCompanion.insert(
                    packId: Value(id), code: code, name: Value(code)));
          }
          await (_db.update(_db.localStickerPacks)
                ..where((p) => p.packId.equals(id)))
              .write(LocalStickerPacksCompanion(
                  installed: const Value(true), position: Value(pos)));
        }
        await _db.delete(_db.localStickerFavorites).go();
        var i = 0;
        for (final f in favs) {
          final sid = _asInt(f);
          if (sid == null || sid <= 0) continue;
          await _db.into(_db.localStickerFavorites).insertOnConflictUpdate(
              LocalStickerFavoritesCompanion(
                  stickerId: Value(sid), position: Value(i++)));
        }
      });
      await _updateUnavailable(remove: meCodes);
      final v = _asInt(body['version']);
      if (v != null) await prefs.setInt(meVersionKey, v);
    } on TalkyException catch (e) {
      _noteFailure(e);
    }
  }

  /// Charge les stickers de chaque pack installé dont la liste est vide, puis
  /// précharge leurs vignettes (Wi-Fi seulement, via [StickerCache]).
  Future<void> syncInstalledPacks({bool force = false}) async {
    final installed = await (_db.select(_db.localStickerPacks)
          ..where((p) => p.installed.equals(true) & p.owned.equals(false)))
        .get();
    for (final pack in installed) {
      final have = await (_db.selectOnly(_db.localStickers)
            ..addColumns([_db.localStickers.stickerId.count()])
            ..where(_db.localStickers.packId.equals(pack.packId)))
          .map((r) => r.read(_db.localStickers.stickerId.count()) ?? 0)
          .getSingle();
      if (!force && have > 0 && have >= pack.stickerCount) continue;
      await fetchPack(pack.code);
    }
    final cache = _cache;
    if (cache != null) {
      final thumbs = await (_db.select(_db.localStickers)
            ..where((s) => s.packId.isIn(installed.map((p) => p.packId))))
          .get();
      unawaited(cache.prefetchThumbs(
          thumbs.map((s) => s.thumbUrl ?? '').where((u) => u.isNotEmpty)));
    }
  }

  /// `GET /packs/:code` → remplace les stickers du pack.
  Future<void> fetchPack(String code) async {
    try {
      final res = await _api.getPack(code);
      final body = res.body;
      if (body is! Map) return;
      final packId = _asInt(body['id']);
      final list = body['stickers'];
      if (packId == null || list is! List) return;
      await _db.transaction(() async {
        await (_db.delete(_db.localStickers)
              ..where((s) => s.packId.equals(packId)))
            .go();
        for (final raw in list) {
          if (raw is! Map) continue;
          final sid = _asInt(raw['id']);
          final url = _str(raw['url']);
          if (sid == null || sid <= 0 || url == null) continue;
          await _db.into(_db.localStickers).insertOnConflictUpdate(
                LocalStickersCompanion(
                  stickerId: Value(sid),
                  packId: Value(packId),
                  position: Value(_asInt(raw['position']) ?? 0),
                  emoji: Value(_str(raw['emoji']) ?? ''),
                  name: Value(_str(raw['name'])),
                  url: Value(url),
                  thumbUrl: Value(_str(raw['thumb'])),
                  width: Value(_asInt(raw['w']) ?? 512),
                  height: Value(_asInt(raw['h']) ?? 512),
                  animated: Value(raw['animated'] == true),
                  bytes: Value(_asInt(raw['bytes'])),
                  // Champ facultatif : absent des packs officiels, ignoré d'un
                  // ancien serveur.
                  assetId: Value(_asInt(raw['assetId'])),
                ),
              );
        }
      });
    } on TalkyException catch (e) {
      // Pack archivé entre deux synchros : il n'existe plus pour nous.
      if (e.code == packUnavailableCode) {
        await packUnavailable(code);
        return;
      }
      _noteFailure(e, module: false);
    }
  }

  /// Événement `stickers:sync` (autre appareil, back-office) : relit l'état.
  ///
  /// `catalog` (publication ou archivage d'un pack officiel, diffusé à tous les
  /// appareils) relit catalogue **sans ETag**, `/me` et les stickers des packs
  /// installés : un pack archivé disparaît du plateau sans toucher à
  /// l'historique des conversations.
  Future<void> onSyncEvent(Object? payload) async {
    final reason = payload is Map ? payload['reason']?.toString() : null;
    if (reason == 'catalog') await syncCatalog(ignoreEtag: true);
    await syncMe();
    if (reason == 'packs' || reason == 'catalog') await syncInstalledPacks();
    if (reason == 'packs' || reason == null) await _afterSync();
  }

  // ── Actions de l'utilisateur ────────────────────────────────────────
  // Le serveur d'abord : un refus (`SUBSCRIPTION_REQUIRED`, `STICKER_PACK_LIMIT`)
  // remonte à l'appelant, qui le présente via `afficherErreur`.

  Future<void> installPack(LocalStickerPack pack) async {
    try {
      await _api.installPack(pack.packId);
    } on TalkyException catch (e) {
      // Pack archivé depuis la dernière synchro (catalogue en retard) : on le
      // retire du catalogue local, l'appelant présente le refus.
      if (e.code == packUnavailableCode) await packUnavailable(pack.code);
      rethrow;
    }
    final last = await (_db.selectOnly(_db.localStickerPacks)
          ..addColumns([_db.localStickerPacks.position.max()])
          ..where(_db.localStickerPacks.installed.equals(true)))
        .map((r) => r.read(_db.localStickerPacks.position.max()))
        .getSingle();
    await (_db.update(_db.localStickerPacks)
          ..where((p) => p.packId.equals(pack.packId)))
        .write(LocalStickerPacksCompanion(
            installed: const Value(true), position: Value((last ?? -1) + 1)));
    await fetchPack(pack.code);
  }

  Future<void> removePack(int packId) async {
    await _api.removePack(packId);
    await (_db.update(_db.localStickerPacks)
          ..where((p) => p.packId.equals(packId)))
        .write(const LocalStickerPacksCompanion(installed: Value(false)));
  }

  /// Applique [orderedIds] localement puis le confirme au serveur ; en cas de
  /// refus, l'état serveur est relu.
  Future<void> reorderPacks(List<int> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.localStickerPacks)
              ..where((p) => p.packId.equals(orderedIds[i])))
            .write(LocalStickerPacksCompanion(position: Value(i)));
      }
    });
    try {
      await _api.reorderPacks(orderedIds);
    } catch (_) {
      await syncMe();
      rethrow;
    }
  }

  Future<void> setFavorite(int stickerId, bool favorite) async {
    if (favorite) {
      await _api.addFavorite(stickerId);
      final n = await (_db.selectOnly(_db.localStickerFavorites)
            ..addColumns([_db.localStickerFavorites.stickerId.count()]))
          .map((r) => r.read(_db.localStickerFavorites.stickerId.count()) ?? 0)
          .getSingle();
      await _db.into(_db.localStickerFavorites).insertOnConflictUpdate(
          LocalStickerFavoritesCompanion(
              stickerId: Value(stickerId), position: Value(n)));
    } else {
      await _api.removeFavorite(stickerId);
      await (_db.delete(_db.localStickerFavorites)
            ..where((f) => f.stickerId.equals(stickerId)))
          .go();
    }
  }

  /// Note un sticker comme récemment utilisé (local à l'appareil).
  Future<void> markUsed(int stickerId) async {
    await _db.into(_db.localStickerRecents).insertOnConflictUpdate(
        LocalStickerRecentsCompanion(
            stickerId: Value(stickerId), usedAt: Value(_now().toUtc())));
    final extra = await (_db.select(_db.localStickerRecents)
          ..orderBy([
            (r) => OrderingTerm(expression: r.usedAt, mode: OrderingMode.desc)
          ])
          ..limit(1000, offset: maxRecents))
        .get();
    if (extra.isNotEmpty) {
      await (_db.delete(_db.localStickerRecents)
            ..where((r) => r.stickerId.isIn(extra.map((e) => e.stickerId))))
          .go();
    }
  }

  // ── Pack indisponible (archivé, A14) ────────────────────────────────

  /// Le serveur a dit `STICKER_PACK_UNAVAILABLE` pour le pack [code] (envoi,
  /// transfert, installation, lecture) : il quitte le plateau, « Mes packs » et
  /// le catalogue local, sans erreur et sans toucher aux messages. Un pack à
  /// moi (V1b) n'est pas retiré d'ici : ses listes suivent `syncCreated`.
  Future<void> packUnavailable(String code) async {
    if (code.isEmpty) return;
    final pack = await packByCode(code);
    if (pack != null && !pack.owned) {
      await _db.transaction(() => _purgePacks([pack]));
    }
    await _updateUnavailable(add: [code]);
    if (pack != null && pack.owned) await _afterSync();
  }

  /// Vrai si l'application sait ce pack archivé ou refusé par le serveur : la
  /// fiche d'un de ses stickers n'offre alors ni copie, ni signalement.
  Future<bool> isPackUnavailable(String code) async {
    if (code.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(unavailablePacksKey) ?? const []).contains(code);
  }

  /// Retire de Drift [packs] (officiels) avec leurs stickers, les favoris et
  /// les récents de ces stickers. À appeler dans une transaction. Les messages
  /// ne sont jamais lus ni modifiés : leur `mediaUrl` suffit à les afficher.
  Future<void> _purgePacks(List<LocalStickerPack> packs) async {
    final ids = [for (final p in packs) if (!p.owned) p.packId];
    if (ids.isEmpty) return;
    final sids = await (_db.selectOnly(_db.localStickers)
          ..addColumns([_db.localStickers.stickerId])
          ..where(_db.localStickers.packId.isIn(ids)))
        .map((r) => r.read(_db.localStickers.stickerId)!)
        .get();
    if (sids.isNotEmpty) {
      await (_db.delete(_db.localStickerFavorites)
            ..where((f) => f.stickerId.isIn(sids)))
          .go();
      await (_db.delete(_db.localStickerRecents)
            ..where((r) => r.stickerId.isIn(sids)))
          .go();
    }
    await (_db.delete(_db.localStickers)..where((s) => s.packId.isIn(ids))).go();
    await (_db.delete(_db.localStickerPacks)..where((p) => p.packId.isIn(ids)))
        .go();
  }

  /// Tient à jour la liste des codes indisponibles ([unavailablePacksKey]).
  Future<void> _updateUnavailable({
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(unavailablePacksKey) ?? const <String>[])
        .toSet();
    final next = {...current, ...add}..removeAll(remove);
    // `add` l'emporte sur `remove` pour un même code : refus du serveur.
    next.addAll(add);
    if (next.length == current.length && next.containsAll(current)) return;
    await prefs.setStringList(unavailablePacksKey, next.toList()..sort());
  }

  // ── Utilitaires ─────────────────────────────────────────────────────

  /// 404 sans code sur les routes de lecture = module fermé côté serveur.
  void _noteFailure(TalkyException e, {bool module = true}) {
    // Fermé = `404 NOT_FOUND` générique (contrat §4) ; un 404 qui porte un
    // code de sticker (`STICKER_PACK_UNAVAILABLE`…) est une réponse normale.
    if (module && isModuleClosed(e)) {
      available.value = false;
      return;
    }
    // Hors ligne ou erreur serveur : le cache local reste affiché.
    debugPrint('[StickerRepository] synchro échouée (${e.statusCode} ${e.code})');
  }

  /// `404` sans code ou avec le code générique `NOT_FOUND` : la fonctionnalité
  /// est fermée côté serveur et ne doit rien révéler.
  static bool isModuleClosed(TalkyException e) =>
      e.statusCode == 404 && (e.code == null || e.code == 'NOT_FOUND');

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    return null;
  }

  static String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
