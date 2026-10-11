// Endpoints stickers (part of talky_api_client.dart). Contrat : §4 et §4b de
// `docs-stickers/contract/CONTRAT-STICKERS.md`.
part of '../talky_api_client.dart';

/// Réponse d'une route stickers : statut, ETag éventuel, corps décodé.
class StickerHttpResult {
  const StickerHttpResult(this.status, {this.etag, this.body});
  final int status;
  final String? etag;
  final dynamic body;
  bool get notModified => status == 304;
}

extension StickersApi on TalkyApiClient {
  /// Les routes répondent 204 (corps vide) ou 304 : `_parseResponse` décode du
  /// JSON, on lui remet donc un corps neutre et on garde statut et ETag ici.
  Future<StickerHttpResult> _stickerCall(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var status = 200;
    String? etag;
    final body = await _handleRequest(() async {
      final r = await request();
      status = r.statusCode;
      etag = r.headers['etag'];
      if (r.statusCode == 204 || r.statusCode == 304 || r.body.isEmpty) {
        return http.Response('null', 200, headers: r.headers);
      }
      return r;
    }, timeout: timeout);
    return StickerHttpResult(status, etag: etag, body: body);
  }

  Map<String, String> get _stickerHeaders => {
        ..._headers,
        'Accept-Language': resolveL10n().localeName,
      };

  Uri _stickerUri(String path) =>
      Uri.parse('${TalkyApiClient.baseUrl}/stickers$path');

  /// `GET /stickers/catalog` — `304` si [etag] est encore valable.
  Future<StickerHttpResult> getStickerCatalog({String? etag, int? since}) {
    final uri = since == null
        ? _stickerUri('/catalog')
        : _stickerUri('/catalog').replace(queryParameters: {'since': '$since'});
    return _stickerCall(() => _client.get(uri, headers: {
          ..._stickerHeaders,
          if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
        }));
  }

  Future<StickerHttpResult> getStickerPack(String code) => _stickerCall(
      () => _client.get(_stickerUri('/packs/$code'), headers: _stickerHeaders));

  Future<StickerHttpResult> getStickerMe() => _stickerCall(
      () => _client.get(_stickerUri('/me'), headers: _stickerHeaders));

  Future<void> installStickerPack(int packId) async {
    await _stickerCall(() =>
        _client.put(_stickerUri('/me/packs/$packId'), headers: _stickerHeaders));
  }

  Future<void> removeStickerPack(int packId) async {
    await _stickerCall(() => _client.delete(_stickerUri('/me/packs/$packId'),
        headers: _stickerHeaders));
  }

  Future<void> reorderStickerPacks(List<int> ids) async {
    await _stickerCall(() => _client.put(_stickerUri('/me/packs/order'),
        headers: _stickerHeaders, body: jsonEncode({'ids': ids})));
  }

  Future<void> addStickerFavorite(int stickerId) async {
    await _stickerCall(() => _client.put(
        _stickerUri('/me/favorites/$stickerId'),
        headers: _stickerHeaders));
  }

  Future<void> removeStickerFavorite(int stickerId) async {
    await _stickerCall(() => _client.delete(
        _stickerUri('/me/favorites/$stickerId'),
        headers: _stickerHeaders));
  }

  // ── V1b : packs personnels et partage (contrat §4b) ─────────────────
  // Tout est derrière `creation_enabled` : fermé, ces routes répondent
  // `404 NOT_FOUND` (code générique), que le repository lit comme « masquer ».

  /// `GET /stickers/me/created` — mes packs actifs, stickers compris.
  Future<StickerHttpResult> getMyCreatedStickerPacks() => _stickerCall(
      () => _client.get(_stickerUri('/me/created'), headers: _stickerHeaders));

  /// `POST /stickers/packs` — crée un pack perso vide (`201 {id, code}`).
  Future<StickerHttpResult> createStickerPack() => _stickerCall(
      () => _client.post(_stickerUri('/packs'), headers: _stickerHeaders));

