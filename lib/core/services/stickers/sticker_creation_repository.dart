
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart' show TalkyException;
import '../../db/app_database.dart';
import 'sticker_animated_check.dart';
import 'sticker_video_check.dart';
import 'sticker_creation_api.dart';
import 'sticker_features.dart';
import 'sticker_image_check.dart';
import 'sticker_repository.dart';
import 'sticker_share_link.dart';

export 'sticker_share_link.dart';

/// Motifs de signalement acceptés par `POST /report` (contrat §4b).
enum StickerReportReason { inapproprie, spam, droits, autre }

/// Plafonds du contrat (le serveur tranche ; ils ne servent qu'à l'affichage).
const int kMaxCreatedPacks = 20;
const int kMaxStickersPerPack = 40;

/// Un sticker d'un pack partagé (lecture seule, avant installation).
class StickerShareItem {
  const StickerShareItem({
    required this.id,
    required this.emoji,
    required this.url,
    this.thumb,
  });
  final int id;
  final String emoji;
  final String url;
  final String? thumb;
}

/// Fiche d'un lien de partage (`GET /share/:token`).
class StickerSharePreview {
  const StickerSharePreview({
    required this.token,
    required this.name,
    required this.description,
    required this.cover,
    required this.count,
    required this.mine,
    required this.added,
    required this.addedPackId,
    required this.stickers,
  });

  final String token;
  final String name;
  final String? description;
  final String? cover;
  final int count;

  /// C'est mon propre pack.
  final bool mine;

  /// Je l'ai déjà installé (copie existante).
  final bool added;
  final int? addedPackId;
  final List<StickerShareItem> stickers;

  /// Rien à installer : mon pack, ou déjà ajouté.
  bool get alreadyHere => mine || added;
}

/// Réponse de `POST /share/:token/add`.
class StickerShareAddResult {
  const StickerShareAddResult({
    required this.packId,
    required this.already,
    required this.mine,
    required this.stickers,
    required this.ignored,
  });
  final int packId;

  /// `true` : rien de nouveau (déjà installé, ou c'est mon pack).
  final bool already;
  final bool mine;
  final int stickers;

  /// Images bloquées ou retirées, non copiées.
  final int ignored;
}

/// Réponse de `POST /assets` et `POST /assets/:id/copy`.
class StickerUploadResult {
  const StickerUploadResult({
    required this.assetId,
    required this.stickerId,
    required this.packId,
    required this.reused,
    required this.copied,
  });
  final int assetId;
  final int stickerId;
  final int packId;

  /// Même image déjà possédée : aucun actif de plus.
  final bool reused;

  /// Copie d'un sticker reçu (fichier recopié côté serveur).
  final bool copied;
}

/// Forme appliquée par le serveur à un sticker animé (contrat §4c : le
/// serveur recadre `cover` en 512×512 puis masque chaque image). Valeur =
/// champ `shape` envoyé.
enum StickerAnimatedShape {
  cercle('cercle'),
  carreArrondi('carre-arrondi'),
  carre('carre');

  const StickerAnimatedShape(this.wire);
  final String wire;
}

/// Réponse de `POST /assets/animated` : [StickerUploadResult] + mesures de
/// l'encodage serveur.
class StickerAnimatedResult {
  const StickerAnimatedResult({
    required this.upload,
    required this.animated,
    required this.bytes,
    required this.frames,
    required this.durationMs,
  });
  final StickerUploadResult upload;
  final bool animated;
  final int bytes;
  final int frames;
  final int durationMs;
}

/// Packs perso, ajout de stickers, copie, signalement et partage (V1b) ;
/// création de stickers animés (V1c).
///
/// Comme `StickerRepository`, **le serveur tranche** (propriété, quotas, URLs,
/// jetons) : chaque action appelle d'abord le serveur, puis relit
/// `GET /me/created` pour refléter l'état dans Drift (une requête, tout
/// compris). Un refus (`STICKER_QUOTA_EXCEEDED`, `STICKER_PACK_LIMIT`,
/// `RATE_LIMITED`…) remonte à l'appelant, qui le présente via `afficherErreur`.
class StickerCreationRepository {
  StickerCreationRepository({
    required AppDatabase db,
    required StickerCreationApi api,
    StickerFeatures? features,
  }) : _db = db,
       _api = api,
       features = features ?? StickerFeatures();

