// NonLoopingAnimatedSticker (V1c, T5a) : lecture UNIQUE d'un WebP animé de test
// (5 images, 50 ms), arrêt sur la dernière image, rejeu au tap, image fixe avec
// `disableAnimations`, libération des décodeurs, plafond de lectures
// simultanées, replis. Le décodage est réel (`dart:ui`), d'où `runAsync`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/semantics.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/stickers/sticker_cache.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/stickers/non_looping_animated_sticker.dart';
import 'package:talky_flutter/widgets/stickers/sticker_image.dart';

class _NoNetwork extends Fake implements CacheManager {}

final Uint8List _anime =
    File('test/fixtures/stickers/images/anime-5x50ms.webp').readAsBytesSync();

const String _url = 'https://x.test/stickers/u/1/a_b.webp';

Widget _host(
  Widget child, {
  bool reduce = false,
  Brightness b = Brightness.light,
  String lang = 'fr',
}) {
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
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

/// Fait avancer le temps réel (décodage `dart:ui`) et le temps simulé (durées
/// des images) par petits pas ; relève les images vues et le plus grand nombre
/// de lectures simultanées.
class _Probe {
  final seen = <int>[];
  var maxActive = 0;
}

Future<_Probe> _advance(
  WidgetTester t, {
  int rounds = 40,
  bool track = true,
}) async {
  final probe = _Probe();
  final f = find.byType(NonLoopingAnimatedSticker, skipOffstage: false);
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 12)));
    await t.pump(const Duration(milliseconds: 30));
    if (StickerPlayback.activeSlots > probe.maxActive) {
      probe.maxActive = StickerPlayback.activeSlots;
    }
    if (track && f.evaluate().isNotEmpty) {
      final st = t.state<NonLoopingAnimatedStickerState>(f.first);
      if (st.shownFrame >= 0 && (probe.seen.isEmpty || probe.seen.last != st.shownFrame)) {
        probe.seen.add(st.shownFrame);
      }
    }
  }
  return probe;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StickerCache.shared =
        StickerCache(manager: _NoNetwork(), canPrefetch: () async => false);
    StickerPlayback.reset();
  });
  tearDown(() {
    StickerCache.shared = null;
    StickerPlayback.reset();
  });

  NonLoopingAnimatedSticker sticker({
    String key = 'msg-1',
    List<int>? counter,
    bool animate = true,
    VoidCallback? onOpen,
    bool interactive = true,
    bool loop = false,
    Future<Uint8List> Function(String)? loader,
  }) => NonLoopingAnimatedSticker(
    url: _url,
    emoji: '😀',
    size: 100,
    playKey: key,
    loop: loop,
    animate: animate,
    interactive: interactive,
    onOpenSheet: onOpen,
    loadBytes: loader ??
        (_) async {
          counter?.add(1);
          return _anime;
        },
  );

  testWidgets('lecture unique : 5 images dans l\'ordre, arrêt sur la dernière',
      (t) async {
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(counter: loads)));
    final probe = await _advance(t);
    final st = t.state<NonLoopingAnimatedStickerState>(
        find.byType(NonLoopingAnimatedSticker));
    expect(probe.seen, [0, 1, 2, 3, 4], reason: 'chaque image, une fois, dans l\'ordre');
    expect(st.shownFrame, 4, reason: 'la lecture s\'arrête sur la dernière image');
    expect(st.isPlaying, isFalse);
    expect(st.hasImage, isTrue);
    expect(StickerPlayback.hasPlayed('msg-1'), isTrue);
    // Rien ne reboucle : encore du temps, la même image, une seule lecture.
    final more = await _advance(t, rounds: 20);
    expect(more.seen, [4]);
    expect(loads.length, 1);
    // Décodeur et place de lecture libérés dès la fin.
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
  });

  testWidgets('tap : rejoue depuis la première image, puis s\'arrête de nouveau',
      (t) async {
    final loads = <int>[];
    var opened = 0;
    await t.pumpWidget(_host(sticker(counter: loads, onOpen: () => opened++)));
    await _advance(t);
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    final probe = await _advance(t);
    expect(probe.seen, containsAllInOrder([0, 1, 2, 3, 4]));
    expect(t.state<NonLoopingAnimatedStickerState>(find.byType(NonLoopingAnimatedSticker)).shownFrame, 4);
    expect(loads.length, 2);
    expect(opened, 0, reason: 'le tap rejoue, il n\'ouvre pas la fiche');
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
  });

  testWidgets('tap pendant la lecture : ignoré (un seul décodeur par bulle)',
      (t) async {
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(counter: loads)));
    // Pendant le chargement / la lecture.
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 12)));
      await t.pump(const Duration(milliseconds: 30));
    }
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    await _advance(t);
    expect(StickerPlayback.liveCodecs, 0);
    expect(loads.length, lessThanOrEqualTo(2));
  });

  testWidgets('bouton « i » : ouvre la fiche (cible ≥ 48 dp) sans rejouer',
      (t) async {
    final loads = <int>[];
    var opened = 0;
    await t.pumpWidget(_host(sticker(counter: loads, onOpen: () => opened++)));
    await _advance(t);
    final btn = find.byKey(const ValueKey('sticker-open-sheet'));
    expect(btn, findsOneWidget);
    final size = t.getSize(btn);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await t.tap(btn);
    await _advance(t, rounds: 10);
    expect(opened, 1);
    expect(loads.length, 1, reason: 'pas de rejeu');
  });

  testWidgets('accessibilité : tap = rejouer, action « Voir la fiche »', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_host(sticker(onOpen: () {})));
    await _advance(t, rounds: 12);
    final node = t.getSemantics(find.bySemanticsLabel('Sticker animé 😀'));
    final data = node.getSemanticsData();
    expect(data.label, 'Sticker animé 😀');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.customAction), isTrue);
    expect(data.hint, "Rejouer l'animation");
    handle.dispose();
  });

  testWidgets('disableAnimations : image fixe (1re image), jamais de lecture',
      (t) async {
    final loads = <int>[];
    var opened = 0;
    await t.pumpWidget(
        _host(sticker(counter: loads, onOpen: () => opened++), reduce: true));
    final probe = await _advance(t, rounds: 20);
    final st = t.state<NonLoopingAnimatedStickerState>(
        find.byType(NonLoopingAnimatedSticker));
    expect(probe.seen, [0]);
    expect(st.shownFrame, 0);
    expect(st.isPlaying, isFalse);
    expect(StickerPlayback.hasPlayed('msg-1'), isFalse);
    // Rien à rejouer : le tap ouvre la fiche, et le bouton « i » disparaît.
    expect(find.byKey(const ValueKey('sticker-open-sheet')), findsNothing);
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    await _advance(t, rounds: 10);
    expect(opened, 1);
    expect(loads.length, 1);
    expect(StickerPlayback.liveCodecs, 0);
  });

  testWidgets('animate: false (fiche) : image fixe, aucun geste', (t) async {
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(counter: loads, animate: false)));
    final probe = await _advance(t, rounds: 20);
    expect(probe.seen, [0]);
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    await _advance(t, rounds: 10);
    expect(loads.length, 1);
    expect(find.byKey(const ValueKey('sticker-open-sheet')), findsNothing);
  });

  testWidgets('déjà joué dans la session : remontage en image fixe', (t) async {
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(counter: loads)));
    await _advance(t);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_host(sticker(counter: loads)));
    final probe = await _advance(t, rounds: 25);
    expect(probe.seen, [0], reason: 'pas de seconde lecture automatique');
    expect(loads.length, 2, reason: 'une lecture + une image fixe');
  });

  testWidgets('hors écran : image fixe, puis une lecture quand il devient visible',
      (t) async {
    final ctrl = ScrollController();
    addTearDown(ctrl.dispose);
    final loads = <int>[];
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          controller: ctrl,
          scrollCacheExtent: const ScrollCacheExtent.pixels(4000), // monté bien avant d'être visible
          children: [
            const SizedBox(height: 1500),
            sticker(counter: loads),
            const SizedBox(height: 1500),
          ],
        ),
      ),
    ));
    final probe = await _advance(t, rounds: 20);
    expect(probe.seen, [0], reason: 'monté mais hors écran : première image');
    expect(StickerPlayback.hasPlayed('msg-1'), isFalse);

    ctrl.jumpTo(1300);
    final after = await _advance(t, rounds: 40);
    expect(after.seen, containsAllInOrder([0, 1, 2, 3, 4]));
    expect(StickerPlayback.hasPlayed('msg-1'), isTrue);
    expect(StickerPlayback.liveCodecs, 0);
  });

  testWidgets('démontage en pleine lecture : décodeur et place libérés',
      (t) async {
    await t.pumpWidget(_host(sticker()));
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 12)));
      await t.pump(const Duration(milliseconds: 30));
    }
    final st = t.state<NonLoopingAnimatedStickerState>(
        find.byType(NonLoopingAnimatedSticker));
    expect(st.isPlaying, isTrue, reason: 'on est bien en pleine lecture');
    expect(StickerPlayback.activeSlots, 1);
    await t.pumpWidget(const SizedBox());
    await _advance(t, rounds: 15, track: false);
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('plafond : jamais plus de maxConcurrent lectures simultanées, toutes finissent',
      (t) async {
    await t.pumpWidget(_host(Wrap(
      children: [
        for (var i = 0; i < 6; i++)
          SizedBox(
            height: 120,
            width: 120,
            child: NonLoopingAnimatedSticker(
              url: _url,
              emoji: '😀',
              size: 120,
              playKey: 'bulle-$i',
              loadBytes: (_) async => _anime,
            ),
          ),
      ],
    )));
    final probe = await _advance(t, rounds: 120);
    expect(probe.maxActive, lessThanOrEqualTo(StickerPlayback.maxConcurrent));
    expect(probe.maxActive, greaterThan(0));
    for (var i = 0; i < 6; i++) {
      expect(StickerPlayback.hasPlayed('bulle-$i'), isTrue, reason: 'bulle $i');
    }
    final states = t.stateList<NonLoopingAnimatedStickerState>(
        find.byType(NonLoopingAnimatedSticker));
    expect(states.map((s) => s.shownFrame), everyElement(4));
    expect(StickerPlayback.activeSlots, 0);
    expect(StickerPlayback.waitingSlots, 0);
    expect(StickerPlayback.liveCodecs, 0);
  });

  testWidgets('loop : tourne sans tap, plusieurs tours, un seul chargement',
      (t) async {
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(counter: loads, loop: true)));
    final probe = await _advance(t, rounds: 60);
    final firstLoop = probe.seen.indexOf(4);
    expect(firstLoop, greaterThanOrEqualTo(0));
    expect(probe.seen.sublist(firstLoop + 1), contains(0),
        reason: 'après la dernière image, la lecture repart au début');
    final st = t.state<NonLoopingAnimatedStickerState>(
        find.byType(NonLoopingAnimatedSticker));
    expect(st.isPlaying, isTrue);
    expect(loads.length, 1);
    // Démontage : décodeur et place libérés.
    await t.pumpWidget(const SizedBox());
    await _advance(t, rounds: 10, track: false);
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
  });

  testWidgets('loop au-delà du plafond : les places tournent, chacun joue',
      (t) async {
    const n = StickerPlayback.maxConcurrent + 2;
    await t.pumpWidget(_host(Wrap(
      children: [
        for (var i = 0; i < n; i++)
          SizedBox(
            height: 120,
            width: 120,
            child: NonLoopingAnimatedSticker(
              url: _url,
              emoji: '😀',
              size: 120,
              loop: true,
              loadBytes: (_) async => _anime,
            ),
          ),
      ],
    )));
    final everPlayed = List.filled(n, false);
    var maxActive = 0;
    for (var r = 0; r < 120; r++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 12)));
      await t.pump(const Duration(milliseconds: 30));
      if (StickerPlayback.activeSlots > maxActive) {
        maxActive = StickerPlayback.activeSlots;
      }
      final states = t.stateList<NonLoopingAnimatedStickerState>(
          find.byType(NonLoopingAnimatedSticker)).toList();
      for (var i = 0; i < n; i++) {
        if (states[i].isPlaying) everPlayed[i] = true;
      }
    }
    expect(maxActive, lessThanOrEqualTo(StickerPlayback.maxConcurrent));
    expect(everPlayed, everyElement(isTrue));
    await t.pumpWidget(const SizedBox());
    await _advance(t, rounds: 10, track: false);
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
    expect(StickerPlayback.waitingSlots, 0);
  });

  testWidgets('vignettes de grille : leur propre plafond, plus large',
      (t) async {
    const n = StickerPlayback.maxConcurrent + 4;
    await t.pumpWidget(_host(Wrap(
      children: [
        for (var i = 0; i < n; i++)
          SizedBox(
            height: 76,
            width: 76,
            child: NonLoopingAnimatedSticker(
              url: _url,
              emoji: '😀',
              size: 76,
              loop: true,
              interactive: false,
              loadBytes: (_) async => _anime,
            ),
          ),
      ],
    )));
    await _advance(t, rounds: 10, track: false);
    expect(StickerPlayback.activeSlots, n, reason: 'toute la grille bouge');
    await t.pumpWidget(const SizedBox());
    await _advance(t, rounds: 10, track: false);
    expect(StickerPlayback.liveCodecs, 0);
    expect(StickerPlayback.activeSlots, 0);
  });

  testWidgets('décodage impossible : image fixe, pas « Sticker retiré »',
      (t) async {
    await t.pumpWidget(_host(sticker(
        loader: (_) async => Uint8List.fromList(List.filled(64, 7)))));
    await _advance(t, rounds: 20);
    expect(find.byType(StickerImage), findsOneWidget);
    expect(find.text('Sticker retiré'), findsNothing);
    expect(StickerPlayback.liveCodecs, 0);
  });

  testWidgets('réseau en panne : image fixe de repli, pas « Sticker retiré »',
      (t) async {
    await t.pumpWidget(_host(sticker(loader: (_) async => throw Exception('hors ligne'))));
    await _advance(t, rounds: 12);
    expect(find.byType(StickerImage), findsOneWidget);
    expect(find.text('Sticker retiré'), findsNothing);
  });

  testWidgets('404 / 410 : « Sticker retiré »', (t) async {
    for (final code in [404, 410]) {
      StickerPlayback.reset();
      await t.pumpWidget(_host(sticker(
          loader: (_) async => throw HttpExceptionWithStatus(code, 'gone',
              uri: Uri.parse(_url)))));
      await _advance(t, rounds: 12);
      expect(find.text('Sticker retiré'), findsOneWidget, reason: '$code');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('URL hors Alanya : repli, aucun téléchargement', (t) async {
    await t.pumpWidget(_host(NonLoopingAnimatedSticker(
      url: 'https://evil.example/sticker.webp',
      emoji: '😀',
      playKey: 'k',
    )));
    await _advance(t, rounds: 5, track: false);
    expect(find.byType(StickerFallback), findsOneWidget);
    expect(StickerPlayback.liveCodecs, 0);
  });

  testWidgets('mode sélection (interactive: false) : aucun geste capté',
      (t) async {
    var opened = 0;
    final loads = <int>[];
    await t.pumpWidget(_host(sticker(
        counter: loads, interactive: false, onOpen: () => opened++)));
    await _advance(t);
    expect(find.byKey(const ValueKey('sticker-open-sheet')), findsNothing);
    await t.tap(find.byType(NonLoopingAnimatedSticker));
    await _advance(t, rounds: 8);
    expect(loads.length, 1);
    expect(opened, 0);
  });

  for (final lang in ['fr', 'en', 'zh']) {
    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('rendu $lang / ${b.name} : image, bouton « i », sans débordement',
          (t) async {
        await t.pumpWidget(_host(sticker(onOpen: () {}), lang: lang, b: b));
        await _advance(t);
        expect(find.byKey(const ValueKey('sticker-open-sheet')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
