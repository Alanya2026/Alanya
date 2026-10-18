import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Base de l'état Signal de cet appareil : identité, pré-clés, sessions.
///
/// ── Pourquoi une base à part, et pas des tables de plus dans `talky_chat` ──
///
/// `talky_chat.sqlite` est l'unité de la sauvegarde (`backup_snapshot.dart`).
/// Y ranger l'état Signal, ce serait le sauvegarder — et donc le restaurer.
/// Or une session restaurée depuis une sauvegarde d'hier est une session
/// revenue en arrière : ses compteurs ont déjà servi, ses clés de message ont
/// déjà été consommées, et les correspondants ont avancé sans elle. Chaque
/// message suivant serait illisible, sans que rien ne l'explique.
///
/// Cette base vit donc dans son propre dossier (`<support>/e2ee/`), exclu de
/// la sauvegarde de l'application, de la sauvegarde automatique Android et de
/// la sauvegarde iCloud. La perdre n'est pas grave : l'appareil publie une
/// identité neuve, et ses correspondants rouvrent une session. C'est le
/// comportement d'une réinstallation, et il est correct.
///
/// ── Pourquoi du SQL écrit à la main ──
///
/// Six tables de clé → enregistrement, lues et écrites par une poignée de
/// méthodes du store. Elles n'appellent ni requêtes réactives ni jointures : la
/// génération de code de drift n'apporterait rien ici, et ce fichier reste
/// lisible sans `build_runner`.
///
/// Les enregistrements privés (`record`, `key_pair`) sont scellés par
/// `CoffreE2ee` avant d'arriver ici : cette classe ne voit que des octets
/// opaques.
class E2eeDatabase extends GeneratedDatabase {
  E2eeDatabase(super.executor);

  /// Ouvre la base de cet appareil, en arrière-plan.
  factory E2eeDatabase.appareil() => E2eeDatabase(
        LazyDatabase(() async => NativeDatabase.createInBackground(await e2eeDatabaseFile())),
      );

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          for (final sql in _schema) {
            await customStatement(sql);
          }
        },
        onUpgrade: (m, from, to) async {
          // Toutes les créations sont en `IF NOT EXISTS` : rejouer le schéma
          // entier ajoute ce qui manque sans toucher à l'existant.
          for (final sql in _schema) {
            await customStatement(sql);
          }
        },
        beforeOpen: (details) async {
          // Écritures fréquentes et petites (une session par message) :
          // le journal WAL évite de réécrire la page entière à chacune.
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );

  static const List<String> _schema = [
    // Petites valeurs : propriétaire du coffre, compteurs d'identifiants.
    'CREATE TABLE IF NOT EXISTS e2ee_meta ('
        ' cle TEXT NOT NULL PRIMARY KEY,'
        ' valeur TEXT NOT NULL)',
    // L'identité de CET appareil : une seule ligne.
    'CREATE TABLE IF NOT EXISTS e2ee_identite ('
        ' id INTEGER NOT NULL PRIMARY KEY CHECK (id = 1),'
        ' registration_id INTEGER NOT NULL,'
        ' key_pair BLOB NOT NULL,'
        ' cree_le INTEGER NOT NULL)',
    'CREATE TABLE IF NOT EXISTS e2ee_prekeys ('
        ' id INTEGER NOT NULL PRIMARY KEY,'
        ' record BLOB NOT NULL)',
    'CREATE TABLE IF NOT EXISTS e2ee_signed_prekeys ('
        ' id INTEGER NOT NULL PRIMARY KEY,'
        ' record BLOB NOT NULL,'
        ' cree_le INTEGER NOT NULL)',
    // Une session par appareil correspondant (compte, appareil).
    'CREATE TABLE IF NOT EXISTS e2ee_sessions ('
        ' nom TEXT NOT NULL,'
        ' appareil INTEGER NOT NULL,'
        ' record BLOB NOT NULL,'
        ' PRIMARY KEY (nom, appareil))',
    // Identités des correspondants, telles qu'utilisées pour ouvrir les
    // sessions. C'est d'ELLES que se calcule le code de sécurité, jamais de ce
    // que le serveur annonce (docs/e2ee, chapitre 6).
    'CREATE TABLE IF NOT EXISTS e2ee_identites_distantes ('
        ' nom TEXT NOT NULL,'
        ' appareil INTEGER NOT NULL,'
        ' identity_key BLOB NOT NULL,'
        ' vu_le INTEGER NOT NULL,'
        ' PRIMARY KEY (nom, appareil))',
    // Conversations passées en chiffré (v2). À sens unique : on n'y efface
    // jamais une ligne sur la parole du serveur (docs/e2ee, chapitre 21).
    'CREATE TABLE IF NOT EXISTS e2ee_conversations ('
        ' conv INTEGER NOT NULL PRIMARY KEY,'
        ' depuis INTEGER NOT NULL)',
  ];

  // ── Accès élémentaires ─────────────────────────────────────────────────

  Future<String?> lireMeta(String cle) async {
    final rows = await customSelect(
      'SELECT valeur FROM e2ee_meta WHERE cle = ?',
      variables: [Variable.withString(cle)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('valeur');
  }

  Future<void> ecrireMeta(String cle, String valeur) => customStatement(
        'INSERT INTO e2ee_meta (cle, valeur) VALUES (?, ?) '
        'ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur',
        [cle, valeur],
      );

  /// Un BLOB par clé primaire entière, ou `null`.
  Future<Uint8List?> lireBlob(String table, String colonne, int id) async {
    final rows = await customSelect(
      'SELECT $colonne AS b FROM $table WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<Uint8List>('b');
  }

  /// Vide toutes les tables : identité, pré-clés, sessions, méta.
  ///
  /// DELETE et non suppression du fichier : la base est peut-être ouverte par
  /// un autre accès en cours, et un fichier supprimé sous une connexion
  /// ouverte survit sur Linux comme sur Android jusqu'à sa fermeture.
  Future<void> toutEffacer() => transaction(() async {
        for (final table in const [
          'e2ee_conversations',
          'e2ee_sessions',
          'e2ee_identites_distantes',
          'e2ee_prekeys',
          'e2ee_signed_prekeys',
          'e2ee_identite',
          'e2ee_meta',
        ]) {
          await customStatement('DELETE FROM $table');
        }
      });
}

/// Dossier de l'état Signal, exclu de toute sauvegarde.
///
/// Android : par `res/xml/backup_rules.xml` et `data_extraction_rules.xml`
/// (domaine « file », chemin `e2ee/`). iOS : par le drapeau
/// `isExcludedFromBackup`, posé à chaque ouverture — il ne coûte rien, et un
/// dossier recréé (après un effacement des données) doit le recevoir aussi.
Future<Directory> e2eeDirectory() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, 'e2ee'));
  if (!await dir.exists()) await dir.create(recursive: true);
  if (!kIsWeb && Platform.isIOS) {
    try {
      await const MethodChannel('com.alanya237.alanya/backup_exclusion')
          .invokeMethod<bool>('exclude', {'path': dir.path});
    } catch (e) {
      debugPrint('[E2EE] exclusion de la sauvegarde iCloud impossible : $e');
    }
  }
  return dir;
}

Future<File> e2eeDatabaseFile() async =>
    File(p.join((await e2eeDirectory()).path, 'alanya_e2ee.sqlite'));
