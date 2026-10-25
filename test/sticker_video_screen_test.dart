// Sticker animé depuis une VIDÉO (V1c, contrat §4d) : écran de découpe (fenêtre,
// forme, boucle, cycle de vie, erreurs), branchement dans l'écran d'un pack et dans
// la tuile « Créer », en clair et en sombre, fr/en/zh. Lecteur et serveur factices :
// la vraie lecture de `video_player` ne tourne pas en `flutter test`.
import 'dart:async';
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
import 'package:talky_flutter/core/services/stickers/sticker_video_check.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/stickers/non_looping_animated_sticker.dart';
import 'package:talky_flutter/widgets/stickers/sticker_created_pack_screen.dart';
import 'package:talky_flutter/widgets/stickers/sticker_quick_create.dart';
import 'package:talky_flutter/widgets/stickers/sticker_video_screen.dart';
import 'package:talky_flutter/widgets/stickers/video_window_player.dart';

import 'support/sticker_creation_fakes.dart';

class _NoNetwork extends Fake implements CacheManager {}

/// Lecteur factice : enregistre ce que l'écran lui demande, sans moteur vidéo.
class FakePlayer extends ChangeNotifier implements VideoWindowPlayer {
  FakePlayer({this.durationMs = 10000, this.failInit = false, this.videoSize = const Size(1920, 1080)});

  @override
  final int durationMs;
  final bool failInit;
  @override
  final Size videoSize;

  int _pos = 0;
  bool _playing = false;
  bool disposed = false;
  final seeks = <int>[];
  int plays = 0;
  int pauses = 0;

  @override
  int get positionMs => _pos;
  @override
  bool get isPlaying => _playing;

  @override
  Future<void> initialize() async {
    if (failInit) throw StateError('illisible');
  }

  @override
  Future<void> seekTo(int ms) async {
    seeks.add(ms);
    _pos = ms;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    plays += 1;
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauses += 1;
    _playing = false;
    notifyListeners();
  }

  /// Simule l'avancée de la lecture.
  void advanceTo(int ms) {
    _pos = ms;
    notifyListeners();
  }

  @override
  Widget buildView() => const ColoredBox(key: ValueKey('fake-video'), color: Color(0xFF336699));

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    super.dispose();
  }
}

