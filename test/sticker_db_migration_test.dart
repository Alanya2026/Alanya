// Migrations Drift 26 → 27 (quatre tables stickers) et 27 → 28 (V1b : colonnes
// `owned`, `share_token`, `asset_id`) : rien d'autre ne bouge.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/db/app_database.dart';

const _tables = [
  'local_sticker_packs',
  'local_stickers',
  'local_sticker_favorites',
  'local_sticker_recents',
];

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('alanya_stk_'));
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<Set<String>> tablesOf(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('schemaVersion vaut 28', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 28);
  });

  test('base neuve : les quatre tables existent', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await tablesOf(db), containsAll(_tables));
  });

  test('26 → 27 : tables créées, messages existants intacts', () async {
    final file = File(p.join(tmp.path, 'v26.sqlite'));

    // Fabrique une base « v26 » : schéma courant moins les tables stickers.
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.into(seed.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: 'avant',
          conversationID: 1,
          senderID: 2,
          sendAt: DateTime.utc(2026, 1, 1),
          content: const Value('bonjour'),
        ));
    for (final t in _tables) {
      await seed.customStatement('DROP TABLE $t');
    }
    await seed.customStatement('PRAGMA user_version = 26');
    await seed.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await tablesOf(db), containsAll(_tables));

    final msgs = await db.select(db.localMessages).get();
    expect(msgs.single.content, 'bonjour');

    // Les nouvelles tables sont utilisables.
    await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
          packId: const Value(1),
          code: 'alanya',
        ));
    await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
          stickerId: const Value(1),
          packId: 1,
          url: 'https://x/1.webp',
        ));
    await db.into(db.localStickerFavorites).insert(
        LocalStickerFavoritesCompanion.insert(stickerId: const Value(1)));
    await db.into(db.localStickerRecents).insert(
        LocalStickerRecentsCompanion.insert(
            stickerId: const Value(1), usedAt: DateTime.utc(2026, 1, 2)));
    expect((await db.select(db.localStickerPacks).get()).single.code, 'alanya');
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 28);
  });

  test('26 → 27 rejouable (tables déjà présentes)', () async {
    final file = File(p.join(tmp.path, 'replay.sqlite'));
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.customSelect('SELECT 1').get();
    await seed.customStatement('PRAGMA user_version = 26');
    await seed.close();
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await tablesOf(db), containsAll(_tables));
  });

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('27 → 28 : colonnes V1b ajoutées, packs et stickers existants intacts', () async {
    final file = File(p.join(tmp.path, 'v27.sqlite'));

    // Base « v27 » : les deux tables dans leur forme d'avant la V1b.
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.customSelect('SELECT 1').get();
    await seed.customStatement('DROP TABLE local_sticker_packs');
    await seed.customStatement('DROP TABLE local_stickers');
    await seed.customStatement('''
      CREATE TABLE local_sticker_packs (
        pack_id INTEGER NOT NULL, code TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '', description TEXT NULL, cover_url TEXT NULL,
        sticker_count INTEGER NOT NULL DEFAULT 0, is_premium INTEGER NOT NULL DEFAULT 0,
        locked INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL DEFAULT 1,
        installed_by_default INTEGER NOT NULL DEFAULT 0, installed INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0, catalog_position INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (pack_id))''');
    await seed.customStatement('''
      CREATE TABLE local_stickers (
        sticker_id INTEGER NOT NULL, pack_id INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0, emoji TEXT NOT NULL DEFAULT '',
        name TEXT NULL, url TEXT NOT NULL, thumb_url TEXT NULL,
        width INTEGER NOT NULL DEFAULT 512, height INTEGER NOT NULL DEFAULT 512,
        animated INTEGER NOT NULL DEFAULT 0, bytes INTEGER NULL,
        PRIMARY KEY (sticker_id))''');
    await seed.customStatement(
        "INSERT INTO local_sticker_packs (pack_id, code, name, installed) VALUES (1, 'alanya', 'Alanya', 1)");
    await seed.customStatement(
        "INSERT INTO local_stickers (sticker_id, pack_id, url) VALUES (4812, 1, 'https://x/1.webp')");
    await seed.customStatement('PRAGMA user_version = 27');
    expect(await columnsOf(seed, 'local_sticker_packs'), isNot(contains('owned')));
    await seed.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await columnsOf(db, 'local_sticker_packs'),
        containsAll(['owned', 'share_token']));
    expect(await columnsOf(db, 'local_stickers'), contains('asset_id'));

    final pack = (await db.select(db.localStickerPacks).get()).single;
    expect((pack.code, pack.installed, pack.owned, pack.shareToken), ('alanya', true, false, null));
    final st = (await db.select(db.localStickers).get()).single;
    expect((st.stickerId, st.assetId), (4812, null));

    // Les nouvelles colonnes s'écrivent.
    await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
        packId: const Value(2),
        code: 'u_7_ab',
        owned: const Value(true),
        shareToken: const Value('Zk3_9aQpLm-X7vB2nR4tYw8e')));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 28);
  });

  test('27 → 28 rejouable (colonnes déjà présentes)', () async {
    final file = File(p.join(tmp.path, 'replay28.sqlite'));
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.customSelect('SELECT 1').get();
    await seed.customStatement('PRAGMA user_version = 27');
    await seed.close();
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await columnsOf(db, 'local_sticker_packs'), contains('owned'));
  });
}
