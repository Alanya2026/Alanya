// « Effacer la discussion » : distincte de « Supprimer la discussion ». La
// conversation reste dans la liste, MA copie repart d'une page blanche, et le
// serveur pose un curseur d'historique qui vaut pour tous mes appareils.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/chat/conversation_clear_service.dart';
import 'package:talky_flutter/talky_api_client.dart' show TalkyException;

import 'fakes/chat_test_harness.dart';

void main() {
  late ChatTestHarness h;
  late Directory appDir;
  late Directory outside;

  setUp(() async {
    appDir = Directory.systemTemp.createTempSync('alanya_app_');
    outside = Directory.systemTemp.createTempSync('alanya_gallery_');
    h = ChatTestHarness(appRoots: () async => [appDir.path]);
    await h.setUp();
  });
  tearDown(() async {
    await h.tearDown();
    appDir.deleteSync(recursive: true);
    outside.deleteSync(recursive: true);
  });

  final cutoff = DateTime.utc(2026, 10, 11, 8);
  final avant = cutoff.subtract(const Duration(hours: 2));
  final apres = cutoff.add(const Duration(minutes: 5));

  File fichier(Directory dir, String nom, {int octets = 100}) {
    final f = File(p.join(dir.path, nom))..writeAsBytesSync(List.filled(octets, 1));
    return f;
  }

  Future<void> media(int msgID, File f, {DateTime? at, int conv = ChatTestHarness.convId}) async {
    await h.db.into(h.db.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: 'srv_$msgID',
          msgID: Value(msgID),
          conversationID: conv,
          senderID: ChatTestHarness.otherId,
          sendAt: at ?? avant,
          type: const Value(1),
          localMediaPath: Value(f.path),
        ));
  }

  group('tous les messages', () {
    test('le serveur est appelé, les messages d\'avant partent, la conversation reste', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      await h.receiveIncoming(msgID: 2, content: 'b', sendAt: avant.add(const Duration(minutes: 1)));
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);
      await h.pumpEventQueue();

      expect(h.api.httpLog, contains('clearConversation:${ChatTestHarness.convId}'));
      expect(await h.messages(), isEmpty);
      final conv = await h.conv();
      expect(conv, isNotNull, reason: 'effacer n\'est pas supprimer : la discussion reste');
      expect(conv!.lastMessage, isNull);
      expect(conv.unreadCount, 0);
      expect(conv.myHistoryCutoffAt!.toUtc(), cutoff);
    });

    test('un message reçu APRÈS le curseur reste, et devient l\'aperçu', () async {
      await h.receiveIncoming(msgID: 1, content: 'ancien', sendAt: avant);
      await h.receiveIncoming(msgID: 2, content: 'récent', sendAt: apres);
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);
      await h.pumpEventQueue();

      expect((await h.messages()).map((m) => m.msgID), [2]);
      expect((await h.conv())!.lastMessage, 'récent');
    });

    test('même seconde que le curseur : le message reste (comme le serveur, >=)', () async {
      await h.receiveIncoming(msgID: 1, content: 'pile', sendAt: cutoff);
      h.api.clearCutoffIso = cutoff.toIso8601String();
      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);
      expect((await h.messages()).map((m) => m.msgID), [1]);
    });

    test('hors ligne (le serveur échoue) : RIEN n\'est effacé et l\'erreur remonte', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      h.api.clearError = TalkyException('hors ligne', 0);

      await expectLater(
        h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all),
        throwsA(isA<TalkyException>()),
      );
      expect((await h.messages()).length, 1);
      expect((await h.conv())!.myHistoryCutoffAt, isNull);
    });

    test('un envoi en attente survit : il appartient à la page blanche', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      await h.db.into(h.db.localMessages).insert(LocalMessagesCompanion.insert(
            clientId: 'c-attente',
            conversationID: ChatTestHarness.convId,
            senderID: ChatTestHarness.myId,
            sendAt: avant,
            content: const Value('pas encore parti'),
            syncPending: const Value(true),
          ));
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);

      expect((await h.messages()).map((m) => m.clientId), ['c-attente']);
    });

    test('les réactions des messages effacés partent aussi', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      await h.dao.upsertReaction(
          msgID: 1, userID: ChatTestHarness.otherId, conversationID: ChatTestHarness.convId, emoji: '👍');
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);

      expect(await h.db.select(h.db.localMessageReactions).get(), isEmpty);
    });

    test('une AUTRE discussion n\'est pas touchée', () async {
      await h.db.into(h.db.localConversations).insert(LocalConversationsCompanion.insert(
            conversID: const Value(11),
            participantsJson: const Value('[]'),
          ));
      await h.db.into(h.db.localMessages).insert(LocalMessagesCompanion.insert(
            clientId: 'srv_900',
            msgID: const Value(900),
            conversationID: 11,
            senderID: ChatTestHarness.otherId,
            sendAt: avant,
            content: const Value('ailleurs'),
          ));
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);

      final autres = await (h.db.select(h.db.localMessages)..where((m) => m.conversationID.equals(11))).get();
      expect(autres.length, 1);
    });
  });

  group('fichiers', () {
    test('« tous » supprime les fichiers de l\'app, jamais ceux d\'ailleurs', () async {
      final dansApp = fichier(appDir, 'telecharge.jpg');
      final galerie = fichier(outside, 'IMG_0001.jpg');
      await media(1, dansApp);
      await media(2, galerie);
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);

      expect(dansApp.existsSync(), isFalse);
      expect(galerie.existsSync(), isTrue, reason: 'le fichier de la galerie est à l\'utilisateur');
    });

    test('un fichier encore utilisé par une autre discussion reste', () async {
      final partage = fichier(appDir, 'transfere.jpg');
      await h.db.into(h.db.localConversations).insert(LocalConversationsCompanion.insert(
            conversID: const Value(11), participantsJson: const Value('[]')));
      await media(1, partage);
      await media(901, partage, conv: 11);
      h.api.clearCutoffIso = cutoff.toIso8601String();

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.all);

      expect(partage.existsSync(), isTrue);
    });

    test('« médias uniquement » : fichiers supprimés, messages et textes conservés, réseau intact', () async {
      final f = fichier(appDir, 'photo.jpg');
      await media(1, f);
      await h.receiveIncoming(msgID: 2, content: 'texte', sendAt: avant);

      await h.repo.clearConversation(ChatTestHarness.convId, mode: ClearMode.mediaOnly);

      expect(f.existsSync(), isFalse);
      final msgs = await h.messages();
      expect(msgs.map((m) => m.msgID), [1, 2]);
      expect(msgs.firstWhere((m) => m.msgID == 1).localMediaPath, isNull);
      expect(h.api.httpLog.where((l) => l.startsWith('clearConversation')), isEmpty,
          reason: 'purement local');
      expect((await h.conv())!.myHistoryCutoffAt, isNull);
    });

    test('estimation : poids des fichiers de l\'app seulement', () async {
      await media(1, fichier(appDir, 'a.jpg', octets: 300));
      await media(2, fichier(appDir, 'b.jpg', octets: 200));
      await media(3, fichier(outside, 'c.jpg', octets: 9999));
      await h.receiveIncoming(msgID: 4, content: '12345', sendAt: avant);

      final e = await h.repo.estimateClear(ChatTestHarness.convId);

      expect(e.mediaFiles, 2);
      expect(e.mediaBytes, 500);
      expect(e.bytesFor(ClearMode.mediaOnly), 500);
      expect(e.bytesFor(ClearMode.all), greaterThanOrEqualTo(505));
    });
  });

  group('autres appareils et appareil resté hors ligne', () {
    test('« conversation:cleared » vide la copie locale de mes autres appareils', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      await h.receiveIncoming(msgID: 2, content: 'b', sendAt: apres);

      h.api.emit('conversation:cleared', {
        'conversationID': ChatTestHarness.convId,
        'historyCutoffAt': cutoff.toIso8601String(),
      });
      await h.pumpEventQueue();

      expect((await h.messages()).map((m) => m.msgID), [2]);
      expect((await h.conv())!.myHistoryCutoffAt!.toUtc(), cutoff);
      expect(h.api.httpLog.where((l) => l.startsWith('clearConversation')), isEmpty,
          reason: 'l\'événement ne renvoie pas un second effacement au serveur');
    });

    test('trame illisible : ignorée', () async {
      await h.receiveIncoming(msgID: 1, content: 'a', sendAt: avant);
      h.api.emit('conversation:cleared', {'conversationID': 'x'});
      h.api.emit('conversation:cleared', 'n\'importe quoi');
      await h.pumpEventQueue();
      expect((await h.messages()).length, 1);
    });

    test('la synchronisation de la liste applique le curseur du serveur (appareil éteint pendant l\'effacement)', () async {
      await h.receiveIncoming(msgID: 1, content: 'ancien', sendAt: avant);
      h.api.conversations = [
        {
          'conversID': ChatTestHarness.convId,
          'isGroup': 0,
          'unreadCount': 0,
          'participants': [
            {'userID': ChatTestHarness.myId, 'username': 'me'},
            {'userID': ChatTestHarness.otherId, 'username': 'other'},
          ],
          'lastMessage': null,
          'lastMessageAt': avant.toIso8601String(),
          'myHistoryCutoffAt': cutoff.toIso8601String(),
        },
      ];

      await h.repo.syncConversations(force: true);
      await h.pumpEventQueue();

      expect(await h.messages(), isEmpty);
      final conv = await h.conv();
      expect(conv!.lastMessage, isNull);
      expect(conv.myHistoryCutoffAt!.toUtc(), cutoff);
    });

    test('une discussion effacée et muette n\'est pas re-téléchargée à chaque synchronisation', () async {
      await h.db.update(h.db.localConversations).write(LocalConversationsCompanion(
            lastMessageAt: Value(avant),
            myHistoryCutoffAt: Value(cutoff),
          ));
      h.api.conversations = const [];
      final avantAppels = h.api.httpLog.length;

      await h.repo.bootstrapEmptyConversationMessages();

      expect(h.api.httpLog.skip(avantAppels).where((l) => l.contains('getMessages') || l.contains('syncMessages')),
          isEmpty);
    });
  });

  group('rattrapage des suppressions pour tous', () {
    final t = DateTime.utc(2026, 10, 10, 9);

    test('premier appel : pas de curseur envoyé, la position du serveur est mémorisée, rien n\'est rejoué', () async {
      await h.receiveIncoming(msgID: 7, content: 'x', sendAt: t);
      h.api.deletionPages.add({'deletions': [], 'cursor': 42, 'hasMore': false});

      await h.repo.catchUpDeletions();

      expect(h.api.deletionAfterArgs, [null]);
      expect((await SharedPreferences.getInstance()).getInt('deletions_cursor_${ChatTestHarness.myId}'), 42);
      expect((await h.messages()).single.isDeleted, isFalse);
    });

    test('appel suivant : repart du curseur mémorisé et masque les messages supprimés', () async {
      await h.receiveIncoming(msgID: 7, content: 'x', sendAt: t);
      await h.receiveIncoming(msgID: 8, content: 'y', sendAt: t.add(const Duration(minutes: 1)));
      SharedPreferences.setMockInitialValues({'deletions_cursor_${ChatTestHarness.myId}': 42});
      h.api.deletionPages.add({
        'deletions': [
          {'msgID': 7, 'conversationID': ChatTestHarness.convId, 'deletedBy': 2},
        ],
        'cursor': 43,
        'hasMore': false,
      });

      await h.repo.catchUpDeletions();
      await h.pumpEventQueue();

      expect(h.api.deletionAfterArgs, [42]);
      final msgs = await h.messages();
      expect(msgs.firstWhere((m) => m.msgID == 7).isDeleted, isTrue);
      expect(msgs.firstWhere((m) => m.msgID == 8).isDeleted, isFalse);
      expect((await SharedPreferences.getInstance()).getInt('deletions_cursor_${ChatTestHarness.myId}'), 43);
    });

    test('plusieurs pages : toutes enchaînées, curseur avancé à chaque page', () async {
      for (final id in [11, 12, 13]) {
        await h.receiveIncoming(msgID: id, content: 'm$id', sendAt: t.add(Duration(minutes: id)));
      }
      SharedPreferences.setMockInitialValues({'deletions_cursor_${ChatTestHarness.myId}': 0});
      h.api.deletionPages
        ..add({'deletions': [{'msgID': 11, 'conversationID': 10}], 'cursor': 1, 'hasMore': true})
        ..add({'deletions': [{'msgID': 12, 'conversationID': 10}, {'msgID': 13, 'conversationID': 10}], 'cursor': 3, 'hasMore': false});

      await h.repo.catchUpDeletions();
      await h.pumpEventQueue();

      expect(h.api.deletionAfterArgs, [0, 1]);
      expect((await h.messages()).every((m) => m.isDeleted), isTrue);
    });

    test('erreur réseau : silencieuse, curseur inchangé', () async {
      SharedPreferences.setMockInitialValues({'deletions_cursor_${ChatTestHarness.myId}': 5});
      h.api.deletionsError = TalkyException('hors ligne', 0);

      await h.repo.catchUpDeletions();

      expect((await SharedPreferences.getInstance()).getInt('deletions_cursor_${ChatTestHarness.myId}'), 5);
    });

    test('la synchronisation de la liste déclenche le rattrapage', () async {
      h.api.conversations = const [];
      await h.repo.syncConversations(force: true);
      expect(h.api.httpLog.any((l) => l.startsWith('getDeletionsSince')), isTrue);
    });
  });
}
