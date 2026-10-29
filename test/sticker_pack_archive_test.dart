// Pack officiel ARCHIVÉ = « indisponible » (contrat §4, A14) : il disparaît des
// tables locales, du plateau et de « Mes packs » après chaque synchro, l'envoi
// et le transfert refusés sont dits, la fiche masque ses actions, et les anciens
// messages continuent de s'afficher. Drift en mémoire, fixtures du contrat.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/navigation/app_navigator.dart';
import 'package:talky_flutter/core/services/chat/socket_message_handlers.dart';
import 'package:talky_flutter/core/services/stickers/sticker_api.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';
import 'package:talky_flutter/widgets/stickers/sticker_image.dart';
import 'package:talky_flutter/widgets/stickers/sticker_sheet.dart';
import 'package:talky_flutter/widgets/stickers/sticker_tray.dart';

import 'fakes/chat_test_harness.dart';
import 'support/sticker_creation_fakes.dart' show FakeCreationApi;

Map<String, dynamic> _fx(String n) => Map<String, dynamic>.from(
    jsonDecode(File('test/fixtures/stickers/$n').readAsStringSync()) as Map);

const _urlMboa = 'https://www.alanya237.com/uploads/official/stickers/mboa/45_cd34ef56.webp';

/// Serveur simulé : on y « archive » le pack `mboa` comme le ferait l'admin.
class _Api implements StickerApi {
  Map<String, dynamic> catalog = _fx('catalog-avant-archivage.json');
  Map<String, dynamic> me = _fx('me.json');
  final Map<String, Map<String, dynamic>> packs = {
    'alanya': _fx('pack.json'),
    'mboa': _fx('pack-mboa.json'),
  };

  /// Codes dont `GET /packs/:code` et `PUT /me/packs/:id` répondent 404.
  final unavailable = <String>{};
  final calls = <String>[];
  String? lastEtag;

  void archiveMboa() {
    catalog = _fx('catalog-apres-archivage.json');
    me = _fx('me-apres-archivage.json');
    unavailable.add('mboa');
  }

  void republishMboa() {
    catalog = _fx('catalog-avant-archivage.json');
    me = _fx('me.json');
    unavailable.remove('mboa');
  }

  @override
  Future<StickerHttpResult> getCatalog({String? etag, int? since}) async {
    calls.add('catalog');
    lastEtag = etag;
    return StickerHttpResult(200, etag: '"v${catalog['version']}"', body: catalog);
  }

  @override
  Future<StickerHttpResult> getMe() async {
    calls.add('me');
    return StickerHttpResult(200, body: me);
  }

  @override
  Future<StickerHttpResult> getPack(String code) async {
    calls.add('pack:$code');
    if (unavailable.contains(code) || !packs.containsKey(code)) {
      throw TalkyException('indisponible', 404, code: 'STICKER_PACK_UNAVAILABLE');
    }
    return StickerHttpResult(200, body: packs[code]);
  }

  @override
  Future<void> installPack(int id) async {
    calls.add('install:$id');
    if (id == 3 && unavailable.contains('mboa')) {
      throw TalkyException('indisponible', 404, code: 'STICKER_PACK_UNAVAILABLE');
    }
  }

  @override
  Future<void> removePack(int id) async => calls.add('remove:$id');
  @override
  Future<void> reorderPacks(List<int> ids) async => calls.add('order:$ids');
  @override
  Future<void> addFavorite(int id) async => calls.add('fav+$id');
  @override
  Future<void> removeFavorite(int id) async => calls.add('fav-$id');
}

