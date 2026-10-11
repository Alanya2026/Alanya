// Éditeur d'image (T4c) : outil « Détourer » dans l'écran — détourage
// automatique (segmenteur injecté), pinceau / gomme, réinitialisation,
// messages d'erreur, clair/sombre × fr/en/zh, accessibilité. Aucun ML Kit réel.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/features/media_editor/cutout/person_segmenter.dart';
import 'package:talky_flutter/features/media_editor/media_editor_screen.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

import 'support/media_editor_fakes.dart';

void testUi(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

Future<void> settle(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 80));
  }
}

class EditorHost {
  MediaEditorResult? result;
  bool closed = false;
}

Future<EditorHost> openEditor(
  WidgetTester t,
  Uint8List bytes, {
  PersonSegmenter? segmenter,
  MediaEditorMode mode = MediaEditorMode.sticker,
  Brightness b = Brightness.light,
  String lang = 'fr',
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final host = EditorHost();
  await t.pumpWidget(
    MaterialApp(
      theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('host-open'),
              onPressed: () async {
                final r = await Navigator.of(context).push<MediaEditorResult>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => MediaEditorScreen(
                      source: MediaEditorSource.bytes(bytes),
                      mode: mode,
                      personSegmenter: segmenter,
                    ),
                  ),
                );
                host.result = r;
                host.closed = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('host-open')));
  await settle(t);
  return host;
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tool(WidgetTester t, String tool) async {
  await t.tap(_key('editor-tool-$tool'));
  await settle(t, rounds: 2);
}

bool _enabled(WidgetTester t, String key) =>
    t.widget<IconButton>(_key(key)).onPressed != null;

bool _chipEnabled(WidgetTester t, String key) =>
    t.widget<ActionChip>(_key(key)).onPressed != null;

Future<void> _drag(WidgetTester t, Offset from, Offset delta) async {
  final g = await t.startGesture(from);
  for (var i = 1; i <= 5; i++) {
    await g.moveBy(delta / 5);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await t.pump(const Duration(milliseconds: 50));
}

Future<Uint8List> _png(WidgetTester t) async =>
    (await t.runAsync(() => solidPng(100, 100)))!;

Future<void> _finish(WidgetTester t, EditorHost host) async {
  await t.tap(_key('editor-done'));
  for (var i = 0; i < 40 && !host.closed; i++) {
    await settle(t, rounds: 1);
  }
}

void main() {
  // Un toucher manqué (bouton hors écran, masqué) doit faire échouer le test.
  WidgetController.hitTestWarningShouldBeFatal = true;
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testUi('outil Détourer : présent pour un sticker, absent pour une photo', (
    t,
  ) async {
    final bytes = await _png(t);
    await openEditor(t, bytes, segmenter: FakePersonSegmenter());
    expect(_key('editor-tool-cutout'), findsOneWidget);
    expect(find.text('Détourer'), findsOneWidget);
  });

  testUi('photo : pas de détourage (une photo reste opaque)', (t) async {
    final bytes = await _png(t);
    await openEditor(
      t,
      bytes,
      segmenter: FakePersonSegmenter(),
      mode: MediaEditorMode.photo,
    );
    expect(_key('editor-tool-cutout'), findsNothing);
  });

  testUi('panneau : le texte du plan, tous les réglages', (t) async {
    final bytes = await _png(t);
    await openEditor(t, bytes, segmenter: FakePersonSegmenter());
    await _tool(t, 'cutout');
    expect(
      find.text(
        'Détourage automatique : personnes. Pour le reste, utilisez le pinceau.',
      ),
      findsOneWidget,
    );
    expect(_key('editor-cutout-auto'), findsOneWidget);
    expect(_key('editor-cutout-keep'), findsOneWidget);
    expect(_key('editor-cutout-erase'), findsOneWidget);
    expect(_key('editor-cutout-soft'), findsOneWidget);
    expect(_key('editor-cutout-reset'), findsOneWidget);
    expect(find.text('Taille du pinceau'), findsOneWidget);
    expect(_chipEnabled(t, 'editor-cutout-reset'), isFalse, reason: 'rien');
  });

  testUi('détourage automatique : masque posé, annulable, exporté transparent',
      (t) async {
    final bytes = await _png(t);
    final seg = FakePersonSegmenter(mask: leftHalfMask(10, 10));
    final host = await openEditor(t, bytes, segmenter: seg);
    await _tool(t, 'cutout');
    expect(_enabled(t, 'editor-undo'), isFalse);

    await t.tap(_key('editor-cutout-auto'));
    await settle(t, rounds: 4);
    expect(seg.calls, 1);
    expect(_enabled(t, 'editor-undo'), isTrue);
    expect(_chipEnabled(t, 'editor-cutout-reset'), isTrue);

    await _finish(t, host);
    final r = host.result!;
    expect(r.width, 512);
    final px = (await t.runAsync(() => decodePixels(r.png)))!;
    expect(px.alphaAt(100, 256), 255, reason: 'personne conservée');
    expect(px.alphaAt(400, 256), 0, reason: 'fond transparent');
  });

  testUi('aucune personne : message clair, rien ne change', (t) async {
    final bytes = await _png(t);
    final seg = FakePersonSegmenter(
      error: const PersonSegmentationException(
        PersonSegmentationIssue.noPerson,
      ),
    );
    await openEditor(t, bytes, segmenter: seg);
    await _tool(t, 'cutout');
    await t.tap(_key('editor-cutout-auto'));
    await settle(t, rounds: 3);
    expect(find.textContaining('Aucune personne détectée'), findsOneWidget);
    expect(_enabled(t, 'editor-undo'), isFalse);
    expect(_chipEnabled(t, 'editor-cutout-auto'), isTrue, reason: 'réessayer');
  });

  testUi('échec natif : message, le pinceau reste utilisable', (t) async {
    final bytes = await _png(t);
    final seg = FakePersonSegmenter(
      error: const PersonSegmentationException(
        PersonSegmentationIssue.failed,
        'boom',
      ),
    );
    await openEditor(t, bytes, segmenter: seg);
    await _tool(t, 'cutout');
    await t.tap(_key('editor-cutout-auto'));
    await settle(t, rounds: 3);
    expect(find.textContaining('a échoué'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing, reason: 'pas de détail');
    expect(_enabled(t, 'editor-undo'), isFalse);
    await _drag(t, t.getCenter(_key('editor-document')), const Offset(40, 0));
    expect(_enabled(t, 'editor-undo'), isTrue);
  });

  testUi('plateforme non prise en charge : bouton masqué, pinceau présent', (
    t,
  ) async {
    final bytes = await _png(t);
    // Sans segmenteur injecté : ML Kit réel, donc non pris en charge sur
    // la machine de test (ni Android ni iOS).
    await openEditor(t, bytes);
    await _tool(t, 'cutout');
    expect(_key('editor-cutout-auto'), findsNothing);
    expect(_key('editor-cutout-keep'), findsOneWidget);
    expect(_key('editor-cutout-erase'), findsOneWidget);
    expect(find.textContaining('utilisez le pinceau'), findsOneWidget);

    // Un segmenteur injecté mais non supporté : même résultat.
    await t.pumpWidget(const SizedBox());
    await openEditor(
      t,
      bytes,
      segmenter: FakePersonSegmenter(supported: false),
    );
    await _tool(t, 'cutout');
    expect(_key('editor-cutout-auto'), findsNothing);
  });

  testUi('calcul en cours : indicateur, bouton désactivé, puis terminé', (
    t,
  ) async {
    final bytes = await _png(t);
    final gate = Future<void>.delayed(const Duration(milliseconds: 300));
    final seg = FakePersonSegmenter(mask: leftHalfMask(8, 8), gate: gate);
    await openEditor(t, bytes, segmenter: seg);
    await _tool(t, 'cutout');
    await t.tap(_key('editor-cutout-auto'));
    await t.pump();
    expect(find.text('Détourage en cours…'), findsOneWidget);
    expect(_chipEnabled(t, 'editor-cutout-auto'), isFalse);
    await settle(t, rounds: 10);
    expect(find.text('Détourer les personnes'), findsOneWidget);
    expect(_enabled(t, 'editor-undo'), isTrue);
  });

  testUi('pinceau / gomme : un trait = une action, annuler, rétablir', (
    t,
  ) async {
    final bytes = await _png(t);
    final host = await openEditor(t, bytes, segmenter: FakePersonSegmenter());
    await _tool(t, 'cutout');
    final centre = t.getCenter(_key('editor-document'));

    // Gomme (par défaut) : efface le fond sous le doigt.
    await _drag(t, centre - const Offset(60, 0), const Offset(120, 0));
    expect(_enabled(t, 'editor-undo'), isTrue);
    expect(_chipEnabled(t, 'editor-cutout-reset'), isTrue);

    await t.tap(_key('editor-cutout-keep'));
    await t.pump();
    await _drag(t, centre, const Offset(20, 0));
    await t.tap(_key('editor-undo'));
    await t.pump();
    await t.tap(_key('editor-undo'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);
    expect(_enabled(t, 'editor-redo'), isTrue);
    expect(_chipEnabled(t, 'editor-cutout-reset'), isFalse);
    await t.tap(_key('editor-redo'));
    await t.pump();
    expect(_chipEnabled(t, 'editor-cutout-reset'), isTrue);

    // Le trait gommé laisse un trou transparent dans l'export.
    await _finish(t, host);
    final px = (await t.runAsync(() => decodePixels(host.result!.png)))!;
    expect(px.alphaAt(256, 256), 0, reason: 'trait de gomme');
    expect(px.alphaAt(256, 40), 255, reason: 'le reste est intact');
  });

  testUi('bords doux et taille : réglages sans action annulable', (t) async {
    final bytes = await _png(t);
    await openEditor(t, bytes, segmenter: FakePersonSegmenter());
    await _tool(t, 'cutout');
    await t.tap(_key('editor-cutout-soft'));
    await t.pump();
    expect(t.widget<FilterChip>(_key('editor-cutout-soft')).selected, isTrue);
    await t.drag(find.byType(Slider).first, const Offset(60, 0));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);
  });

  testUi('réinitialiser le masque : une action, annulable', (t) async {
    final bytes = await _png(t);
    final seg = FakePersonSegmenter(mask: leftHalfMask(10, 10));
    final host = await openEditor(t, bytes, segmenter: seg);
    await _tool(t, 'cutout');
    await t.tap(_key('editor-cutout-auto'));
    await settle(t, rounds: 4);
    await t.tap(_key('editor-cutout-reset'));
    await t.pump();
    expect(_chipEnabled(t, 'editor-cutout-reset'), isFalse);

    await t.tap(_key('editor-undo')); // annule la réinitialisation
    await t.pump();
    expect(_chipEnabled(t, 'editor-cutout-reset'), isTrue);
    await t.tap(_key('editor-redo'));
    await t.pump();
    await _finish(t, host);
    final px = (await t.runAsync(() => decodePixels(host.result!.png)))!;
    expect(px.alphaAt(400, 256), 255, reason: 'tout est revenu');
  });

  group('clair / sombre × fr / en / zh', () {
    for (final b in Brightness.values) {
      for (final (lang, outil, hint, auto, keep, erase, soft, reset) in [
        (
          'fr',
          'Détourer',
          'Détourage automatique : personnes. Pour le reste, utilisez le pinceau.',
          'Détourer les personnes',
          'Garder',
          'Effacer',
          'Bords doux',
          'Réinitialiser le masque',
        ),
        (
          'en',
          'Cut out',
          'Automatic cut-out: people. For everything else, use the brush.',
          'Cut out people',
          'Keep',
          'Erase',
          'Soft edges',
          'Reset mask',
        ),
        (
          'zh',
          '抠图',
          '自动抠图：仅限人物。其他内容请使用画笔。',
          '抠出人物',
          '保留',
          '擦除',
          '柔和边缘',
          '重置蒙版',
        ),
      ]) {
        testUi('outil Détourer ($lang, $b)', (t) async {
          final sem = t.ensureSemantics();
          final bytes = await _png(t);
          await openEditor(
            t,
            bytes,
            segmenter: FakePersonSegmenter(),
            lang: lang,
            b: b,
          );
          expect(find.text(outil), findsWidgets);
          await _tool(t, 'cutout');
          for (final s in [hint, auto, keep, erase, soft, reset]) {
            expect(find.text(s), findsOneWidget, reason: s);
          }
          // Cibles tactiles d'au moins 48 dp : barre d'outils et boutons.
          for (final k in [
            'editor-tool-cutout',
            'editor-cutout-keep',
            'editor-cutout-erase',
          ]) {
            final s = t.getSize(_key(k));
            expect(s.width, greaterThanOrEqualTo(48), reason: k);
            expect(s.height, greaterThanOrEqualTo(48), reason: k);
          }
          // Les boutons du pinceau sont des boutons nommés et sélectionnés.
          expect(
            t.getSemantics(find.bySemanticsLabel(erase).first),
            matchesSemantics(
              label: erase,
              isButton: true,
              hasTapAction: true,
              hasEnabledState: true,
              isEnabled: true,
              hasSelectedState: true,
              isSelected: true,
            ),
          );
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          expect(t.takeException(), isNull);
          sem.dispose();
        });
      }
    }
  });
}