  /// Mémorise que la création était ouverte : hors ligne, l'entrée « Mes
  /// créations » ne disparaît pas parce que le réseau manque.
  static const String availableKey = 'stickers_creation_available';

  final AppDatabase _db;
  final StickerCreationApi _api;

  /// Fonctionnalités ouvertes (`GET /me` → `features`) : l'option « Sticker
  /// animé » n'apparaît que si `features.animated` est vrai. Partagé avec
  /// `StickerRepository`.
  final StickerFeatures features;

  /// `true` quand `GET /me/created` répond. Un `404 NOT_FOUND` (module ou
  /// création fermés côté serveur) le passe à `false` : l'interface masque
  /// alors toutes les entrées de création, sans rien révéler.
  final ValueNotifier<bool> creationAvailable = ValueNotifier<bool>(false);

  // ── Lecture réactive ────────────────────────────────────────────────

  /// Mes packs créés, dans l'ordre du serveur.
  Stream<List<LocalStickerPack>> watchCreated() =>
      (_db.select(_db.localStickerPacks)
            ..where((p) => p.owned.equals(true))
            ..orderBy([(p) => OrderingTerm(expression: p.position)]))
          .watch();

  Stream<List<LocalSticker>> watchStickers(int packId) =>
      (_db.select(_db.localStickers)
            ..where((s) => s.packId.equals(packId))
            ..orderBy([(s) => OrderingTerm(expression: s.position)]))
          .watch();

  /// Identifiant d'actif d'un sticker, quand on le connaît (les miens).
  Future<int?> assetIdOf(int stickerId) async {
    final s = await (_db.select(
      _db.localStickers,
    )..where((t) => t.stickerId.equals(stickerId))).getSingleOrNull();
    return s?.assetId;
  }

  Future<LocalStickerPack?> packById(int packId) => (_db.select(
    _db.localStickerPacks,
  )..where((p) => p.packId.equals(packId))).getSingleOrNull();

  // ── Synchronisation ─────────────────────────────────────────────────

