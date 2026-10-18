import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/e2ee/e2ee_charge.dart';
import 'package:talky_flutter/core/e2ee/e2ee_service.dart';

import 'fakes/faux_serveur_e2ee.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late FauxServeur serveur;
  late Telephone alice1, alice2, bob;

  setUp(() async {
    serveur = FauxServeur();
    alice1 = Telephone(serveur, 1, 11);
    alice2 = Telephone(serveur, 1, 12);
    bob = Telephone(serveur, 2, 21);
    for (final t in [alice1, alice2, bob]) {
      expect(await t.service.synchroniser(t.alanyaID), SynchroE2ee.publie);
    }
  });

  ChargeE2ee charge(String id, String texte, {int conv = 7}) =>
      ChargeE2ee(id: id, conv: conv, texte: texte);

  test('conversation en clair : rien n\'est chiffré', () async {
    serveur.e2eeSince = null;
    final envoi = await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'bonjour'));
    expect(envoi, isNull, reason: 'le message part en clair, comme avant');
    expect(serveur.bundlesServis, 0, reason: 'aucune clé consommée pour rien');
  });

  test('conversation chiffrée : Bob ET mon second téléphone lisent, le serveur non', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    final envoi = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'bonjour Bob')))!;

    final destinataires = envoi.envelopes.map((e) => e['appareilId']).toSet();
    expect(destinataires, {12, 21}, reason: 'Bob, et mon autre appareil — jamais celui qui écrit');
    expect(utf8.decode(base64Decode(envoi.body['ct']!), allowMalformed: true), isNot(contains('bonjour')));

    for (final t in [bob, alice2]) {
      final recu = serveur.livrer(envoi: envoi, emetteur: 1, appareilEmetteur: 11, appareil: t.appareilId, clientId: 'c1')!;
      final lu = await t.service.dechiffrer(recu);
      expect(lu.texte, 'bonjour Bob');
    }
  });

  test('une session par appareil : pas de nouvelle clé consommée au message suivant', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    final e1 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'un')))!;
    expect(serveur.bundlesServis, 2);
    expect(e1.envelopes.every((e) => e['envType'] == kSignalAmorcage), isTrue);

    final e2 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c2', 'deux')))!;
    expect(serveur.bundlesServis, 2, reason: 'la session existe : rien n\'est redemandé (chapitre 13)');

    // Tant que Bob n'a pas répondu, Alice reste en amorçage — même session,
    // même pré-clé, rien de consommé (chapitre 13, § 6).
    expect(e2.envelopes.firstWhere((e) => e['appareilId'] == 21)['envType'], kSignalAmorcage);

    for (final (envoi, id, texte) in [(e1, 'c1', 'un'), (e2, 'c2', 'deux')]) {
      final recu = serveur.livrer(envoi: envoi, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: id)!;
      expect((await bob.service.dechiffrer(recu)).texte, texte);
    }

    // Bob répond ; Alice passe au cliquet.
    final rep = (await bob.service.chiffrer(conversationID: 7, moi: 2, charge: charge('b1', 'salut')))!;
    final recuParAlice = serveur.livrer(envoi: rep, emetteur: 2, appareilEmetteur: 21, appareil: 11, clientId: 'b1')!;
    expect((await alice1.service.dechiffrer(recuParAlice)).texte, 'salut');
    final e3 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c3', 'trois')))!;
    expect(e3.envelopes.firstWhere((e) => e['appareilId'] == 21)['envType'], kSignalCliquet);
  });

  test('le serveur ne peut pas déplacer un texte sur un autre message ni dans un autre fil', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    final envoi = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'oui')))!;
    final recu = serveur.livrer(envoi: envoi, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c1')!;

    await expectLater(
      bob.service.dechiffrer({...recu, 'clientId': 'c-autre'}),
      throwsA(isA<E2eeIndechiffrable>()),
    );
    // Autre fil : refusé aussi.
    final e2 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c2', 'non')))!;
    final recu2 = serveur.livrer(envoi: e2, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c2')!;
    await expectLater(
      bob.service.dechiffrer({...recu2, 'conversationID': 8}),
      throwsA(isA<E2eeIndechiffrable>()),
    );
    // Témoin : un message rattaché à SA ligne s'ouvre. (Le message déplacé,
    // lui, est perdu : sa clé a servi avant que la charge soit refusée. Un
    // serveur peut toujours supprimer un message ; il ne peut pas le faire
    // dire autre chose.)
    final e3 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c3', 'peut-être')))!;
    final recu3 = serveur.livrer(envoi: e3, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c3')!;
    expect((await bob.service.dechiffrer(recu3)).texte, 'peut-être');
  });

  test('session établie : un serveur qui ment sur l\'émetteur fait échouer le déchiffrement', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    // Session établie dans les deux sens.
    final e1 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'un')))!;
    await bob.service.dechiffrer(serveur.livrer(envoi: e1, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c1')!);
    final rep = (await bob.service.chiffrer(conversationID: 7, moi: 2, charge: charge('b1', 'deux')))!;
    await alice1.service.dechiffrer(serveur.livrer(envoi: rep, emetteur: 2, appareilEmetteur: 21, appareil: 11, clientId: 'b1')!);

    final e2 = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c2', 'secret')))!;
    final recu = serveur.livrer(envoi: e2, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c2')!;
    expect((recu['envelope'] as Map)['envType'], kSignalCliquet);
    // Prétendu venir du second téléphone d'Alice, ou d'un autre compte.
    for (final (emetteur, appareil) in [(1, 12), (3, 31)]) {
      await expectLater(
        bob.service.dechiffrer({
          ...recu,
          'senderID': emetteur,
          'body': {...recu['body'] as Map, 'senderAppareilId': appareil},
        }),
        throwsA(isA<E2eeIndechiffrable>()),
      );
    }
    // Témoin : avec le vrai émetteur, il s'ouvre.
    expect((await bob.service.dechiffrer(recu)).texte, 'secret');
  });

  // Limite connue, à ne pas oublier : le PREMIER message d'une session
  // (amorçage) porte de quoi ouvrir la session lui-même, avec l'identité de
  // son vrai émetteur. Un serveur qui l'attribue à un autre appareil fait
  // ouvrir une session sous cette fausse adresse. C'est la confiance au
  // premier contact de Signal ; la parade est la vérification du code de
  // sécurité et l'alerte « nouvel appareil » (étape 3, docs/e2ee chapitre 16).

  test('une enveloppe reçue deux fois : « déjà lu », rien de perdu', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    final envoi = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'une fois')))!;
    final recu = serveur.livrer(envoi: envoi, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c1')!;
    expect((await bob.service.dechiffrer(recu)).texte, 'une fois');
    await expectLater(
      bob.service.dechiffrer(recu),
      throwsA(isA<E2eeIndechiffrable>().having((e) => e.dejaLu, 'dejaLu', isTrue)),
    );
  });

  test('un « non » du serveur après un « oui » est ignoré : on chiffre quand même', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'un'));
    serveur.e2eeSince = null; // le serveur prétend que le fil n'est plus chiffré
    final envoi = await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c2', 'deux'));
    expect(envoi, isNotNull, reason: 'un fil chiffré le reste (chapitre 21)');
  });

  test('Bob réinstalle : nouvelle identité, la session est rouverte', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c1', 'avant'));
    final servisAvant = serveur.bundlesServis;

    bob = Telephone(serveur, 2, 21); // même appareil, base vide
    await bob.service.synchroniser(2);
    // La liste des appareils est gardée 60 s (`kE2eeCacheAppareils`) : un
    // message écrit dans cette minute part encore pour l'ancienne identité, et
    // Bob ne le lira pas — c'est le renvoi automatique de l'étape 3 qui le
    // rattrapera. Passé ce délai, la nouvelle identité est vue :
    alice1.service.oublierAppareils(7);

    final envoi = (await alice1.service.chiffrer(conversationID: 7, moi: 1, charge: charge('c2', 'après')))!;
    expect(serveur.bundlesServis, servisAvant + 1, reason: 'identité changée : nouvelle session');
    final recu = serveur.livrer(envoi: envoi, emetteur: 1, appareilEmetteur: 11, appareil: 21, clientId: 'c2')!;
    expect((await bob.service.dechiffrer(recu)).texte, 'après');
  });

  group('Charge', () {
    test('aller-retour, champs absents quand vides', () {
      const c = ChargeE2ee(id: 'c1', conv: 7, texte: 'salut');
      expect(c.encoder(), '\u0000A2{"v":2,"id":"c1","conv":7,"texte":"salut"}');
      final lu = ChargeE2ee.lire(c.encoder(), clientIdAttendu: 'c1', convAttendue: 7);
      expect(lu.texte, 'salut');
      expect(lu.genre, isNull);
    });

    test('un texte qui ressemble à une charge reste un texte', () {
      expect(
        () => ChargeE2ee.lire('{"v":2,"id":"c1","conv":7}', clientIdAttendu: 'c1', convAttendue: 7),
        throwsA(isA<ChargeRefusee>()),
      );
    });

    test('champ inconnu ignoré, valeur inattendue écartée, id et conv stricts', () {
      const brut = '\u0000A2{"v":2,"id":"c1","conv":7,"texte":"x","genre":"SONDAGE","futur":true}';
      final lu = ChargeE2ee.lire(brut, clientIdAttendu: 'c1', convAttendue: 7);
      expect(lu.texte, 'x');
      expect(lu.genre, isNull, reason: 'genre inattendu écarté, pas de refus');
      expect(() => ChargeE2ee.lire(brut, clientIdAttendu: 'c2', convAttendue: 7), throwsA(isA<ChargeRefusee>()));
      expect(() => ChargeE2ee.lire(brut, clientIdAttendu: 'c1', convAttendue: 8), throwsA(isA<ChargeRefusee>()));
    });
  });
}
