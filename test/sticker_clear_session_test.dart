// clearSession doit emporter les stickers : tables Drift, ETags/versions
// SharedPreferences et le cache disque dédié. Un appareil partagé ne doit
// jamais laisser les packs/favoris/récents d'un compte à un autre.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/local_cache_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/talky_api_client.dart';

class _FakeManager extends Fake implements CacheManager {
  int emptied = 0;
  @override
  Future<void> emptyCache() async => emptied++;
}

void main() {
  test('clearSession vide les 4 tables stickers, les ETags et le cache disque',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Cache disque : un faux enregistre les appels de purge.
    final cache = StickerCache(
        manager: _FakeManager(), canPrefetch: () async => false);
    StickerCache.shared = cache;
    addTearDown(() => StickerCache.shared = null);

    // Une session « vécue » : packs installés, stickers, favoris, récents,
    // et le catalogue mémorisé (ETag + versions).
    await db.into(db.localStickerPacks).insert(
        LocalStickerPacksCompanion.insert(
            packId: const Value(1),
            code: 'alanya',
            name: const Value('Alanya'),
            installed: const Value(true)));
    await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
        packId: 1, stickerId: const Value(4812), url: 'https://x/1.webp'));
    await db.into(db.localStickerFavorites).insert(
        LocalStickerFavoritesCompanion(stickerId: const Value(4812)));
    await db.into(db.localStickerRecents).insert(
        LocalStickerRecentsCompanion.insert(
            stickerId: const Value(4812), usedAt: DateTime.utc(2026, 1, 1)));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StickerRepository.catalogEtagKey, '"v3"');
    await prefs.setInt(StickerRepository.catalogVersionKey, 3);
    await prefs.setInt(StickerRepository.meVersionKey, 1);
    await prefs
        .setStringList(StickerRepository.unavailablePacksKey, ['mboa']);

    final repo = LocalCacheRepository(db: db, api: TalkyApiClient());
    await repo.clearSession();

    expect(await db.select(db.localStickerPacks).get(), isEmpty);
    expect(await db.select(db.localStickers).get(), isEmpty);
    expect(await db.select(db.localStickerFavorites).get(), isEmpty);
    expect(await db.select(db.localStickerRecents).get(), isEmpty);
    expect(prefs.getString(StickerRepository.catalogEtagKey), isNull);
    expect(prefs.getInt(StickerRepository.catalogVersionKey), isNull);
    expect(prefs.getInt(StickerRepository.meVersionKey), isNull);
    expect(prefs.getStringList(StickerRepository.unavailablePacksKey), isNull,
        reason: 'les packs archivés vus par un compte ne suivent pas le suivant');
    expect((cache.manager as _FakeManager).emptied, 1,
        reason: 'le cache disque des stickers est purgé');
  });
}