Uint8List _mp4([int extra = 64]) => Uint8List.fromList([
  0, 0, 0, 24, ...'ftyp'.codeUnits, ...'isom'.codeUnits, ...List.filled(extra, 7),
]);

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
  late FakePlayer player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StickerCache.shared = StickerCache(manager: _NoNetwork(), canPrefetch: () async => false);
    StickerPlayback.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeCreationApi();
    features = StickerFeatures();
    stickers = StickerRepository(db: db, api: OfficialStickerApi(), features: features);
    creation = StickerCreationRepository(db: db, api: api, features: features);
    player = FakePlayer();
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
      home: home,
    ),
  );

  Future<void> settle(WidgetTester t, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> openScreen(
    WidgetTester t, {
    FakePlayer? p,
    String lang = 'fr',
    Brightness b = Brightness.light,
    bool reduce = false,
    String filename = 'clip.mp4',
    int? packId = 41,
    Size surface = const Size(400, 1000),
  }) async {
    // Fenêtre assez haute : la liste ne construit que ce qui est visible.
    await t.binding.setSurfaceSize(surface);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.runAsync(() => creation.syncCreated());
    final used = p ?? player;
    await t.pumpWidget(app(
      StickerVideoScreen(
        packId: packId,
        bytes: _mp4(),
        filename: filename,
        playerFactory: (bytes, kind) async => used,
      ),
      lang: lang,
      b: b,
      reduce: reduce,
    ));
    await settle(t);
  }

  final add = find.byKey(const ValueKey('sticker-video-add'));
  final startKey = find.byKey(const ValueKey('sticker-video-start'));
  final durationKey = find.byKey(const ValueKey('sticker-video-duration'));

  Slider sliderIn(Finder key) => (find.descendant(of: key, matching: find.byType(Slider)).evaluate().single.widget) as Slider;

  group('chargement', () {
    testUi('vidéo lisible : aperçu, lecture automatique, fenêtre 3 s par défaut', (t) async {
      await openScreen(t);
      expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
      expect(player.plays, 1, reason: 'lecture lancée une fois l\'écran visible');
      expect(player.seeks.first, 0, reason: 'positionnée sur le début de la fenêtre');
      expect(find.text('3.0 s'), findsOneWidget);
      expect(add, findsOneWidget);
    });

    testUi('vidéo illisible : message, pas de curseur, bouton Annuler', (t) async {
      final bad = FakePlayer(failInit: true);
      await openScreen(t, p: bad);
      expect(find.byKey(const ValueKey('sticker-video-error')), findsOneWidget);
      expect(find.textContaining('Impossible de lire'), findsOneWidget);
      expect(add, findsNothing);
      expect(bad.disposed, isTrue, reason: 'lecteur libéré après l\'échec');
    });

    testUi('vidéo de moins de 500 ms : refusée avec un message clair', (t) async {
      final court = FakePlayer(durationMs: 300);
      await openScreen(t, p: court);
      expect(find.textContaining('trop courte'), findsOneWidget);
      expect(add, findsNothing);
      expect(court.disposed, isTrue);
    });

    testUi('vidéo plus courte que 3 s : la fenêtre est toute la vidéo, durée non réglable plus haut', (t) async {
      await openScreen(t, p: FakePlayer(durationMs: 1800));
      expect(find.text('1.8 s'), findsOneWidget);
      final d = sliderIn(durationKey);
      expect(d.max, 1800);
      expect(sliderIn(startKey).onChanged, isNull, reason: 'rien à décaler : la fenêtre couvre toute la vidéo');
    });

    testUi('« réduire les animations » : la lecture ne démarre pas toute seule', (t) async {
      await openScreen(t, reduce: true);
      expect(player.plays, 0);
      await t.tap(find.byKey(const ValueKey('sticker-video-play')));
      await settle(t, rounds: 2);
      expect(player.plays, 1, reason: 'mais un bouton visible la lance');
    });
  });

  group('fenêtre et boucle', () {
    testUi('le curseur de début décale la fenêtre sans dépasser la fin, puis la lecture saute au début', (t) async {
      await openScreen(t);
      final s = sliderIn(startKey);
      expect(s.max, 7000, reason: '10 s − 3 s');
      s.onChanged!(5000);
      await t.pump();
      expect(find.text('00:05.0'), findsOneWidget);
      s.onChangeEnd!(5000);
      await settle(t, rounds: 1);
      expect(player.seeks.last, 5000);
      s.onChanged!(99999);
      await t.pump();
      expect(find.text('00:07.0'), findsOneWidget, reason: 'bloqué à la fin moins la durée');
    });

    testUi('le curseur de durée : 500 ms à 3 s, la fenêtre reste dans la vidéo', (t) async {
      await openScreen(t);
      final s = sliderIn(durationKey);
      expect([s.min, s.max], [500, 3000]);
      s.onChanged!(1200);
      await t.pump();
      expect(find.text('1.2 s'), findsOneWidget);
      s.onChanged!(100);
      await t.pump();
      expect(find.text('0.5 s'), findsOneWidget, reason: 'jamais sous 500 ms');
    });

    testUi('boucle : en fin de fenêtre, retour au début de la fenêtre', (t) async {
      await openScreen(t);
      sliderIn(startKey).onChanged!(2000);
      await t.pump();
      player.advanceTo(2000); // lecture en cours dans la fenêtre
      final avant = player.seeks.length;
      player.advanceTo(5000); // fin de la fenêtre (2000 + 3000)
      await settle(t, rounds: 1);
      expect(player.seeks.length, greaterThan(avant));
      expect(player.seeks.last, 2000);
    });

    testUi('arrière-plan : pause ; retour : reprise (batterie)', (t) async {
      await openScreen(t);
      expect(player.isPlaying, isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(player.isPlaying, isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(player.isPlaying, isTrue);
    });

    testUi('arrière-plan alors que la lecture était en pause : elle ne repart pas', (t) async {
      await openScreen(t);
      await t.tap(find.byKey(const ValueKey('sticker-video-play')));
      await settle(t, rounds: 1);
      expect(player.isPlaying, isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(player.isPlaying, isFalse);
    });

    testUi('sortie de l\'écran : lecteur libéré', (t) async {
      await openScreen(t);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 20));
      expect(player.disposed, isTrue);
    });
  });

  group('forme', () {
    testUi('carré arrondi par défaut, cercle, carré : l\'aperçu suit', (t) async {
      await openScreen(t);
      double radius() {
        final clip = t.widget<ClipRRect>(find.byKey(const ValueKey('sticker-video-clip')));
        return clip.borderRadius.resolve(TextDirection.ltr).topLeft.x;
      }
      expect(radius(), closeTo(240 * 0.22, 0.01));
      await t.tap(find.text('Cercle'));
      await t.pump();
      expect(radius(), 120);
      await t.tap(find.text('Carré'));
      await t.pump();
      expect(radius(), 0);
    });
  });

  group('ajout', () {
    testUi('« Ajouter » : vidéo entière + fenêtre + forme, retour avec le résultat', (t) async {
      await openScreen(t, filename: 'vacances.mov');
      sliderIn(startKey).onChanged!(1500);
      sliderIn(durationKey).onChanged!(2000); // sans réaffichage entre les deux
      await t.pump();
      await t.tap(find.text('Cercle'));
      await t.pump();
      await t.runAsync(() => creation.features.apply({'creation': true, 'animated': true, 'video': true}));
      await t.tap(add);
      await settle(t);
      expect(api.calls.where((c) => c.startsWith('video:')), ['video:vacances.mov:1500:2000']);
      expect(api.animatedShapes.last, 'cercle');
      expect(find.byType(StickerVideoScreen), findsOneWidget, reason: 'pas d\'écran de résultat ici : le test lit la pile');
    });

    testUi('conversion en cours : voile « Envoi et conversion », Annuler interrompt', (t) async {
      await t.runAsync(() => creation.features.apply({'creation': true, 'animated': true, 'video': true}));
      api.holdAnimated = Completer<void>();
      await openScreen(t);
      await t.tap(add);
      await settle(t, rounds: 2);
      expect(find.textContaining('Envoi et conversion'), findsWidgets);
      expect(find.byKey(const ValueKey('sticker-animated-cancel')), findsOneWidget);
      expect(player.isPlaying, isFalse, reason: 'lecture coupée pendant l\'envoi');
      await t.tap(find.byKey(const ValueKey('sticker-animated-cancel')));
      await settle(t);
      expect(api.calls, contains('animated-aborted'));
      expect(find.byType(StickerVideoScreen), findsOneWidget, reason: 'on reste sur l\'écran');
      expect(find.byKey(const ValueKey('sticker-animated-cancel')), findsNothing);
    });

    for (final (lang, code, status, extrait) in [
      ('fr', 'STICKER_ASSET_INVALID', 422, 'prise en charge ou est trop détaillée'),
      ('en', 'STICKER_ASSET_INVALID', 422, 'isn\'t supported or is too detailed'),
      ('zh', 'STICKER_ASSET_INVALID', 422, '内容过于复杂'),
      ('fr', 'RATE_LIMITED', 429, '10 par heure'),
      ('fr', 'SERVICE_UNAVAILABLE', 503, 'occupé'),
    ]) {
      testUi('erreur serveur $code ($lang) : message traduit, on reste sur l\'écran', (t) async {
        await t.runAsync(() => creation.features.apply({'creation': true, 'animated': true, 'video': true}));
        await openScreen(t, lang: lang);
        api.failNext = TalkyException('x', status, code: code);
        await t.tap(add);
        await settle(t);
        expect(find.textContaining(extrait), findsOneWidget);
        expect(find.byType(StickerVideoScreen), findsOneWidget);
        expect(add, findsOneWidget, reason: 'on peut réessayer');
      });
    }

    testUi('404 NOT_FOUND : animés fermés, option masquée, écran quitté', (t) async {
      await t.runAsync(() => creation.features.apply({'creation': true, 'animated': true, 'video': true}));
      await t.pumpWidget(app(
        Builder(builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => StickerVideoScreen(packId: 41, bytes: _mp4(), filename: 'a.mp4', playerFactory: (_, _) async => player),
          )),
          child: const Text('ouvrir'),
        )),
      ));
      await t.tap(find.text('ouvrir'));
      await settle(t);
      api.failNext = TalkyException('nope', 404, code: 'NOT_FOUND');
      await t.tap(add);
      await settle(t, rounds: 16);
      expect(find.byType(StickerVideoScreen), findsNothing, reason: 'écran quitté');
      expect(features.animated.value, isFalse);
      expect(features.video.value, isFalse, reason: 'la vidéo se ferme avec les animés');
    });
  });

  group('refus avant tout envoi', () {
    for (final (nom, bytes, issue) in [
      ('image HEIC', Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits, ...List.filled(40, 1)]), StickerVideoIssue.format),
      ('octets quelconques', Uint8List.fromList(List.filled(100, 9)), StickerVideoIssue.format),
    ]) {
      test('$nom → ${issue.name}', () {
        expect(
          () => StickerVideoCheck.validate(bytes),
          throwsA(isA<StickerVideoRejected>().having((e) => e.issue, 'issue', issue)),
        );
      });
    }

    test('serveur sans ffmpeg (features.video faux) : unsupported, rien d\'envoyé', () async {
      await features.apply({'creation': true, 'animated': true, 'video': false});
      await expectLater(
        creation.addVideoSticker(
          1, _mp4(),
          filename: 'a.mp4',
          shape: StickerAnimatedShape.cercle,
          window: const StickerVideoWindow(startMs: 0, durationMs: 1000),
        ),
        throwsA(isA<StickerVideoRejected>().having((e) => e.issue, 'issue', StickerVideoIssue.unsupported)),
      );
      expect(api.calls.where((c) => c.startsWith('animated')), isEmpty);
    });

    test('nom de fichier : l\'extension suit le contenu', () async {
      await features.apply({'creation': true, 'animated': true, 'video': true});
      await creation.syncCreated();
      await creation.addVideoSticker(
        41, _mp4(),
        filename: 'sans-extension',
        shape: StickerAnimatedShape.carre,
        window: const StickerVideoWindow(startMs: 200, durationMs: 800),
      );
      expect(api.calls, contains('video:sticker.mp4:200:800'));
    });
  });

  group('branchement', () {
    Future<void> openPack(WidgetTester t, {Future<_Picked?> Function()? pick, StickerVideoFlow? flow, String lang = 'fr'}) async {
      await t.runAsync(() => creation.syncCreated());
      await t.pumpWidget(app(
        Scaffold(
          body: StickerCreatedPackScreen(
            packId: 41,
            pickImage: pick ?? () async => (bytes: _mp4(), name: 'clip.mp4'),
            pickAnimated: () async => (bytes: _mp4(), name: 'clip.mp4'),
            videoFlow: flow ?? (context, packId, bytes, name) async => null,
            adaptImage: (b) async => b,
            shareText: (_, _) async {},
          ),
        ),
        lang: lang,
      ));
      await settle(t);
    }

    testUi('vidéo choisie, serveur sans ffmpeg : message « pas encore prises en charge », rien ne s\'ouvre', (t) async {
      await features.apply({'creation': true, 'animated': true, 'video': false});
      var ouvert = false;
      await openPack(t, flow: (c, p, b, n) async { ouvert = true; return null; });
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      expect(ouvert, isFalse);
      expect(find.textContaining('pas encore prises en charge'), findsOneWidget);
    });

    testUi('vidéo choisie, serveur avec ffmpeg : écran de découpe ouvert avec les octets et le nom', (t) async {
      await features.apply({'creation': true, 'animated': true, 'video': true});
      int? packRecu;
      String? nomRecu;
      await openPack(t, flow: (c, p, b, n) async { packRecu = p; nomRecu = n; return null; });
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      expect([packRecu, nomRecu], [41, 'clip.mp4']);
    });

    testUi('la cellule « Sticker animé » accepte aussi une vidéo', (t) async {
      await features.apply({'creation': true, 'animated': true, 'video': true});
      var ouvert = false;
      await openPack(t, flow: (c, p, b, n) async { ouvert = true; return null; });
      await t.tap(find.byKey(const ValueKey('sticker-add-animated')));
      await settle(t);
      expect(ouvert, isTrue);
    });

    testUi('l\'option vidéo n\'existe pas quand les animés sont fermés (la vidéo est refusée)', (t) async {
      await features.apply({'creation': true, 'animated': false, 'video': true});
      expect(features.video.value, isFalse, reason: 'jamais de vidéo sans les animés');
      var ouvert = false;
      await openPack(t, flow: (c, p, b, n) async { ouvert = true; return null; });
      await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(t);
      expect(ouvert, isFalse);
    });

    testUi('tuile « Créer » : vidéo → écran de découpe sans pack', (t) async {
      await features.apply({'creation': true, 'animated': true, 'video': true});
      await t.runAsync(() => creation.syncCreated());
      String? nomRecu;
      await t.pumpWidget(app(Scaffold(
        body: SizedBox(
          width: 120,
          height: 120,
          child: StickerCreateTile(
            creation: creation,
            stickers: stickers,
            onViewPack: (_) {},
            hooks: StickerCreateHooks(
              pickImage: () async => (bytes: _mp4(), name: 'clip.mp4'),
              videoFlow: (context, bytes, name) async { nomRecu = name; return null; },
            ),
          ),
        ),
      )));
      await settle(t);
      SharedPreferences.setMockInitialValues({'stickers_privacy_ack': true});
      await t.tap(find.byType(StickerCreateTile));
      await settle(t, rounds: 8);
      // L'avis de confidentialité s'affiche une première fois : on l'accepte.
      final ok = find.text('J\'ai compris');
      if (ok.evaluate().isNotEmpty) {
        await t.tap(ok);
        await settle(t, rounds: 8);
      }
      expect(nomRecu, 'clip.mp4');
    });
  });

  group('apparence', () {
    for (final b in Brightness.values) {
      for (final lang in ['fr', 'en', 'zh']) {
        testUi('écran de découpe — $lang / ${b.name} : curseurs ≥ 48 dp, sans débordement', (t) async {
          await openScreen(t, lang: lang, b: b, surface: const Size(360, 700));
          expect(t.takeException(), isNull);
          for (final k in [startKey, durationKey]) {
            expect(t.getSize(k).height, greaterThanOrEqualTo(48), reason: 'cible tactile du curseur');
          }
          expect(t.getSize(find.byKey(const ValueKey('sticker-video-play'))).height, greaterThanOrEqualTo(48));
          expect(t.getSize(add).height, greaterThanOrEqualTo(48));
          // Les curseurs se lisent à voix haute avec leur valeur.
          final sem = t.getSemantics(startKey);
          expect(sem.value, isNotEmpty);
        });
      }
    }
  });
}
