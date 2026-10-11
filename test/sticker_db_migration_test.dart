// Migration Drift 26 → 27 : quatre tables stickers, rien d'autre ne bouge.
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

  test('schemaVersion vaut 27', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 27);
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
    expect(v.read<int>('user_version'), 27);
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
}
