// Éditeur d'image : cadre imposé (photo de profil / de groupe) — carré d'office,
// image qui remplit le cadre, aucun choix de format, aperçu rond, export carré.
// Le mode sticker n'est pas touché par ces paramètres.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/media_editor_screen.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';
import 'package:talky_flutter/features/media_editor/render/editor_exporter.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

import 'support/media_editor_fakes.dart';

Future<EditorController> _controller(
  MediaEditorMode mode, {
  EditorAspect? fixed,
  bool round = false,
  int w = 400,
  int h = 200,
}) async => EditorController(
  mode: mode,
  image: await solidImage(w, h),
  fixedAspect: fixed,
  roundFrame: round,
);

Future<void> _settle(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _open(
  WidgetTester t,
  Uint8List bytes, {
  EditorAspect? fixed,
  bool round = false,
  String lang = 'fr',
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaEditorScreen(
        source: MediaEditorSource.bytes(bytes),
        mode: MediaEditorMode.photo,
        fixedAspect: fixed,
        roundFrame: round,
      ),
    ),
  );
  await _settle(t);
}

void main() {
  test('cadre carré imposé : document carré dès l\'ouverture, image qui remplit',
      () async {
    final c = await _controller(
      MediaEditorMode.photo,
      fixed: EditorAspect.square,
    );
    addTearDown(c.dispose);
    expect(c.doc.canvas, const Size(400, 400));
    expect(
      c.doc.imageTransform,
      EditorImageTransform.cover(const Size(400, 400), 400, 200),
    );
    // Ouvrir l'éditeur ne compte pas comme une retouche.
    expect(c.hasChanges, isFalse);
    expect(c.canUndo, isFalse);
    expect(c.tool, EditorTool.crop);
  });

  test('cadre imposé : le choix du format ne change plus rien', () async {
    final c = await _controller(
      MediaEditorMode.photo,
      fixed: EditorAspect.square,
    );
    addTearDown(c.dispose);
    c.setAspect(EditorAspect.r16x9);
    expect(c.doc.canvas, const Size(400, 400));
    expect(c.hasChanges, isFalse);
  });

  test('cadre imposé : l\'image portrait donne aussi un carré', () async {
    final c = await _controller(
      MediaEditorMode.photo,
      fixed: EditorAspect.square,
      w: 200,
      h: 600,
    );
    addTearDown(c.dispose);
    expect(c.doc.canvas, const Size(600, 600));
  });

  test('cadre libre (sans paramètre ou « original ») : comme avant', () async {
    final a = await _controller(MediaEditorMode.photo);
    final b = await _controller(MediaEditorMode.photo, fixed: EditorAspect.original);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    for (final c in [a, b]) {
      expect(c.fixedAspect, isNull);
      expect(c.doc.canvas, const Size(400, 200));
      c.setAspect(EditorAspect.square);
      expect(c.doc.canvas, const Size(400, 400));
    }
  });

  test('mode sticker : le cadre imposé est ignoré (512×512, « contain »)',
      () async {
    final c = await _controller(
      MediaEditorMode.sticker,
      fixed: EditorAspect.r16x9,
      round: true,
    );
    addTearDown(c.dispose);
    expect(c.fixedAspect, isNull);
    expect(c.doc.canvas, const Size(512, 512));
    expect(
      c.doc.imageTransform,
      EditorImageTransform.contain(const Size(512, 512), 400, 200),
    );
  });

  test('export d\'un cadre imposé : PNG carré, taille du grand côté', () async {
    final c = await _controller(
      MediaEditorMode.photo,
      fixed: EditorAspect.square,
      round: true,
    );
    addTearDown(c.dispose);
    final r = await MediaEditorExporter.export(c.doc, c.image, c.mode);
    expect((r.width, r.height), (400, 400));
    final px = await decodePixels(r.png);
    // L'image remplit le cadre : aucun pixel transparent, même dans les coins
    // (le repère rond n'est jamais exporté).
    expect(px.alphaAt(0, 0), 255);
    expect(px.alphaAt(399, 399), 255);
    expect(px.at(200, 200)[0], greaterThan(150));
  });

  testWidgets('écran : photo de profil — pas de choix de format, repère rond',
      (t) async {
    final png = await t.runAsync(() => solidPng(300, 200));
    await _open(t, png!, fixed: EditorAspect.square, round: true);
    expect(find.byKey(const ValueKey('editor-aspect-square')), findsNothing);
    expect(find.byKey(const ValueKey('editor-aspect-original')), findsNothing);
    expect(
      find.text('Glissez et pincez pour cadrer la photo : elle s\'affichera '
          'dans un cercle.'),
      findsOneWidget,
    );
    // L'outil de départ est bien le rognage.
    expect(find.byKey(const ValueKey('editor-fit-cover')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });

  testWidgets('écran : sans cadre imposé, les formats restent proposés',
      (t) async {
    final png = await t.runAsync(() => solidPng(300, 200));
    await _open(t, png!);
    expect(find.byKey(const ValueKey('editor-aspect-square')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-aspect-r16x9')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });

  for (final lang in ['en', 'zh']) {
    testWidgets('écran : indication ronde en $lang', (t) async {
      final png = await t.runAsync(() => solidPng(300, 200));
      await _open(t, png!, fixed: EditorAspect.square, round: true, lang: lang);
      final l10n = await AppLocalizations.delegate.load(Locale(lang));
      expect(find.text(l10n.mediaEditorCropHintRound), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 10));
    });
  }
}