  /// `PATCH /stickers/packs/:id` — renomme et/ou change la couverture.
  /// [coverStickerId] : `null` ne change rien ; [resetCover] remet « premier
  /// sticker » (`null` côté serveur).
  Future<void> patchStickerPack(
    int packId, {
    Map<String, String>? nameI18n,
    int? coverStickerId,
    bool resetCover = false,
  }) async {
    final body = <String, dynamic>{
      if (nameI18n != null) 'nameI18n': nameI18n,
      if (coverStickerId != null) 'coverStickerId': coverStickerId,
      if (resetCover && coverStickerId == null) 'coverStickerId': null,
    };
    await _stickerCall(() => _client.patch(_stickerUri('/packs/$packId'),
        headers: _stickerHeaders, body: jsonEncode(body)));
  }

  /// `DELETE /stickers/packs/:id` — archive le pack (idempotent).
  Future<void> archiveStickerPack(int packId) async {
    await _stickerCall(() => _client.delete(_stickerUri('/packs/$packId'),
        headers: _stickerHeaders));
  }

  /// `PUT /stickers/packs/:id/order` — ordre des stickers du pack.
  Future<void> reorderPackStickers(int packId, List<int> stickerIds) async {
    await _stickerCall(() => _client.put(_stickerUri('/packs/$packId/order'),
        headers: _stickerHeaders, body: jsonEncode({'ids': stickerIds})));
  }

  /// `POST /stickers/packs/:id/stickers` — range un de mes actifs dans le pack.
  Future<StickerHttpResult> addAssetToStickerPack(
    int packId,
    int assetId, {
    String? emoji,
    String? name,
  }) =>
      _stickerCall(() => _client.post(_stickerUri('/packs/$packId/stickers'),
          headers: _stickerHeaders,
          body: jsonEncode({
            'assetId': assetId,
            if (emoji != null) 'emoji': emoji,
            if (name != null) 'nom': name,
          })));

  /// `DELETE /stickers/packs/:id/stickers/:stickerId` — retire du pack.
  Future<void> removeStickerFromPack(int packId, int stickerId) async {
    await _stickerCall(() => _client.delete(
        _stickerUri('/packs/$packId/stickers/$stickerId'),
        headers: _stickerHeaders));
  }

  /// `POST /stickers/assets` — multipart `file` (PNG/WebP 512×512 avec alpha,
  /// ≤ 1 Mo ; le serveur ré-encode et tranche) → `201 {assetId, stickerId,
  /// packId, reutilise}`.
  Future<StickerHttpResult> uploadStickerAsset(
    List<int> bytes, {
    required String filename,
    int? packId,
    String? emoji,
    String? name,
  }) =>
      _stickerCall(() async {
        // Reconstruit à chaque appel : une requête multipart ne se rejoue pas
        // (retour du rafraîchissement du jeton après un 401).
        final req = http.MultipartRequest('POST', _stickerUri('/assets'))
          ..headers.addAll({
            if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
            'Accept-Language': resolveL10n().localeName,
          })
          ..files.add(http.MultipartFile.fromBytes('file', bytes,
              filename: filename,
              contentType: MediaType.parse(_stickerMimeOf(filename))));
        if (packId != null) req.fields['packId'] = '$packId';
        if (emoji != null && emoji.isNotEmpty) req.fields['emoji'] = emoji;
        if (name != null && name.isNotEmpty) req.fields['nom'] = name;
        return http.Response.fromStream(await _client.send(req));
      }, timeout: const Duration(seconds: 60));

  static String _stickerMimeOf(String filename) =>
      filename.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/png';

