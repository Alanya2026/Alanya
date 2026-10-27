import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/documents_sensibles/descripteur_sensible.dart';
// Compilé ici pour vérifier le branchement de l'envoi (menu des pièces jointes).
// ignore: unused_import
import 'package:talky_flutter/screens/chats/chat_detail_screen.dart';

/// Documents sensibles, lot 1 : le descripteur et la colonne locale.
void main() {
  group('DescripteurSensible', () {
    test('mêmes clés JSON que le descripteur chiffré d\'Alanya Work', () {
      const nu = DescripteurSensible();
      expect(nu.toJson(), {'sensible': true});

      const protege = DescripteurSensible(
        protection: ProtectionPdf(
          imprimer: false,
          ouverture: 'abcd',
          proprietaire: 'wxyz',
        ),
      );
      expect(protege.toJson(), {
        'sensible': true,
        'protection': {
          'imprimer': false,
          'ouverture': 'abcd',
          'proprietaire': 'wxyz',
        },
      });
    });

    test('aller-retour : chaîne (colonne locale) ou objet (serveur)', () {
      const d = DescripteurSensible(
        protection: ProtectionPdf(imprimer: true, proprietaire: 'secret12'),
      );
      for (final brut in [d.encoder(), jsonDecode(d.encoder())]) {
        final lu = DescripteurSensible.depuisJson(brut);
        expect(lu.protection!.imprimer, isTrue);
        expect(lu.protection!.ouverture, isNull);
        expect(lu.protection!.avecMotDePasse, isFalse);
        expect(lu.protection!.proprietaire, 'secret12');
      }
    });

    test('un descripteur mal formé est refusé, jamais complété', () {
      for (final brut in [
        '{}',
        '{"sensible":false}',
        '[]',
        {'sensible': true, 'protection': 'x'},
        {'sensible': true, 'protection': {'imprimer': 'non', 'proprietaire': 'a'}},
        {'sensible': true, 'protection': {'imprimer': true, 'proprietaire': ''}},
        {
          'sensible': true,
          'protection': {'imprimer': true, 'proprietaire': 'a', 'ouverture': ''},
        },
      ]) {
        expect(() => DescripteurSensible.depuisJson(brut),
            throwsFormatException, reason: '$brut');
      }
    });

    test('duMessage : ordinaire, sensible nu, sensible illisible', () {
      expect(
          DescripteurSensible.duMessage(isSensitive: false,
              mediaProtection: '{"sensible":true}'),
          isNull);
      expect(DescripteurSensible.duMessage(isSensitive: true)?.protection,
          isNull);
      // Illisible : le message reste sensible (jamais rétrogradé en
      // ordinaire), mais sans protection de PDF.
      final d = DescripteurSensible.duMessage(
          isSensitive: true, mediaProtection: 'pas du json {');
      expect(d, isNotNull);
      expect(d!.protection, isNull);
    });

    test('mot de passe propriétaire tiré au hasard : 24 caractères sûrs', () {
      final a = ProtectionPdf.proprietaireAuHasard();
      expect(a.length, 24);
      expect(a, matches(RegExp(r'^[A-HJ-NP-Za-km-z2-9]{24}$')));
      expect(ProtectionPdf.proprietaireAuHasard(), isNot(a));
    });
  });

  test('type de message d\'après le nom du fichier', () {
    expect(typeMessagePourFichier('photo.JPG'), 1);
    expect(typeMessagePourFichier('clip.mp4'), 2);
    expect(typeMessagePourFichier('note.m4a'), 3);
    expect(typeMessagePourFichier('contrat.pdf'), 4);
    expect(typeMessagePourFichier('archive.zip'), 4);
    expect(typeMessagePourFichier('sans_extension'), 4);
  });

  test('migration 29 → 30 : les deux colonnes arrivent, le cache reste', () async {
    final tmp = await Directory.systemTemp.createTemp('alanya_sensible_');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File(p.join(tmp.path, 'v29.sqlite'));

    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seed.customSelect('SELECT 1').get();
    await seed.customStatement(
        'ALTER TABLE local_messages DROP COLUMN is_sensitive');
    await seed.customStatement(
        'ALTER TABLE local_messages DROP COLUMN media_protection');
    await seed.customStatement('PRAGMA user_version = 29');
    await seed.close();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final cols = (await db.customSelect('PRAGMA table_info(local_messages)').get())
        .map((r) => r.read<String>('name'));
    expect(cols, containsAll(['is_sensitive', 'media_protection']));
    await db.select(db.localMessages).get();
  });
}
