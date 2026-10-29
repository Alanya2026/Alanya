// Bouton « Créer » du plateau Stickers : tuile première des Récents (même sans
// récent), sélecteur de la galerie injecté, parcours animé si les animés sont
// ouverts, tuile masquée si la création est fermée, `POST /assets` sans pack,
// récents mis à jour + message « Ajouté à … » avec « Voir », avis de
// confidentialité une seule fois, erreurs — en clair et en sombre, fr/en/zh.
import 'dart:io';
import 'dart:typed_data';

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
import 'package:talky_flutter/core/services/stickers/sticker_features.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/chat/expandable_panel.dart';
import 'package:talky_flutter/widgets/stickers/non_looping_animated_sticker.dart';
import 'package:talky_flutter/widgets/stickers/sticker_creation_flows.dart'
    show kStickerPrivacyAckKey;
import 'package:talky_flutter/widgets/stickers/sticker_quick_create.dart';
import 'package:talky_flutter/widgets/stickers/sticker_tray.dart';

import 'support/sticker_creation_fakes.dart';

class _NoNetwork extends Fake implements CacheManager {}

final Uint8List _anime =
    File('test/fixtures/stickers/images/anime-5x50ms.webp').readAsBytesSync();

typedef _Picked = ({Uint8List bytes, String name});

