import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/media_cache_service.dart';
import 'package:talky_flutter/core/services/voice_asset_resolver.dart';
import 'package:talky_flutter/core/services/voice_message_coordinator.dart';
import 'package:talky_flutter/core/services/voice_waveform_store.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/core/services/chat_repository.dart';

class _FakeMediaCache extends MediaCacheService {
  final Map<String, String> files;

  _FakeMediaCache(this.files);

  @override
  Future<String?> cachedPathFor(String url) async => files[url];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceAssetResolver', () {
    late Directory tmp;
    late ChatDao dao;
    late AppDatabase db;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('voice_resolver_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = ChatDao(db);
    });

    tearDown(() async {
      await db.close();
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('dbPath valide retourne immédiatement', () async {
      final file = File(p.join(tmp.path, 'voice.m4a'))..writeAsStringSync('audio');
      final resolver = VoiceAssetResolver(
        mediaCache: MediaCacheService(),
        dao: dao,
      );

      final result = await resolver.resolve(
        serverMsgId: 10,
        isMe: false,
        dbPath: file.path,
      );

      expect(result?.path, file.path);
      expect(result?.source, VoiceLocalSource.dbPath);
    });

    test('cache hit sans DB adopte le chemin', () async {
      final cached = File(p.join(tmp.path, 'cached.m4a'))..writeAsStringSync('x');
      const url = 'https://example.com/voice.m4a';
      final resolver = VoiceAssetResolver(
        mediaCache: _FakeMediaCache({url: cached.path}),
        dao: dao,
      );

      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
            clientId: 'srv_42',
            msgID: const Value(42),
            conversationID: 1,
            senderID: 2,
            type: const Value(3),
            mediaUrl: const Value(url),
            sendAt: DateTime.now().toUtc(),
            syncPending: const Value(false),
          ));

      final result = await resolver.resolve(
        serverMsgId: 42,
        isMe: false,
        mediaUrl: url,
      );

      expect(result?.path, cached.path);
      expect(result?.source, VoiceLocalSource.mediaCache);

      final row = await (db.select(db.localMessages)
            ..where((m) => m.msgID.equals(42)))
          .getSingle();
      expect(row.localMediaPath, cached.path);
    });

    test('dbPath mort est nettoyé', () async {
      await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
            clientId: 'srv_7',
            msgID: const Value(7),
            conversationID: 1,
            senderID: 2,
            type: const Value(3),
            localMediaPath: const Value('/missing/file.m4a'),
            sendAt: DateTime.now().toUtc(),
            syncPending: const Value(false),
          ));

      final resolver = VoiceAssetResolver(
        mediaCache: MediaCacheService(),
        dao: dao,
      );

      final result = await resolver.resolve(
        serverMsgId: 7,
        isMe: false,
        dbPath: '/missing/file.m4a',
      );

      expect(result, isNull);
      final row = await (db.select(db.localMessages)
            ..where((m) => m.msgID.equals(7)))
          .getSingle();
      expect(row.localMediaPath, isNull);
    });
  });

  group('VoiceWaveformStore', () {
    test('fallback déterministe produit 56 barres', () {
      final a = VoiceWaveformStore.generateDeterministicFallback('/a.m4a', 12);
      final b = VoiceWaveformStore.generateDeterministicFallback('/a.m4a', 12);
      final c = VoiceWaveformStore.generateDeterministicFallback('/b.m4a', 12);

      expect(a.length, VoiceWaveformStore.defaultSampleCount);
      expect(b, equals(a));
      expect(c, isNot(equals(a)));
      expect(a.every((v) => v > 0), isTrue);
    });

    test('loadOrGenerate utilise le cache mémoire au second appel', () async {
      final tmp = await Directory.systemTemp.createTemp('waveform_store_');
      final file = File(p.join(tmp.path, 'voice.m4a'))..writeAsStringSync('x');
      final store = VoiceWaveformStore();

      final first = await store.loadOrGenerate(
        localPath: file.path,
        durationSeconds: 5,
      );
      final second = await store.loadOrGenerate(
        localPath: file.path,
        durationSeconds: 5,
      );

      expect(first, isNotEmpty);
      expect(second, equals(first));

      await tmp.delete(recursive: true);
    });
  });

  group('VoiceMessageCoordinator', () {
    late Directory tmp;
    late AppDatabase db;
    late ChatRepository repo;
    late VoiceMessageCoordinator coordinator;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('voice_coord_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ChatRepository(
        api: TalkyApiClient(),
        database: db,
      );
      coordinator = VoiceMessageCoordinator(repository: repo);
    });

    tearDown(() async {
      await db.close();
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('fichier local → ready sans download', () async {
      final file = File(p.join(tmp.path, 'mine.m4a'))..writeAsStringSync('audio');
      final ref = VoiceMessageRef(
        clientId: 'srv_1',
        serverMsgId: 1,
        isMe: true,
        pendingPath: file.path,
        durationSeconds: 8,
      );

      final snap = await coordinator.ensureReady(ref);

      expect(snap.phase, VoiceUiPhase.ready);
      expect(snap.localPath, file.path);
      expect(snap.waveform, isNotNull);
      expect(snap.waveform!.length, VoiceWaveformStore.defaultSampleCount);
    });

    test('sans fichier local → needsDownload', () async {
      final ref = VoiceMessageRef(
        clientId: 'srv_2',
        serverMsgId: 2,
        isMe: false,
        durationSeconds: 4,
      );

      final snap = await coordinator.ensureReady(ref);

      expect(snap.phase, VoiceUiPhase.needsDownload);
      expect(snap.localPath, isNull);
    });
  });
}
