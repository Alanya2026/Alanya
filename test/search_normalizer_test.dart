// Protège la normalisation de la recherche de messages : accents et majuscules
// ignorés, et surtout la table `origine`, dont le surlignage dépend pour
// redécouper le texte affiché quand `œ → oe` allonge la chaîne.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/search_normalizer.dart';

void main() {
  test('minuscules et accents retirés', () {
    expect(normaliserPourRecherche('Réunion').texte, 'reunion');
    expect(normaliserPourRecherche('ÀÉÎÕÜŸ çÇ ñ').texte, 'aeiouy cc n');
  });

  test('œ et æ produisent deux caractères pointant la même origine', () {
    final n = normaliserPourRecherche('Œuvre');
    expect(n.texte, 'oeuvre');
    expect(n.origine, [0, 0, 1, 2, 3, 4]);
    final a = normaliserPourRecherche('æ');
    expect(a.texte, 'ae');
    expect(a.origine, [0, 0]);
  });

  test('apostrophe typographique et accent aigu isolé deviennent \'', () {
    expect(normaliserPourRecherche('l’heure').texte, "l'heure");
    expect(normaliserPourRecherche('l´heure').texte, "l'heure");
  });

  test('espaces insécables deviennent des espaces', () {
    expect(normaliserPourRecherche('a b c').texte, 'a b c');
  });

  test('chaîne vide', () {
    final n = normaliserPourRecherche('');
    expect(n.texte, '');
    expect(n.origine, isEmpty);
  });

  test('origine garde la taille du texte normalisé', () {
    final n = normaliserPourRecherche('Cœur à 😀 ok');
    expect(n.origine.length, n.texte.length);
  });
}