void testUi(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

void main() {
  late AppDatabase db;
  late FakeCreationApi api;
  late StickerFeatures features;
  late StickerRepository stickers;
  late StickerCreationRepository creation;
  var picked = 0;
  var adapted = 0;
  var animatedCalls = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({kStickerPrivacyAckKey: true});
    StickerCache.shared = StickerCache(
      manager: _NoNetwork(),
      canPrefetch: () async => false,
    );
    StickerPlayback.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeCreationApi();
    features = StickerFeatures();
    stickers = StickerRepository(
      db: db,
      api: OfficialStickerApi(),
      features: features,
    );
    creation = StickerCreationRepository(db: db, api: api, features: features);
    picked = 0;
    adapted = 0;
    animatedCalls = 0;
  });
  tearDown(() async {
    StickerCache.shared = null;
    await db.close();
  });

  StickerCreateHooks hooks({
    Future<_Picked?> Function()? pick,
    bool animatedFlowReturns = true,
  }) => StickerCreateHooks(
    pickImage: () async {
      picked++;
      return pick == null ? (bytes: png512(), name: 'photo.png') : pick();
    },
    adaptImage: (b) async {
      adapted++;
      return png512();
    },
    animatedFlow: (context, bytes, filename) async {
      animatedCalls++;
      if (!animatedFlowReturns) return null;
      final res = await creation.addAnimatedSticker(
        null,
        bytes,
        filename: filename,
        shape: StickerAnimatedShape.carre,
      );
      return res;
    },
  );

  Widget app({
    Brightness b = Brightness.light,
    String lang = 'fr',
    StickerCreateHooks? h,
  }) => MultiProvider(
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
      home: Scaffold(
        body: SizedBox(
          height: 360,
          child: StickerTray(
            repo: stickers,
            onSend: (_) {},
            createHooks: h ?? hooks(),
          ),
        ),
      ),
    ),
  );

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> open(
    WidgetTester t, {
    Brightness b = Brightness.light,
    String lang = 'fr',
    StickerCreateHooks? h,
  }) async {
    await t.runAsync(() => creation.syncCreated());
    await t.pumpWidget(app(b: b, lang: lang, h: h));
    await settle(t);
  }

  final tile = find.byKey(const ValueKey('sticker-create-tile'));

  group('tuile « Créer » dans les Récents', () {
    testUi('première case même sans aucun récent, avec un texte d\'aide', (
      t,
    ) async {
      await open(t);
      expect(tile, findsOneWidget);
      expect(find.text('Créer'), findsOneWidget);
      final hint = find.byKey(const ValueKey('sticker-create-hint'));
      expect(hint, findsOneWidget);
      expect(
        find.text('Créez un sticker à partir d\'une photo de votre galerie.'),
        findsOneWidget,
      );
      // Le texte d'aide est SOUS la tuile.
      expect(
        t.getTopLeft(hint).dy,
        greaterThanOrEqualTo(t.getBottomLeft(tile).dy),
      );
      // Même taille qu'une cellule de la grille, cible tactile ≥ 48 dp.
      final size = t.getSize(tile);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testUi('toujours première, avant les stickers récents', (t) async {
      await t.runAsync(() async {
        await creation.syncCreated();
        await stickers.syncMe();
        await stickers.fetchPack('alanya');
      });
      final ids = await t.runAsync(
        () => (db.select(db.localStickers)).get().then(
          (l) => l.map((s) => s.stickerId).toList(),
        ),
      );
      expect(ids, isNotEmpty);
      await t.runAsync(() => stickers.markUsed(ids!.first));
      await t.pumpWidget(app());
      await settle(t);
      expect(tile, findsOneWidget);
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      expect(cells, findsWidgets);
      // Tuile en première position (haut-gauche) ; le récent vient après.
      expect(t.getTopLeft(cells.first), t.getTopLeft(tile));
      expect(cells.evaluate().length, greaterThanOrEqualTo(2));
      expect(find.byKey(const ValueKey('sticker-create-hint')), findsNothing);
    });

    testUi('masquée quand la création est fermée côté serveur', (t) async {
      api.closed = true;
      await open(t);
      expect(tile, findsNothing);
      expect(find.text('Créer'), findsNothing);
      expect(creation.creationAvailable.value, isFalse);
    });

    testUi('ni dans Favoris ni dans l\'onglet d\'un pack', (t) async {
      await open(t);
      await t.tap(find.byIcon(Icons.star_border).first);
      await settle(t);
      expect(tile, findsNothing);
    });
  });

  group('création depuis la tuile', () {
    testUi(
      'tap : le sélecteur injecté est appelé, aperçu, Ajouter → POST /assets sans pack',
      (t) async {
        await open(t);
        await t.tap(tile);
        await settle(t);
        expect(picked, 1);
        expect(adapted, 1);
        // Aperçu : Annuler / Modifier / Ajouter.
        expect(find.text('Annuler'), findsOneWidget);
        expect(find.text('Modifier'), findsOneWidget);
        expect(find.text('Ajouter'), findsOneWidget);
        await t.tap(find.text('Ajouter'));
        await settle(t);
        // Aucun packId : le serveur choisit le pack perso par défaut.
        expect(
          api.calls.where((c) => c.startsWith('upload:')),
          ['upload:null:photo.png:${png512().length}'],
        );
        // Aucun écran de pack à traverser, aucun écran de création de pack.
        expect(api.calls, isNot(contains('create')));
      },
    );

    testUi(
      'après l\'ajout : snackbar « Ajouté à Mes stickers » + Voir, sticker en tête des Récents',
      (t) async {
        await open(t);
        await t.tap(tile);
        await settle(t);
        await t.tap(find.text('Ajouter'));
        await settle(t);
        expect(find.text('Ajouté à Mes stickers'), findsOneWidget);
        expect(find.text('Voir'), findsOneWidget);
        // Récents locaux (Drift) : le nouveau sticker est en tête.
        final recents = await t.runAsync(() => stickers.watchRecents().first);
        expect(recents!.first.sticker.stickerId, 503);
        // Il s'affiche tout de suite, derrière la tuile.
        final cells = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(InkWell),
        );
        expect(cells.evaluate().length, 2);
        expect(find.byKey(const ValueKey('sticker-create-hint')), findsNothing);
        // « Voir » ouvre l'onglet du pack « Mes stickers ».
        await t.tap(find.text('Voir'));
        await settle(t);
        expect(tile, findsNothing);
        // Onglet du pack : ses 3 stickers (501, 502 + le nouveau 503).
        expect(
          find
              .descendant(
                of: find.byType(GridView),
                matching: find.byType(InkWell),
              )
              .evaluate()
              .length,
          3,
        );
      },
    );

    testUi('image déjà possédée (réutilisée) : message dédié', (t) async {
      api.uploadReused = true;
      await open(t);
      await t.tap(tile);
      await settle(t);
      await t.tap(find.text('Ajouter'));
      await settle(t);
      expect(find.text('Cette image est déjà dans vos stickers.'),
          findsOneWidget);
      expect(find.text('Ajouté à Mes stickers'), findsNothing);
    });

    testUi('annuler l\'aperçu : rien n\'est envoyé', (t) async {
      await open(t);
      await t.tap(tile);
      await settle(t);
      await t.tap(find.text('Annuler'));
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('upload:')), isEmpty);
      expect(find.text('Voir'), findsNothing);
    });

    testUi('galerie fermée sans choix : rien ne se passe', (t) async {
      await open(
        t,
        h: StickerCreateHooks(
          pickImage: () async {
            picked++;
            return null;
          },
        ),
      );
      await t.tap(tile);
      await settle(t);
      expect(picked, 1);
      expect(find.text('Ajouter'), findsNothing);
      expect(api.calls.where((c) => c.startsWith('upload:')), isEmpty);
    });

    testUi('image fixe + animés ouverts : parcours fixe (pas d\'écran animé)', (
      t,
    ) async {
      features.animated.value = true;
      await open(t);
      await t.tap(tile);
      await settle(t);
      expect(animatedCalls, 0);
      expect(adapted, 1);
    });

    testUi('GIF / WebP animé + animés ouverts : parcours « Sticker animé »', (
      t,
    ) async {
      features.animated.value = true;
      await open(t, h: hooks(pick: () async => (bytes: _anime, name: 'a.webp')));
      await t.tap(tile);
      await settle(t);
      expect(animatedCalls, 1);
      expect(adapted, 0, reason: 'le fichier animé part tel quel');
      expect(
        api.calls.where((c) => c.startsWith('animated:')).single,
        startsWith('animated:null:'),
      );
      expect(find.text('Ajouté à Mes stickers'), findsOneWidget);
      final recents = await t.runAsync(() => stickers.watchRecents().first);
      expect(recents!.first.sticker.stickerId, 504);
    });

    testUi('animé mais animés fermés : parcours fixe habituel', (t) async {
      features.animated.value = false;
      await open(t, h: hooks(pick: () async => (bytes: _anime, name: 'a.webp')));
      await t.tap(tile);
      await settle(t);
      expect(animatedCalls, 0);
      expect(adapted, 1);
    });

    testUi('quota atteint : message traduit, la tuile reste utilisable', (
      t,
    ) async {
      await open(t);
      api.failNext = TalkyException('quota', 429, code: 'STICKER_QUOTA_EXCEEDED');
      await t.tap(tile);
      await settle(t);
      await t.tap(find.text('Ajouter'));
      await settle(t);
      expect(
        find.textContaining('Vous avez atteint votre limite de 200 stickers.'),
        findsOneWidget,
      );
      expect(find.text('Voir'), findsNothing);
      // La tuile est de nouveau active.
      await t.tap(tile);
      await settle(t);
      expect(picked, 2);
    });

    testUi('hors ligne : erreur présentée, aucun récent ajouté', (t) async {
      await open(t);
      api.failNext = TalkyException('offline', 0);
      await t.tap(tile);
      await settle(t);
      await t.tap(find.text('Ajouter'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      final recents = await t.runAsync(() => stickers.watchRecents().first);
      expect(recents, isEmpty);
    });

    testUi('image refusée par le sélecteur (trop lourde) : texte clair', (
      t,
    ) async {
      await open(
        t,
        h: StickerCreateHooks(
          pickImage: () async => throw StateError('jamais montré tel quel'),
        ),
      );
      await t.tap(tile);
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });

  group('avis de confidentialité', () {
    testUi('affiché une seule fois, puis mémorisé', (t) async {
      SharedPreferences.setMockInitialValues({});
      await open(t);
      await t.tap(tile);
      await settle(t);
      expect(find.text('Un sticker envoyé peut être vu par ses destinataires.'),
          findsOneWidget);
      expect(picked, 0, reason: 'avant la galerie');
      await t.tap(find.text('J\'ai compris'));
      await settle(t);
      expect(picked, 1);
      await t.tap(find.text('Ajouter'));
      await settle(t);
      expect((await SharedPreferences.getInstance()).getBool(kStickerPrivacyAckKey),
          isTrue);
      // Deuxième création : pas d'avis.
      await t.tap(tile);
      await settle(t);
      expect(find.text('J\'ai compris'), findsNothing);
      expect(picked, 2);
    });

    testUi('renoncer à l\'avis : ni galerie ni envoi', (t) async {
      SharedPreferences.setMockInitialValues({});
      await open(t);
      await t.tap(tile);
      await settle(t);
      await t.tap(find.text('Annuler'));
      await settle(t);
      expect(picked, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool(kStickerPrivacyAckKey),
        isNull,
      );
    });
  });

  group('dans le panneau extensible', () {
    testUi('plateau Stickers : tuile « Créer » visible en normal et en grand, sans débordement', (
      t,
    ) async {
      await t.runAsync(() async {
        await creation.syncCreated();
        await stickers.refresh();
      });
      final ctl = ExpandablePanelController();
      addTearDown(ctl.dispose);
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StickerRepository>.value(value: stickers),
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
              body: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ExpandablePanel(
                      controller: ctl,
                      normalHeight: 328,
                      largeHeight: 540,
                      expandLabel: 'Agrandir le panneau',
                      collapseLabel: 'Réduire le panneau',
                      onClose: () {},
                      child: EmojiStickerPicker(
                        emojiPicker: const SizedBox.expand(child: Text('EMOJIS')),
                        onSendSticker: (_) {},
                        createHooks: hooks(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('Stickers'));
      await settle(t);
      expect(tile, findsOneWidget);
      await t.tap(find.byKey(const ValueKey('panel-handle')));
      await settle(t);
      expect(ctl.isLarge, isTrue);
      expect(tile, findsOneWidget);
      expect(t.takeException(), isNull);
      // La tuile reste utilisable dans le panneau grand.
      await t.tap(tile);
      await settle(t);
      expect(picked, 1);
    });
  });

  group('rendu clair / sombre × fr / en / zh', () {
    const labels = {'fr': 'Créer', 'en': 'Create', 'zh': '创建'};
    for (final b in Brightness.values) {
      for (final lang in labels.keys) {
        testUi('grille Récents — ${b.name} — $lang', (t) async {
          await open(t, b: b, lang: lang);
          expect(find.text(labels[lang]!), findsOneWidget);
          expect(find.byKey(const ValueKey('sticker-create-hint')),
              findsOneWidget);
          // La tuile suit le thème : jamais de couleur en dur.
          final box = t.widget<Container>(
            find.descendant(of: tile, matching: find.byType(Container)).first,
          );
          final theme = b == Brightness.light ? AppTheme.light : AppTheme.dark;
          expect(
            (box.decoration! as BoxDecoration).color,
            theme.colorScheme.surfaceContainerHighest,
          );
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
