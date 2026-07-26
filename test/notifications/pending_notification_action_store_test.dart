import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/notifications/pending_notification_action_store.dart';

/// Le JSON lu ici est écrit par `NotificationActionQueue` (Kotlin) : les noms
/// de champs sont un contrat inter-langages, verrouillé aussi côté natif par
/// `NotificationActionQueueTest`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> replyEntry({
    int conv = 42,
    String text = 'salut',
    String clientId = 'notif_1_42',
    int? ts,
    int attempts = 0,
  }) =>
      {
        'kind': 'reply',
        'conversationId': conv,
        'text': text,
        'clientId': clientId,
        'ts': ts ?? now,
        'attempts': attempts,
      };

  Map<String, dynamic> readEntry({int conv = 42, int? ts, int attempts = 0}) =>
      {
        'kind': 'read',
        'conversationId': conv,
        'ts': ts ?? now,
        'attempts': attempts,
      };

  Future<void> seed(List<Map<String, dynamic>> entries) async {
    SharedPreferences.setMockInitialValues({
      PendingNotificationActionStore.prefsKey: jsonEncode(entries),
    });
  }

  Future<List<Map<String, dynamic>>> rawEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PendingNotificationActionStore.prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  group('takeAll', () {
    test('relit le contrat Kotlin champ par champ', () async {
      await seed([replyEntry(), readEntry(conv: 7)]);
      final actions = await PendingNotificationActionStore.takeAll();
      expect(actions, hasLength(2));
      final reply = actions.first;
      expect(reply.kind, PendingNotificationActionStore.kindReply);
      expect(reply.conversationId, 42);
      expect(reply.text, 'salut');
      expect(reply.clientId, 'notif_1_42');
      expect(reply.attempts, 0);
      expect(actions.last.kind, PendingNotificationActionStore.kindRead);
      expect(actions.last.conversationId, 7);
    });

    test('purge les entrées périmées', () async {
      final old = now -
          PendingNotificationActionStore.maxAge.inMilliseconds -
          1000;
      await seed([replyEntry(ts: old), readEntry(conv: 7)]);
      final actions = await PendingNotificationActionStore.takeAll();
      expect(actions, hasLength(1));
      expect(actions.single.kind, PendingNotificationActionStore.kindRead);
    });

    test('ignore les entrées à bout de tentatives', () async {
      await seed([
        replyEntry(
            clientId: 'cid_epuise',
            attempts: PendingNotificationActionStore.maxAttempts + 1),
        replyEntry(clientId: 'cid_ok'),
      ]);
      final actions = await PendingNotificationActionStore.takeAll();
      expect(actions.map((a) => a.clientId), ['cid_ok']);
    });

    test('un reply sans clientId est irrécupérable et ignoré', () async {
      final e = replyEntry()..remove('clientId');
      await seed([e, readEntry(conv: 7)]);
      final actions = await PendingNotificationActionStore.takeAll();
      expect(actions, hasLength(1));
      expect(actions.single.kind, PendingNotificationActionStore.kindRead);
    });

    test('json illisible = liste vide, pas d\'exception', () async {
      SharedPreferences.setMockInitialValues({
        PendingNotificationActionStore.prefsKey: '{pas du json[',
      });
      expect(await PendingNotificationActionStore.takeAll(), isEmpty);
    });
  });

  group('remove', () {
    test('un reply se retire par clientId, pas par conversation', () async {
      await seed([
        replyEntry(clientId: 'cid_a'),
        replyEntry(clientId: 'cid_b', text: 'autre'),
        readEntry(),
      ]);
      final actions = await PendingNotificationActionStore.takeAll();
      await PendingNotificationActionStore.remove(
          actions.firstWhere((a) => a.clientId == 'cid_a'));
      final rest = await rawEntries();
      expect(rest, hasLength(2));
      expect(rest.any((e) => e['clientId'] == 'cid_b'), isTrue);
      expect(rest.any((e) => e['kind'] == 'read'), isTrue);
    });

    test('un read se retire par conversation', () async {
      await seed([readEntry(conv: 7), readEntry(conv: 8)]);
      final actions = await PendingNotificationActionStore.takeAll();
      await PendingNotificationActionStore.remove(
          actions.firstWhere((a) => a.conversationId == 7));
      final rest = await rawEntries();
      expect(rest, hasLength(1));
      expect(rest.single['conversationId'], 8);
    });
  });

  group('bumpAttempts', () {
    test('incrémente puis abandonne au-delà du plafond', () async {
      await seed([replyEntry(clientId: 'cid_a')]);
      var actions = await PendingNotificationActionStore.takeAll();
      for (var i = 1; i <= PendingNotificationActionStore.maxAttempts; i++) {
        await PendingNotificationActionStore.bumpAttempts(actions.single);
        final raw = await rawEntries();
        expect(raw, hasLength(1), reason: 'tentative $i conservée');
        expect(raw.single['attempts'], i);
      }
      actions = await PendingNotificationActionStore.takeAll();
      await PendingNotificationActionStore.bumpAttempts(actions.single);
      expect(await rawEntries(), isEmpty);
    });
  });

  test('clear vide la file (logout / changement de compte)', () async {
    await seed([replyEntry(), readEntry()]);
    await PendingNotificationActionStore.clear();
    expect(await PendingNotificationActionStore.takeAll(), isEmpty);
  });
}
