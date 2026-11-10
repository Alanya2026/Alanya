import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:talky_flutter/core/e2ee/e2ee_coffre.dart';
import 'package:talky_flutter/core/e2ee/e2ee_database.dart';
import 'package:talky_flutter/core/e2ee/e2ee_service.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Faux serveur : l'annuaire de `/api/e2ee`, tel que le backend le tient.
///
/// ⚠ Il éprouve le protocole et la logique de synchronisation, pas le contrat
/// HTTP (docs/e2ee, chapitre 10). Le format des champs est vérifié à part,
/// contre les règles de `src/utils/e2eeBundle.js`.
class FauxAnnuaire implements E2eeApiPort {
  FauxAnnuaire({this.appareilId = 42});

  int appareilId;
  bool inactif = false;
  bool publie = false;
  String? identityKey;
  int? registrationId;
  int? capacite;
  Map<String, dynamic>? signedPreKey;
  final List<Map<String, dynamic>> stock = [];
  final List<String> appels = [];
  Object? echecRetrait;
  Object? echecRotation;

  /// Ralentit chaque appel d'un tour de boucle, pour que deux appels lancés
  /// « ensemble » s'entrelacent vraiment (docs/e2ee, chapitre 11).
  Future<void> _tour() => Future<void>.delayed(Duration.zero);

  @override
  Future<Map<String, dynamic>> etat() async {
    await _tour();
    appels.add('etat');
    if (inactif) {
      throw TalkyException('fermé', 404, code: 'E2EE_INACTIF');
    }
    return {
      'appareilId': appareilId,
      'publie': publie,
      if (publie) ...{
        'identityKey': identityKey,
        'registrationId': registrationId,
        'capacite': capacite,
        'signedPreKeyId': signedPreKey!['keyId'],
      },
      'otpkLibres': stock.length,
      'seuil': 20,
      'regarnissageNecessaire': stock.length < 20,
    };
  }

  @override
  Future<Map<String, dynamic>> publier(Map<String, dynamic> bundle) async {
    await _tour();
    appels.add('publier');
    final nouvelle = !publie || bundle['identityKey'] != identityKey;
    publie = true;
    identityKey = bundle['identityKey'] as String;
    registrationId = bundle['registrationId'] as int;
    capacite = bundle['capacite'] as int;
    signedPreKey = Map<String, dynamic>.from(bundle['signedPreKey'] as Map);
    if (nouvelle) stock.clear();
    stock.addAll((bundle['oneTimePreKeys'] as List).cast<Map<String, dynamic>>());
    return {'otpkLibres': stock.length};
  }

  @override
  Future<Map<String, dynamic>> regarnir(List<Map<String, dynamic>> cles) async {
    await _tour();
    appels.add('regarnir');
    stock.addAll(cles);
    return {'otpkLibres': stock.length};
  }

  @override
  Future<Map<String, dynamic>> tournerSignedPreKey(Map<String, dynamic> spk) async {
    await _tour();
    appels.add('tourner');
    if (echecRotation != null) throw echecRotation!;
    signedPreKey = spk;
    return {'tourne': true};
  }

  @override
  Future<void> retirer() async {
    await _tour();
    appels.add('retirer');
    if (echecRetrait != null) throw echecRetrait!;
    publie = false;
    stock.clear();
  }

  @override
  Future<Map<String, dynamic>> appareils(int conversationID) async =>
      throw UnimplementedError('voir e2ee_messages_test.dart');

  @override
  Future<Map<String, dynamic>> bundles(List<int> appareilIds) async =>
      throw UnimplementedError('voir e2ee_messages_test.dart');

  /// Sert un bundle, en consommant une clé à usage unique.
  PreKeyBundle servir() {
    final otpk = stock.removeAt(0);
    ECPublicKey cle(String b64) => Curve.decodePoint(base64Decode(b64), 0);
    return PreKeyBundle(
      registrationId!,
      appareilId,
      otpk['keyId'] as int,
      cle(otpk['publicKey'] as String),
      signedPreKey!['keyId'] as int,
      cle(signedPreKey!['publicKey'] as String),
      base64Decode(signedPreKey!['signature'] as String),
      IdentityKey.fromBytes(base64Decode(identityKey!), 0),
    );
  }
}

