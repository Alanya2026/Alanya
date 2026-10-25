// Widgets stickers : repli « Sticker retiré », plateau Émojis · Stickers,
// verrou Plus — en clair et en sombre, en fr et en zh.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_api.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/stickers/sticker_image.dart';
import 'package:talky_flutter/widgets/stickers/sticker_tray.dart';

dynamic _fx(String n) =>
    jsonDecode(File('test/fixtures/stickers/$n').readAsStringSync());

/// Tout fichier est « retiré » : le serveur répond 404.
class _GoneManager extends Fake implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool withProgress = false}) =>
      Stream.error(HttpExceptionWithStatus(404, 'gone', uri: Uri.parse(url)));
}

class _Api implements StickerApi {
  _Api({this.closed = false});
  final bool closed;
  void _g() {
    if (closed) throw TalkyException('', 404);
  }

  @override
  Future<StickerHttpResult> getCatalog({String? etag, int? since}) async {
    _g();
    return StickerHttpResult(200, body: _fx('catalog.json'));
  }

  @override
  Future<StickerHttpResult> getMe() async {
    _g();
    final me = _fx('me.json') as Map;
    // `royal` (verrouillé) installé après expiration : visible, envoi bloqué.
    return StickerHttpResult(200, body: {
      ...me,
      'packs': [
        {'id': 1, 'code': 'alanya', 'position': 0},
        {'id': 6, 'code': 'royal', 'position': 1},
      ],
    });
  }

  @override
  Future<StickerHttpResult> getPack(String code) async {
    final pack = Map<String, dynamic>.from(_fx('pack.json') as Map);
    if (code == 'royal') {
      pack['id'] = 6;
      pack['code'] = 'royal';
      pack['stickers'] = [
        {
          'id': 71,
          'position': 0,
          'emoji': '👑',
          'url': 'https://www.alanya237.com/uploads/official/stickers/mboa/71.webp',
          'thumb': 'https://www.alanya237.com/uploads/official/stickers/mboa/71_t.webp',
          'w': 512,
          'h': 512,
          'animated': false,
        }
      ];
    }
    return StickerHttpResult(200, body: pack);
  }

  @override
  Future<void> installPack(int packId) async {}
  @override
  Future<void> removePack(int packId) async {}
  @override
  Future<void> reorderPacks(List<int> ids) async {}
  @override
  Future<void> addFavorite(int stickerId) async {}
  @override
  Future<void> removeFavorite(int stickerId) async {}
}

