// Agencement de l'aperçu d'un sticker (Ajouter / Modifier / Annuler) : les trois
// boutons sont empilés en pleine largeur, séparés, jamais collés, et gardent
// une cible tactile d'au moins 48 dp — en clair et en sombre, en fr, en et zh,
// avec ou sans le bouton « Modifier ».
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/stickers/sticker_creation_flows.dart';

import 'support/media_editor_fakes.dart' show solidPng;

Widget _app(Brightness b, String lang, Uint8List png, bool canEdit,
    void Function(StickerPreviewChoice) onResult) {
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
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async =>
                onResult(await confirmStickerPreview(context, png, canEdit: canEdit)),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cles = ['sticker-preview-add', 'sticker-preview-edit', 'sticker-preview-cancel'];

  for (final b in Brightness.values) {
    for (final lang in ['fr', 'en', 'zh']) {
      for (final canEdit in [true, false]) {
        testWidgets('boutons séparés, pleine largeur, ≥ 48 dp — $lang / ${b.name} / modifier=$canEdit',
            (tester) async {
          final png = (await tester.runAsync(() => solidPng(64, 64)))!;
          await tester.binding.setSurfaceSize(const Size(360, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(_app(b, lang, png, canEdit, (_) {}));
          await tester.tap(find.text('ouvrir'));
          await tester.pumpAndSettle();

          final attendues = canEdit ? cles : [cles.first, cles.last];
          final rects = <Rect>[];
          for (final k in attendues) {
            final f = find.byKey(ValueKey(k));
            expect(f, findsOneWidget, reason: k);
            rects.add(tester.getRect(f));
          }
          if (!canEdit) {
            expect(find.byKey(const ValueKey('sticker-preview-edit')), findsNothing);
          }

          for (final r in rects) {
            expect(r.height, greaterThanOrEqualTo(48), reason: 'cible tactile');
          }
          // Empilés de haut en bas, avec un vrai espace entre deux boutons.
          for (var i = 1; i < rects.length; i++) {
            expect(rects[i].top - rects[i - 1].bottom, greaterThanOrEqualTo(8),
                reason: 'boutons collés entre ${attendues[i - 1]} et ${attendues[i]}');
          }
          // Même largeur : pleine largeur de la boîte.
          for (final r in rects) {
            expect(r.width, closeTo(rects.first.width, 0.5));
          }
          // La boîte ne déborde pas de l'écran.
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('chaque bouton renvoie son choix', (tester) async {
    final png = (await tester.runAsync(() => solidPng(64, 64)))!;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final attendus = {
      'sticker-preview-add': StickerPreviewChoice.add,
      'sticker-preview-edit': StickerPreviewChoice.edit,
      'sticker-preview-cancel': StickerPreviewChoice.cancel,
    };
    for (final e in attendus.entries) {
      StickerPreviewChoice? recu;
      await tester.pumpWidget(_app(Brightness.light, 'fr', png, true, (c) => recu = c));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(e.key)));
      await tester.pumpAndSettle();
      expect(recu, e.value, reason: e.key);
    }
  });
}