  /// `GET /me/created` → Drift. Silencieux hors ligne ; `404 NOT_FOUND` =
  /// création fermée (entrées masquées).
  Future<void> syncCreated() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _api.getCreated();
      final body = res.body;
      if (body is! Map || body['packs'] is! List) return;
      creationAvailable.value = true;
      await prefs.setBool(availableKey, true);
      await _store(body['packs'] as List);
    } on TalkyException catch (e) {
      if (StickerRepository.isModuleClosed(e)) {
        creationAvailable.value = false;
        await prefs.setBool(availableKey, false);
        await _forgetOwned();
        return;
      }
      // Hors ligne ou erreur serveur : le cache reste affiché ; on garde
      // l'état « ouvert » vu la dernière fois.
      creationAvailable.value = prefs.getBool(availableKey) ?? false;
      debugPrint(
        '[StickerCreation] synchro échouée (${e.statusCode} ${e.code})',
      );
    }
  }

  Future<void> _forgetOwned() => _db.transaction(() async {
    final owned = await (_db.select(
      _db.localStickerPacks,
    )..where((p) => p.owned.equals(true))).get();
    for (final p in owned) {
      await (_db.delete(
        _db.localStickers,
      )..where((s) => s.packId.equals(p.packId))).go();
    }
    await (_db.delete(
      _db.localStickerPacks,
    )..where((p) => p.owned.equals(true) & p.installed.equals(false))).go();
    await (_db.update(
      _db.localStickerPacks,
    )..where((p) => p.owned.equals(true))).write(
      const LocalStickerPacksCompanion(
        owned: Value(false),
        shareToken: Value(null),
      ),
    );
  });

  Future<void> _store(List packs) => _db.transaction(() async {
    final seen = <int>{};
    var i = 0;
    for (final raw in packs) {
      if (raw is! Map) continue;
      final id = _asInt(raw['id']);
      final code = raw['code'];
      if (id == null || id <= 0 || code is! String || code.isEmpty) continue;
      seen.add(id);
      final stickers = raw['stickers'] is List
          ? raw['stickers'] as List
          : const [];
      final shared = raw['shared'] == true;
      final token = _str(raw['shareToken']);
      final existing = await packById(id);
      final cols = LocalStickerPacksCompanion(
        code: Value(code),
        name: Value(_str(raw['name']) ?? code),
        coverUrl: Value(_str(raw['cover'])),
        stickerCount: Value(_asInt(raw['count']) ?? stickers.length),
        version: Value(_asInt(raw['version']) ?? 1),
        owned: const Value(true),
        // Pas de jeton si le pack n'est plus partagé (lien révoqué).
        shareToken: Value(shared ? token : null),
        position: existing != null && existing.installed
            ? const Value.absent()
            : Value(i),
      );
      if (existing == null) {
        await _db
            .into(_db.localStickerPacks)
            .insert(cols.copyWith(packId: Value(id)));
      } else {
        await (_db.update(
          _db.localStickerPacks,
        )..where((p) => p.packId.equals(id))).write(cols);
      }
      i++;
      await (_db.delete(
        _db.localStickers,
      )..where((s) => s.packId.equals(id))).go();
      for (final st in stickers) {
        if (st is! Map) continue;
        final sid = _asInt(st['id']);
        final url = _str(st['url']);
        if (sid == null || sid <= 0 || url == null) continue;
        await _db
            .into(_db.localStickers)
            .insertOnConflictUpdate(
              LocalStickersCompanion(
                stickerId: Value(sid),
                packId: Value(id),
                position: Value(_asInt(st['position']) ?? 0),
                emoji: Value(_str(st['emoji']) ?? ''),
                name: Value(_str(st['name'])),
                url: Value(url),
                thumbUrl: Value(_str(st['thumb'])),
                width: Value(_asInt(st['w']) ?? 512),
                height: Value(_asInt(st['h']) ?? 512),
                animated: Value(st['animated'] == true),
                bytes: Value(_asInt(st['bytes'])),
                assetId: Value(_asInt(st['assetId'])),
              ),
            );
      }
    }
    // Un pack à moi qui n'est plus rendu (archivé ici ou ailleurs) part.
    final gone = await (_db.select(
      _db.localStickerPacks,
    )..where((p) => p.owned.equals(true) & p.packId.isNotIn(seen))).get();
    for (final p in gone) {
      await (_db.delete(
        _db.localStickers,
      )..where((s) => s.packId.equals(p.packId))).go();
      await (_db.delete(
        _db.localStickerPacks,
      )..where((q) => q.packId.equals(p.packId))).go();
    }
  });

  /// Événement `stickers:sync` (`packs`) : relit mes créations.
  Future<void> onSyncEvent(Object? payload) async {
    final reason = payload is Map ? payload['reason']?.toString() : null;
    if (reason == 'packs' || reason == null) await syncCreated();
  }

  // ── Actions : packs ─────────────────────────────────────────────────

  /// Crée un pack nommé [name] ; renvoie son identifiant. Le serveur crée un
  /// pack vide au nom par défaut (`POST /packs` sans corps), puis on le nomme.
  Future<int> createPack(String name) => _guard(() async {
    final res = await _api.createPack();
    final body = res.body;
    final id = body is Map ? _asInt(body['id']) : null;
    if (id == null) throw TalkyException('réponse inattendue', res.status);
    try {
      final clean = name.trim();
      if (clean.isNotEmpty) {
        await _api.patchPack(id, nameI18n: _nameInAllLanguages(clean));
      }
    } finally {
      // Le pack existe déjà côté serveur, même si le nommage échoue.
      await syncCreated();
    }
    return id;
  });

  Future<void> renamePack(int packId, String name) => _guard(() async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _api.patchPack(packId, nameI18n: _nameInAllLanguages(clean));
    await syncCreated();
  });

  /// Choisit la couverture (un sticker du pack) ; `null` = premier sticker.
  Future<void> setCover(int packId, int? stickerId) => _guard(() async {
    await _api.patchPack(
      packId,
      coverStickerId: stickerId,
      resetCover: stickerId == null,
    );
    await syncCreated();
  });

  /// Archive le pack (lien révoqué, stickers retirés du pack côté serveur).
  Future<void> archivePack(int packId) => _guard(() async {
    await _api.archivePack(packId);
    await _db.transaction(() async {
      await (_db.delete(
        _db.localStickers,
      )..where((s) => s.packId.equals(packId))).go();
      await (_db.delete(
        _db.localStickerPacks,
      )..where((p) => p.packId.equals(packId))).go();
    });
    await syncCreated();
  });

  // ── Actions : stickers ──────────────────────────────────────────────

  /// Ajoute une image de la galerie au pack. [packId] nul : `POST /assets` sans
  /// `packId`, le serveur dépose le sticker dans le pack perso par défaut
  /// (« Mes stickers », créé au besoin ; contrat §4b) : c'est le chemin du
  /// bouton « Créer » du plateau. Le contrat exige un PNG/WebP
  /// **512×512 avec alpha** ≤ 1 Mo : sinon [StickerImageRejected], avant tout
  /// envoi. Les photos de la galerie sont d'abord adaptées par
  /// `StickerImageAdapter` ; ce contrôle reste la dernière garde.
  Future<StickerUploadResult> addStickerFromImage(
    int? packId,
    Uint8List bytes, {
    required String filename,
    String? emoji,
    String? name,
  }) async {
    final info = StickerImageCheck.validate(bytes);
    final fixedName =
        filename.toLowerCase().endsWith(
          info.mime == 'image/webp' ? '.webp' : '.png',
        )
        ? filename
        : (info.mime == 'image/webp' ? 'sticker.webp' : 'sticker.png');
    return _guard(() async {
      final res = await _api.uploadAsset(
        bytes,
        filename: fixedName,
        packId: packId,
        emoji: emoji,
        name: name,
      );
      await syncCreated();
      return _uploadResult(res.body, copied: false);
    });
  }

  /// Crée un sticker animé depuis un GIF ou un WebP animé (V1c, contrat §4c).
  ///
  /// Le fichier part **tel quel** : le serveur recadre en 512×512, applique
  /// [shape], tronque à 3 s / 45 images et ré-encode (jusqu'à ~15 s). Refus
  /// local sans réseau : [StickerAnimatedRejected] (format, > 3 Mo, non animé).
  /// Refus du serveur, à présenter : `STICKER_ASSET_INVALID` (trop lourd ou non
  /// pris en charge), `STICKER_QUOTA_EXCEEDED`, `STICKER_ASSET_BLOCKED`,
  /// `STICKER_PACK_LIMIT`, `RATE_LIMITED` (10/h), `503 SERVICE_UNAVAILABLE`
  /// (réessayer plus tard). Un `404 NOT_FOUND` générique = animés fermés : le
  /// drapeau [features] repasse à faux (l'option disparaît) ; la création
  /// elle-même n'est pas masquée sur cette seule réponse, mais relue.
  /// [cancel] annule la requête en cours.
  Future<StickerAnimatedResult> addAnimatedSticker(
    int? packId,
    Uint8List bytes, {
    required String filename,
    required StickerAnimatedShape shape,
    String? emoji,
    String? name,
    Future<void>? cancel,
  }) async {
    final info = StickerAnimatedCheck.validate(bytes);
    final ext = info.kind == StickerAnimatedKind.gif ? '.gif' : '.webp';
    final fixedName = filename.toLowerCase().endsWith(ext)
        ? filename
        : 'sticker$ext';
    return _uploadAnimated(
      packId,
      bytes,
      filename: fixedName,
      shape: shape,
      emoji: emoji,
      name: name,
      cancel: cancel,
    );
  }

  /// Crée un sticker animé depuis une **vidéo** MP4 / MOV / WebM (V1c, contrat
  /// §4d). La vidéo part **entière** (≤ 20 Mo) avec la fenêtre [window] ; le
  /// serveur la découpe avec ffmpeg, recadre en 512×512, applique [shape] et
  /// ré-encode (jusqu'à ~25 s). Refus local sans réseau : [StickerVideoRejected]
  /// (serveur sans ffmpeg, format, > 20 Mo). Mêmes refus du serveur que
  /// [addAnimatedSticker].
  Future<StickerAnimatedResult> addVideoSticker(
    int? packId,
    Uint8List bytes, {
    required String filename,
    required StickerAnimatedShape shape,
    required StickerVideoWindow window,
    String? emoji,
    String? name,
    Future<void>? cancel,
  }) async {
    if (!features.video.value) {
      throw const StickerVideoRejected(StickerVideoIssue.unsupported);
    }
    final kind = StickerVideoCheck.validate(bytes);
    final lower = filename.toLowerCase();
    final fixedName = (lower.endsWith(kind.extension) || lower.endsWith('.mov'))
        ? filename
        : 'sticker${kind.extension}';
    return _uploadAnimated(
      packId,
      bytes,
      filename: fixedName,
      shape: shape,
      emoji: emoji,
      name: name,
      startMs: window.startMs,
      durationMs: window.durationMs,
      cancel: cancel,
    );
  }

  Future<StickerAnimatedResult> _uploadAnimated(
    int? packId,
    Uint8List bytes, {
    required String filename,
    required StickerAnimatedShape shape,
    String? emoji,
    String? name,
    int? startMs,
    int? durationMs,
    Future<void>? cancel,
  }) async {
    try {
      final res = await _api.uploadAnimatedAsset(
        bytes,
        filename: filename,
        shape: shape.wire,
        packId: packId,
        emoji: emoji,
        name: name,
        startMs: startMs,
        durationMs: durationMs,
        cancel: cancel,
      );
      await syncCreated();
      final b = res.body is Map ? res.body as Map : const {};
      return StickerAnimatedResult(
        upload: _uploadResult(res.body, copied: false),
        animated: b['animated'] == true,
        bytes: _asInt(b['bytes']) ?? 0,
        frames: _asInt(b['frames']) ?? 0,
        durationMs: _asInt(b['durationMs']) ?? 0,
      );
    } on TalkyException catch (e) {
      if (StickerRepository.isModuleClosed(e)) {
        await features.animatedClosed();
        // Création fermée aussi ? `syncCreated` le constate (404 → masquée).
        await syncCreated();
      }
      rethrow;
    }
  }

  Future<void> removeSticker(int packId, int stickerId) => _guard(() async {
    await _api.removeStickerFromPack(packId, stickerId);
    await (_db.delete(
      _db.localStickers,
    )..where((s) => s.stickerId.equals(stickerId))).go();
    await syncCreated();
  });

  /// Applique [orderedIds] localement puis le confirme au serveur ; en cas de
  /// refus, l'état serveur est relu.
  Future<void> reorderStickers(int packId, List<int> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.localStickers)..where(
              (s) =>
                  s.stickerId.equals(orderedIds[i]) & s.packId.equals(packId),
            ))
            .write(LocalStickersCompanion(position: Value(i)));
      }
    });
    try {
      await _guard(() => _api.reorderStickers(packId, orderedIds));
    } catch (_) {
      await syncCreated();
      rethrow;
    }
  }

  /// « Ajouter à un pack » depuis un sticker reçu, désigné par son [stickerId]
  /// (le `sid` de la charge utile) : le serveur résout l'actif et le copie chez
  /// moi (règle « installer = copier »). [packId] nul : pack par défaut.
  /// `STICKER_NOT_FOUND` (404) : sticker inaccessible ou retiré.
  Future<StickerUploadResult> copyToPack(
    int stickerId, {
    int? packId,
    String? emoji,
    String? name,
  }) => _guard(() async {
    final res = await _api.copySticker(
      stickerId,
      packId: packId,
      emoji: emoji,
      name: name,
    );
    await syncCreated();
    return _uploadResult(res.body, copied: true);
  });

  /// Signale un sticker reçu, désigné par son [stickerId] (`sid`). `true` si
  /// je l'avais déjà signalé (`deja`).
  Future<bool> report(int stickerId, StickerReportReason reason) =>
      _guard(() async {
        final res = await _api.reportSticker(stickerId, reason.name);
        final b = res.body;
        return b is Map && b['deja'] == true;
      });

  // ── Partage ─────────────────────────────────────────────────────────

  /// Crée (ou rend) le lien du pack : renvoie le jeton. Pas de rotation si le
  /// pack est déjà partagé.
  Future<String> sharePack(int packId) => _guard(() async {
    final res = await _api.sharePack(packId);
    final b = res.body;
    final token = b is Map ? _str(b['token']) : null;
    if (token == null || !StickerShareLink.isToken(token)) {
      throw TalkyException('réponse inattendue', res.status);
    }
    await (_db.update(_db.localStickerPacks)
          ..where((p) => p.packId.equals(packId)))
        .write(LocalStickerPacksCompanion(shareToken: Value(token)));
    await syncCreated();
    return token;
  });

  /// Révoque le lien. Les packs déjà installés par des destinataires ne
  /// bougent pas (ce sont des copies).
  Future<void> unsharePack(int packId) => _guard(() async {
    await _api.unsharePack(packId);
    await (_db.update(_db.localStickerPacks)
          ..where((p) => p.packId.equals(packId)))
        .write(const LocalStickerPacksCompanion(shareToken: Value(null)));
    await syncCreated();
  });

  /// `GET /share/:token`. Jeton mal formé, inconnu, révoqué ou pack archivé :
  /// `STICKER_PACK_UNAVAILABLE` (404), toujours le même.
  Future<StickerSharePreview> resolveShare(String token) => _guard(() async {
    final res = await _api.getShare(token);
    final b = res.body;
    if (b is! Map) throw TalkyException('réponse inattendue', res.status);
    final list = b['stickers'] is List ? b['stickers'] as List : const [];
    return StickerSharePreview(
      token: token,
      name: _str(b['name']) ?? '',
      description: _str(b['description']),
      cover: _str(b['cover']),
      count: _asInt(b['count']) ?? list.length,
      mine: b['mine'] == true,
      added: b['added'] == true,
      addedPackId: _asInt(b['addedPackId']),
      stickers: [
        for (final s in list)
          if (s is Map && _asInt(s['id']) != null && _str(s['url']) != null)
            StickerShareItem(
              id: _asInt(s['id'])!,
              emoji: _str(s['emoji']) ?? '',
              url: _str(s['url'])!,
              thumb: _str(s['thumb']),
            ),
      ],
    );
  });

  /// `POST /share/:token/add` : installer = **copier** (pack privé à moi,
  /// fichiers à moi). `already` si rien de nouveau.
  Future<StickerShareAddResult> addShared(String token) => _guard(() async {
    final res = await _api.addShare(token);
    final b = res.body;
    if (b is! Map) throw TalkyException('réponse inattendue', res.status);
    final packId = _asInt(b['packId']);
    if (packId == null) throw TalkyException('réponse inattendue', res.status);
    final already = b['deja'] == true;
    if (!already) await syncCreated();
    return StickerShareAddResult(
      packId: packId,
      already: already,
      mine: b['mine'] == true,
      stickers: _asInt(b['stickers']) ?? 0,
      ignored: _asInt(b['ignores']) ?? 0,
    );
  });

  // ── Utilitaires ─────────────────────────────────────────────────────

  /// Un `404 NOT_FOUND` générique, où qu'il tombe, ferme les entrées de
  /// création ; l'erreur remonte quand même.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TalkyException catch (e) {
      if (StickerRepository.isModuleClosed(e)) creationAvailable.value = false;
      rethrow;
    }
  }

  static StickerUploadResult _uploadResult(
    Object? body, {
    required bool copied,
  }) {
    final b = body is Map ? body : const {};
    return StickerUploadResult(
      assetId: _asInt(b['assetId']) ?? 0,
      stickerId: _asInt(b['stickerId']) ?? 0,
      packId: _asInt(b['packId']) ?? 0,
      reused: b['reutilise'] == true,
      copied: copied || b['copie'] == true,
    );
  }

  /// Le nom saisi vaut pour les trois langues : c'est le nom que l'auteur
  /// donne à *son* pack, sans traduction automatique.
  static Map<String, String> _nameInAllLanguages(String name) {
    final n = String.fromCharCodes(name.runes.take(60));
    return {'fr': n, 'en': n, 'zh': n};
  }

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
