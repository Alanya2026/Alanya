// Faux clients et utilitaires partagés par les tests de la création de
// stickers (V1b) : ils répondent avec les fixtures du contrat §4b.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:talky_flutter/core/services/stickers/sticker_api.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_api.dart';
import 'package:talky_flutter/talky_api_client.dart';

dynamic fx(String nom) =>
    jsonDecode(File('test/fixtures/stickers/$nom').readAsStringSync());

/// Faux client V1b : répond avec les fixtures, enregistre les appels.
class FakeCreationApi implements StickerCreationApi {
  final calls = <String>[];
  Object? patchBody;
  Object? failNext;
  bool closed = false;
  Map<String, dynamic>? created;

  /// État serveur simulé (copie profonde de la fixture), modifié par les
  /// actions de partage et d'archivage comme le ferait le vrai serveur.
  Map<String, dynamic> get state =>
      created ??= jsonDecode(jsonEncode(fx('created.json'))) as Map<String, dynamic>;

  /// Pack perso par défaut : le premier ; sinon « Mes stickers », créé.
  Map<String, dynamic> _defaultPack() {
    final packs = (state['packs'] as List).cast<Map<String, dynamic>>();
    if (packs.isNotEmpty) return packs.first;
    final p = <String, dynamic>{
      'id': 41,
      'code': 'u_7_ab12cd34',
      'name': 'Mes stickers',
      'nameI18n': {'fr': 'Mes stickers'},
      'version': 1,
      'shared': false,
      'shareToken': null,
      'cover': null,
      'count': 0,
      'stickers': [],
    };
    packs.add(p);
    return p;
  }

  Map<String, dynamic>? _pack(int id) => (state['packs'] as List)
      .cast<Map<String, dynamic>>()
      .where((p) => p['id'] == id)
      .firstOrNull;
  Map<String, dynamic> sharePreview = Map.of(fx('share-preview.json') as Map).cast();
  Map<String, dynamic> shareAdd = Map.of(fx('share-add.json') as Map).cast();
  bool reportDeja = false;
  bool copyReused = false;

  /// `POST /assets` répond « réutilisé » (image déjà possédée).
  bool uploadReused = false;

