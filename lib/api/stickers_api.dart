// Endpoints stickers (part of talky_api_client.dart). Contrat : §4 de
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
    Future<http.Response> Function() request,
  ) async {
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
    });
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
}
