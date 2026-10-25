// StickerRepository contre les fixtures du contrat (client API injecté).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_api.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/talky_api_client.dart';

dynamic _fx(String nom) =>
    jsonDecode(File('test/fixtures/stickers/$nom').readAsStringSync());

class FakeApi implements StickerApi {
  final calls = <String>[];
  String? lastEtag;
  bool closed = false;
  bool catalogNotModified = false;
  Object? failInstall;

  void _guard() {
    if (closed) throw TalkyException('nope', 404);
  }

  @override
  Future<StickerHttpResult> getCatalog({String? etag, int? since}) async {
    _guard();
    calls.add('catalog');
    lastEtag = etag;
    if (catalogNotModified) return const StickerHttpResult(304);
    return StickerHttpResult(200, etag: '"v3"', body: _fx('catalog.json'));
  }

  @override
  Future<StickerHttpResult> getMe() async {
    _guard();
    calls.add('me');
    return StickerHttpResult(200, body: _fx('me.json'));
  }

  @override
  Future<StickerHttpResult> getPack(String code) async {
    calls.add('pack:$code');
    return StickerHttpResult(200, body: _fx('pack.json'));
  }

  @override
  Future<void> installPack(int id) async {
    calls.add('install:$id');
    if (failInstall != null) throw failInstall!;
  }

  @override
  Future<void> removePack(int id) async => calls.add('remove:$id');
  @override
  Future<void> reorderPacks(List<int> ids) async => calls.add('order:$ids');
  @override
  Future<void> addFavorite(int id) async => calls.add('fav+$id');
  @override
  Future<void> removeFavorite(int id) async => calls.add('fav-$id');
}

void main() {
  late AppDatabase db;
  late FakeApi api;
  late StickerRepository repo;
  var clock = DateTime.utc(2026, 1, 1);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeApi();
    repo = StickerRepository(db: db, api: api, now: () => clock = clock.add(const Duration(seconds: 1)));
  });
  tearDown(() => db.close());

  test('catalogue : packs de la fixture, ordre du serveur, verrou reflété', () async {
    await repo.syncCatalog();
    final packs = await repo.watchCatalog().first;
    expect(packs.map((p) => p.code), ['alanya', 'royal']);
    expect(packs[0].installedByDefault, isTrue);
    expect(packs[1].isPremium, isTrue);
    expect(packs[1].locked, isTrue);
    expect(packs[0].name, 'Alanya');
  });

  test('catalogue : ETag renvoyé seulement si le cache local est rempli', () async {
    await repo.syncCatalog();
    expect(api.lastEtag, isNull);
    await repo.syncCatalog();
    expect(api.lastEtag, '"v3"');
    api.catalogNotModified = true;
    await repo.syncCatalog();
    expect((await repo.watchCatalog().first), hasLength(2));
  });

  test('me : installés (ordre) et favoris', () async {
    await repo.syncCatalog();
    await repo.syncMe();
    final installed = await repo.watchInstalled().first;
    // `mboa` (id 3) n'est pas au catalogue : ligne minimale conservée.
    expect(installed.map((p) => p.code), ['alanya', 'mboa']);
    expect(installed.map((p) => p.position), [0, 1]);
    expect((await repo.watchFavoriteIds().first), {1, 45, 46});
  });

  test('pack : stickers de la fixture, favoris et récents jointés', () async {
    await repo.syncCatalog();
    await repo.syncMe();
    await repo.syncInstalledPacks();
    expect(api.calls, contains('pack:alanya'));
    final stickers = await repo.watchStickers(1).first;
    expect(stickers.single.emoji, '👋');
    expect(stickers.single.thumbUrl, endsWith('_t.webp'));

    final favs = await repo.watchFavorites().first;
    expect(favs.map((e) => e.sticker.stickerId), [1]); // 45, 46 : stickers inconnus
    expect(favs.single.payload.pack, 'alanya');

    await repo.markUsed(1);
    final recents = await repo.watchRecents().first;
    expect(recents.single.payload.encode(), contains('"sid":1'));
  });

  test('installer / retirer / favori : le serveur d\'abord', () async {
    await repo.syncCatalog();
    final royal = (await repo.watchCatalog().first).last;
    api.failInstall = TalkyException('x', 403, code: 'SUBSCRIPTION_REQUIRED');
    await expectLater(repo.installPack(royal), throwsA(isA<TalkyException>()));
    expect(await repo.watchInstalled().first, isEmpty);

    api.failInstall = null;
    await repo.installPack(royal);
    expect((await repo.watchInstalled().first).single.code, 'royal');
    await repo.removePack(royal.packId);
    expect(await repo.watchInstalled().first, isEmpty);

    await repo.syncInstalledPacks();
    await repo.fetchPack('alanya');
    await repo.setFavorite(1, true);
    expect(await repo.watchFavoriteIds().first, {1});
    await repo.setFavorite(1, false);
    expect(await repo.watchFavoriteIds().first, isEmpty);
  });

  test('réordonner : local puis serveur', () async {
    await repo.syncCatalog();
    await repo.syncMe();
    await repo.reorderPacks([3, 1]);
    expect((await repo.watchInstalled().first).map((p) => p.code), ['mboa', 'alanya']);
    expect(api.calls.last, 'order:[3, 1]');
  });

  test('récents plafonnés', () async {
    await repo.fetchPack('alanya');
    for (var i = 1; i <= StickerRepository.maxRecents + 5; i++) {
      await db.into(db.localStickers).insertOnConflictUpdate(
          LocalStickersCompanion.insert(
              stickerId: Value(i), packId: 1, url: 'u$i'));
      await repo.markUsed(i);
    }
    final rows = await db.select(db.localStickerRecents).get();
    expect(rows.length, StickerRepository.maxRecents);
  });

  test('module fermé (404 sans code) : indisponible, rien d\'affiché', () async {
    api.closed = true;
    await repo.refresh();
    expect(repo.available.value, isFalse);
    expect(await repo.watchCatalog().first, isEmpty);
  });

  test('événement stickers:sync relit /me', () async {
    await repo.syncCatalog();
    await repo.onSyncEvent({'reason': 'favorites', 'version': 13});
    expect(api.calls, contains('me'));
  });
}
