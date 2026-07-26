import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/notifications/pending_notification_action_store.dart';

import '../fakes/chat_test_harness.dart';
import '../fakes/fake_chat_api.dart';

/// Rejeu des actions déposées par la couche notification native
/// (`ChatRepository.flushPendingNotificationActions`).
void main() {
  late ChatTestHarness h;

  Future<void> seedQueue(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PendingNotificationActionStore.prefsKey,
      jsonEncode(entries),
    );
  }

  Map<String, dynamic> replyEntry(String clientId, {String text = 'depuis la notif'}) => {
        'kind': 'reply',
        'conversationId': ChatTestHarness.convId,
        'text': text,
        'clientId': clientId,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
      };

  group('rejeu nominal', () {
    setUp(() async {
      h = ChatTestHarness();
      await h.setUp();
    });

    tearDown(() => h.tearDown());

    test('reply non trouvé côté serveur → sendText avec LE MÊME clientId',
        () async {
      await seedQueue([replyEntry('notif_123_10')]);

      await h.repo.flushPendingNotificationActions();
      await h.pumpEventQueue();

      // Vérifié côté serveur d'abord (2e ceinture anti-doublon)…
      expect(
          h.api.httpLog, contains('getMessageStatusByClientId:notif_123_10'));
      // …puis envoyé par le chemin normal, clientId natif conservé sur le
      // fil : c'est lui qui fait jouer l'idempotence serveur.
      final sends = h.api.eventsNamed('message:send');
      expect(sends, hasLength(1));
      expect((sends.single.data as Map)['clientId'], 'notif_123_10');

      // La réponse apparaît dans le fil (ligne re-clé srv_* après l'ack).
      final msgs = await h.messages();
      expect(msgs.map((m) => m.content), contains('depuis la notif'));
      expect(await PendingNotificationActionStore.takeAll(), isEmpty);
    });

    test('reply déjà passé (found) → aucun renvoi, purge', () async {
      h.api.messageStatusByClientId['notif_123_10'] = {
        'msgID': 555,
        'status': 1,
        'conversationID': ChatTestHarness.convId,
      };
      await seedQueue([replyEntry('notif_123_10')]);

      await h.repo.flushPendingNotificationActions();
      await h.pumpEventQueue();

      expect(h.api.eventsNamed('message:send'), isEmpty,
          reason:
              'le POST natif avait abouti : renvoyer doublerait le message');
      expect(await PendingNotificationActionStore.takeAll(), isEmpty);
    });

    test('read → markConversationAsRead HTTP + purge', () async {
      await seedQueue([
        {
          'kind': 'read',
          'conversationId': ChatTestHarness.convId,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'attempts': 0,
        }
      ]);

      await h.repo.flushPendingNotificationActions();
      await h.pumpEventQueue();

      expect(h.api.httpLog,
          contains('markConversationAsRead:${ChatTestHarness.convId}'));
      expect(await PendingNotificationActionStore.takeAll(), isEmpty);
    });
  });

  group('rejeu en panne', () {
    test('échec transitoire → entrée conservée, attempts incrémenté',
        () async {
      final api = _StatusThrowingApi();
      final failing = ChatTestHarness();
      await failing.setUp(api: api);
      await seedQueue([replyEntry('notif_err_10')]);

      await failing.repo.flushPendingNotificationActions();

      expect(api.eventsNamed('message:send'), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(PendingNotificationActionStore.prefsKey) ?? '[]';
      final entries = (jsonDecode(raw) as List).whereType<Map>().toList();
      expect(entries, hasLength(1),
          reason: 'une panne réseau ne doit pas perdre la réponse');
      expect(entries.single['attempts'], 1);
      await failing.tearDown();
    });
  });
}

class _StatusThrowingApi extends FakeChatApi {
  @override
  Future<Map<String, dynamic>> getMessageStatusByClientId(String clientId) {
    throw Exception('réseau coupé');
  }
}
