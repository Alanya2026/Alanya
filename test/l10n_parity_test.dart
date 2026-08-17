import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre la dérive des fichiers de traduction.
///
/// Chaque nouvelle chaîne d'interface se paie désormais en autant
/// d'exemplaires qu'il y a de langues. Sans ce test, une clé ajoutée au
/// template et oubliée ailleurs ne se voit qu'à l'exécution — et seulement par
/// un utilisateur de la langue concernée, qui verra du français au milieu de
/// son interface.
///
/// Le test **découvre** les fichiers présents au lieu d'en coder la liste :
/// déposer `app_zh.arb` le met aussitôt sous surveillance, et la suite n'est
/// jamais artificiellement rouge tant qu'une langue n'a pas commencé.
void main() {
  const l10nDir = 'lib/l10n';

  /// `app_fr.arb` est le template déclaré dans `l10n.yaml` : c'est lui qui fait
  /// foi, les autres langues s'y conforment.
  const templateFile = 'app_fr.arb';

  /// Mots-clés de la syntaxe ICU, à ne pas confondre avec des placeholders.
  ///
  /// Dans `{count, plural, other{…}}`, `count` est un argument mais `plural` et
  /// `other` sont de la grammaire.
  const icuKeywords = {
    'plural',
    'select',
    'selectordinal',
    'zero',
    'one',
    'two',
    'few',
    'many',
    'other',
  };

  Map<String, dynamic> readArb(String name) {
    final file = File('$l10nDir/$name');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Clés réellement traduisibles : ni métadonnées (`@clé`), ni directives
  /// globales (`@@locale`).
  Set<String> translatableKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// Noms des placeholders d'une chaîne ICU.
  ///
  /// Capture `{email}` comme `{count, plural, …}`, puis retire les mots-clés
  /// ICU — sans quoi le `other{…}` d'un pluriel passerait pour un argument.
  Set<String> placeholdersOf(String value) {
    final matches = RegExp(r'\{\s*(\w+)\s*[,}]').allMatches(value);
    return matches
        .map((m) => m.group(1)!)
        .where((name) => !icuKeywords.contains(name))
        .toSet();
  }

  final template = readArb(templateFile);
  final templateKeys = translatableKeys(template);

  final localeFiles = Directory(l10nDir)
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.startsWith('app_') && n.endsWith('.arb'))
      .where((n) => n != templateFile)
      .toList()
    ..sort();

  test('le template est bien celui déclaré dans l10n.yaml', () {
    final yaml = File('l10n.yaml').readAsStringSync();
    expect(
      yaml.contains('template-arb-file: $templateFile'),
      isTrue,
      reason:
          'Ce test suppose que $templateFile fait foi. Si le template a changé '
          'dans l10n.yaml, corriger `templateFile` ici.',
    );
  });

  test('au moins une langue en plus du template', () {
    expect(localeFiles, isNotEmpty,
        reason: 'Aucun app_*.arb à comparer — le garde-fou ne surveille rien.');
  });

  for (final name in localeFiles) {
    group(name, () {
      final arb = readArb(name);
      final keys = translatableKeys(arb);

      test('aucune clé manquante', () {
        final missing = templateKeys.difference(keys).toList()..sort();
        expect(
          missing,
          isEmpty,
          reason: '${missing.length} clé(s) absente(s) de $name '
              '(sur ${templateKeys.length} attendues).\n'
              'Premières manquantes : ${missing.take(20).join(', ')}',
        );
      });

      test('aucune clé orpheline', () {
        // Une clé présente ici mais absente du template ne sera jamais lue :
        // soit elle a été renommée dans le template, soit elle est morte.
        final extra = keys.difference(templateKeys).toList()..sort();
        expect(
          extra,
          isEmpty,
          reason: '${extra.length} clé(s) de $name absente(s) du template.\n'
              'Premières : ${extra.take(20).join(', ')}',
        );
      });

      test('placeholders identiques au template', () {
        final mismatches = <String>[];
        for (final key in templateKeys) {
          final source = template[key];
          final translated = arb[key];
          if (source is! String || translated is! String) continue;

          final expected = placeholdersOf(source);
          final actual = placeholdersOf(translated);
          if (!_setEquals(expected, actual)) {
            mismatches.add(
              '$key — attendu {${(expected.toList()..sort()).join(', ')}}, '
              'trouvé {${(actual.toList()..sort()).join(', ')}}',
            );
          }
        }

        // Un placeholder traduit ou renommé ne casse pas la compilation : il
        // casse `gen-l10n`, ou pire, s'affiche tel quel à l'utilisateur.
        expect(
          mismatches,
          isEmpty,
          reason: '${mismatches.length} divergence(s) de placeholders dans '
              '$name :\n${mismatches.take(20).join('\n')}',
        );
      });
    });
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.every(b.contains);
