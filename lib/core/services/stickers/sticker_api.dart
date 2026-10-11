import '../../../talky_api_client.dart';

/// Accès réseau aux stickers, injectable : le repository ne connaît que cette
/// interface, les tests lui donnent les fixtures du contrat.
abstract class StickerApi {
  /// `notModified` si l'ETag fourni est encore valable (304).
  Future<StickerHttpResult> getCatalog({String? etag, int? since});
  Future<StickerHttpResult> getPack(String code);
  Future<StickerHttpResult> getMe();
  Future<void> installPack(int packId);
  Future<void> removePack(int packId);
  Future<void> reorderPacks(List<int> ids);
  Future<void> addFavorite(int stickerId);
  Future<void> removeFavorite(int stickerId);
}

/// Adaptateur : [TalkyApiClient] → [StickerApi] (les endpoints sont des
/// extensions, qui ne satisfont pas `implements`).
class TalkyStickerApi implements StickerApi {
  TalkyStickerApi(this._client);
  final TalkyApiClient _client;

  @override
  Future<StickerHttpResult> getCatalog({String? etag, int? since}) =>
      _client.getStickerCatalog(etag: etag, since: since);
  @override
  Future<StickerHttpResult> getPack(String code) => _client.getStickerPack(code);
  @override
  Future<StickerHttpResult> getMe() => _client.getStickerMe();
  @override
  Future<void> installPack(int packId) => _client.installStickerPack(packId);
  @override
  Future<void> removePack(int packId) => _client.removeStickerPack(packId);
  @override
  Future<void> reorderPacks(List<int> ids) => _client.reorderStickerPacks(ids);
  @override
  Future<void> addFavorite(int stickerId) =>
      _client.addStickerFavorite(stickerId);
  @override
  Future<void> removeFavorite(int stickerId) =>
      _client.removeStickerFavorite(stickerId);
}
