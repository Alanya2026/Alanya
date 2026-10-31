// Fiche, plateau et listes face à un sticker animé (V1c) : mention « Animé »,
// image fixe partout sauf dans la bulle, vignette déduite du fichier.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/stickers/non_looping_animated_sticker.dart';
import 'package:talky_flutter/widgets/stickers/sticker_image.dart';
import 'package:talky_flutter/widgets/stickers/sticker_sheet.dart';
import 'package:talky_flutter/widgets/stickers/sticker_tray.dart';

import 'support/sticker_creation_fakes.dart';

class _NoNetwork extends Fake implements CacheManager {}

const _full = 'https://www.alanya237.com/uploads/stickers/u/7/anim_ff.webp';
const _thumb = 'https://www.alanya237.com/uploads/stickers/u/7/anim_ff_t.webp';

void testUi(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

void main() {
  group('stickerThumbUrlOf : même clé + _t.webp (contrat §8)', () {
    test('fichier perso et officiel', () {
      expect(stickerThumbUrlOf(_full), _thumb);
      expect(
        stickerThumbUrlOf(
            'https://www.alanya237.com/uploads/official/stickers/mboa/12_ab12cd34.webp'),
        'https://www.alanya237.com/uploads/official/stickers/mboa/12_ab12cd34_t.webp',
      );
    });

    test('une vignette se rend telle quelle, un autre format donne null', () {
      expect(stickerThumbUrlOf(_thumb), _thumb);
      expect(stickerThumbUrlOf('https://x.test/stickers/u/1/a.png'), isNull);
      expect(stickerThumbUrlOf('pas une url'), isNull);
      expect(stickerThumbUrlOf(''), isNull);
    });

    test('paramètres d\'URL conservés', () {
      expect(stickerThumbUrlOf('$_full?X-Amz=abc'), '$_thumb?X-Amz=abc');
    });
  });

  group('StickerImage.staticFrame', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StickerCache.shared =
          StickerCache(manager: _NoNetwork(), canPrefetch: () async => false);
    });
    tearDown(() => StickerCache.shared = null);

    Widget host(Widget w) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: w),
    );

    testWidgets('télécharge la vignette 96×96, jamais le fichier animé', (t) async {
      await t.pumpWidget(host(const StickerImage(
          url: _full, emoji: '😀', size: 60, staticFrame: true)));
      expect(t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
          _thumb);
    });

    testWidgets('la vignette du serveur prime sur la déduite', (t) async {
      const other = 'https://www.alanya237.com/uploads/stickers/u/7/autre_t.webp';
      await t.pumpWidget(host(const StickerImage(
          url: _full, thumbUrl: other, emoji: '😀', size: 60, staticFrame: true)));
      expect(t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
          other);
    });

    testWidgets('par défaut : le fichier complet, comme avant', (t) async {
      await t.pumpWidget(
          host(const StickerImage(url: _full, emoji: '😀', size: 60)));
      expect(t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
          _full);
    });

    testWidgets('hôte étranger : repli, rien n\'est téléchargé', (t) async {
      await t.pumpWidget(host(const StickerImage(
          url: 'https://evil.test/stickers/u/1/a.webp',
          emoji: '😀',
          size: 60,
          showRemovedLabel: false,
          staticFrame: true)));
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(StickerFallback), findsOneWidget);
    });
  });

  group('fiche et plateau', () {
    late AppDatabase db;
    late StickerRepository stickers;
    late StickerCreationRepository creation;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      StickerCache.shared =
          StickerCache(manager: _NoNetwork(), canPrefetch: () async => false);
      StickerPlayback.reset();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      stickers = StickerRepository(db: db, api: OfficialStickerApi());
      creation = StickerCreationRepository(db: db, api: FakeCreationApi());
    });
    tearDown(() async {
      StickerCache.shared = null;
      await db.close();
    });

    Widget app(Widget home, {String lang = 'fr', Brightness b = Brightness.light}) =>
        MultiProvider(
          providers: [
            Provider<StickerRepository>.value(value: stickers),
            Provider<StickerCreationRepository>.value(value: creation),
          ],
          child: MaterialApp(
            theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: home),
          ),
        );

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 80));
      }
    }

    StickerPayload payload({required bool animated}) => StickerPayload(
      version: 1,
      pack: 'u_7_ab12cd34',
      sid: 504,
      emoji: '😀',
      animated: animated,
    );

    for (final b in Brightness.values) {
      for (final (lang, mention) in [('fr', 'Animé'), ('en', 'Animated'), ('zh', '动态')]) {
        testUi('fiche d\'un sticker animé $lang / ${b.name} : mention + boucle',
            (t) async {
          t.view.physicalSize = const Size(800, 1800);
          t.view.devicePixelRatio = 1.0;
          addTearDown(t.view.reset);
          await t.pumpWidget(app(
            StickerSheet(payload: payload(animated: true), mediaUrl: _full),
            lang: lang,
            b: b,
          ));
          await settle(t);
          expect(find.byKey(const ValueKey('sticker-badge-animated')), findsOneWidget);
          expect(find.text(mention), findsOneWidget);
          final anim = t.widget<NonLoopingAnimatedSticker>(
              find.byType(NonLoopingAnimatedSticker));
          expect(anim.loop, isTrue, reason: 'la fiche tourne en boucle');
          expect(anim.interactive, isFalse);
          expect(anim.playKey, isNull);
          expect(t.takeException(), isNull);
        });
      }
    }

    testUi('fiche d\'un sticker fixe : ni mention, ni lecteur animé', (t) async {
      await t.pumpWidget(app(
          StickerSheet(payload: payload(animated: false), mediaUrl: _full)));
      await settle(t);
      expect(find.byKey(const ValueKey('sticker-badge-animated')), findsNothing);
      expect(find.byType(NonLoopingAnimatedSticker), findsNothing);
      expect(find.byType(StickerImage), findsOneWidget);
    });

    testUi('la ligne locale « animated » suffit (payload sans `a`)', (t) async {
      await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
          packId: const Value(900), code: 'u_7_ab12cd34', name: const Value('Pack')));
      await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
          stickerId: const Value(504),
          packId: 900,
          url: _full,
          animated: const Value(true)));
      await t.pumpWidget(app(
          StickerSheet(payload: payload(animated: false), mediaUrl: _full)));
      await settle(t);
      expect(find.byKey(const ValueKey('sticker-badge-animated')), findsOneWidget);
    });

    testUi('plateau : un sticker animé tourne en boucle, le tap envoie', (t) async {
      await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
          packId: const Value(900),
          code: 'u_7_ab12cd34',
          name: const Value('Pack'),
          installed: const Value(true)));
      await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
          stickerId: const Value(504),
          packId: 900,
          url: _full,
          animated: const Value(true)));
      await db.into(db.localStickers).insert(LocalStickersCompanion.insert(
          stickerId: const Value(505),
          packId: 900,
          url: 'https://www.alanya237.com/uploads/stickers/u/7/fixe_aa.webp',
          thumbUrl: const Value(
              'https://www.alanya237.com/uploads/stickers/u/7/fixe_aa_t.webp')));
      StickerEntry? sent;
      await t.pumpWidget(app(StickerTray(repo: stickers, onSend: (e) => sent = e)));
      await settle(t);
      await t.tap(find.bySemanticsLabel('Pack'));
      await settle(t);
      // L'animé passe par le lecteur en boucle (sans geste propre) ; le fixe
      // reste une image.
      final anim = t.widget<NonLoopingAnimatedSticker>(
          find.byType(NonLoopingAnimatedSticker));
      expect(anim.url, _full);
      expect(anim.loop, isTrue);
      expect(anim.interactive, isFalse);
      expect(sent, isNull);
      await t.tap(find.byType(NonLoopingAnimatedSticker));
      expect(sent?.sticker.stickerId, 504, reason: 'le tap reste l\'envoi');
    });
  });
}
