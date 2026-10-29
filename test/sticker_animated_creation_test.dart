// Création d'un sticker animé (V1c, T5b) : option masquée tant que `/me` ne
// l'ouvre pas, choix GIF / WebP animé, écran « Sticker animé » (forme, aperçu
// découpé, ajout, progression + annulation), erreurs traduites fr/en/zh, 404 qui
// masque l'option — en clair et en sombre. Client factice sur les fixtures.
import 'dart:async';
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
import 'package:talky_flutter/core/services/stickers/sticker_animated_check.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_features.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/stickers/non_looping_animated_sticker.dart';
import 'package:talky_flutter/widgets/stickers/sticker_animated_screen.dart';
import 'package:talky_flutter/widgets/stickers/sticker_created_pack_screen.dart';

import 'support/sticker_creation_fakes.dart';

class _NoNetwork extends Fake implements CacheManager {}

final Uint8List _anime =
    File('test/fixtures/stickers/images/anime-5x50ms.webp').readAsBytesSync();
final Uint8List _gifFixe =
    File('test/fixtures/stickers/images/statique-32x32.gif').readAsBytesSync();

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StickerCache.shared =
        StickerCache(manager: _NoNetwork(), canPrefetch: () async => false);
    StickerPlayback.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeCreationApi();
    features = StickerFeatures();
    stickers = StickerRepository(db: db, api: OfficialStickerApi(), features: features);
    creation = StickerCreationRepository(db: db, api: api, features: features);
  });
  tearDown(() async {
    StickerCache.shared = null;
    await db.close();
  });

  Widget app(
    Widget home, {
    Brightness b = Brightness.light,
    String lang = 'fr',
    bool reduce = false,
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
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: c!,
      ),
      home: Scaffold(body: home),
    ),
  );

  Future<void> settle(WidgetTester t, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> openPack(
    WidgetTester t, {
    Future<_Picked?> Function()? pickAnimated,
    Future<_Picked?> Function()? pickImage,
    String lang = 'fr',
    Brightness b = Brightness.light,
    bool reduce = false,
  }) async {
    await t.runAsync(() => creation.syncCreated());
    await t.pumpWidget(app(
      StickerCreatedPackScreen(
        packId: 41,
        pickImage: pickImage ?? () async => null,
        pickAnimated: pickAnimated ?? () async => (bytes: _anime, name: 'mon.webp'),
        adaptImage: (b) async => b,
        shareText: (_, _) async {},
      ),
      lang: lang,
      b: b,
      reduce: reduce,
    ));
    await settle(t);
  }

  final cell = find.byKey(const ValueKey('sticker-add-animated'));
  final addButton = find.byKey(const ValueKey('sticker-animated-add'));

  Future<void> openAnimatedScreen(WidgetTester t) async {
    await t.tap(cell);
    await settle(t);
    expect(find.byType(StickerAnimatedScreen), findsOneWidget);
  }

  group('option masquée tant que le serveur ne l\'ouvre pas', () {
    testUi('features.animated faux : aucune cellule « Sticker animé »', (t) async {
      await openPack(t);
      expect(cell, findsNothing);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    });

    testUi('features.animated vrai : la cellule apparaît (cible ≥ 48 dp)', (t) async {
      await features.apply({'creation': true, 'animated': true});
      await openPack(t);
      expect(cell, findsOneWidget);
      expect(t.getSize(cell).width, greaterThanOrEqualTo(48));
      expect(t.getSize(cell).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Ajouter un sticker animé'), findsOneWidget);
    });

    testUi('le serveur ferme les animés pendant que l\'écran est ouvert : elle disparaît',
        (t) async {
      await features.apply({'creation': true, 'animated': true});
      await openPack(t);
      expect(cell, findsOneWidget);
      await t.runAsync(() => features.apply({'creation': true, 'animated': false}));
      await settle(t, rounds: 2);
      expect(cell, findsNothing);
    });
  });

  group('choix du fichier', () {
    setUp(() => features.apply({'creation': true, 'animated': true}));

    testUi('GIF / WebP animé : ouvre l\'écran « Sticker animé »', (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      expect(find.text('Sticker animé'), findsWidgets);
      expect(find.byKey(const ValueKey('sticker-animated-preview')), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('animated')), isEmpty,
          reason: 'rien n\'est envoyé avant « Ajouter »');
    });

    testUi('annuler le choix dans la galerie : rien ne se passe', (t) async {
      await openPack(t, pickAnimated: () async => null);
      await t.tap(cell);
      await settle(t);
      expect(find.byType(StickerAnimatedScreen), findsNothing);
      expect(find.text('2/40'), findsOneWidget);
    });

    for (final (nom, bytes, texte) in <(String, Uint8List, String)>[
      ('plus de 3 Mo', Uint8List(StickerAnimatedCheck.maxBytes + 1), 'Ce fichier dépasse 3 Mo.'),
      ('PNG', png512(), 'Seuls les GIF et les WebP animés sont acceptés.'),
      ('GIF fixe', _gifFixe, "Ce fichier n'est pas animé. Choisissez un GIF ou un WebP animé."),
    ]) {
      testUi('refus local ($nom) : message, écran fermé, rien d\'envoyé', (t) async {
        await openPack(t, pickAnimated: () async => (bytes: bytes, name: 'a.gif'));
        await t.tap(cell);
        await settle(t);
        expect(find.text(texte), findsOneWidget);
        expect(find.byType(StickerAnimatedScreen), findsNothing);
        expect(api.calls.where((c) => c.startsWith('animated')), isEmpty);
      });
    }

    testUi('galerie : fichier > 3 Mo refusé à la lecture (exception du sélecteur)',
        (t) async {
      await openPack(t, pickAnimated: () => Future.error(
          const StickerAnimatedRejected(StickerAnimatedIssue.tooBig)));
      await t.tap(cell);
      await settle(t);
      expect(find.text('Ce fichier dépasse 3 Mo.'), findsOneWidget);
    });

    testUi('le bouton « image » prend aussi un GIF animé quand les animés sont ouverts',
        (t) async {
      await openPack(t, pickImage: () async => (bytes: _anime, name: 'x.webp'));
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      expect(find.byType(StickerAnimatedScreen), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
    });
  });

  group('écran « Sticker animé »', () {
    setUp(() => features.apply({'creation': true, 'animated': true}));

    ClipRRect clip(WidgetTester t) => t.widget<ClipRRect>(
        find.byKey(const ValueKey('sticker-animated-clip')));

    testUi('aperçu découpé dans la forme : carré arrondi par défaut, cercle, carré',
        (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      final r0 = clip(t).borderRadius as BorderRadius;
      expect(r0.topLeft.x, closeTo(240 * 0.22, 0.01));
      await t.tap(find.text('Cercle'));
      await settle(t, rounds: 2);
      expect((clip(t).borderRadius as BorderRadius).topLeft.x, 120,
          reason: 'cercle : rayon = moitié du côté');
      await t.tap(find.text('Carré').last);
      await settle(t, rounds: 2);
      expect((clip(t).borderRadius as BorderRadius).topLeft.x, 0);
      // L'aperçu est animé : l'image du fichier source, en boucle (Image).
      expect(find.descendant(
          of: find.byKey(const ValueKey('sticker-animated-clip')),
          matching: find.byType(Image)), findsOneWidget);
    });

    testUi('« réduire les animations » : aperçu en image fixe (jamais de boucle)',
        (t) async {
      await openPack(t, reduce: true);
      await openAnimatedScreen(t);
      expect(find.descendant(
          of: find.byKey(const ValueKey('sticker-animated-clip')),
          matching: find.byType(NonLoopingAnimatedSticker)), findsOneWidget);
      expect(find.descendant(
          of: find.byKey(const ValueKey('sticker-animated-clip')),
          matching: find.byType(Image)), findsNothing);
    });

    testUi('« Ajouter » : fichier tel quel + forme choisie, retour au pack, 3 stickers',
        (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(find.text('Cercle'));
      await settle(t, rounds: 2);
      await t.tap(addButton);
      await settle(t);
      expect(api.calls,
          contains('animated:41:mon.webp:cercle:${_anime.length}'));
      expect(find.byType(StickerAnimatedScreen), findsNothing);
      expect(find.text('Sticker animé ajouté.'), findsOneWidget);
      expect(find.text('3/40'), findsOneWidget);
    });

    testUi('forme par défaut : carré arrondi', (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(addButton);
      await settle(t);
      expect(api.animatedShapes, ['carre-arrondi']);
    });

    testUi('« Carré » : valeur `carre`', (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(find.text('Carré').last);
      await settle(t, rounds: 2);
      await t.tap(addButton);
      await settle(t);
      expect(api.animatedShapes, ['carre']);
    });

    testUi('progression et annulation : l\'envoi est interrompu, l\'écran reste',
        (t) async {
      api.holdAnimated = Completer<void>();
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(addButton);
      await settle(t, rounds: 3);
      expect(find.byKey(const ValueKey('sticker-animated-progress')), findsOneWidget);
      expect(find.text('Conversion en cours…'), findsWidgets);
      final cancel = find.byKey(const ValueKey('sticker-animated-cancel'));
      expect(t.getSize(cancel).height, greaterThanOrEqualTo(48));
      // Le bouton « Ajouter » ne se réarme pas pendant la conversion.
      expect(t.widget<FilledButton>(addButton).onPressed, isNull);
      await t.tap(cancel);
      await settle(t, rounds: 3);
      expect(api.calls, contains('animated-aborted'));
      expect(find.byKey(const ValueKey('sticker-animated-progress')), findsNothing);
      expect(find.byType(StickerAnimatedScreen), findsOneWidget);
      expect(find.text('Sticker animé ajouté.'), findsNothing);
      // Aucune erreur affichée pour une annulation voulue.
      expect(find.byType(SnackBar), findsNothing);
      // Nouvelle tentative : passe.
      api.holdAnimated = null;
      await t.tap(addButton);
      await settle(t);
      expect(find.byType(StickerAnimatedScreen), findsNothing);
      expect(find.text('3/40'), findsOneWidget);
    });

    testUi('retour système pendant la conversion : annule, ne quitte pas', (t) async {
      api.holdAnimated = Completer<void>();
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(addButton);
      await settle(t, rounds: 3);
      await t.binding.handlePopRoute();
      await settle(t, rounds: 3);
      expect(api.calls, contains('animated-aborted'));
      expect(find.byType(StickerAnimatedScreen), findsOneWidget);
    });

    testUi('fermer l\'écran en cours de conversion : requête interrompue', (t) async {
      api.holdAnimated = Completer<void>();
      await openPack(t);
      await openAnimatedScreen(t);
      await t.tap(addButton);
      await settle(t, rounds: 3);
      await t.pumpWidget(const SizedBox());
      await settle(t, rounds: 2);
      expect(api.calls, contains('animated-aborted'));
    });

    for (final (lang, code, status, texte) in <(String, String, int, String)>[
      ('fr', 'STICKER_ASSET_INVALID', 422, 'trop lourd ou n\'est pas pris en charge'),
      ('en', 'STICKER_ASSET_INVALID', 422, 'too heavy or isn\'t supported'),
      ('zh', 'STICKER_ASSET_INVALID', 422, '过大或不受支持'),
      ('fr', 'STICKER_QUOTA_EXCEEDED', 429, '200 stickers'),
      ('en', 'STICKER_QUOTA_EXCEEDED', 429, '200 stickers'),
      ('zh', 'STICKER_QUOTA_EXCEEDED', 429, '200'),
      ('fr', 'RATE_LIMITED', 429, '10 par heure'),
      ('en', 'RATE_LIMITED', 429, '10 per hour'),
      ('zh', 'RATE_LIMITED', 429, '每小时最多 10 个'),
      ('fr', 'SERVICE_UNAVAILABLE', 503, 'Le service est occupé'),
      ('en', 'SERVICE_UNAVAILABLE', 503, 'The service is busy'),
      ('zh', 'SERVICE_UNAVAILABLE', 503, '服务繁忙'),
    ]) {
      testUi('erreur $code ($lang) : message traduit, l\'écran reste, on peut réessayer',
          (t) async {
        await openPack(t, lang: lang);
        await openAnimatedScreen(t);
        api.failNext = TalkyException('x', status, code: code);
        await t.tap(addButton);
        await settle(t);
        expect(find.textContaining(texte), findsOneWidget);
        expect(find.byType(StickerAnimatedScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('sticker-animated-progress')), findsNothing);
        expect(t.widget<FilledButton>(addButton).onPressed, isNotNull);
        expect(features.animated.value, isTrue);
        // Réessai : le serveur répond cette fois.
        await t.tap(addButton);
        await settle(t);
        expect(find.byType(StickerAnimatedScreen), findsNothing);
      });
    }

    testUi('503 sans code (proxy) : même message « service occupé »', (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      api.failNext = TalkyException('Bad gateway', 503);
      await t.tap(addButton);
      await settle(t);
      expect(find.textContaining('Le service est occupé'), findsOneWidget);
    });

    testUi('404 NOT_FOUND : animés fermés, message, écran fermé, option masquée',
        (t) async {
      await openPack(t);
      await openAnimatedScreen(t);
      api.failNext = TalkyException('nope', 404, code: 'NOT_FOUND');
      await t.tap(addButton);
      await settle(t);
      expect(find.text('Les stickers animés ne sont pas disponibles pour le moment.'),
          findsOneWidget);
      expect(find.byType(StickerAnimatedScreen), findsNothing);
      expect(features.animated.value, isFalse);
      expect(cell, findsNothing, reason: 'l\'option est masquée');
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget,
          reason: 'l\'ajout d\'une image fixe reste là');
    });
  });

  group('clair / sombre × fr / en / zh', () {
    for (final b in Brightness.values) {
      for (final (lang, titre, forme, cercle, arrondi, carre, ajouter, aide) in [
        ('fr', 'Sticker animé', 'Forme', 'Cercle', 'Carré arrondi', 'Carré', 'Ajouter', 'recadrée en carré'),
        ('en', 'Animated sticker', 'Shape', 'Circle', 'Rounded square', 'Square', 'Add', 'cropped to a square'),
        ('zh', '动态贴纸', '形状', '圆形', '圆角方形', '方形', '添加', '裁剪为正方形'),
      ]) {
        testUi('écran $lang / ${b.name}', (t) async {
          await features.apply({'creation': true, 'animated': true});
          await openPack(t, lang: lang, b: b);
          expect(find.bySemanticsLabel(RegExp('.+')), findsWidgets);
          await t.tap(cell);
          await settle(t);
          expect(find.text(titre), findsWidgets);
          expect(find.text(forme), findsOneWidget);
          expect(find.text(cercle), findsOneWidget);
          expect(find.text(arrondi), findsOneWidget);
          expect(find.text(carre), findsOneWidget);
          expect(find.textContaining(aide), findsOneWidget);
          expect(find.widgetWithText(FilledButton, ajouter), findsOneWidget);
          // Cibles ≥ 48 dp.
          expect(t.getSize(addButton).height, greaterThanOrEqualTo(48));
          for (final s in [cercle, arrondi, carre]) {
            expect(t.getSize(find.text(s)).height, greaterThan(0));
          }
          expect(t.getSize(find.byKey(const ValueKey('sticker-animated-shapes'))).height,
              greaterThanOrEqualTo(48));
          // Aperçu annoncé aux lecteurs d'écran.
          expect(find.bySemanticsLabel(
              {'fr': 'Aperçu animé du sticker', 'en': 'Animated sticker preview', 'zh': '动态贴纸预览'}[lang]!),
              findsOneWidget);
          expect(t.takeException(), isNull);
        });

        testUi('conversion en cours $lang / ${b.name} : voile, indicateur, Annuler',
            (t) async {
          await features.apply({'creation': true, 'animated': true});
          api.holdAnimated = Completer<void>();
          await openPack(t, lang: lang, b: b);
          await t.tap(cell);
          await settle(t);
          await t.tap(addButton);
          await settle(t, rounds: 3);
          expect(find.byKey(const ValueKey('sticker-animated-progress')), findsOneWidget);
          final annuler = {'fr': 'Annuler', 'en': 'Cancel', 'zh': '取消'}[lang]!;
          expect(find.widgetWithText(OutlinedButton, annuler), findsOneWidget);
          expect(t.takeException(), isNull);
          api.holdAnimated!.complete();
          await settle(t);
        });
      }
    }
  });
}