Widget _app(Widget child, {required Brightness b, String lang = 'fr', StickerRepository? repo}) {
  Widget body = Scaffold(body: child);
  if (repo != null) {
    body = Provider<StickerRepository>.value(value: repo, child: body);
  }
  return MaterialApp(
    theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: body,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StickerCache.shared = StickerCache(
        manager: _GoneManager(), canPrefetch: () async => false);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    StickerCache.shared = null;
    await db.close();
  });

  for (final b in Brightness.values) {
    testWidgets('fichier retiré (404) : « Sticker retiré » + emoji, jamais de JSON — ${b.name}',
        (t) async {
      await t.pumpWidget(_app(
          const StickerImage(url: 'https://www.alanya237.com/uploads/official/stickers/mboa/x.webp', emoji: '😂'),
          b: b));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Sticker retiré'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      expect(find.textContaining('{'), findsNothing);
    });
  }

  testWidgets('libellés zh et en', (t) async {
    await t.pumpWidget(_app(
        const StickerImage(url: 'https://www.alanya237.com/uploads/official/stickers/mboa/x.webp', emoji: '😂'),
        b: Brightness.light,
        lang: 'zh'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('贴纸已移除'), findsOneWidget);
    await t.pumpWidget(_app(
        const StickerImage(url: 'https://www.alanya237.com/uploads/official/stickers/mboa/x.webp', emoji: '😂'),
        b: Brightness.light,
        lang: 'en'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Sticker removed'), findsOneWidget);
  });

  testWidgets('version future : repli « non pris en charge »', (t) async {
    await t.pumpWidget(_app(
        const StickerFallback(emoji: '😂', label: 'Sticker non pris en charge'),
        b: Brightness.dark));
    expect(find.text('😂'), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
  });

  testWidgets('module fermé : plateau d\'émojis seul, sans onglet Stickers',
      (t) async {
    final repo = StickerRepository(db: db, api: _Api(closed: true));
    await t.pumpWidget(_app(
        EmojiStickerPicker(
          emojiPicker: const Text('EMOJIS'),
          onSendSticker: (_) {},
        ),
        b: Brightness.light,
        repo: repo));
    await t.runAsync(() => repo.refresh());
    await t.pump();
    expect(find.text('EMOJIS'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('plateau : onglets, envoi, pack verrouillé avec bandeau — clair et sombre',
      (t) async {
    for (final b in Brightness.values) {
      final repo = StickerRepository(db: db, api: _Api());
      await t.runAsync(() async {
        await repo.refresh();
        await repo.fetchPack('royal');
      });
      final sent = <StickerEntry>[];
      await t.pumpWidget(_app(
          EmojiStickerPicker(
            emojiPicker: const Text('EMOJIS'),
            onSendSticker: sent.add,
          ),
          b: b,
          repo: repo));
      await t.pump();
      expect(find.text('Émojis'), findsOneWidget);
      expect(find.text('Stickers'), findsOneWidget);
      // Le dernier onglet ouvert est mémorisé pour la session.
      await t.tap(find.text('Émojis'));
      await t.pump();
      expect(find.text('EMOJIS'), findsOneWidget);

      await t.tap(find.text('Stickers'));
      await t.pump();

      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('EMOJIS'), findsNothing);
      // Onglets : récents, favoris, alanya, royal (cadenas).
      expect(find.byIcon(Icons.lock), findsWidgets);

      // Onglet du pack Alanya (3e) puis envoi.
      final strip = find.byType(InkWell);
      expect(strip, findsWidgets);
      await t.tap(find.byIcon(Icons.star_border).first);
      await t.pump();
      expect(find.text('Touchez ★ dans la fiche d\'un sticker pour l\'ajouter à vos favoris.'),
          findsOneWidget);
      // Onglet royal : bandeau du verrou.
      final tabs = find.descendant(
          of: find.byType(ListView), matching: find.byType(InkWell));
      await t.tap(tabs.at(3));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Ce pack est réservé à Alanya Plus.'), findsOneWidget);
      expect(find.text('Découvrir Alanya Plus'), findsOneWidget);
      // Le sticker verrouillé est estompé mais remonte avec locked = true :
      // c'est l'écran de chat qui ouvre l'offre.
      await t.tap(find.byType(GridView).first, warnIfMissed: false);
      final grid = find.descendant(
          of: find.byType(GridView), matching: find.byType(InkWell));
      await t.tap(grid.first);
      expect(sent.single.locked, isTrue);
      expect(sent.single.sticker.stickerId, 71);

      // Onglet alanya : envoi normal.
      await t.tap(tabs.at(2));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.descendant(
              of: find.byType(GridView), matching: find.byType(InkWell))
          .first);
      expect(sent.last.locked, isFalse);
      expect(sent.last.payload.encode(), contains('"pack":"alanya"'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 10));
    }
  });

  testWidgets('accessibilité : vignettes et onglets sont des boutons nommés',
      (t) async {
    final handle = t.ensureSemantics();
    final repo = StickerRepository(db: db, api: _Api());
    await t.runAsync(() async {
      await repo.refresh();
      await repo.fetchPack('royal');
    });
    await t.pumpWidget(_app(
        EmojiStickerPicker(
          emojiPicker: const Text('EMOJIS'),
          onSendSticker: (_) {},
        ),
        b: Brightness.light,
        repo: repo));
    await t.pump();
    await t.tap(find.text('Stickers'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    // Un onglet de pack verrouillé s'annonce comme verrouillé.
    expect(find.bySemanticsLabel(RegExp('verrouillé', caseSensitive: false)),
        findsWidgets);

    // Onglet royal : sa vignette est un bouton, nommé et verrouillé.
    final tabs = find.descendant(
        of: find.byType(ListView), matching: find.byType(InkWell));
    await t.tap(tabs.at(3));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    final item = find
        .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
        .first;
    final node = t.getSemantics(item);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains('Sticker'));
    expect(node.label, contains('Verrouillé'));

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
    handle.dispose();
  });
}