/// Cache disque qui ne répond jamais : ni image ni 404 (rien ne change l'état).
class _Pending extends Fake implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool withProgress = false}) =>
      const Stream<FileResponse>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late _Api api;
  late StickerRepository repo;
  var clock = DateTime.utc(2026, 1, 1);

  // Plusieurs bases mémoire coexistent (la mienne et celle du harnais de chat).
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController();
    StickerCache.shared =
        StickerCache(manager: _Pending(), canPrefetch: () async => false);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _Api();
    repo = StickerRepository(
        db: db,
        api: api,
        now: () => clock = clock.add(const Duration(seconds: 1)));
  });
  tearDown(() async {
    StickerCache.shared = null;
    await db.close();
  });

  Future<List<String>> codes(Stream<List<LocalStickerPack>> s) async =>
      [for (final p in await s.first) p.code];

  /// État « avant » : alanya + mboa installés, leurs stickers chargés, 3
  /// favoris (1, 45, 46), des récents, et un message mboa déjà reçu.
  Future<void> seed() async {
    await repo.refresh();
    await repo.markUsed(1);
    await repo.markUsed(45);
    await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: 'c_mboa',
          conversationID: 10,
          senderID: 2,
          sendAt: DateTime.utc(2026, 1, 1),
          type: const Value(kStickerMessageType),
          status: const Value(1),
          content: const Value(
              '{"v":1,"pack":"mboa","sid":45,"emoji":"😂","w":512,"h":512,"a":0}'),
          mediaUrl: const Value(_urlMboa),
          mediaName: const Value('Sticker 😂'),
        ));
  }

  Future<void> expectMessageIntact() async {
    final m = await (db.select(db.localMessages)
          ..where((t) => t.clientId.equals('c_mboa')))
        .getSingle();
    expect(m.mediaUrl, _urlMboa);
    expect(m.status, 1);
    expect(StickerPayload.tryParse(m.content)?.pack, 'mboa');
  }

  group('synchro : le pack archivé quitte Drift et le plateau', () {
    test('état de départ : mboa installé, stickers, favoris, récents', () async {
      await seed();
      expect(await codes(repo.watchTray()), ['alanya', 'mboa']);
      expect((await repo.watchStickers(3).first).map((s) => s.stickerId), [45, 46]);
      expect(await repo.watchFavoriteIds().first, {1, 45, 46});
      expect((await repo.watchRecents().first).map((e) => e.sticker.stickerId),
          containsAll([1, 45]));
    });

    test('refresh (catalogue + /me sans le pack) : plus nulle part', () async {
      await seed();
      api.archiveMboa();
      await repo.refresh();

      expect(await codes(repo.watchTray()), ['alanya']);
      expect(await codes(repo.watchInstalled()), ['alanya']);
      expect(await codes(repo.watchCatalog()), ['alanya', 'royal']);
      expect(await repo.packByCode('mboa'), isNull);
      // Stickers, favoris et récents du pack : retirés ; ceux d'alanya : intacts.
      expect(await db.select(db.localStickers).get().then((r) => r.map((s) => s.stickerId)),
          [1]);
      expect(await repo.watchFavoriteIds().first, {1});
      expect((await db.select(db.localStickerFavorites).get()).map((f) => f.stickerId),
          [1]);
      expect((await repo.watchRecents().first).map((e) => e.sticker.stickerId), [1]);
      expect((await db.select(db.localStickerRecents).get()).map((r) => r.stickerId),
          [1]);
      expect(await repo.isPackUnavailable('mboa'), isTrue);
      expect(await repo.isPackUnavailable('alanya'), isFalse);
      // L'historique n'est pas touché : la bulle garde son image.
      await expectMessageIntact();
    });

    test('catalogue seul sans le pack (installé) : le pack est retiré quand même',
        () async {
      await seed();
      api.catalog = _fx('catalog-apres-archivage.json');
      await repo.syncCatalog();
      expect(await repo.packByCode('mboa'), isNull);
      expect(await codes(repo.watchTray()), ['alanya']);
      expect(await repo.isPackUnavailable('mboa'), isTrue);
    });

    test('/me seul sans le pack (catalogue en retard) : désinstallé, pas purgé',
        () async {
      await seed();
      api.me = _fx('me-apres-archivage.json');
      await repo.syncMe();
      expect(await codes(repo.watchTray()), ['alanya']);
      expect(await repo.watchFavoriteIds().first, {1});
      // Le catalogue local le connaît encore tant qu'il n'est pas relu.
      expect(await codes(repo.watchCatalog()), contains('mboa'));
      api.catalog = _fx('catalog-apres-archivage.json');
      await repo.syncCatalog();
      expect(await codes(repo.watchCatalog()), ['alanya', 'royal']);
    });

    test('« Mes packs » : syncInstalledPacks ne redemande pas un pack disparu',
        () async {
      await seed();
      api.archiveMboa();
      await repo.syncCatalog();
      await repo.syncMe();
      api.calls.clear();
      await repo.syncInstalledPacks();
      expect(api.calls, isNot(contains('pack:mboa')));
    });

    test('pack lu en 404 STICKER_PACK_UNAVAILABLE : retiré sans erreur', () async {
      await seed();
      // Le catalogue et /me sont en retard sur l'archivage : seul le pack répond.
      api.unavailable.add('mboa');
      await repo.syncInstalledPacks(force: true);
      expect(await repo.packByCode('mboa'), isNull);
      expect(await codes(repo.watchTray()), ['alanya']);
      expect(await repo.watchFavoriteIds().first, {1});
      expect(await repo.isPackUnavailable('mboa'), isTrue);
      await expectMessageIntact();
    });

    test('installer un pack archivé : 404 remonté, pack retiré du catalogue',
        () async {
      await seed();
      await repo.removePack(3);
      api.unavailable.add('mboa');
      final mboa = (await repo.packByCode('mboa'))!;
      await expectLater(
          repo.installPack(mboa),
          throwsA(isA<TalkyException>()
              .having((e) => e.code, 'code', 'STICKER_PACK_UNAVAILABLE')));
      expect(await repo.packByCode('mboa'), isNull);
      expect(await codes(repo.watchCatalog()), ['alanya', 'royal']);
    });

    test('pack republié : il revient tel quel et n\'est plus « indisponible »',
        () async {
      await seed();
      api.archiveMboa();
      await repo.refresh();
      expect(await repo.isPackUnavailable('mboa'), isTrue);
      api.republishMboa();
      await repo.refresh();
      expect(await codes(repo.watchTray()), ['alanya', 'mboa']);
      expect((await repo.watchStickers(3).first), hasLength(2));
      expect(await repo.isPackUnavailable('mboa'), isFalse);
    });

    test('un pack à moi (V1b) n\'est jamais retiré par la synchro du catalogue',
        () async {
      await seed();
      await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
          packId: const Value(900),
          code: 'u_7_aaaa',
          name: const Value('Mes stickers'),
          owned: const Value(true)));
      await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
          stickerId: const Value(5000), packId: 900, url: 'https://x/y.webp'));
      api.archiveMboa();
      await repo.refresh();
      expect(await repo.packByCode('u_7_aaaa'), isNotNull);
      expect(await repo.watchStickers(900).first, hasLength(1));
      expect(await codes(repo.watchTray()), ['alanya', 'u_7_aaaa']);
    });

    test('catalogue illisible : rien n\'est retiré', () async {
      await seed();
      api.catalog = {
        'version': 9,
        'packs': [
          {'id': 'x'}
        ]
      };
      await repo.syncCatalog();
      expect(await codes(repo.watchTray()), ['alanya', 'mboa']);
    });

    test('catalogue vide (tout archivé) : les packs officiels quittent le plateau',
        () async {
      await seed();
      api.catalog = {'version': 9, 'packs': []};
      api.me = {'version': 14, 'packs': [], 'favorites': []};
      await repo.refresh();
      expect(await repo.watchTray().first, isEmpty);
      expect(await db.select(db.localStickers).get(), isEmpty);
    });
  });

  group('stickers:sync « catalog »', () {
    test('relit le catalogue SANS ETag, /me et les packs, puis retire le pack',
        () async {
      await seed();
      api.archiveMboa();
      api.calls.clear();
      await repo.onSyncEvent({'reason': 'catalog', 'version': 4});
      expect(api.calls.take(2), ['catalog', 'me']);
      expect(api.lastEtag, isNull, reason: 'un ETag périmé ne doit pas masquer l\'archivage');
      expect(await repo.packByCode('mboa'), isNull);
      expect(await codes(repo.watchTray()), ['alanya']);
    });

    test('les autres raisons ne relisent pas le catalogue', () async {
      await seed();
      api.calls.clear();
      await repo.onSyncEvent({'reason': 'favorites', 'version': 14});
      expect(api.calls, ['me']);
    });
  });

  group('plateau : le pack archivé disparaît sans erreur', () {
    Widget app(Widget child) => Provider<StickerRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: child),
          ),
        );

    testWidgets('onglet du pack retiré en cours d\'affichage', (t) async {
      await t.runAsync(seed);
      await t.pumpWidget(app(StickerTray(repo: repo, onSend: (_) {})));
      await t.pump(const Duration(milliseconds: 100));
      final tabs = find.descendant(
          of: find.byType(ListView), matching: find.byType(InkWell));
      // récents, favoris, alanya, mboa.
      expect(tabs, findsNWidgets(4));
      // On se place sur l'onglet du pack qui va disparaître.
      await t.tap(tabs.at(3));
      await t.pump(const Duration(milliseconds: 100));

      api.archiveMboa();
      // La synchro tourne pendant que le plateau écoute Drift : on alterne
      // temps réel (SQLite) et horloge du test.
      final sync = repo.onSyncEvent({'reason': 'catalog', 'version': 4});
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await sync;

      expect(t.takeException(), isNull);
      expect(find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)),
          findsNWidgets(3));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 10));
    });
  });

  group('bulle : le fichier d\'un pack archivé s\'affiche toujours', () {
    testWidgets('pack archivé, image non retirée : jamais « Sticker retiré »', (t) async {
      await t.runAsync(seed);
      api.archiveMboa();
      await t.runAsync(repo.refresh);
      expect(await repo.packByCode('mboa'), isNull);
      // Même `mediaUrl` recopiée dans le message : StickerImage la demande au
      // cache (le fichier est conservé, A13), sans consulter les tables.
      await t.pumpWidget(const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: StickerImage(url: _urlMboa, emoji: '😂')),
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Sticker retiré'), findsNothing);
      expect(find.byType(StickerFallback), findsNothing);
      expect(find.text('😂'), findsOneWidget, reason: 'emoji de chargement');
    });

    test('« retiré » seulement sur 404/410 du fichier', () {
      expect(isStickerGone(HttpExceptionWithStatus(404, 'x', uri: Uri.parse('https://x'))),
          isTrue);
      expect(isStickerGone(HttpExceptionWithStatus(410, 'x', uri: Uri.parse('https://x'))),
          isTrue);
      expect(isStickerGone(HttpExceptionWithStatus(500, 'x', uri: Uri.parse('https://x'))),
          isFalse);
      expect(isStickerGone(Exception('hors ligne')), isFalse);
    });
  });

  group('fiche d\'un sticker de pack archivé', () {
    late FakeCreationApi creationApi;
    late StickerCreationRepository creation;

    setUp(() {
      creationApi = FakeCreationApi();
      creation = StickerCreationRepository(db: db, api: creationApi);
    });

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 8; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 80));
      }
    }

    Future<void> openSheet(WidgetTester t, String pack, int sid,
        {VoidCallback? onForward}) async {
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(MultiProvider(
        providers: [
          Provider<StickerRepository>.value(value: repo),
          Provider<StickerCreationRepository>.value(value: creation),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: StickerSheet(
              payload: StickerPayload(
                  version: 1,
                  pack: pack,
                  sid: sid,
                  emoji: '😂',
                  w: 512,
                  h: 512,
                  animated: false),
              mediaUrl: _urlMboa,
              senderName: 'Ami',
              onForward: onForward,
            ),
          ),
        ),
      ));
      await settle(t);
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 10));
    }

    testWidgets('pack archivé : ni « Ajouter à un pack », ni « Signaler », ni « Voir le pack »',
        (t) async {
      await t.runAsync(seed);
      api.archiveMboa();
      await t.runAsync(repo.refresh);
      var forwarded = false;
      await openSheet(t, 'mboa', 45, onForward: () => forwarded = true);
      expect(find.text('Ajouter à un pack'), findsNothing);
      expect(find.text('Signaler'), findsNothing);
      expect(find.text('Voir le pack'), findsNothing);
      expect(find.text('Ajouter aux favoris'), findsNothing);
      // L'image reste affichée ; le transfert reste proposé (le serveur tranche).
      expect(find.byType(StickerImage), findsOneWidget);
      expect(find.text('Transférer'), findsOneWidget);
      expect(forwarded, isFalse);
      await close(t);
    });

    testWidgets('pack disponible : « Voir le pack » et les actions sont là', (t) async {
      await t.runAsync(seed);
      await openSheet(t, 'alanya', 1);
      expect(find.text('Voir le pack'), findsOneWidget);
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
      await close(t);
    });

    testWidgets('pack inconnu non marqué (sticker perso d\'un contact) : copie et signalement '
        'restent, « Voir le pack » est masqué', (t) async {
      await t.runAsync(seed);
      await openSheet(t, 'u_12_aaaa', 701);
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
      expect(find.text('Voir le pack'), findsNothing);
      await close(t);
    });

    testWidgets('404 uniforme à la copie : « Ce sticker n\'existe plus. », sans planter',
        (t) async {
      await t.runAsync(seed);
      await openSheet(t, 'u_12_aaaa', 701);
      creationApi.failNext =
          TalkyException('nope', 404, code: 'STICKER_NOT_FOUND');
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      await t.tap(find.text('Famille'));
      await settle(t);
      // En debug le présentateur ajoute un suffixe de diagnostic au texte.
      expect(find.textContaining("Ce sticker n'existe plus."), findsOneWidget);
      expect(t.takeException(), isNull);
      await close(t);
    });
  });

  group('envoi et transfert refusés : STICKER_PACK_UNAVAILABLE', () {
    late ChatTestHarness h;
    late StickerRepository chatStickers;

    setUp(() async {
      h = ChatTestHarness();
      await h.setUp(autoAckSend: false);
      // Dépôt de stickers branché sur la base du harnais (le gestionnaire du
      // socket le retrouve par `maybeInstance`, comme dans l'application).
      chatStickers = StickerRepository(db: h.db, api: api);
      await chatStickers.refresh();
    });
    tearDown(() async => h.tearDown());

    Future<LocalMessage> sendMboa({bool forwarded = false}) async {
      await h.repo.sendSticker(
        conversationID: ChatTestHarness.convId,
        sticker: StickerPayload(
            version: 1,
            pack: 'mboa',
            sid: 45,
            emoji: '😂',
            w: 512,
            h: 512,
            animated: false),
        mediaUrl: _urlMboa,
        isForwarded: forwarded,
      );
      await h.pumpEventQueue();
      return (await h.messages())
          .singleWhere((m) => m.senderID == ChatTestHarness.myId);
    }

    test('code terminal : bulle en échec définitif, jamais rejouée', () {
      expect(kTerminalSendFailures, contains('STICKER_PACK_UNAVAILABLE'));
      expect(kStickerSendRefusals, contains('STICKER_PACK_UNAVAILABLE'));
    });

    test('socket message:send_failed : bulle en échec, pack retiré du plateau', () async {
      final m = await sendMboa();
      expect(await codes(chatStickers.watchTray()), ['alanya', 'mboa']);
      h.api.emit('message:send_failed',
          {'clientId': m.clientId, 'code': 'STICKER_PACK_UNAVAILABLE'});
      await h.pumpEventQueue();

      final after = (await h.messages())
          .singleWhere((x) => x.clientId == m.clientId);
      expect(after.status, 4);
      expect(after.failureCode, 'STICKER_PACK_UNAVAILABLE');
      expect(after.mediaUrl, _urlMboa, reason: 'le message garde son image');
      expect(await codes(chatStickers.watchTray()), ['alanya']);
      expect(await chatStickers.isPackUnavailable('mboa'), isTrue);

      final before = h.api.eventsNamed(SocketEvents.messageSend).length;
      for (var i = 0; i < 3; i++) {
        await h.repo.flushOutbox();
        await h.pumpEventQueue();
      }
      expect(h.api.eventsNamed(SocketEvents.messageSend).length, before,
          reason: 'un refus définitif n\'est jamais réémis');
    });

    test('transfert d\'un sticker archivé : même refus, sans plantage', () async {
      final m = await sendMboa(forwarded: true);
      h.api.emit('message:send_failed',
          {'clientId': m.clientId, 'code': 'STICKER_PACK_UNAVAILABLE'});
      await h.pumpEventQueue();
      final after = (await h.messages())
          .singleWhere((x) => x.clientId == m.clientId);
      expect(after.isForwarded, isTrue);
      expect(after.failureCode, 'STICKER_PACK_UNAVAILABLE');
      expect(await chatStickers.packByCode('mboa'), isNull);
    });

    test('un refus sur un message texte ne touche pas au plateau', () async {
      await h.repo.sendText(
          conversationID: ChatTestHarness.convId, content: 'salut');
      await h.pumpEventQueue();
      final m = (await h.messages())
          .singleWhere((x) => x.senderID == ChatTestHarness.myId);
      h.api.emit('message:send_failed',
          {'clientId': m.clientId, 'code': 'STICKER_PACK_UNAVAILABLE'});
      await h.pumpEventQueue();
      expect(await codes(chatStickers.watchTray()), ['alanya', 'mboa']);
    });

    testWidgets('le refus est dit : « Ce pack n\'est plus disponible. »', (t) async {
      await t.runAsync(() async {
        await h.tearDown();
        h = ChatTestHarness();
        await h.setUp(autoAckSend: false);
        chatStickers = StickerRepository(db: h.db, api: api);
        await chatStickers.refresh();
      });
      await t.pumpWidget(MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ));
      late LocalMessage m;
      await t.runAsync(() async {
        m = await sendMboa();
        h.api.emit('message:send_failed',
            {'clientId': m.clientId, 'code': 'STICKER_PACK_UNAVAILABLE'});
        await h.pumpEventQueue();
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(
          find.textContaining(
              LocaleController.instance.l10n.errCodeStickerPackUnavailable),
          findsOneWidget);
      expect(LocaleController.instance.l10n.errCodeStickerPackUnavailable,
          isNotEmpty);
      appMessengerKey.currentState?.clearSnackBars();
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        await h.tearDown();
        // tearDown du groupe : harnais déjà fermé, on en remet un neutre.
        h = ChatTestHarness();
        await h.setUp(autoAckSend: false);
      });
    });
  });
}
