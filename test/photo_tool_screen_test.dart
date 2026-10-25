// Retouche avant envoi, un outil à la fois : chaque outil s'ouvre sur son
// panneau (thème sombre), « OK » sans changement ne rend rien, une retouche
// rend le PNG et son document, texte et emoji commencent par la saisie,
// fr / en / zh. Le décodage et l'export (dart:ui) avancent par `runAsync`.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/media_editor_source.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/photo_tool_screen.dart';
import 'package:talky_flutter/features/media_editor/render/editor_exporter.dart';
import 'package:talky_flutter/features/media_editor/render/editor_renderer.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

import 'support/media_editor_fakes.dart';

void _testUi(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

Future<void> _settle(WidgetTester t, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 80));
  }
}

class _Host {
  MediaEditorResult? result;
  bool closed = false;
}

Future<_Host> _open(
  WidgetTester t,
  Uint8List bytes,
  EditorTool tool, {
  String lang = 'fr',
  EditorDoc? initialDoc,
  Future<String?> Function(BuildContext)? emoji,
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final host = _Host();
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
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('host-open'),
            onPressed: () async {
              host.result = await Navigator.of(context).push<MediaEditorResult>(
                MaterialPageRoute(
                  builder: (_) => PhotoToolScreen(
                    source: MediaEditorSource.bytes(bytes),
                    tool: tool,
                    initialDoc: initialDoc,
                    pickEmoji: emoji ?? (_) async => '😀',
                  ),
                ),
              );
              host.closed = true;
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('host-open')));
  await _settle(t);
  return host;
}

Future<void> _ok(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('photo-done')));
  await _settle(t, rounds: 14);
}

void main() {
  late Uint8List png;
  setUpAll(() async => png = await solidPng(64, 48));
  // Pas de réseau en test : la police manuscrite (google_fonts) est remplacée.
  final realFonts = EditorFonts.resolver;
  setUp(
    () => EditorFonts.resolver = (font, color, size) =>
        TextStyle(color: color, fontSize: size),
  );
  tearDown(() => EditorFonts.resolver = realFonts);

  _testUi('rogner : molette, formats, pivoter ; OK sans changement = rien',
      (t) async {
    final host = await _open(t, png, EditorTool.crop);
    expect(find.byKey(const ValueKey('photo-crop-dial')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-aspect-square')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-rotate')), findsOneWidget);
    // Thème sombre imposé, quel que soit celui de l'app.
    final ctx = t.element(find.byKey(const ValueKey('photo-done')));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    await _ok(t);
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  _testUi('pivoter puis OK : PNG tourné et son document', (t) async {
    final host = await _open(t, png, EditorTool.crop);
    await t.tap(find.byKey(const ValueKey('photo-rotate')));
    await t.pump();
    await _ok(t);
    final r = host.result!;
    expect(r.width, 48);
    expect(r.height, 64);
    expect(r.doc!.imageTransform.quarterTurns, 1);
  });

  _testUi('filtres : choisir N&B, l\'intensité apparaît', (t) async {
    final host = await _open(t, png, EditorTool.look);
    expect(find.byKey(const ValueKey('photo-look-intensity')), findsNothing);
    await t.tap(find.byKey(const ValueKey('photo-filter-mono')));
    await t.pump();
    expect(find.byKey(const ValueKey('photo-look-intensity')), findsOneWidget);
    await _ok(t);
    expect(host.result!.doc!.look.filter, EditorFilter.mono);
  });

  _testUi('crayon : les cinq pinceaux, annuler/rétablir', (t) async {
    await _open(t, png, EditorTool.draw);
    for (final k in ['pen', 'highlighter', 'neon', 'blur', 'eraser']) {
      expect(find.byKey(ValueKey('photo-brush-$k')), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('photo-brush-size')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('photo-brush-blur')));
    await t.pump();
    expect(find.text('Passez le doigt sur un visage ou une plaque pour le flouter.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('photo-undo')), findsOneWidget);
  });

  _testUi('texte : la saisie s\'ouvre d\'office ; annuler referme l\'outil',
      (t) async {
    final host = await _open(t, png, EditorTool.text);
    expect(find.byKey(const ValueKey('photo-text-field')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('photo-text-cancel')));
    await _settle(t);
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  _testUi('texte : saisi, sur fond plein, rendu avec son document', (t) async {
    final host = await _open(t, png, EditorTool.text);
    await t.enterText(find.byKey(const ValueKey('photo-text-field')), 'Salut');
    await t.tap(find.byKey(const ValueKey('photo-text-background')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('photo-text-done')));
    await _settle(t);
    expect(find.byKey(const ValueKey('photo-item-add')), findsOneWidget);
    await _ok(t);
    final item = host.result!.doc!.items.single as EditorTextItem;
    expect(item.text, 'Salut');
    expect(item.background, EditorTextBackground.solid);
  });

  _testUi('emoji : le sélecteur s\'ouvre d\'office', (t) async {
    var asked = 0;
    final host = await _open(
      t,
      png,
      EditorTool.sticker,
      emoji: (_) async {
        asked++;
        return '🎉';
      },
    );
    expect(asked, 1);
    await _ok(t);
    expect((host.result!.doc!.items.single as EditorEmojiItem).emoji, '🎉');
  });

  for (final lang in ['en', 'zh']) {
    _testUi('titre et panneau en $lang', (t) async {
      await _open(t, png, EditorTool.look, lang: lang);
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(find.text(l10n.mediaEditorToolFilters), findsWidgets);
      expect(find.text(l10n.mediaEditorTabAdjust), findsOneWidget);
    });
  }
}
