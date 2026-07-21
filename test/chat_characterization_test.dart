import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/talky_models.dart';

import 'fakes/chat_test_harness.dart';

/// Tests de caractérisation — comportement voulu du module chat
/// (envoi/dédup, non-lus lifecycle, aperçu delete/edit, reçus).
void main() {
  late ChatTestHarness h;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp();
  });

  tearDown(() async {
    await h.tearDown();
  });

  group('envoi / dédup', () {
    test('optimiste + message:sent → 1 seule ligne (clientId)', () async {
      await h.repo.sendText(conversationID: ChatTestHarness.convId, content: 'hello');
      await h.pumpEventQueue();

      final msgs = await h.messages();
      expect(msgs, hasLength(1));
      expect(msgs.single.content, 'hello');
      expect(msgs.single.msgID, greaterThan(0));
      expect(msgs.single.syncPending, isFalse);
    });

    test('N flushOutbox → 1 seul message (idempotence clientId)', () async {
      h.api.autoAckSend = false;
      await h.repo.sendText(conversationID: ChatTestHarness.convId, content: 'retry-me');
      await h.pumpEventQueue();

      final pending = await h.messages();
      expect(pending, hasLength(1));
      final clientId = pending.single.clientId;

      // Simule plusieurs retries d'émission avant ack.
      for (var i = 0; i < 3; i++) {
        await h.repo.flushOutbox();
        await h.pumpEventQueue();
      }
      expect(h.api.eventsNamed(SocketEvents.messageSend), isNotEmpty);

      // Un seul ack serveur pour le même clientId.
      h.api.emit('message:sent', {
        'msgID': 4242,
        'clientId': clientId,
        'conversationID': ChatTestHarness.convId,
        'senderID': ChatTestHarness.myId,
        'content': 'retry-me',
        'type': 0,
        'status': 1,
        'sendAt': DateTime.now().toUtc().toIso8601String(),
      });
      await h.pumpEventQueue();

      final after = await h.messages();
      expect(after.where((m) => m.content == 'retry-me'), hasLength(1));
      expect(after.single.msgID, 4242);
    });

    test('double message:sent (echo autre appareil) → 1 ligne', () async {
      h.api.autoAckSend = false;
      await h.repo.sendText(conversationID: ChatTestHarness.convId, content: 'multi');
      await h.pumpEventQueue();
      final clientId = (await h.messages()).single.clientId;
      final payload = {
        'msgID': 9001,
        'clientId': clientId,
        'conversationID': ChatTestHarness.convId,
        'senderID': ChatTestHarness.myId,
        'content': 'multi',
        'type': 0,
        'status': 1,
        'sendAt': DateTime.now().toUtc().toIso8601String(),
      };
      h.api.emit('message:sent', payload);
      await h.pumpEventQueue();
      h.api.emit('message:sent', payload);
      await h.pumpEventQueue();
      expect(await h.messages(), hasLength(1));
      expect((await h.messages()).single.msgID, 9001);
    });
  });

  group('non-lus lifecycle', () {
    test('reçu hors chat → unread +1', () async {
      await h.receiveIncoming(msgID: 1, content: 'ping');
      final c = await h.conv();
      expect(c?.unreadCount, 1);
      expect(c?.lastMessage, 'ping');
    });

    test('chat ouvert premier plan → unread 0', () async {
      h.repo.setActiveConversation(ChatTestHarness.convId);
      h.repo.syncPushSuppressionForLifecycle(true);
      await h.receiveIncoming(msgID: 2, content: 'vu');
      final c = await h.conv();
      expect(c?.unreadCount, 0);
    });

    test('app arrière-plan + chat ouvert → unread +1', () async {
      h.repo.setActiveConversation(ChatTestHarness.convId);
      h.repo.syncPushSuppressionForLifecycle(false);
      await h.receiveIncoming(msgID: 3, content: 'bg');
      final c = await h.conv();
      expect(c?.unreadCount, 1);
    });

    test('retour premier plan + markAsRead → unread 0', () async {
      h.repo.setActiveConversation(ChatTestHarness.convId);
      h.repo.syncPushSuppressionForLifecycle(false);
      await h.receiveIncoming(msgID: 4, content: 'bg2');
      expect((await h.conv())?.unreadCount, 1);

      h.repo.syncPushSuppressionForLifecycle(true);
      await h.repo.markAsRead(ChatTestHarness.convId);
      await h.pumpEventQueue();
      expect((await h.conv())?.unreadCount, 0);
    });
  });

  group('aperçu delete / edit', () {
    test('reçu met à jour lastMessage', () async {
      await h.receiveIncoming(msgID: 10, content: 'a');
      await h.receiveIncoming(
        msgID: 11,
        content: 'b',
        sendAt: DateTime.now().toUtc().add(const Duration(seconds: 1)),
      );
      expect((await h.conv())?.lastMessage, 'b');
    });

    test('delete non-dernier → aperçu inchangé', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      await h.receiveIncoming(msgID: 20, content: 'first', sendAt: t0);
      await h.receiveIncoming(
        msgID: 21,
        content: 'second',
        sendAt: t0.add(const Duration(seconds: 2)),
      );
      expect((await h.conv())?.lastMessage, 'second');

      await h.repo.deleteMessages([20], forAll: true, conversationID: ChatTestHarness.convId);
      await h.pumpEventQueue();
      expect((await h.conv())?.lastMessage, 'second');
    });

    test('delete dernier forAll → placeholder supprimé (aperçu)', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      await h.receiveIncoming(msgID: 30, content: 'keep', sendAt: t0);
      await h.receiveIncoming(
        msgID: 31,
        content: 'gone',
        sendAt: t0.add(const Duration(seconds: 2)),
      );

      await h.repo.deleteMessages([31], forAll: true, conversationID: ChatTestHarness.convId);
      await h.pumpEventQueue();
      // Soft-delete forAll : le message reste visible comme placeholder.
      expect((await h.conv())?.lastMessage, 'Ce message a été supprimé');
    });

    test('delete dernier pour moi → aperçu = message précédent', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      await h.receiveIncoming(msgID: 32, content: 'keep', sendAt: t0);
      await h.receiveIncoming(
        msgID: 33,
        content: 'gone-for-me',
        sendAt: t0.add(const Duration(seconds: 2)),
      );

      await h.repo.deleteMessages(
        [33],
        forAll: false,
        conversationID: ChatTestHarness.convId,
      );
      await h.pumpEventQueue();
      expect((await h.conv())?.lastMessage, 'keep');
    });

    test('edit dernier → aperçu suit', () async {
      await h.receiveIncoming(msgID: 40, content: 'old');
      // Edit d'un message entrant via handler socket (pas editMessage local = mien).
      h.api.emit('message:updated', {'msgID': 40, 'content': 'new'});
      await h.pumpEventQueue();
      expect((await h.conv())?.lastMessage, 'new');
    });
  });

  group('sync delta globale', () {
    Map<String, dynamic> srvMsg(int id, String content, DateTime at,
        {int status = 1}) {
      return {
        'msgID': id,
        'conversationID': ChatTestHarness.convId,
        'senderID': ChatTestHarness.otherId,
        'content': content,
        'type': 0,
        'status': status,
        'sendAt': at.toIso8601String(),
      };
    }

    test('rapatrie les messages manqués par le socket + non-lus corrects',
        () async {
      // Un seul message livré par le socket ; 6 et 7 seront « ratés ».
      await h.receiveIncoming(
        msgID: 5,
        content: 'm5',
        sendAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      );
      expect((await h.conv())?.unreadCount, 1);

      // Le serveur a en réalité 3 messages dans la conversation.
      h.api.messagesByConv[ChatTestHarness.convId] = [
        srvMsg(5, 'm5', DateTime.utc(2026, 1, 1, 12, 0, 0)),
        srvMsg(6, 'm6', DateTime.utc(2026, 1, 1, 12, 0, 1)),
        srvMsg(7, 'm7', DateTime.utc(2026, 1, 1, 12, 0, 2)),
      ];

      await h.repo.syncGlobalDelta();
      await h.pumpEventQueue();

      final ids = (await h.messages()).map((m) => m.msgID).toSet();
      expect(ids.containsAll({5, 6, 7}), isTrue);

      final c = await h.conv();
      expect(c?.unreadCount, 3);
      expect(c?.lastMessage, 'm7');
    });

    test('idempotent : re-sync ne duplique pas / ne recompte pas', () async {
      await h.receiveIncoming(
        msgID: 5,
        content: 'm5',
        sendAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      );
      h.api.messagesByConv[ChatTestHarness.convId] = [
        srvMsg(5, 'm5', DateTime.utc(2026, 1, 1, 12, 0, 0)),
        srvMsg(6, 'm6', DateTime.utc(2026, 1, 1, 12, 0, 1)),
      ];
      await h.repo.syncGlobalDelta();
      await h.pumpEventQueue();
      await h.repo.syncGlobalDelta();
      await h.pumpEventQueue();

      final msgs = await h.messages();
      expect(msgs.where((m) => m.msgID == 6), hasLength(1));
      expect((await h.conv())?.unreadCount, 2);
    });
  });

  group('reçus delivered vs read', () {
    test('hors chat actif → emit delivered (status 2)', () async {
      await h.receiveIncoming(msgID: 50, content: 'd');
      final delivered = h.api.eventsNamed(SocketEvents.messageDelivered);
      final read = h.api.eventsNamed(SocketEvents.messageRead);
      expect(delivered, isNotEmpty);
      expect(read, isEmpty);
    });

    test('chat actif premier plan → emit read (status 3)', () async {
      h.repo.setActiveConversation(ChatTestHarness.convId);
      h.repo.syncPushSuppressionForLifecycle(true);
      await h.receiveIncoming(msgID: 51, content: 'r');
      final read = h.api.eventsNamed(SocketEvents.messageRead);
      expect(read, isNotEmpty);
    });
  });
}
