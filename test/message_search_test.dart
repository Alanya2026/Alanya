// Protège le filtre de la recherche de messages : accents et majuscules
// ignorés, tri du plus récent au plus ancien, et aucune recherche sous
// 2 caractères (sinon presque tout le fil « correspond »).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/chat/message_search.dart';

CandidatRecherche c(int id, String txt, int minute) => CandidatRecherche(
      msgID: id,
      content: txt,
      sendAt: DateTime.utc(2026, 1, 1, 10, minute),
    );

void main() {
  final fil = [
    c(1, 'Réunion demain à 9h', 1),
    c(2, 'ok', 2),
    c(3, 'La REUNION est annulée', 3),
    c(4, "l’œuvre de l'équipe", 4),
  ];

  test('accents et majuscules ignorés, du plus récent au plus ancien', () {
    expect(filtrerMessages(fil, 'reunion'), [3, 1]);
  });

  test('plusieurs résultats triés par date décroissante', () {
    final desordre = [c(5, 'abc', 1), c(6, 'abc', 9), c(7, 'abc', 5)];
    expect(filtrerMessages(desordre, 'abc'), [6, 7, 5]);
  });

  test('ligature et apostrophe typographique', () {
    expect(filtrerMessages(fil, 'oeuvre'), [4]);
    expect(filtrerMessages(fil, "l'oeuvre"), [4]);
  });

  test('requête trop courte : aucun résultat', () {
    expect(filtrerMessages(fil, 'o'), isEmpty);
    expect(filtrerMessages(fil, ''), isEmpty);
  });

  test('requête faite d\'espaces : aucun résultat', () {
    expect(filtrerMessages(fil, '    '), isEmpty);
    expect(filtrerMessages(fil, '   '), isEmpty);
  });

  test('requête sans correspondance', () {
    expect(filtrerMessages(fil, 'zzz'), isEmpty);
  });

  test('rechercherMessages donne le même résultat que filtrerMessages',
      () async {
    expect(await rechercherMessages(fil, 'reunion'), [3, 1]);
  });

  test('au-delà du seuil, le passage par un isolate donne le même résultat',
      () async {
    final gros = List.generate(6000, (i) => c(i + 1, 'message $i', i % 60));
    expect(await rechercherMessages(gros, 'message 42'),
        filtrerMessages(gros, 'message 42'));
  });

  test('mesure de volume : 20 000 candidats', () {
    final gros = List.generate(
        20000, (i) => c(i + 1, 'Une réunion numéro $i à Œuvre', i % 60));
    final sw = Stopwatch()..start();
    final r = filtrerMessages(gros, 'reunion numero 1');
    sw.stop();
    // ignore: avoid_print
    print('VOLUME 20000 candidats : ${sw.elapsedMilliseconds} ms, ${r.length} résultats');
    expect(r, isNotEmpty);
  });
}
