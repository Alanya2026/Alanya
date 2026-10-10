import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';

import 'fakes/chat_test_harness.dart';

/// Essai fini, aucun abonnement : le compte reçoit, il n'émet pas.
///
/// Éprouvé au niveau du dépôt de chat, là où passent TOUS les envois (composeur,
/// transfert, partage, réponse à un statut, note vocale) : aucun écran n'a à
/// savoir qu'une règle existe, et aucun message n'est mis en file pour rien.
Map<String, dynamic> _rights({required bool outgoing}) => {
      'model': 2,
      'phase': 'paid',
      'trial': {'endsAt': '2026-01-01T00:00:00.000Z', 'active': !outgoing},
      'exempt': false,
      'features': {'outgoing': outgoing},
    };

void main() {
  late ChatTestHarness h;
  late EntitlementService rights;
  late List<void> blocked;
  late StreamSubscription<void> sub;

  const conv = ChatTestHarness.convId;

  setUp(() async {
    h = ChatTestHarness();
    await h.setUp(autoAckSend: false);
    rights = EntitlementService(api: TalkyApiClient());
    blocked = [];
    sub = rights.outgoingBlocked.listen(blocked.add);
  });

  tearDown(() async {
    await sub.cancel();
    rights.dispose();
    await h.tearDown();
  });

  Future<void> restrict() => rights.apply(_rights(outgoing: false));
  Future<void> allow() => rights.apply(_rights(outgoing: true));

  Future<void> settle() => h.pumpEventQueue();

  Future<List<LocalMessage>> sent() async =>
      (await h.messages()).where((m) => m.senderID == ChatTestHarness.myId).toList();

  group('rien n\'est mis en file sans droit d\'envoi', () {
    test('texte', () async {
      await restrict();
      await h.repo.sendText(conversationID: conv, content: 'bonjour');
      await settle();
      expect(await sent(), isEmpty);
      expect(h.api.eventsNamed(SocketEvents.messageSend), isEmpty);
      expect(blocked, hasLength(1), reason: 'le panneau de l\'abonnement s\'ouvre');
    });

    test('position, contact et média', () async {
      await restrict();
      await h.repo.sendMedia(
        conversationID: conv,
        type: 1,
        mediaUrl: 'https://cdn.test/a.jpg',
      );
      await settle();
      expect(await sent(), isEmpty);
      expect(h.api.eventsNamed(SocketEvents.messageSend), isEmpty);
    });

    test('plusieurs refus coup sur coup ne font qu\'un signal', () async {
      await restrict();
      for (var i = 0; i < 5; i++) {
        await h.repo.sendText(conversationID: conv, content: 'm$i');
      }
      await settle();
      expect(blocked, hasLength(1));
    });

    test('le transfert est refusé, sans appel au serveur', () async {
      await h.receiveIncoming(msgID: 77, content: 'à transférer');
      final source = (await h.messages()).single;
      await restrict();
      final result = await h.repo.forwardMessages(
        sources: [source],
        targetConversationIDs: [conv],
      );
      expect(result.succeeded, 0);
      expect(result.failed, greaterThan(0));
      expect(h.api.httpLog.where((l) => l.contains('forward')), isEmpty);
      expect(blocked, hasLength(1));
    });

    test('la modification n\'altère pas le texte local', () async {
      await h.receiveIncoming(msgID: 78, content: 'avant');
      await restrict();
      await h.repo.editMessage(78, 'après');
      await settle();
      expect((await h.messages()).single.content, 'avant',
          reason: 'l\'écran ne montre pas un texte que le serveur refuserait');
      expect(blocked, hasLength(1));
    });

    test('la réaction est refusée avant l\'écriture optimiste', () async {
      await h.receiveIncoming(msgID: 79, content: 'x');
      await restrict();
      await h.repo.setReaction(79, '👍', conversationID: conv);
      await settle();
      final rows = await h.db.select(h.db.localMessageReactions).get();
      expect(rows, isEmpty);
      expect(blocked, hasLength(1));
    });
  });

  group('avec un droit d\'envoi, rien ne change', () {
    test('texte', () async {
      await allow();
      await h.repo.sendText(conversationID: conv, content: 'bonjour');
      await settle();
      expect(await sent(), hasLength(1));
      expect(h.api.eventsNamed(SocketEvents.messageSend), hasLength(1));
      expect(blocked, isEmpty);
    });

    test('sans droits connus (serveur ancien), tout est permis', () async {
      // Aucun `apply` : `Entitlements.unrestricted`.
      await h.repo.sendText(conversationID: conv, content: 'bonjour');
      await settle();
      expect(await sent(), hasLength(1));
      expect(blocked, isEmpty);
    });
  });

  group('le serveur refuse un envoi que le cache autorisait', () {
    Future<String> sendOne() async {
      await allow();
      await h.repo.sendText(conversationID: conv, content: 'trop tard');
      await settle();
      return (await sent()).single.clientId;
    }

    test('la bulle passe en échec, sans être terminale, et le panneau s\'ouvre', () async {
      final clientId = await sendOne();
      h.api.emit('message:send_failed', {
        'clientId': clientId,
        'code': 'SUBSCRIPTION_REQUIRED',
        'feature': 'outgoing',
      });
      await settle();
      final msg = (await sent()).single;
      expect(msg.status, 4);
      // Pas de code définitif : « réessayer » doit marcher dès qu'un code est activé.
      expect(msg.failureCode, isNull);
      expect(blocked, hasLength(1));
    });

    test('tant que le droit manque, l\'outbox ne rejoue pas', () async {
      final clientId = await sendOne();
      h.api.emit('message:send_failed', {'clientId': clientId, 'code': 'SUBSCRIPTION_REQUIRED'});
      await settle();
      await restrict();
      final before = h.api.eventsNamed(SocketEvents.messageSend).length;
      for (var i = 0; i < 3; i++) {
        await h.repo.flushOutbox();
        await settle();
      }
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, before,
          reason: 'chaque rejeu recevrait le même refus');
      expect((await sent()).single.retryCount, 0);
    });

    test('« réessayer » est refusé tant que le droit manque, puis passe', () async {
      final clientId = await sendOne();
      h.api.emit('message:send_failed', {'clientId': clientId, 'code': 'SUBSCRIPTION_REQUIRED'});
      await settle();
      await restrict();
      blocked.clear();

      final before0 = h.api.eventsNamed(SocketEvents.messageSend).length;
      await h.repo.retryMessage(clientId);
      await settle();
      expect((await sent()).single.status, 4, reason: 'toujours en échec');
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, before0,
          reason: 'rien n\'est réémis');

      // Un code est activé : le droit revient, la même bulle repart.
      await allow();
      final before = h.api.eventsNamed(SocketEvents.messageSend).length;
      await h.repo.retryMessage(clientId);
      await settle();
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, greaterThan(before));
      expect((await sent()).single.status, isNot(4));
    });
  });

  group('un refus définitif n\'est jamais rejoué (défaut corrigé)', () {
    test('un code terminal n\'est pas réémis par l\'outbox', () async {
      await allow();
      await h.repo.sendText(conversationID: conv, content: 'réservé aux admins');
      await settle();
      final clientId = (await sent()).single.clientId;
      h.api.emit('message:send_failed', {'clientId': clientId, 'code': 'GROUP_ADMINS_ONLY'});
      await settle();
      expect((await sent()).single.failureCode, 'GROUP_ADMINS_ONLY');

      final before = h.api.eventsNamed(SocketEvents.messageSend).length;
      for (var i = 0; i < 3; i++) {
        await h.repo.flushOutbox();
        await settle();
      }
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, before,
          reason: 'il échouerait à l\'identique, trois fois pour rien');
      expect((await sent()).single.retryCount, 0);
    });

    test('un échec réseau, lui, reste rejoué', () async {
      await allow();
      await h.repo.sendText(conversationID: conv, content: 'réseau');
      await settle();
      final clientId = (await sent()).single.clientId;
      // Échec sans code terminal : relançable.
      await h.db.update(h.db.localMessages).write(
            const LocalMessagesCompanion(status: Value(4), syncPending: Value(false)),
          );
      final before = h.api.eventsNamed(SocketEvents.messageSend).length;
      await h.repo.flushOutbox();
      await settle();
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, greaterThan(before));
      expect((await sent()).single.clientId, clientId);
    });
  });
}
