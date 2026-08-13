import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/db/app_database.dart';

/// Rejoue l'échelle de migrations depuis chaque version passée.
///
/// Le bug d'origine : les colonnes de compte officiel étaient ajoutées par le
/// bloc `from < 20` *et* rejouées par le rattrapage `from < 21`. Le second
/// `ALTER TABLE local_users ADD COLUMN account_type` échouait en « duplicate
/// column name » — dans `beforeOpen`, donc `ensureOpen()` rejetait et plus
/// aucune requête sur le cache ne passait : zéro conversation à l'écran. Comme
/// `user_version` n'était jamais incrémenté, l'échec se répétait à chaque
/// lancement.
///
/// Invisible sur une install neuve (`onCreate` construit le schéma courant d'un
/// coup, `onUpgrade` n'est jamais appelé) : seule une base préexistante migre.
/// D'où ce test, qui fabrique justement des bases préexistantes.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('alanya_migration_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Crée une base au schéma courant, rembobine `user_version` à [from], puis
  /// la rouvre — ce qui déclenche `onUpgrade(from, schemaVersion)` sur une base
  /// dont toutes les colonnes sont déjà présentes, le pire cas pour un
  /// `ALTER TABLE … ADD COLUMN` non gardé.
  Future<AppDatabase> reopenFrom(int from, {String? name}) async {
    final file = File(p.join(tmp.path, name ?? 'v$from.sqlite'));

    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.customSelect('SELECT 1').get();
    await seed.customStatement('PRAGMA user_version = $from');
    await seed.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    await migrated.customSelect('SELECT 1').get();
    return migrated;
  }

  Future<List<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  test('la migration 19 → courant ne rejoue pas les colonnes deux fois',
      () async {
    // from = 19 exécute `from < 20` (qui pose les colonnes) puis `from < 21`
    // (qui les reposait). C'est le scénario qui plantait systématiquement.
    final db = await reopenFrom(19);
    addTearDown(db.close);

    final columns = await columnsOf(db, 'local_users');
    expect(columns.where((c) => c == 'account_type'), hasLength(1));
    expect(columns, containsAll(['verification_status', 'verified_until']));
  });

  test('la migration 20 → courant supporte les colonnes déjà posées', () async {
    // Base laissée par un build v20 « broadcast » : les colonnes existent, seul
    // le rattrapage `from < 21` s'exécute.
    final db = await reopenFrom(20);
    addTearDown(db.close);

    expect(await columnsOf(db, 'local_users'), contains('account_type'));
  });

  test('chaque version passée migre jusqu\'au schéma courant', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final target = db.schemaVersion;
    await db.close();

    for (var from = 1; from < target; from++) {
      final migrated = await reopenFrom(from);
      try {
        final version = await migrated.customSelect('PRAGMA user_version').get();
        expect(version.single.read<int>('user_version'), target,
            reason: 'migration depuis v$from non finalisée');

        // Le cache reste interrogeable : c'est ce qui manquait quand la
        // migration échouait.
        await migrated.select(migrated.localUsers).get();
        await migrated.select(migrated.localConversations).get();
        await migrated.select(migrated.localTrips).get();
      } finally {
        await migrated.close();
      }
    }
  });

  test('une migration interrompue avant user_version se rejoue sans casser',
      () async {
    // Appareil déjà bloqué : l'ALTER avait été appliqué, mais l'échec suivant
    // avait empêché la mise à jour de `user_version`. Rouvrir doit réparer, pas
    // replanter.
    final first = await reopenFrom(19, name: 'interrompue.sqlite');
    await first.customStatement('PRAGMA user_version = 19');
    await first.close();

    final second = AppDatabase.forTesting(
        NativeDatabase(File(p.join(tmp.path, 'interrompue.sqlite'))));
    addTearDown(second.close);

    await second.customSelect('SELECT 1').get();
    final version = await second.customSelect('PRAGMA user_version').get();
    expect(version.single.read<int>('user_version'), second.schemaVersion);
  });
}
