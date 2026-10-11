import '../../../talky_api_client.dart';

/// Accès réseau à la création de stickers et au partage (V1b, contrat §4b),
/// injectable : le repository ne connaît que cette interface, les tests lui
/// donnent les fixtures du contrat. Séparée de `StickerApi` (V1a) pour que
/// celle-ci ne bouge pas.
abstract class StickerCreationApi {
  Future<StickerHttpResult> getCreated();
  Future<StickerHttpResult> createPack();
  Future<void> patchPack(
    int packId, {
    Map<String, String>? nameI18n,
    int? coverStickerId,
    bool resetCover,
  });
  Future<void> archivePack(int packId);
  Future<void> reorderStickers(int packId, List<int> stickerIds);
  Future<StickerHttpResult> addAssetToPack(
    int packId,
    int assetId, {
    String? emoji,
    String? name,
  });
  Future<void> removeStickerFromPack(int packId, int stickerId);
  Future<StickerHttpResult> uploadAsset(
    List<int> bytes, {
    required String filename,
    int? packId,
    String? emoji,
    String? name,
  });
  Future<void> deleteAsset(int assetId);

  /// V1c (contrat §4c) : GIF ou WebP animé **tel quel**, `shape` =
  /// `cercle` | `carre-arrondi` | `carre`. [cancel] interrompt la requête.
  /// Vidéo (§4d) : [startMs] et [durationMs] donnent la fenêtre à découper.
  Future<StickerHttpResult> uploadAnimatedAsset(
    List<int> bytes, {
    required String filename,
    required String shape,
    int? packId,
    String? emoji,
    String? name,
    int? startMs,
    int? durationMs,
    Future<void>? cancel,
  });

  /// Sticker reçu, désigné par son `sid` (id du sticker, pas de l'actif).
  Future<StickerHttpResult> copySticker(
    int stickerId, {
    int? packId,
    String? emoji,
    String? name,
  });
  Future<StickerHttpResult> reportSticker(int stickerId, String reason);
  Future<StickerHttpResult> sharePack(int packId);
  Future<void> unsharePack(int packId);
  Future<StickerHttpResult> getShare(String token);
  Future<StickerHttpResult> addShare(String token);
}

/// Adaptateur : [TalkyApiClient] → [StickerCreationApi].
class TalkyStickerCreationApi implements StickerCreationApi {
  TalkyStickerCreationApi(this._client);
  final TalkyApiClient _client;

  @override
  Future<StickerHttpResult> getCreated() => _client.getMyCreatedStickerPacks();
  @override
  Future<StickerHttpResult> createPack() => _client.createStickerPack();
  @override
  Future<void> patchPack(
    int packId, {
    Map<String, String>? nameI18n,
    int? coverStickerId,
    bool resetCover = false,
  }) => _client.patchStickerPack(
    packId,
    nameI18n: nameI18n,
    coverStickerId: coverStickerId,
    resetCover: resetCover,
  );
  @override
  Future<void> archivePack(int packId) => _client.archiveStickerPack(packId);
  @override
  Future<void> reorderStickers(int packId, List<int> stickerIds) =>
      _client.reorderPackStickers(packId, stickerIds);
  @override
  Future<StickerHttpResult> addAssetToPack(
    int packId,
    int assetId, {
    String? emoji,
    String? name,
  }) =>
      _client.addAssetToStickerPack(packId, assetId, emoji: emoji, name: name);
  @override
  Future<void> removeStickerFromPack(int packId, int stickerId) =>
      _client.removeStickerFromPack(packId, stickerId);
  @override
  Future<StickerHttpResult> uploadAsset(
    List<int> bytes, {
    required String filename,
    int? packId,
    String? emoji,
    String? name,
  }) => _client.uploadStickerAsset(
    bytes,
    filename: filename,
    packId: packId,
    emoji: emoji,
    name: name,
  );
  @override
  Future<StickerHttpResult> uploadAnimatedAsset(
    List<int> bytes, {
    required String filename,
    required String shape,
    int? packId,
    String? emoji,
    String? name,
    int? startMs,
    int? durationMs,
    Future<void>? cancel,
  }) => _client.uploadAnimatedStickerAsset(
    bytes,
    filename: filename,
    shape: shape,
    packId: packId,
    emoji: emoji,
    name: name,
    startMs: startMs,
    durationMs: durationMs,
    cancel: cancel,
  );
  @override
  Future<void> deleteAsset(int assetId) => _client.deleteStickerAsset(assetId);
  @override
  Future<StickerHttpResult> copySticker(
    int stickerId, {
    int? packId,
    String? emoji,
    String? name,
  }) => _client.copyStickerBySid(
    stickerId,
    packId: packId,
    emoji: emoji,
    name: name,
  );
  @override
  Future<StickerHttpResult> reportSticker(int stickerId, String reason) =>
      _client.reportStickerBySid(stickerId, reason);
  @override
  Future<StickerHttpResult> sharePack(int packId) =>
      _client.shareStickerPack(packId);
  @override
  Future<void> unsharePack(int packId) => _client.unshareStickerPack(packId);
  @override
  Future<StickerHttpResult> getShare(String token) =>
      _client.getStickerShare(token);
  @override
  Future<StickerHttpResult> addShare(String token) =>
      _client.addStickerShare(token);
}
