import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/e2ee/e2ee_affichage.dart';
import 'package:talky_flutter/core/e2ee/e2ee_charge.dart';
import 'package:talky_flutter/core/e2ee/e2ee_service.dart';

import 'fakes/chat_test_harness.dart';
import 'fakes/faux_serveur_e2ee.dart';

/// Le chiffrement branché au vrai fil : dépôt, base locale, socket simulée.
///
/// Ce que ces tests gardent, d'abord : un texte déchiffré n'existe que sur
/// l'appareil, et rien ne doit l'effacer (docs/e2ee, chapitre 17) ; rien ne
/// part en clair dans un fil chiffré (chapitres 3 et 26).
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const conv = ChatTestHarness.convId;
  late ChatTestHarness h;
  late FauxServeur serveur;
  late Telephone moi, bob;

  Future<void> attendre(bool Function() condition, {String raison = ''}) async {
    for (var i = 0; i < 400; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('délai dépassé : $raison');
  }

  Future<String?> contenuDe(int msgID) async {
    final m = (await h.messages()).where((m) => m.msgID == msgID).toList();
    return m.isEmpty ? null : m.first.content;
  }

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp(autoAckSend: false);
    serveur = FauxServeur();
    moi = Telephone(serveur, ChatTestHarness.myId, 11);
    bob = Telephone(serveur, ChatTestHarness.otherId, 21);
    await moi.service.synchroniser(ChatTestHarness.myId);
    await bob.service.synchroniser(ChatTestHarness.otherId);
    E2eeService.instancePourTest = moi.service;
  });

  tearDown(() async {
    E2eeService.instancePourTest = null;
    await h.tearDown();
  });

  Map<String, dynamic> recuDeBob(EnvoiChiffre envoi, {required int msgID, required String clientId}) => {
        ...serveur.livrer(envoi: envoi, emetteur: ChatTestHarness.otherId, appareilEmetteur: 21, appareil: 11, clientId: clientId, conv: conv)!,
        'msgID': msgID,
        'type': 0,
        'status': 1,
        'sendAt': DateTime.now().toUtc().toIso8601String(),
      };

  test('message chiffré reçu : déchiffré, rangé, PUIS acquitté', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    final envoi = (await bob.service.chiffrer(
      conversationID: conv,
      moi: ChatTestHarness.otherId,
      charge: const ChargeE2ee(id: 'b1', conv: conv, texte: 'bonjour'),
    ))!;
    h.api.emit('message:received', recuDeBob(envoi, msgID: 501, clientId: 'b1'));

    var lu = await contenuDe(501);
    for (var i = 0; i < 100 && lu != 'bonjour'; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      lu = await contenuDe(501);
    }
    expect(lu, 'bonjour');
    final acks = h.api.eventsNamed('e2ee:ack');
    expect(acks, isNotEmpty);
    expect((acks.last.data as Map)['msgIDs'], [501]);
    expect(await moi.service.estChiffree(conv), isTrue, reason: 'un message chiffré prouve que le fil l\'est');

    // La même ligne servie à nouveau (historique) : le texte reste, aucune
    // erreur, rien de redéchiffré.
    h.api.emit('message:received', recuDeBob(envoi, msgID: 501, clientId: 'b1'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await contenuDe(501), 'bonjour');
  });

  test('message illisible : libellé « en attente », jamais d\'accusé', () async {
    h.api.emit('message:received', {
      'msgID': 502,
      'conversationID': conv,
      'senderID': ChatTestHarness.otherId,
      'clientId': 'b2',
      'enc_version': 1,
      'content': null,
      'type': 0,
      'status': 1,
      'sendAt': DateTime.now().toUtc().toIso8601String(),
      'body': {'ct': 'AAAA', 'nonce': 'AAAAAAAAAAAAAAAA', 'senderAppareilId': 21},
      'envelope': {'envType': 3, 'wrappedKey': 'AAAA'},
    });
    String? c;
    for (var i = 0; i < 100 && c == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c = await contenuDe(502);
    }
    expect(c, isNotNull);
    expect(c!.startsWith(kE2eePrefixeAttente), isTrue);
    expect(e2eeEstTexteReel(c), isFalse);
    expect(h.api.eventsNamed('e2ee:ack'), isEmpty);
  });

  test('envoi dans un fil chiffré : rien en clair, et mon texte survit à l\'accusé', () async {
    serveur.e2eeSince = DateTime(2026, 10, 18);
    await h.repo.sendText(conversationID: conv, content: 'secret');
    await attendre(() => h.api.eventsNamed('message:send').isNotEmpty, raison: 'émission');
    final payload = Map<String, dynamic>.from(h.api.eventsNamed('message:send').last.data as Map);

    expect(payload.containsKey('content'), isFalse, reason: 'le texte ne part jamais en clair');
    expect(payload['body'], isA<Map>());
    final envoi = EnvoiChiffre(
      body: Map<String, String>.from(payload['body'] as Map),
      envelopes: [for (final e in payload['envelopes'] as List) Map<String, Object>.from(e as Map)],
    );
    expect(envoi.envelopes.map((e) => e['appareilId']), [21]);

    // Bob le lit.
    final clientId = payload['clientId'] as String;
    final pourBob = serveur.livrer(envoi: envoi, emetteur: ChatTestHarness.myId, appareilEmetteur: 11, appareil: 21, clientId: clientId, conv: conv)!;
    expect((await bob.service.dechiffrer(pourBob)).texte, 'secret');

    // L'accusé du serveur ne porte pas le texte (il ne l'a pas) : la ligne
    // locale garde le sien — seule copie au monde (chapitre 17).
    h.api.emit('message:sent', {
      'msgID': 900,
      'clientId': clientId,
      'conversationID': conv,
      'senderID': ChatTestHarness.myId,
      'content': null,
      'enc_version': 1,
      'type': 0,
      'status': 1,
      'sendAt': DateTime.now().toUtc().toIso8601String(),
    });
    String? c;
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c = await contenuDe(900);
      if (c != null) break;
    }
    expect(c, 'secret');
  });

  test('fil en clair : le message part en clair, comme avant', () async {
    serveur.e2eeSince = null;
    await h.repo.sendText(conversationID: conv, content: 'clair');
    await attendre(() => h.api.eventsNamed('message:send').isNotEmpty, raison: 'émission');
    final payload = h.api.eventsNamed('message:send').last.data as Map;
    expect(payload['content'], 'clair');
    expect(payload.containsKey('body'), isFalse);
  });

  test('compte non inscrit : aucun appel réseau supplémentaire', () async {
    final pasInscrit = Telephone(serveur, ChatTestHarness.myId, 13); // jamais synchronisé
    E2eeService.instancePourTest = pasInscrit.service;
    await h.repo.sendText(conversationID: conv, content: 'clair');
    await attendre(() => h.api.eventsNamed('message:send').isNotEmpty, raison: 'émission');
    expect(serveur.appelsAppareils, 0);
    expect((h.api.eventsNamed('message:send').last.data as Map)['content'], 'clair');
  });

  test('refus CONVERSATION_CHIFFREE : retenu en file, fil noté chiffré', () async {
    serveur.e2eeSince = null;
    await h.repo.sendText(conversationID: conv, content: 'trop tôt');
    await attendre(() => h.api.eventsNamed('message:send').isNotEmpty, raison: 'émission');
    final clientId = (h.api.eventsNamed('message:send').last.data as Map)['clientId'];
    h.api.emit('message:send_failed', {'clientId': clientId, 'code': 'CONVERSATION_CHIFFREE'});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final ligne = (await h.messages()).firstWhere((m) => m.clientId == clientId);
    expect(ligne.syncPending, isTrue, reason: 'pas « échoué » : il repartira chiffré');
    expect(await moi.service.estChiffree(conv), isTrue);
  });
}
