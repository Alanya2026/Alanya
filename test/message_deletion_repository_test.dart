// Suppression pour tous : le serveur décide (72 h, droits). Quand il REFUSE, le
// message revient à l'écran (il est resté visible chez tous les autres) et l'erreur
// remonte pour être dite ; une panne réseau, elle, ne défait rien.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/talky_api_client.dart' show TalkyException;

import 'fakes/chat_test_harness.dart';

void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  Future<bool> visible(int msgID) async =>
      !(await h.messages()).firstWhere((m) => m.msgID == msgID).isDeleted;

  final t0 = DateTime.utc(2026, 1, 1, 12);

  group('« pour tous » refusé par le serveur', () {
    test('72 h dépassées (403 DELETE_WINDOW_EXPIRED) : le message revient, l\'erreur remonte', () async {
      await h.receiveIncoming(msgID: 50, content: 'ancien', sendAt: t0);
      h.api.deleteError = TalkyException('x', 403, code: 'DELETE_WINDOW_EXPIRED');

      await expectLater(
        h.repo.deleteMessages([50], forAll: true, conversationID: ChatTestHarness.convId),
        throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'DELETE_WINDOW_EXPIRED')),
      );
      await h.pumpEventQueue();
      expect(await visible(50), isTrue, reason: 'restauré : il est resté visible chez les autres');
      expect((await h.conv())?.lastMessage, 'ancien', reason: 'aperçu réaligné');
    });

    test('droits insuffisants (403 FORBIDDEN) et message inconnu (404) : même retour arrière', () async {
      for (final (id, statut, code) in [(51, 403, 'FORBIDDEN'), (52, 404, 'MESSAGE_NOT_FOUND')]) {
        await h.receiveIncoming(msgID: id, content: 'm$id', sendAt: t0.add(Duration(minutes: id)));
        h.api.deleteError = TalkyException('x', statut, code: code);
        await expectLater(
          h.repo.deleteMessages([id], forAll: true, conversationID: ChatTestHarness.convId),
          throwsA(isA<TalkyException>()),
        );
        expect(await visible(id), isTrue, reason: code);
      }
    });

    test('lot : tout est rendu — sauf ce qui était déjà supprimé avant l\'appel', () async {
      await h.receiveIncoming(msgID: 60, content: 'a', sendAt: t0);
      await h.receiveIncoming(msgID: 61, content: 'b', sendAt: t0.add(const Duration(minutes: 1)));
      await h.receiveIncoming(msgID: 62, content: 'c', sendAt: t0.add(const Duration(minutes: 2)));
      // 62 avait déjà été supprimé pour tous (événement reçu plus tôt).
      h.api.emit('message:deleted', {'msgID': 62, 'conversationID': ChatTestHarness.convId, 'all': true});
      await h.pumpEventQueue();
      expect(await visible(62), isFalse);

      h.api.deleteError = TalkyException('x', 403, code: 'DELETE_WINDOW_EXPIRED');
      await expectLater(
        h.repo.deleteMessages([60, 61, 62], forAll: true, conversationID: ChatTestHarness.convId),
        throwsA(isA<TalkyException>()),
      );
      expect(await visible(60), isTrue);
      expect(await visible(61), isTrue);
      expect(await visible(62), isFalse, reason: 'déjà supprimé avant : ne ressuscite pas');
    });

    test('le serveur est bien appelé avec la demande « pour tous »', () async {
      await h.receiveIncoming(msgID: 70, content: 'x', sendAt: t0);
      await h.repo.deleteMessages([70], forAll: true, conversationID: ChatTestHarness.convId);
      expect(h.api.httpLog, contains('deleteMessages:70:true'));
      expect(await visible(70), isFalse, reason: 'accepté : reste supprimé');
    });
  });

  group('ce qui ne change pas', () {
    test('panne réseau ou erreur serveur (5xx, 429, 408) : la suppression locale reste, rien ne remonte', () async {
      final pannes = <Object>[
        TalkyException('x', 503, code: 'SERVICE_UNAVAILABLE'),
        TalkyException('x', 500),
        TalkyException('x', 429, code: 'RATE_LIMITED'),
        TalkyException('x', 408),
        Exception('hors ligne'),
      ];
      var id = 80;
      for (final panne in pannes) {
        id += 1;
        await h.receiveIncoming(msgID: id, content: 'p$id', sendAt: t0.add(Duration(minutes: id)));
        h.api.deleteError = panne;
        await h.repo.deleteMessages([id], forAll: true, conversationID: ChatTestHarness.convId);
        expect(await visible(id), isFalse, reason: '$panne');
      }
    });

    test('« pour moi » : une erreur du serveur n\'annule rien et ne remonte pas (inchangé)', () async {
      await h.receiveIncoming(msgID: 90, content: 'perso', sendAt: t0);
      h.api.deleteError = TalkyException('x', 404, code: 'MESSAGE_NOT_FOUND');
      await h.repo.deleteMessages([90], forAll: false, conversationID: ChatTestHarness.convId);
      final m = (await h.messages()).firstWhere((m) => m.msgID == 90);
      expect(m.deletedForID, ChatTestHarness.myId);
    });
  });
}