  void _guard() {
    if (closed) throw TalkyException('nope', 404, code: 'NOT_FOUND');
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<StickerHttpResult> getCreated() async {
    if (closed) throw TalkyException('nope', 404, code: 'NOT_FOUND');
    calls.add('created');
    return StickerHttpResult(200, body: state);
  }

  @override
  Future<StickerHttpResult> createPack() async {
    _guard();
    calls.add('create');
    (state['packs'] as List).add({
      'id': 43,
      'code': 'u_7_11223344',
      'name': 'Mes stickers',
      'nameI18n': {'fr': 'Mes stickers'},
      'version': 1,
      'shared': false,
      'shareToken': null,
      'cover': null,
      'count': 0,
      'stickers': [],
    });
    return StickerHttpResult(201, body: fx('pack-created.json'));
  }

  @override
  Future<void> patchPack(int packId,
      {Map<String, String>? nameI18n, int? coverStickerId, bool resetCover = false}) async {
    _guard();
    calls.add('patch:$packId');
    final n = nameI18n?['fr'];
    if (n != null) _pack(packId)?['name'] = n;
    patchBody = {'nameI18n': nameI18n, 'cover': coverStickerId, 'reset': resetCover};
  }

  @override
  Future<void> archivePack(int packId) async {
    _guard();
    calls.add('archive:$packId');
    (state['packs'] as List).removeWhere((p) => (p as Map)['id'] == packId);
  }

  @override
  Future<void> reorderStickers(int packId, List<int> ids) async {
    _guard();
    calls.add('order:$packId:$ids');
  }

  @override
  Future<StickerHttpResult> addAssetToPack(int packId, int assetId,
      {String? emoji, String? name}) async {
    _guard();
    calls.add('addAsset:$packId:$assetId');
    return StickerHttpResult(201, body: {'stickerId': 1, 'packId': packId, 'assetId': assetId});
  }

  @override
  Future<void> removeStickerFromPack(int packId, int stickerId) async {
    _guard();
    calls.add('remove:$packId:$stickerId');
    final pack = _pack(packId);
    if (pack != null) {
      (pack['stickers'] as List).removeWhere((s) => (s as Map)['id'] == stickerId);
      pack['count'] = (pack['stickers'] as List).length;
    }
  }

  @override
  Future<StickerHttpResult> uploadAsset(List<int> bytes,
      {required String filename, int? packId, String? emoji, String? name}) async {
    _guard();
    calls.add('upload:$packId:$filename:${bytes.length}');
    // Sans `packId` : le serveur range dans le pack perso par défaut (le plus
    // ancien), créé au besoin (contrat §4b).
    final pack = packId == null ? _defaultPack() : _pack(packId);
    if (pack != null) {
      (pack['stickers'] as List).add({
        'id': 503,
        'position': (pack['stickers'] as List).length,
        'emoji': '😀',
        'name': '',
        'url': 'https://<bucket>/stickers/u/7/new_ee.webp',
        'thumb': 'https://<bucket>/stickers/u/7/new_ee_t.webp',
        'w': 512,
        'h': 512,
        'animated': false,
        'bytes': 1000,
        'assetId': 9003,
      });
      pack['count'] = (pack['stickers'] as List).length;
    }
    final body = Map<String, dynamic>.from(fx('asset-created.json') as Map);
    if (uploadReused) body['reutilise'] = true;
    return StickerHttpResult(201, body: body);
  }

  @override
  Future<void> deleteAsset(int assetId) async => calls.add('deleteAsset:$assetId');

  /// Création animée (V1c) : réponse de la fixture `asset-animated-created.json`.
  /// [holdAnimated] suspend l'appel (conversion serveur en cours) jusqu'à son
  /// achèvement ou à l'annulation.
  Completer<void>? holdAnimated;
  final animatedShapes = <String>[];

  @override
  Future<StickerHttpResult> uploadAnimatedAsset(List<int> bytes,
      {required String filename,
      required String shape,
      int? packId,
      String? emoji,
      String? name,
      Future<void>? cancel}) async {
    _guard();
    calls.add('animated:$packId:$filename:$shape:${bytes.length}');
    animatedShapes.add(shape);
    final hold = holdAnimated;
    if (hold != null) {
      final aborted = Completer<void>();
      unawaited(cancel?.then((_) {
        if (!aborted.isCompleted) aborted.complete();
      }));
      await Future.any([hold.future, aborted.future]);
      if (aborted.isCompleted) {
        calls.add('animated-aborted');
        throw TalkyException('annulé', 0);
      }
    }
    final pack = packId == null ? _defaultPack() : _pack(packId);
    if (pack != null) {
      (pack['stickers'] as List).add({
        'id': 504,
        'position': (pack['stickers'] as List).length,
        'emoji': '😀',
        'name': '',
        'url': 'https://<bucket>/stickers/u/7/anim_ff.webp',
        'thumb': 'https://<bucket>/stickers/u/7/anim_ff_t.webp',
        'w': 512,
        'h': 512,
        'animated': true,
        'bytes': 120000,
        'assetId': 9004,
      });
      pack['count'] = (pack['stickers'] as List).length;
    }
    return StickerHttpResult(201, body: fx('asset-animated-created.json'));
  }

  @override
  Future<StickerHttpResult> copySticker(int stickerId,
      {int? packId, String? emoji, String? name}) async {
    _guard();
    calls.add('copy:$stickerId:$packId');
    final body = Map<String, dynamic>.from(fx('asset-copy.json') as Map);
    if (copyReused) body['reutilise'] = true;
    return StickerHttpResult(201, body: body);
  }

  @override
  Future<StickerHttpResult> reportSticker(int stickerId, String reason) async {
    _guard();
    calls.add('report:$stickerId:$reason');
    final body = Map<String, dynamic>.from(fx('report.json') as Map);
    body['deja'] = reportDeja;
    return StickerHttpResult(200, body: body);
  }

  @override
  Future<StickerHttpResult> sharePack(int packId) async {
    _guard();
    calls.add('share:$packId');
    _pack(packId)
      ?..['shared'] = true
      ..['shareToken'] = 'Zk3_9aQpLm-X7vB2nR4tYw8e';
    return StickerHttpResult(201, body: fx('share-token.json'));
  }

  @override
  Future<void> unsharePack(int packId) async {
    _guard();
    calls.add('unshare:$packId');
    _pack(packId)
      ?..['shared'] = false
      ..['shareToken'] = null;
  }

  @override
  Future<StickerHttpResult> getShare(String token) async {
    _guard();
    calls.add('getShare:$token');
    return StickerHttpResult(200, body: sharePreview);
  }

  @override
  Future<StickerHttpResult> addShare(String token) async {
    _guard();
    calls.add('addShare:$token');
    return StickerHttpResult(shareAdd['deja'] == true ? 200 : 201, body: shareAdd);
  }
}

/// PNG RGBA 512×512 minimal : seul l'en-tête compte pour le contrôle client.
Uint8List png512() {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13]);
  b.add('IHDR'.codeUnits);
  b.add([0, 0, 2, 0, 0, 0, 2, 0, 8, 6, 0, 0, 0, 0, 0, 0, 0]);
  return b.toBytes();
}

Uint8List png(int w, int h) {
  final d = png512();
  d[16] = w >> 24 & 255;
  d[17] = w >> 16 & 255;
  d[18] = w >> 8 & 255;
  d[19] = w & 255;
  d[20] = h >> 24 & 255;
  d[21] = h >> 16 & 255;
  d[22] = h >> 8 & 255;
  d[23] = h & 255;
  return d;
}

const kToken = 'Zk3_9aQpLm-X7vB2nR4tYw8e';


/// Catalogue + « installés » officiels (fixtures V1a).
class OfficialStickerApi implements StickerApi {
  final packCalls = <String>[];
  @override
  Future<StickerHttpResult> getCatalog({String? etag, int? since}) async =>
      StickerHttpResult(200, body: fx('catalog.json'));
  @override
  Future<StickerHttpResult> getMe() async =>
      StickerHttpResult(200, body: fx('me.json'));
  @override
  Future<StickerHttpResult> getPack(String code) async {
    packCalls.add(code);
    return StickerHttpResult(200, body: fx('pack.json'));
  }

  @override
  Future<void> installPack(int packId) async {}
  @override
  Future<void> removePack(int packId) async {}
  @override
  Future<void> reorderPacks(List<int> ids) async {}
  @override
  Future<void> addFavorite(int stickerId) async {}
  @override
  Future<void> removeFavorite(int stickerId) async {}
}
