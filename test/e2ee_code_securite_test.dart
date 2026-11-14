import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/e2ee/e2ee_service.dart';

import 'fakes/faux_serveur_e2ee.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late FauxServeur serveur;
  late Telephone alice1, alice2, bob;

  setUp(() async {
    serveur = FauxServeur()..e2eeSince = DateTime(2026, 11, 14);
    alice1 = Telephone(serveur, 1, 11);
    alice2 = Telephone(serveur, 1, 12);
    bob = Telephone(serveur, 2, 21);
    for (final t in [alice1, alice2, bob]) {
      expect(await t.service.synchroniser(t.alanyaID), SynchroE2ee.publie);
    }
  });

  // Les dates d'alerte se comparent à la milliseconde : on laisse l'horloge
  // avancer entre deux lots.
  Future<void> plusTard() => Future<void>.delayed(const Duration(milliseconds: 5));

  test('le même code des deux côtés, sur tous les appareils des deux comptes', () async {
    final vuParAlice = (await alice1.service.codeSecurite(conversationID: 7, moi: 1))!;
    final vuParBob = (await bob.service.codeSecurite(conversationID: 7, moi: 2))!;

    expect(vuParAlice.chiffres, hasLength(60));
    expect(vuParAlice.groupes, hasLength(12));
    expect(vuParBob.chiffres, vuParAlice.chiffres);
    expect(vuParAlice.appareilsManquants, 0);
    expect(vuParAlice.verifie, isFalse);

    // Le second téléphone d'Alice voit le même code : il couvre les mêmes clés.
    final vuParAlice2 = (await alice2.service.codeSecurite(conversationID: 7, moi: 1))!;
    expect(vuParAlice2.chiffres, vuParAlice.chiffres);
  });

  test('première rencontre : aucun avertissement, même avec plusieurs appareils', () async {
    await bob.service.codeSecurite(conversationID: 7, moi: 2);
    expect(bob.service.comptesAvecAlerte.value, isEmpty,
        reason: 'les deux téléphones d\'Alice sont découverts ensemble');
  });

  test('clé changée : avertissement, et la marque « vérifié » tombe', () async {
    final avant = (await alice1.service.codeSecurite(conversationID: 7, moi: 1))!;
    await alice1.service.marquerVerifie(7, avant.empreinte);
    expect((await alice1.service.codeSecurite(conversationID: 7, moi: 1))!.verifie, isTrue);

    // Bob réinstalle : même appareil, identité neuve.
    await plusTard();
    bob = Telephone(serveur, 2, 21);
    await bob.service.synchroniser(2);

    final apres = (await alice1.service.codeSecurite(conversationID: 7, moi: 1))!;
    expect(apres.chiffres, isNot(avant.chiffres));
    expect(apres.verifie, isFalse);
    expect(alice1.service.comptesAvecAlerte.value, {'2'});

    await alice1.service.marquerAlertesVues(2);
    expect(alice1.service.comptesAvecAlerte.value, isEmpty);
  });

  test('appareil apparu chez un correspondant connu : avertissement', () async {
    final avant = (await alice1.service.codeSecurite(conversationID: 7, moi: 1))!;
    await plusTard();
    final bob2 = Telephone(serveur, 2, 22);
    await bob2.service.synchroniser(2);

    final apres = (await alice1.service.codeSecurite(conversationID: 7, moi: 1))!;
    expect(apres.chiffres, isNot(avant.chiffres));
    expect(alice1.service.comptesAvecAlerte.value, {'2'});
  });

  test('l\'avertissement survit au redémarrage tant qu\'il n\'est pas vu', () async {
    await alice1.service.codeSecurite(conversationID: 7, moi: 1);
    await plusTard();
    await Telephone(serveur, 2, 22).service.synchroniser(2);
    await alice1.service.codeSecurite(conversationID: 7, moi: 1);

    alice1.service.comptesAvecAlerte.value = const {};
    await alice1.service.prechargerEtat();
    expect(alice1.service.comptesAvecAlerte.value, {'2'});
  });

  test('conversation non chiffrable à deux : pas de code', () async {
    serveur.inscrits.remove(21);
    expect(await alice1.service.codeSecurite(conversationID: 7, moi: 1), isNull);
  });
}