class Appareil {
  Appareil({int appareilId = 42, DateTime? maintenant})
      : annuaire = FauxAnnuaire(appareilId: appareilId),
        db = E2eeDatabase(NativeDatabase.memory()),
        cle = CleDuCoffreMemoire() {
    horloge = maintenant ?? DateTime(2026, 10, 9);
    service = creerService();
  }

  final FauxAnnuaire annuaire;
  final E2eeDatabase db;
  final CleDuCoffreMemoire cle;
  late DateTime horloge;
  late E2eeService service;

  E2eeService creerService() => E2eeService(
        db: db,
        cleDuCoffre: cle,
        api: annuaire,
        horloge: () => horloge,
      );

  Future<String> identite() => service.executer(
        () async => base64Encode((await service.store.getIdentityKeyPair()).getPublicKey().serialize()),
      );
}

void main() {
  // Chaque test ouvre ses propres bases en mémoire, chacune sur son propre
  // exécuteur : l'avertissement de drift ne vise pas ce cas.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('Publication', () {
    test('première synchronisation : identité créée et bundle publié au format du serveur', () async {
      final a = Appareil();
      expect(await a.service.synchroniser(7), SynchroE2ee.publie);

      // Les règles de `src/utils/e2eeBundle.js`, une par une.
      final cle = base64Decode(a.annuaire.identityKey!);
      expect(cle.length, 33, reason: 'clé publique Signal : 0x05 + 32 octets');
      expect(cle.first, 0x05);
      expect(a.annuaire.registrationId, inInclusiveRange(0, 16383));
      expect(a.annuaire.capacite, kE2eeCapacite);
      expect(kE2eeCapacite, 1, reason: 'cette version déchiffre le texte');
      final spk = a.annuaire.signedPreKey!;
      expect(base64Decode(spk['publicKey'] as String).length, 33);
      expect(base64Decode(spk['publicKey'] as String).first, 0x05);
      expect(base64Decode(spk['signature'] as String).length, 64);
      expect(spk['keyId'], inInclusiveRange(0, 0xFFFFFF));

      // Signature vérifiable avec la clé d'identité publiée : c'est ce que le
      // correspondant fera avant d'ouvrir une session.
      expect(
        Curve.verifySignature(
          Curve.decodePoint(cle, 0),
          base64Decode(spk['publicKey'] as String),
          base64Decode(spk['signature'] as String),
        ),
        isTrue,
      );

      expect(a.annuaire.stock, hasLength(kE2eeStockCible));
      expect(a.annuaire.stock.length, lessThanOrEqualTo(100), reason: 'plafond serveur par envoi');
      final ids = [for (final c in a.annuaire.stock) c['keyId'] as int];
      expect(ids.toSet(), hasLength(ids.length), reason: 'aucun identifiant en double');
      for (final c in a.annuaire.stock) {
        final pub = base64Decode(c['publicKey'] as String);
        expect(pub.length, 33);
        expect(pub.first, 0x05);
      }
    });

    test('à jour : rien n\'est republié', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      a.annuaire.appels.clear();
      expect(await a.service.synchroniser(7), SynchroE2ee.aJour);
      expect(a.annuaire.appels, ['etat']);
    });

    test('chiffrement fermé : rien n\'est créé ni publié', () async {
      final a = Appareil();
      a.annuaire.inactif = true;
      expect(await a.service.synchroniser(7), SynchroE2ee.inactif);
      expect(a.annuaire.appels, ['etat']);
      final identites = await a.db.customSelect('SELECT 1 FROM e2ee_identite').get();
      expect(identites, isEmpty);
    });

    test('serveur qui a oublié l\'appareil : republie la MÊME identité', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final avant = a.annuaire.identityKey;
      a.annuaire.publie = false;
      a.annuaire.stock.clear();
      expect(await a.service.synchroniser(7), SynchroE2ee.publie);
      expect(a.annuaire.identityKey, avant, reason: 'aucune alerte « clé changée » chez les correspondants');
    });

    test('regarnissage : identifiants consécutifs, jamais réutilisés', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final premiers = {for (final c in a.annuaire.stock) c['keyId'] as int};
      a.annuaire.stock.removeRange(0, 85); // 85 consommées, 15 restent
      expect(await a.service.synchroniser(7), SynchroE2ee.regarni);
      expect(a.annuaire.stock, hasLength(kE2eeStockCible));
      final nouveaux = [for (final c in a.annuaire.stock.skip(15)) c['keyId'] as int];
      expect(nouveaux, hasLength(85));
      expect(nouveaux.toSet().intersection(premiers), isEmpty,
          reason: 'un identifiant déjà publié ne doit jamais revenir');
    });

    test('deux synchronisations lancées ensemble : une seule publication', () async {
      final a = Appareil();
      final r = await Future.wait([a.service.synchroniser(7), a.service.synchroniser(7)]);
      expect(r, [SynchroE2ee.publie, SynchroE2ee.publie]);
      expect(a.annuaire.appels.where((x) => x == 'publier'), hasLength(1));
    });

    test('un échec réseau ne lève pas', () async {
      final a = Appareil();
      final api = _AnnuaireEnPanne();
      final s = E2eeService(db: a.db, cleDuCoffre: a.cle, api: api);
      expect(await s.synchroniser(7), SynchroE2ee.echec);
    });
  });

  group('Propriétaire du coffre', () {
    test('autre compte, ou autre ligne d\'appareil : identité neuve', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final premiere = await a.identite();

      // Même compte, même appareil : identité conservée.
      await a.service.synchroniser(7);
      expect(await a.identite(), premiere);

      // Autre compte sur ce téléphone.
      await a.service.synchroniser(8);
      final deuxieme = await a.identite();
      expect(deuxieme, isNot(premiere), reason: 'un compte ne publie jamais l\'identité d\'un autre');

      // Ligne d'appareil recréée (révocation puis reconnexion).
      a.annuaire.appareilId = 43;
      await a.service.synchroniser(8);
      expect(await a.identite(), isNot(deuxieme));
    });

    test('clé du coffre perdue : état remis à zéro, identité neuve', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final avant = await a.identite();
      // Keystore invalidé, ou restauration sur un autre téléphone.
      a.cle.valeur = null;
      a.service = a.creerService();
      await a.service.synchroniser(7);
      expect(await a.identite(), isNot(avant));
    });

    test('oublier : retrait du serveur puis effacement local', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      await a.service.oublier(retirerDuServeur: true);
      expect(a.annuaire.appels.last, 'retirer');
      expect(a.annuaire.publie, isFalse);
      expect(await a.db.customSelect('SELECT 1 FROM e2ee_identite').get(), isEmpty);
      expect(a.cle.valeur, isNull, reason: 'la clé du coffre part aussi');
    });

    test('oublier sans réseau : l\'effacement local a lieu quand même', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      a.annuaire.echecRetrait = TalkyException('hors ligne', 0);
      await a.service.oublier(retirerDuServeur: true);
      expect(await a.db.customSelect('SELECT 1 FROM e2ee_identite').get(), isEmpty);
    });
  });

  group('Pré-clé signée', () {
    test('tourne après 30 jours, l\'ancienne reste 60 jours après son retrait', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final premiere = a.annuaire.signedPreKey!['keyId'] as int;

      a.horloge = a.horloge.add(const Duration(days: 29));
      await a.service.synchroniser(7);
      expect(a.annuaire.appels, isNot(contains('tourner')));

      a.horloge = a.horloge.add(const Duration(days: 2)); // J+31
      await a.service.synchroniser(7);
      expect(a.annuaire.appels, contains('tourner'));
      final deuxieme = a.annuaire.signedPreKey!['keyId'] as int;
      expect(deuxieme, isNot(premiere));

      Future<bool> garde(int id) => a.service.executer(() => a.service.store.containsSignedPreKey(id));

      // J+81 : retirée depuis 50 jours seulement — créée il y a 81 jours.
      a.horloge = a.horloge.add(const Duration(days: 50));
      await a.service.synchroniser(7);
      expect(await garde(premiere), isTrue,
          reason: 'la conservation court depuis le retrait, pas depuis la création');

      // J+92 : retirée depuis 61 jours. Entre-temps une troisième a pris la
      // place de la deuxième (J+61 dépassé).
      a.horloge = a.horloge.add(const Duration(days: 11));
      await a.service.synchroniser(7);
      expect(await garde(premiere), isFalse);
      expect(await garde(deuxieme), isTrue);
    });

    test('rotation dont l\'envoi a échoué : renvoyée, et l\'ancienne gardée tant qu\'elle est servie', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final premiere = a.annuaire.signedPreKey!['keyId'] as int;

      a.horloge = a.horloge.add(const Duration(days: 31));
      a.annuaire.echecRotation = TalkyException('hors ligne', 0);
      expect(await a.service.synchroniser(7), SynchroE2ee.echec);
      expect(a.annuaire.signedPreKey!['keyId'], premiere, reason: 'le serveur sert toujours la première');

      // 70 jours plus tard, le réseau revient. La première est retirée
      // localement depuis plus de 60 jours, mais le serveur la sert encore :
      // elle doit survivre jusqu'à ce que la rotation passe.
      a.annuaire.echecRotation = null;
      a.horloge = a.horloge.add(const Duration(days: 70));
      a.annuaire.appels.clear();
      await a.service.synchroniser(7);
      expect(a.annuaire.appels, contains('tourner'), reason: 'la rotation ratée repart');
      expect(a.annuaire.signedPreKey!['keyId'], isNot(premiere));
    });

    test('pas de rotation posée sur l\'identité d\'une autre installation', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      // Le serveur détient une autre identité pour cet appareil, et notre
      // pré-clé signée a vieilli : la rotation ne doit PAS partir seule, le
      // bundle complet la porte.
      a.annuaire.identityKey = base64Encode(Uint8List(33)..[0] = 0x05);
      a.horloge = a.horloge.add(const Duration(days: 31));
      a.annuaire.appels.clear();
      expect(await a.service.synchroniser(7), SynchroE2ee.publie);
      expect(a.annuaire.appels, isNot(contains('tourner')));
    });
  });

  group('Protocole', () {
    test('Alice ouvre une session sur le bundle publié par Bob, Bob déchiffre', () async {
      final alice = Appareil(appareilId: 1);
      final bob = Appareil(appareilId: 2);
      await alice.service.synchroniser(10);
      await bob.service.synchroniser(20);

      const adresseBob = SignalProtocolAddress('20', 2);
      const adresseAlice = SignalProtocolAddress('10', 1);
      final bundle = bob.annuaire.servir();

      final chiffre = await alice.service.executer(() async {
        await SessionBuilder.fromSignalStore(alice.service.store, adresseBob).processPreKeyBundle(bundle);
        return SessionCipher.fromStore(alice.service.store, adresseBob)
            .encrypt(Uint8List.fromList(utf8.encode('bonjour Bob')));
      });
      expect(chiffre.getType(), CiphertextMessage.prekeyType);

      final clair = await bob.service.executer(() => SessionCipher.fromStore(bob.service.store, adresseAlice)
          .decrypt(PreKeySignalMessage(chiffre.serialize())));
      expect(utf8.decode(clair), 'bonjour Bob');

      // La réponse passe par le cliquet, et la session survit à une
      // réouverture du store : elle a bien été écrite, scellée, en base.
      bob.service = bob.creerService();
      final reponse = await bob.service.executer(
        () => SessionCipher.fromStore(bob.service.store, adresseAlice)
            .encrypt(Uint8List.fromList(utf8.encode('bonjour Alice'))),
      );
      expect(reponse.getType(), CiphertextMessage.whisperType);
      final lu = await alice.service.executer(() => SessionCipher.fromStore(alice.service.store, adresseBob)
          .decryptFromSignal(SignalMessage.fromSerialized(reponse.serialize())));
      expect(utf8.decode(lu), 'bonjour Alice');

      // La pré-clé à usage unique a été consommée chez Bob.
      final reste = await bob.service.executer(
        () => bob.service.store.containsPreKey(bundle.getPreKeyId()!),
      );
      expect(reste, isFalse);
    });
  });

  group('Date de passage en chiffré', () {
    test('la date du serveur fait foi ; sinon la première notée est gardée', () async {
      final a = Appareil();
      final premierMessage = DateTime.utc(2026, 11, 10, 12, 0, 9);
      final serveur = DateTime.utc(2026, 11, 10, 12, 0, 5);
      final notifications = <Map<int, DateTime>>[];
      a.service.conversationsChiffrees.addListener(
        () => notifications.add(a.service.conversationsChiffrees.value),
      );

      // Premier message chiffré reçu : sa date, postérieure ou égale à la vraie.
      await a.service.noterConversationChiffree(5, premierMessage);
      expect(a.service.estChiffreeEnMemoire(5), isTrue);
      expect(a.service.conversationsChiffrees.value[5], premierMessage);

      // Un refus plus tardif ne la déplace pas.
      await a.service.noterConversationChiffree(5, premierMessage.add(const Duration(minutes: 3)));
      expect(a.service.conversationsChiffrees.value[5], premierMessage);

      // `e2ee_since` du serveur : la remplace, en mémoire et en base.
      await a.service.noterConversationChiffree(5, serveur, dateDuServeur: true);
      expect(a.service.conversationsChiffrees.value[5], serveur);
      // Redite du serveur (réponse en cache, événement rejoué) : rien ne bouge.
      await a.service.noterConversationChiffree(5, serveur.toLocal(), dateDuServeur: true);
      expect(notifications, hasLength(2), reason: 'premier message, puis date du serveur');

      // Un service neuf sur la même base relit la date du serveur.
      final relu = a.creerService();
      await relu.prechargerEtat();
      expect(relu.conversationsChiffrees.value[5]?.millisecondsSinceEpoch, serveur.millisecondsSinceEpoch);
      expect(await relu.estChiffree(5), isTrue);
      expect(relu.estChiffreeEnMemoire(6), isFalse);
    });

    test('oublier efface aussi les conversations chiffrées en mémoire', () async {
      final a = Appareil();
      await a.service.noterConversationChiffree(5, DateTime.utc(2026, 11, 10));
      await a.service.oublier();
      expect(a.service.conversationsChiffrees.value, isEmpty);
      expect(await a.service.estChiffree(5), isFalse);
    });
  });

  group('Coffre', () {
    test('la clé privée n\'apparaît nulle part en clair dans la base', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final privee = await a.service.executer(
        () async => (await a.service.store.getIdentityKeyPair()).getPrivateKey().serialize(),
      );
      final lignes = await a.db.customSelect('SELECT key_pair AS b FROM e2ee_identite '
          'UNION ALL SELECT record FROM e2ee_prekeys '
          'UNION ALL SELECT record FROM e2ee_signed_prekeys').get();
      expect(lignes, isNotEmpty);
      for (final l in lignes) {
        expect(_contient(l.read<Uint8List>('b'), privee), isFalse);
      }
      // Témoin : la recherche sait trouver la clé là où elle est.
      expect(_contient(Uint8List.fromList([1, 2, ...privee, 3]), privee), isTrue);
    });

    test('un enregistrement déplacé sur une autre ligne ne s\'ouvre pas', () async {
      final a = Appareil();
      await a.service.synchroniser(7);
      final rows = await a.db.customSelect('SELECT id FROM e2ee_prekeys ORDER BY id LIMIT 2').get();
      final premier = rows[0].read<int>('id');
      final second = rows[1].read<int>('id');
      // La pré-clé du premier recopiée sur la ligne du second.
      await a.db.customStatement(
        'UPDATE e2ee_prekeys SET record = (SELECT record FROM e2ee_prekeys WHERE id = ?) WHERE id = ?',
        [premier, second],
      );
      await expectLater(
        a.service.executer(() => a.service.store.loadPreKey(second)),
        throwsA(isA<CoffreIllisible>()),
      );
      // Témoin : le premier, à sa place, s'ouvre.
      final ok = await a.service.executer(() => a.service.store.loadPreKey(premier));
      expect(ok.id, premier);
    });
  });

  test('le verrou fait passer les opérations une par une, même en échec', () async {
    final verrou = VerrouSequentiel();
    final ordre = <String>[];
    final f1 = verrou.executer(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      ordre.add('a');
      throw StateError('échec');
    });
    final f2 = verrou.executer(() async {
      ordre.add('b');
      return 2;
    });
    await expectLater(f1, throwsStateError);
    expect(await f2, 2);
    expect(ordre, ['a', 'b']);
  });
}

class _AnnuaireEnPanne extends FauxAnnuaire {
  @override
  Future<Map<String, dynamic>> etat() async => throw TalkyException('panne', 0);
}

bool _contient(Uint8List meule, Uint8List aiguille) {
  for (var i = 0; i + aiguille.length <= meule.length; i++) {
    var ok = true;
    for (var j = 0; j < aiguille.length; j++) {
      if (meule[i + j] != aiguille[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}