  /// `POST /stickers/assets/animated` (V1c, contrat §4c) — multipart `file` =
  /// GIF ou WebP animé **tel que choisi** (≤ 3 Mo) + `shape` (`cercle` |
  /// `carre-arrondi` | `carre`) ; le serveur recadre, applique la forme,
  /// tronque à 3 s / 45 images et ré-encode → `201 {assetId, stickerId,
  /// packId, reutilise, animated, bytes, frames, durationMs}`.
  ///
  /// La conversion peut prendre jusqu'à ~15 s (un seul encodage animé à la
  /// fois côté serveur) : délai large. [cancel] **annule** la requête en cours
  /// (le serveur peut avoir fini : l'appelant relit ses packs).
  Future<StickerHttpResult> uploadAnimatedStickerAsset(
    List<int> bytes, {
    required String filename,
    required String shape,
    int? packId,
    String? emoji,
    String? name,
    Future<void>? cancel,
  }) =>
      _stickerCall(() async {
        final req = http.AbortableMultipartRequest(
          'POST',
          _stickerUri('/assets/animated'),
          abortTrigger: cancel,
        )
          ..headers.addAll({
            if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
            'Accept-Language': resolveL10n().localeName,
          })
          ..files.add(http.MultipartFile.fromBytes('file', bytes,
              filename: filename,
              contentType: MediaType.parse(_stickerAnimatedMimeOf(filename))))
          ..fields['shape'] = shape;
        if (packId != null) req.fields['packId'] = '$packId';
        if (emoji != null && emoji.isNotEmpty) req.fields['emoji'] = emoji;
        if (name != null && name.isNotEmpty) req.fields['nom'] = name;
        return http.Response.fromStream(await _client.send(req));
      }, timeout: const Duration(seconds: 90));

  static String _stickerAnimatedMimeOf(String filename) =>
      filename.toLowerCase().endsWith('.gif') ? 'image/gif' : 'image/webp';

  /// `DELETE /stickers/assets/:id` — supprime un de mes actifs.
  Future<void> deleteStickerAsset(int assetId) async {
    await _stickerCall(() => _client.delete(_stickerUri('/assets/$assetId'),
        headers: _stickerHeaders));
  }

  /// `POST /stickers/stickers/:stickerId/copy` — « Ajouter à un pack » depuis
  /// un sticker reçu, désigné par son `sid` (l'id du sticker de la charge
  /// utile) : le serveur résout l'actif, le copie chez moi (`201 {assetId,
  /// stickerId, packId, reutilise, copie}`). `404 STICKER_NOT_FOUND` uniforme
  /// si inaccessible ou retiré ; `403 SUBSCRIPTION_REQUIRED` pour un pack Plus.
  Future<StickerHttpResult> copyStickerBySid(
    int stickerId, {
    int? packId,
    String? emoji,
    String? name,
  }) =>
      _stickerCall(() => _client.post(_stickerUri('/stickers/$stickerId/copy'),
          headers: _stickerHeaders,
          body: jsonEncode({
            if (packId != null) 'packId': packId,
            if (emoji != null) 'emoji': emoji,
            if (name != null) 'nom': name,
          })));

  /// `POST /stickers/stickers/:stickerId/report` — sticker reçu, par son
  /// `sid`. Motif : `inapproprie|spam|droits|autre` → `200 {ok, deja}`.
  Future<StickerHttpResult> reportStickerBySid(int stickerId, String reason) =>
      _stickerCall(() => _client.post(_stickerUri('/stickers/$stickerId/report'),
          headers: _stickerHeaders, body: jsonEncode({'reason': reason})));

  /// `POST /stickers/packs/:id/share` — `{token}` (`200` si déjà partagé).
  Future<StickerHttpResult> shareStickerPack(int packId) => _stickerCall(() =>
      _client.post(_stickerUri('/packs/$packId/share'),
          headers: _stickerHeaders));

  /// `DELETE /stickers/packs/:id/share` — révoque le lien (idempotent).
  Future<void> unshareStickerPack(int packId) async {
    await _stickerCall(() => _client.delete(_stickerUri('/packs/$packId/share'),
        headers: _stickerHeaders));
  }

  /// `GET /stickers/share/:token` — fiche en lecture seule d'un pack partagé.
  Future<StickerHttpResult> getStickerShare(String token) => _stickerCall(() =>
      _client.get(_stickerUri('/share/${Uri.encodeComponent(token)}'),
          headers: _stickerHeaders));

  /// `POST /stickers/share/:token/add` — installe (copie) le pack partagé.
  Future<StickerHttpResult> addStickerShare(String token) => _stickerCall(() =>
      _client.post(_stickerUri('/share/${Uri.encodeComponent(token)}/add'),
          headers: _stickerHeaders));
}
