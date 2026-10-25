// Écrans de création de stickers (V1b) : onglet « Mes créations », écran d'un
// pack perso, fiche d'un sticker reçu (＋ / ⚑), lien de partage — en clair et
// en sombre, en fr, en et zh. Client injecté sur les fixtures du contrat §4b.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/features/media_editor/media_editor_screen.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/stickers/sticker_created_pack_screen.dart';
import 'package:talky_flutter/core/services/stickers/sticker_order.dart';
import 'package:talky_flutter/widgets/stickers/sticker_creation_flows.dart'
    show kStickerPrivacyAckKey;
import 'package:talky_flutter/widgets/stickers/sticker_packs_screen.dart';
import 'package:talky_flutter/widgets/stickers/sticker_share_screens.dart';
import 'package:talky_flutter/widgets/stickers/sticker_sheet.dart';

import 'support/media_editor_fakes.dart' show solidPng;
import 'support/sticker_creation_fakes.dart';

class _NoNetwork extends Fake implements CacheManager {}

/// `testWidgets` + démontage de l'arbre à la fin : les flux Drift laissent un
/// minuteur à zéro seconde à leur annulation, que le test refuserait sinon.
void testUi(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

Widget _app(
  Widget home, {
  required AppDatabase db,
  required FakeCreationApi api,
  Brightness b = Brightness.light,
  String lang = 'fr',
  required StickerRepository stickers,
  required StickerCreationRepository creation,
}) {
  return MultiProvider(
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
}

void main() {
  late AppDatabase db;
  late FakeCreationApi api;
  late StickerRepository stickers;
  late StickerCreationRepository creation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StickerCache.shared = StickerCache(
      manager: _NoNetwork(),
      canPrefetch: () async => false,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeCreationApi();
    stickers = StickerRepository(db: db, api: OfficialStickerApi());
    creation = StickerCreationRepository(db: db, api: api);
  });
  tearDown(() async {
    StickerCache.shared = null;
    await db.close();
  });

  Widget screen(
    Widget w, {
    Brightness b = Brightness.light,
    String lang = 'fr',
  }) => _app(
    w,
    db: db,
    api: api,
    b: b,
    lang: lang,
    stickers: stickers,
    creation: creation,
  );

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  group('gestion des stickers : onglet « Mes créations »', () {
    testUi(
      'création fermée (404 NOT_FOUND) : écran V1a, aucune entrée de création',
      (t) async {
        api.closed = true;
        await t.pumpWidget(screen(const StickerPacksScreen()));
        await settle(t);
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('Mes créations'), findsNothing);
        expect(find.text('Nouveau pack'), findsNothing);
        expect(find.byIcon(Icons.link), findsNothing);
        expect(find.text('Gérer les stickers'), findsOneWidget);
      },
    );

    testUi('création ouverte : deux onglets, mes packs listés avec leur état', (
      t,
    ) async {
      await t.pumpWidget(screen(const StickerPacksScreen()));
      await settle(t);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Installés'), findsOneWidget);
      await t.tap(find.text('Mes créations'));
      await settle(t);
      expect(find.text('Mes stickers'), findsOneWidget);
      expect(find.text('Famille'), findsOneWidget);
      expect(find.text('2 stickers · Partagé'), findsOneWidget);
      expect(find.text('0 stickers'), findsOneWidget);
      expect(find.text('2/20'), findsOneWidget);
    });

    testUi(
      'créer un pack : confidentialité (une seule fois), nom, puis écran du pack',
      (t) async {
        await t.pumpWidget(screen(const StickerPacksScreen()));
        await settle(t);
        await t.tap(find.text('Mes créations'));
        await settle(t);

        await t.tap(find.text('Nouveau pack'));
        await settle(t);
        expect(
          find.text('Un sticker envoyé peut être vu par ses destinataires.'),
          findsOneWidget,
        );
        expect(find.text('Avant de créer'), findsOneWidget);
        await t.tap(find.text("J'ai compris"));
        await settle(t);

        // Le nom : le rappel de confidentialité reste sous le champ.
        expect(find.text('Nom du pack'), findsOneWidget);
        expect(
          find.text('Un sticker envoyé peut être vu par ses destinataires.'),
          findsOneWidget,
        );
        await t.enterText(find.byType(TextField), 'Les copains');
        await t.tap(find.text('Créer'));
        await settle(t);
        expect(api.calls, containsAllInOrder(['create', 'patch:43']));
        expect(
          find.text('Les copains'),
          findsWidgets,
        ); // titre de l'écran du pack
        expect(find.byType(StickerCreatedPackScreen), findsOneWidget);

        // Seconde création : plus d'écran de confidentialité.
        t.state<NavigatorState>(find.byType(Navigator).first).pop();
        await settle(t);

        await t.tap(find.text('Nouveau pack'));
        await settle(t);
        expect(find.text('Avant de créer'), findsNothing);
        expect(find.text('Nom du pack'), findsOneWidget);
      },
    );

    testUi('confidentialité refusée : aucun pack créé', (t) async {
      await t.pumpWidget(screen(const StickerPacksScreen()));
      await settle(t);
      await t.tap(find.text('Mes créations'));
      await settle(t);
      await t.tap(find.text('Nouveau pack'));
      await settle(t);
      await t.tap(find.text('Annuler'));
      await settle(t);
      expect(api.calls, isNot(contains('create')));
    });

    testUi('STICKER_PACK_LIMIT à la création : message traduit, pas de crash', (
      t,
    ) async {
      await t.pumpWidget(screen(const StickerPacksScreen()));
      await settle(t);
      await t.tap(find.text('Mes créations'));
      await settle(t);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kStickerPrivacyAckKey, true);
      api.failNext = TalkyException('x', 409, code: 'STICKER_PACK_LIMIT');
      await t.tap(find.text('Nouveau pack'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Trop');
      await t.tap(find.text('Créer'));
      await settle(t);
      expect(find.textContaining('limite de packs'), findsOneWidget);
    });

    testUi(
      'lien reçu : saisie invalide refusée, lien valide ouvre la fiche du pack',
      (t) async {
        await t.pumpWidget(screen(const StickerPacksScreen()));
        await settle(t);
        await t.tap(find.byIcon(Icons.link).first);
        await settle(t);
        await t.enterText(find.byType(TextField), 'coucou');
        await t.tap(find.text('Ouvrir un lien de pack').last);
        await settle(t);
        expect(
          find.textContaining("n'est pas celui d'un pack"),
          findsOneWidget,
        );

        await t.enterText(
          find.byType(TextField),
          'Voici : alanya://sticker/$kToken',
        );
        await t.tap(find.text('Ouvrir un lien de pack').last);
        await settle(t);
        expect(api.calls, contains('getShare:$kToken'));
        expect(find.byType(StickerSharePreviewScreen), findsOneWidget);
        expect(find.text('Les copains'), findsOneWidget);
      },
    );
  });

  group('écran d\'un pack perso', () {
    Future<void> open(
      WidgetTester t,
      int id, {
      StickerImagePicker? pick,
      StickerImageAdaptation? adapt,
      StickerImageEditor? edit,
      StickerTextSharer? share,
      String lang = 'fr',
      Brightness b = Brightness.light,
    }) async {
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(
        screen(
          StickerCreatedPackScreen(
            packId: id,
            pickImage: pick ?? () async => null,
            adaptImage: adapt ?? (b) async => b,
            editImage: edit ?? openStickerEditor,
            shareText: share ?? (_, _) async {},
          ),
          lang: lang,
          b: b,
        ),
      );
      await settle(t);
    }

    testUi('grille : stickers, compteur et cellule d\'ajout', (t) async {
      await open(t, 41);
      expect(find.text('Mes stickers'), findsWidgets);
      expect(find.text('2/40'), findsOneWidget);
      expect(find.text('Partagé'), findsOneWidget);
      expect(find.text('😀'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.text('Maintenez et glissez pour réordonner'), findsOneWidget);
    });

    testUi('pack vide : message d\'invite', (t) async {
      await open(t, 42);
      expect(find.textContaining('Ce pack est vide'), findsOneWidget);
    });

    // L'adaptation réelle (dart:ui) est testée dans sticker_image_adapter_test ;
    // ici elle est injectée, un moteur de décodage n'avance pas sous fakeAsync.
    Future<Uint8List> passThrough(Uint8List b) async => b;
    Future<Uint8List> reject(StickerImageIssue i) =>
        Future.error(StickerImageRejected(i));

    for (final (lang, issue, texte) in [
      ('fr', StickerImageIssue.format, 'Image illisible'),
      ('en', StickerImageIssue.format, "Can't read this image"),
      ('zh', StickerImageIssue.format, '无法读取'),
      ('fr', StickerImageIssue.animated, 'GIF, WebP animé'),
      ('en', StickerImageIssue.animated, 'GIF, animated WebP'),
      ('zh', StickerImageIssue.animated, 'GIF'),
      ('fr', StickerImageIssue.inputTooBig, '20 Mo'),
      ('en', StickerImageIssue.inputTooBig, '20 MB'),
      ('zh', StickerImageIssue.inputTooBig, '20 MB'),
      ('fr', StickerImageIssue.tooBig, '1 Mo'),
    ]) {
      testUi(
        'refus d\'adaptation $issue traduit ($lang) : rien n\'est envoyé',
        (t) async {
          await open(
            t,
            41,
            pick: () async => (bytes: Uint8List(8), name: 'a.jpg'),
            adapt: (_) => reject(issue),
            lang: lang,
          );
          await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
          await settle(t);
          expect(find.textContaining(texte), findsOneWidget);
          expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
        },
      );
    }

    testUi(
      'image 400×400 qui passerait l\'adaptation : le contrôle d\'envoi garde',
      (t) async {
        await open(
          t,
          41,
          pick: () async => (bytes: png(400, 400), name: 'photo.png'),
          adapt: passThrough,
        );
        await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(t);
        await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
        await settle(t);
        expect(find.textContaining('exactement 512 × 512'), findsOneWidget);
        expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
      },
    );

    testUi(
      'confirmation : aperçu sur damier, rien n\'est envoyé avant « Ajouter »',
      (t) async {
        await open(
          t,
          41,
          pick: () async => (bytes: Uint8List(8), name: 'photo.jpg'),
          adapt: (_) async => png512(),
        );
        await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(t);
        expect(find.text('Aperçu du sticker'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('sticker-checkerboard')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('sticker-preview-image')),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Ajouter'), findsOneWidget);
        expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
        await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
        await settle(t);
        // Le nom d'origine (.jpg) devient un .png : c'est un PNG qui part.
        expect(
          api.calls.any((c) => c.startsWith('upload:41:sticker.png')),
          isTrue,
        );
        expect(find.text('Sticker ajouté au pack.'), findsOneWidget);
      },
    );

    testUi('confirmation : annuler n\'envoie rien', (t) async {
      await open(
        t,
        41,
        pick: () async => (bytes: Uint8List(8), name: 'photo.jpg'),
        adapt: (_) async => png512(),
      );
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      await t.tap(find.text('Annuler'));
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
      expect(find.text('2/40'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      for (final (lang, titre, bouton) in [
        ('en', 'Sticker preview', 'Add'),
        ('zh', '贴纸预览', '添加'),
      ]) {
        testUi('confirmation traduite ($lang, $b)', (t) async {
          await open(
            t,
            41,
            pick: () async => (bytes: Uint8List(8), name: 'a.png'),
            adapt: (_) async => png512(),
            lang: lang,
            b: b,
          );
          await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
          await settle(t);
          expect(find.text(titre), findsOneWidget);
          expect(find.widgetWithText(FilledButton, bouton), findsOneWidget);
        });
      }
    }

    group('éditeur d\'image depuis l\'aperçu', () {
      testUi(
        'aperçu : Annuler · Modifier · Ajouter, « Ajouter » sans modifier',
        (t) async {
          await open(
            t,
            41,
            pick: () async => (bytes: Uint8List(8), name: 'photo.jpg'),
            adapt: (_) async => png512(),
            edit: (_, _) async => fail('l\'éditeur ne doit pas s\'ouvrir'),
          );
          await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
          await settle(t);
          expect(find.widgetWithText(TextButton, 'Annuler'), findsOneWidget);
          expect(
            find.widgetWithText(OutlinedButton, 'Modifier'),
            findsOneWidget,
          );
          expect(find.widgetWithText(FilledButton, 'Ajouter'), findsOneWidget);
          // Le chemin d'origine reste intact : Ajouter envoie l'image adaptée.
          await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
          await settle(t);
          expect(api.calls.any((c) => c.startsWith('upload:41:')), isTrue);
        },
      );

      testUi(
        'Modifier : l\'éditeur reçoit l\'original, puis l\'image retouchée',
        (t) async {
          final original = Uint8List.fromList([9, 9, 9, 9, 9, 9, 9, 9]);
          final retouche1 = png512();
          final sources = <Uint8List>[];
          await open(
            t,
            41,
            pick: () async => (bytes: original, name: 'photo.jpg'),
            adapt: (_) async => png512(),
            edit: (_, source) async {
              sources.add(source);
              return sources.length == 1 ? retouche1 : null;
            },
          );
          await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
          await settle(t);
          await t.tap(find.widgetWithText(OutlinedButton, 'Modifier'));
          await settle(t);
          expect(sources.single, same(original));
          // Retour à l'aperçu, sur le résultat de l'éditeur : rien n'est envoyé.
          expect(find.text('Aperçu du sticker'), findsOneWidget);
          expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);

          // Seconde retouche : elle part de la précédente ; abandon = on garde.
          await t.tap(find.widgetWithText(OutlinedButton, 'Modifier'));
          await settle(t);
          expect(sources, hasLength(2));
          expect(sources.last, same(retouche1));
          expect(find.text('Aperçu du sticker'), findsOneWidget);

          await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
          await settle(t);
          expect(
            api.calls.any((c) => c.startsWith('upload:41:sticker.png')),
            isTrue,
          );
          expect(find.text('Sticker ajouté au pack.'), findsOneWidget);
        },
      );

      testUi('éditeur abandonné puis aperçu annulé : rien n\'est envoyé', (
        t,
      ) async {
        await open(
          t,
          41,
          pick: () async => (bytes: Uint8List(8), name: 'photo.jpg'),
          adapt: (_) async => png512(),
          edit: (_, _) async => null,
        );
        await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(t);
        await t.tap(find.widgetWithText(OutlinedButton, 'Modifier'));
        await settle(t);
        expect(find.text('Aperçu du sticker'), findsOneWidget);
        await t.tap(find.text('Annuler'));
        await settle(t);
        expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
        expect(find.text('2/40'), findsOneWidget);
      });

      testUi('éditeur réel : ouvert depuis le pack, fermé sans changement', (
        t,
      ) async {
        final src = (await t.runAsync(() => solidPng(300, 200)))!;
        await open(
          t,
          41,
          pick: () async => (bytes: src, name: 'photo.png'),
          adapt: (_) async => png512(),
        );
        await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(t);
        await t.tap(find.widgetWithText(OutlinedButton, 'Modifier'));
        await settle(t);
        expect(find.byType(MediaEditorScreen), findsOneWidget);
        expect(find.text('Modifier le sticker'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('editor-close')));
        await settle(t);
        expect(find.byType(MediaEditorScreen), findsNothing);
        expect(find.text('Aperçu du sticker'), findsOneWidget);
        expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
      });

      testUi('éditeur réel : retouche validée, l\'image éditée est envoyée', (
        t,
      ) async {
        final src = (await t.runAsync(() => solidPng(300, 200)))!;
        await open(
          t,
          41,
          pick: () async => (bytes: src, name: 'photo.png'),
          adapt: (_) async => png512(),
        );
        await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(t);
        await t.tap(find.widgetWithText(OutlinedButton, 'Modifier'));
        await settle(t);
        await t.tap(find.byKey(const ValueKey('editor-fit-cover')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('editor-done')));
        for (
          var i = 0;
          i < 40 && find.byType(MediaEditorScreen).evaluate().isNotEmpty;
          i++
        ) {
          await settle(t);
        }
        expect(find.byType(MediaEditorScreen), findsNothing);
        expect(find.text('Aperçu du sticker'), findsOneWidget);
        await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
        await settle(t);
        // Un vrai PNG 512×512 avec alpha est parti : le contrôle d'envoi passe.
        final envoi = api.calls.singleWhere((c) => c.startsWith('upload:41:'));
        final octets = int.parse(envoi.split(':').last);
        expect(
          octets,
          greaterThan(100),
          reason: 'le PNG exporté, pas l\'adaptation factice',
        );
      });

      for (final b in Brightness.values) {
        for (final (lang, edit) in [('en', 'Edit'), ('zh', '编辑')]) {
          testUi('bouton « Modifier » traduit ($lang, $b)', (t) async {
            await open(
              t,
              41,
              pick: () async => (bytes: Uint8List(8), name: 'a.png'),
              adapt: (_) async => png512(),
              lang: lang,
              b: b,
            );
            await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
            await settle(t);
            expect(find.widgetWithText(OutlinedButton, edit), findsOneWidget);
          });
        }
      }
    });

    testUi('image 512×512 transparente : envoyée, le pack se met à jour', (
      t,
    ) async {
      await open(
        t,
        41,
        pick: () async => (bytes: png512(), name: 'ok.png'),
        adapt: passThrough,
      );
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
      await settle(t);
      expect(api.calls.any((c) => c.startsWith('upload:41:ok.png')), isTrue);
      expect(find.text('Sticker ajouté au pack.'), findsOneWidget);
      expect(find.text('3/40'), findsOneWidget);
    });

    testUi('quota de 200 stickers : STICKER_QUOTA_EXCEEDED traduit', (t) async {
      await open(
        t,
        41,
        pick: () async => (bytes: png512(), name: 'ok.png'),
        adapt: passThrough,
      );
      api.failNext = TalkyException('x', 429, code: 'STICKER_QUOTA_EXCEEDED');
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
      await settle(t);
      expect(find.textContaining('200 stickers'), findsOneWidget);
    });

    testUi('annuler la galerie : rien ne se passe', (t) async {
      await open(t, 41);
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('upload')), isEmpty);
    });

    testUi('toucher un sticker : feuille, retirer du pack', (t) async {
      await open(t, 41);
      await t.tap(find.text('😀'));
      await settle(t);
      expect(find.text('Retirer du pack'), findsOneWidget);
      expect(find.text('Définir comme couverture'), findsOneWidget);
      await t.tap(find.text('Retirer du pack'));
      await settle(t);
      expect(api.calls, contains('remove:41:501'));
      expect(find.text('1/40'), findsOneWidget);
    });

    testUi('couverture : un sticker du pack', (t) async {
      await open(t, 41);
      await t.tap(find.text('🎉'));
      await settle(t);
      await t.tap(find.text('Définir comme couverture'));
      await settle(t);
      expect((api.patchBody as Map)['cover'], 502);
    });

    testUi('réordonner : appui long puis glisser envoie le nouvel ordre', (
      t,
    ) async {
      await open(t, 41);
      final first = t.getCenter(find.byKey(const ValueKey('created_501')));
      final second = t.getCenter(find.byKey(const ValueKey('created_502')));
      final g = await t.startGesture(first);
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await g.moveTo(second);
      await t.pump();
      await g.up();
      await settle(t);
      expect(api.calls, contains('order:41:[502, 501]'));
    });

    test('reorderedIds : déplacement avant / après', () {
      expect(reorderedIds([1, 2, 3, 4], 0, 2), [2, 3, 1, 4]);
      expect(reorderedIds([1, 2, 3, 4], 3, 0), [4, 1, 2, 3]);
      expect(reorderedIds([1, 2], 0, 1), [2, 1]);
    });

    testUi(
      'partager : jeton créé, feuille de partage système avec lien et code',
      (t) async {
        String? shared;
        await open(t, 41, share: (text, _) async => shared = text);
        await t.tap(find.byIcon(Icons.ios_share));
        await settle(t);
        expect(api.calls, contains('share:41'));
        expect(shared, contains('https://www.alanya237.com/s/$kToken'));
        expect(shared, contains('Code : $kToken'));
        expect(shared, contains('« Mes stickers »'));
      },
    );

    testUi('partager un pack vide : message, pas d\'appel serveur', (t) async {
      String? shared;
      await open(t, 42, share: (text, _) async => shared = text);
      await t.tap(find.byIcon(Icons.ios_share));
      await settle(t);
      expect(
        find.text('Ajoutez au moins un sticker avant de partager.'),
        findsOneWidget,
      );
      expect(api.calls.where((c) => c.startsWith('share:')), isEmpty);
      expect(shared, isNull);
    });

    testUi('RATE_LIMITED au partage : message traduit', (t) async {
      await open(t, 41);
      api.failNext = TalkyException('x', 429, code: 'RATE_LIMITED');
      await t.tap(find.byIcon(Icons.ios_share));
      await settle(t);
      expect(find.textContaining('Trop de demandes'), findsOneWidget);
    });

    testUi('révoquer le lien : confirmation puis jeton effacé', (t) async {
      await open(t, 41);
      await t.tap(find.byIcon(Icons.more_vert));
      await settle(t);
      await t.tap(find.text('Révoquer le lien'));
      await settle(t);
      expect(
        find.textContaining('Les personnes qui ont déjà ajouté le pack'),
        findsOneWidget,
      );
      await t.tap(find.text('Révoquer le lien').last);
      await settle(t);
      expect(api.calls, contains('unshare:41'));
      expect(find.text('Lien révoqué.'), findsOneWidget);
      expect(find.text('Partagé'), findsNothing);
    });

    testUi('pack non partagé : pas d\'entrée « Révoquer le lien »', (t) async {
      await open(t, 42);
      await t.tap(find.byIcon(Icons.more_vert));
      await settle(t);
      expect(find.text('Révoquer le lien'), findsNothing);
      expect(find.text('Renommer'), findsOneWidget);
      expect(find.text('Supprimer le pack'), findsOneWidget);
    });

    testUi('renommer', (t) async {
      await open(t, 41);
      await t.tap(find.byIcon(Icons.more_vert));
      await settle(t);
      await t.tap(find.text('Renommer'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Autre nom');
      await t.tap(find.text('Enregistrer'));
      await settle(t);
      expect(api.calls, contains('patch:41'));
      expect(find.text('Autre nom'), findsWidgets);
    });

    testUi('supprimer : confirmation, archivage, retour', (t) async {
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(screen(const Text('racine')));
      unawaited(
        t
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => StickerCreatedPackScreen(packId: 41),
              ),
            ),
      );
      await settle(t);
      await t.tap(find.byIcon(Icons.more_vert));
      await settle(t);
      await t.tap(find.text('Supprimer le pack'));
      await settle(t);
      await t.tap(find.text('Supprimer').last);
      await settle(t);
      expect(api.calls, contains('archive:41'));
      expect(find.byType(StickerCreatedPackScreen), findsNothing);
      expect(find.text('racine'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      for (final lang in ['fr', 'en', 'zh']) {
        testUi('rendu sans débordement — ${b.name} / $lang', (t) async {
          await open(t, 41, lang: lang, b: b);
          expect(t.takeException(), isNull);
          await t.tap(find.byIcon(Icons.more_vert));
          await settle(t);
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  group('fiche d\'un sticker reçu : ＋ Ajouter à un pack, ⚑ Signaler', () {
    StickerPayload payload() => StickerPayload(
      version: 1,
      pack: 'u_12_aaaa',
      sid: 701,
      emoji: '😎',
      w: 512,
      h: 512,
      animated: false,
    );

    // Le sticker reçu est désigné par son `sid` (701), jamais par l'actif :
    // le client ne connaît pas l'`assetId` d'un sticker des autres.
    Future<void> seedReceived({int? assetId}) async {
      await db
          .into(db.localStickerPacks)
          .insert(
            LocalStickerPacksCompanion.insert(
              packId: const Value(900),
              code: 'u_12_aaaa',
              name: const Value('Pack d\'un ami'),
            ),
          );
      await db
          .into(db.localStickers)
          .insert(
            LocalStickersCompanion.insert(
              stickerId: const Value(701),
              packId: 900,
              url: 'https://<bucket>/stickers/u/12/a.webp',
              assetId: Value(assetId),
            ),
          );
    }

    Future<void> openSheet(
      WidgetTester t, {
      Brightness b = Brightness.light,
      String lang = 'fr',
    }) async {
      // Écran haut : la fiche défile sur un petit écran, mais les tests
      // touchent des entrées qui doivent être visibles.
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(
        screen(
          StickerSheet(
            payload: payload(),
            mediaUrl: 'https://<bucket>/stickers/u/12/a.webp',
            senderName: 'Ami',
          ),
          b: b,
          lang: lang,
        ),
      );
      await settle(t);
    }

    testUi('sticker reçu, création ouverte : les deux entrées', (t) async {
      await seedReceived();
      await openSheet(t);
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
    });

    testUi('sticker reçu sans actif connu : les deux entrées quand même', (
      t,
    ) async {
      await seedReceived(assetId: null);
      await openSheet(t);
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
    });

    testUi('sticker reçu absent de la base locale : entrées présentes, '
        'copie et signalement par sid', (t) async {
      await openSheet(t); // rien d'inséré : seul le `sid` de la charge utile
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
      await t.tap(find.text('Signaler'));
      await settle(t);
      await t.tap(find.text('Spam'));
      await settle(t);
      expect(api.calls, contains('report:701:spam'));
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      await t.tap(find.text('Famille'));
      await settle(t);
      expect(api.calls, contains('copy:701:42'));
    });

    testUi('charge utile sans sid : aucune entrée', (t) async {
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(
        screen(
          StickerSheet(
            payload: StickerPayload(
              version: 1,
              pack: 'u_12_aaaa',
              sid: null,
              emoji: '😎',
              w: 512,
              h: 512,
              animated: false,
            ),
            mediaUrl: 'https://<bucket>/stickers/u/12/a.webp',
          ),
        ),
      );
      await settle(t);
      expect(find.text('Ajouter à un pack'), findsNothing);
      expect(find.text('Signaler'), findsNothing);
    });

    testUi('création fermée : aucune entrée', (t) async {
      await seedReceived();
      api.closed = true;
      await openSheet(t);
      expect(find.text('Ajouter à un pack'), findsNothing);
      expect(find.text('Signaler'), findsNothing);
    });

    testUi('mon propre sticker : ＋ oui, ⚑ non', (t) async {
      // Sticker 501 du pack 41 (fixture /me/created) : il est à moi.
      t.view.physicalSize = const Size(800, 1800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(
        screen(
          StickerSheet(
            payload: StickerPayload(
              version: 1,
              pack: 'u_7_ab12cd34',
              sid: 501,
              emoji: '😀',
              w: 512,
              h: 512,
              animated: false,
            ),
            mediaUrl: 'https://<bucket>/stickers/u/7/a.webp',
          ),
        ),
      );
      await settle(t);
      expect(find.text('Ajouter à un pack'), findsOneWidget);
      expect(find.text('Signaler'), findsNothing);
      // Et jamais « Ajouter » (installer un pack officiel) sur mon propre pack.
      expect(find.text('Ajouter'), findsNothing);
    });

    testUi('signaler : choix du motif, appel, remerciement', (t) async {
      await seedReceived();
      await openSheet(t);
      await t.tap(find.text('Signaler'));
      await settle(t);
      expect(find.text('Pourquoi signaler ce sticker ?'), findsOneWidget);
      await t.tap(find.text('Spam'));
      await settle(t);
      expect(api.calls, contains('report:701:spam'));
      expect(
        find.text('Merci, votre signalement a été envoyé.'),
        findsOneWidget,
      );
    });

    testUi('signaler deux fois : « déjà signalé »', (t) async {
      await seedReceived();
      api.reportDeja = true;
      await openSheet(t);
      await t.tap(find.text('Signaler'));
      await settle(t);
      await t.tap(find.text('Autre'));
      await settle(t);
      expect(find.text('Vous avez déjà signalé ce sticker.'), findsOneWidget);
    });

    testUi('ajouter à un pack : choix du pack, copie (installer = copier)', (
      t,
    ) async {
      await seedReceived();
      await openSheet(t);
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      expect(find.text('Choisir un pack'), findsOneWidget);
      expect(find.text('Nouveau pack'), findsOneWidget);
      await t.tap(find.text('Famille'));
      await settle(t);
      expect(api.calls, contains('copy:701:42'));
      expect(find.text('Sticker ajouté à votre pack.'), findsOneWidget);
    });

    testUi(
      'ajouter à un nouveau pack : confidentialité, nom, création puis copie',
      (t) async {
        await seedReceived();
        await openSheet(t);
        await t.tap(find.text('Ajouter à un pack'));
        await settle(t);
        await t.tap(find.text('Nouveau pack'));
        await settle(t);
        await t.tap(find.text("J'ai compris"));
        await settle(t);
        await t.enterText(find.byType(TextField), 'Reçus');
        await t.tap(find.text('Créer'));
        await settle(t);
        expect(
          api.calls,
          containsAllInOrder(['create', 'patch:43', 'copy:701:43']),
        );
      },
    );

    testUi('quota de 200 stickers à la copie : message traduit', (t) async {
      await seedReceived();
      await openSheet(t);
      api.failNext = TalkyException('x', 429, code: 'STICKER_QUOTA_EXCEEDED');
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      await t.tap(find.text('Famille'));
      await settle(t);
      expect(find.textContaining('200 stickers'), findsOneWidget);
    });

    testUi(
      '404 STICKER_NOT_FOUND (retiré/inaccessible) : message, pas de crash',
      (t) async {
        await seedReceived();
        await openSheet(t);
        api.failNext = TalkyException('x', 404, code: 'STICKER_NOT_FOUND');
        await t.tap(find.text('Ajouter à un pack'));
        await settle(t);
        await t.tap(find.text('Famille'));
        await settle(t);
        expect(
          find.textContaining("Ce sticker n'existe plus."),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        // L'entrée reste utilisable (rien n'est resté « occupé »).
        expect(find.text('Ajouter à un pack'), findsOneWidget);
      },
    );

    testUi('signaler un sticker retiré (404 uniforme) : même message', (
      t,
    ) async {
      await seedReceived();
      await openSheet(t);
      api.failNext = TalkyException('x', 404, code: 'STICKER_NOT_FOUND');
      await t.tap(find.text('Signaler'));
      await settle(t);
      await t.tap(find.text('Spam'));
      await settle(t);
      expect(find.textContaining("Ce sticker n'existe plus."), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testUi('pack Plus : 403 SUBSCRIPTION_REQUIRED ouvre le panneau Plus', (
      t,
    ) async {
      await seedReceived();
      await openSheet(t);
      api.failNext = TalkyException(
        'x',
        403,
        code: 'SUBSCRIPTION_REQUIRED',
        details: {'feature': 'stickers_premium'},
      );
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      await t.tap(find.text('Famille'));
      await settle(t);
      expect(t.takeException(), isNull);
      // Pas de message d'erreur générique ni de succès : c'est le panneau Plus.
      expect(find.text('Sticker ajouté à votre pack.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testUi('image déjà possédée (reutilise) : message dédié', (t) async {
      await seedReceived();
      api.copyReused = true;
      await openSheet(t);
      await t.tap(find.text('Ajouter à un pack'));
      await settle(t);
      await t.tap(find.text('Famille'));
      await settle(t);
      expect(
        find.text('Cette image est déjà dans vos stickers.'),
        findsOneWidget,
      );
    });

    for (final b in Brightness.values) {
      for (final lang in ['fr', 'en', 'zh']) {
        testUi('rendu — ${b.name} / $lang', (t) async {
          await seedReceived();
          await openSheet(t, b: b, lang: lang);
          expect(t.takeException(), isNull);
          expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
          expect(find.byIcon(Icons.library_add_outlined), findsOneWidget);
        });
      }
    }
  });

  group('lien de partage reçu', () {
    Future<void> open(
      WidgetTester t, {
      Brightness b = Brightness.light,
      String lang = 'fr',
    }) async {
      await t.pumpWidget(
        screen(
          StickerSharePreviewScreen(token: kToken),
          b: b,
          lang: lang,
        ),
      );
      await settle(t);
    }

    testUi('aperçu en lecture seule puis installation (copie)', (t) async {
      await open(t);
      expect(api.calls, contains('getShare:$kToken'));
      expect(find.text('Les copains'), findsOneWidget);
      expect(find.text('2 stickers'), findsOneWidget);
      expect(find.text('😎'), findsOneWidget);
      expect(find.textContaining('votre propre copie'), findsOneWidget);
      await t.tap(find.text('Ajouter à mes packs'));
      await settle(t);
      expect(api.calls, contains('addShare:$kToken'));
      expect(
        find.textContaining('Pack ajouté à vos créations.'),
        findsOneWidget,
      );
      expect(find.textContaining('1 image(s) ignorée(s)'), findsOneWidget);
      // L'état « déjà ajouté » remplace le bouton.
      expect(find.text('Déjà ajouté'), findsOneWidget);
      expect(find.text('Ajouter à mes packs'), findsNothing);
    });

    testUi('déjà installé : « Déjà ajouté », pas de bouton', (t) async {
      api.sharePreview = Map.of(fx('share-preview-deja.json') as Map).cast();
      await open(t);
      expect(find.text('Déjà ajouté'), findsOneWidget);
      expect(find.text('Ajouter à mes packs'), findsNothing);
    });

    testUi('mon propre pack : « C\'est votre propre pack. »', (t) async {
      api.sharePreview = {...api.sharePreview, 'mine': true};
      await open(t);
      expect(find.text("C'est votre propre pack."), findsOneWidget);
      expect(find.text('Ajouter à mes packs'), findsNothing);
    });

    testUi('lien révoqué ou inconnu : message unique, réessayer', (t) async {
      api.failNext = TalkyException('x', 404, code: 'STICKER_PACK_UNAVAILABLE');
      await open(t);
      expect(find.textContaining("n'est plus disponible"), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      await t.tap(find.text('Réessayer'));
      await settle(t);
      expect(find.text('Les copains'), findsOneWidget);
    });

    testUi(
      'installation : STICKER_PACK_LIMIT, QUOTA et RATE_LIMITED traduits',
      (t) async {
        await open(t);
        api.failNext = TalkyException('x', 409, code: 'STICKER_PACK_LIMIT');
        await t.tap(find.text('Ajouter à mes packs'));
        await settle(t);
        expect(find.textContaining('limite de packs'), findsOneWidget);
        await t.pump(const Duration(seconds: 5));

        api.failNext = TalkyException('x', 429, code: 'STICKER_QUOTA_EXCEEDED');
        await t.tap(find.text('Ajouter à mes packs'));
        await settle(t);
        expect(find.textContaining('200 stickers'), findsOneWidget);
        await t.pump(const Duration(seconds: 5));

        api.failNext = TalkyException('x', 429, code: 'RATE_LIMITED');
        await t.tap(find.text('Ajouter à mes packs'));
        await settle(t);
        expect(find.textContaining('Trop de demandes'), findsOneWidget);
        // Le bouton reste disponible : rien n'a été ajouté.
        expect(find.text('Ajouter à mes packs'), findsOneWidget);
      },
    );

    for (final b in Brightness.values) {
      for (final lang in ['fr', 'en', 'zh']) {
        testUi('rendu — ${b.name} / $lang', (t) async {
          await open(t, b: b, lang: lang);
          expect(t.takeException(), isNull);
          expect(find.byType(FilledButton), findsOneWidget);
        });
      }
    }
  });
}
