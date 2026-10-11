// Éditeur d'image (T4b) : écran principal — ouverture, outils, annuler/rétablir,
// validation, abandon, clair/sombre × fr/en/zh, accessibilité. Le décodage et
// l'export (dart:ui) demandent un moteur réel : on les laisse avancer avec
// `runAsync`, comme les autres tests d'écrans de stickers.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/features/media_editor/media_editor_screen.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

import 'support/media_editor_fakes.dart';

/// Démonte l'arbre à la fin (minuteurs des animations de route).
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

/// Hôte : un bouton qui ouvre l'éditeur et garde son résultat.
class EditorHost {
  MediaEditorResult? result;
  bool closed = false;
}

Future<EditorHost> openEditor(
  WidgetTester t,
  Uint8List bytes, {
  MediaEditorMode mode = MediaEditorMode.sticker,
  Brightness b = Brightness.light,
  String lang = 'fr',
  Future<String?> Function(BuildContext)? emoji,
  Size surface = const Size(420, 900),
}) async {
  t.view.physicalSize = surface;
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
                      pickEmoji: emoji ?? (_) async => '😀',
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

Future<Uint8List> _png([int w = 120, int h = 60]) async {
  final b = await solidPng(w, h);
  return b;
}

Future<void> _tool(WidgetTester t, String tool) async {
  await t.tap(_key('editor-tool-$tool'));
  await settle(t, rounds: 2);
}

bool _enabled(WidgetTester t, String key) =>
    t.widget<IconButton>(_key(key)).onPressed != null;

/// Trace un trait au doigt sur le document.
Future<void> _drag(WidgetTester t, Offset from, Offset delta) async {
  final g = await t.startGesture(from);
  for (var i = 1; i <= 5; i++) {
    await g.moveBy(delta / 5);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  testUi('ouverture : chargement puis outils, rien d\'annulable', (t) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    expect(find.text('Modifier le sticker'), findsOneWidget);
    for (final label in ['Rogner', 'Crayon', 'Texte', 'Emoji']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Terminer'), findsOneWidget);
    expect(_enabled(t, 'editor-undo'), isFalse);
    expect(_enabled(t, 'editor-redo'), isFalse);
    expect(_key('editor-document'), findsOneWidget);
    expect(_key('editor-checkerboard'), findsOneWidget);
    // Sticker : cadre carré imposé, aucun choix de format.
    expect(_key('editor-aspect-square'), findsNothing);
    expect(find.textContaining('dans le carré'), findsOneWidget);
  });

  testUi('crayon : un tracé s\'annule, se rétablit, change de couleur', (
    t,
  ) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    await _tool(t, 'draw');
    expect(find.text('Épaisseur du trait'), findsOneWidget);
    expect(find.text('Gomme'), findsWidgets);

    final centre = t.getCenter(_key('editor-document'));
    await _drag(t, centre - const Offset(60, 0), const Offset(120, 30));
    expect(_enabled(t, 'editor-undo'), isTrue);
    expect(_enabled(t, 'editor-redo'), isFalse);

    await t.tap(_key('editor-undo'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);
    expect(_enabled(t, 'editor-redo'), isTrue);
    await t.tap(_key('editor-redo'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isTrue);

    // Gomme puis retour au crayon par une couleur.
    await t.tap(_key('editor-eraser'));
    await t.pump();
    await t.tap(_key('editor-pen'));
    await t.pump();
    await t.tap(
      find.bySemanticsLabel(RegExp('Rouge')).first,
      warnIfMissed: false,
    );
  });

  testUi('rognage : glisser l\'image, « Remplir » / « Ajuster »', (t) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    expect(_enabled(t, 'editor-undo'), isFalse);
    final centre = t.getCenter(_key('editor-document'));
    await _drag(t, centre, const Offset(40, 0));
    expect(_enabled(t, 'editor-undo'), isTrue, reason: 'geste = une action');
    await t.tap(_key('editor-undo'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);

    await t.tap(_key('editor-fit-cover'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isTrue);
    await t.tap(_key('editor-fit-contain'));
    await t.pump();
    await t.tap(_key('editor-undo'));
    await t.tap(_key('editor-undo'));
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);
  });

  testUi('pincement : deux doigts zooment l\'image', (t) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    final c = t.getCenter(_key('editor-document'));
    final a = await t.startGesture(c - const Offset(20, 0), pointer: 1);
    final b = await t.startGesture(c + const Offset(20, 0), pointer: 2);
    for (var i = 1; i <= 5; i++) {
      await a.moveBy(const Offset(-8, 0));
      await b.moveBy(const Offset(8, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await t.pump(const Duration(milliseconds: 50));
    expect(_enabled(t, 'editor-undo'), isTrue);
  });

  testUi('texte : ajouter, régler, supprimer, annuler', (t) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    await _tool(t, 'text');
    await t.tap(_key('editor-add-text'));
    await settle(t, rounds: 3);
    // Feuille de saisie : le bouton reste inactif tant que le champ est vide.
    expect(find.text('Gras'), findsOneWidget);
    expect(find.text('Manuscrite'), findsOneWidget);
    final ajouter = find.widgetWithText(FilledButton, 'Ajouter un texte');
    expect(t.widget<FilledButton>(ajouter).onPressed, isNull);
    await t.enterText(_key('editor-text-field'), 'Salut');
    await t.pump();
    await t.tap(ajouter);
    await settle(t, rounds: 3);

    // L'élément est sélectionné : taille, rotation, suppression, modification.
    expect(find.text('Taille'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(_key('editor-delete-item'), findsOneWidget);
    expect(_key('editor-edit-text'), findsOneWidget);
    expect(_enabled(t, 'editor-undo'), isTrue);

    // Le curseur de taille = une action.
    final slider = find.byType(Slider).first;
    await t.drag(slider, const Offset(60, 0));
    await t.pump();

    await t.tap(_key('editor-delete-item'));
    await t.pump();
    expect(find.text('Taille'), findsNothing);
    await t.tap(_key('editor-undo')); // suppression
    await t.pump();
    expect(_key('editor-delete-item'), findsNothing, reason: 'non sélectionné');
    await t.tap(_key('editor-undo')); // taille
    await t.tap(_key('editor-undo')); // ajout
    await t.pump();
    expect(_enabled(t, 'editor-undo'), isFalse);
  });

  testUi('texte : toucher un élément le sélectionne, le glisser le déplace', (
    t,
  ) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    await _tool(t, 'text');
    await t.tap(_key('editor-add-text'));
    await settle(t, rounds: 3);
    await t.enterText(_key('editor-text-field'), 'Hop');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Ajouter un texte'));
    await settle(t, rounds: 3);
    final depart = t.widget<Slider>(find.byType(Slider).first).value;

    // Toucher le vide désélectionne.
    final doc = t.getRect(_key('editor-document'));
    await t.tapAt(doc.topLeft + const Offset(4, 4));
    await t.pump();
    expect(find.text('Taille'), findsNothing);
    // Toucher l'élément (au centre) le re-sélectionne. La zone de retouche ne
    // bouge pas quand la sélection change (le panneau a une hauteur fixe).
    final cadre = t.getRect(_key('editor-document'));
    expect(cadre, doc);
    await t.tapAt(cadre.center);
    await t.pump();
    expect(find.text('Taille'), findsOneWidget);
    expect(t.widget<Slider>(find.byType(Slider).first).value, depart);

    // Glisser l'élément : une seule action, annulable sans le perdre.
    final avant = t.widget<IconButton>(_key('editor-undo')).onPressed;
    expect(avant, isNotNull);
    await _drag(
      t,
      t.getRect(_key('editor-document')).center,
      const Offset(30, 20),
    );
    await t.tap(_key('editor-undo'));
    await t.pump();
    expect(find.text('Taille'), findsOneWidget);
    expect(
      _enabled(t, 'editor-undo'),
      isTrue,
      reason: 'l\'ajout reste annulable',
    );
  });

  testUi('emoji : sélecteur injecté, élément posé puis supprimé', (t) async {
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes, emoji: (_) async => '🎉');
    await _tool(t, 'sticker');
    expect(find.text('Ajouter un emoji'), findsOneWidget);
    await t.tap(_key('editor-add-emoji'));
    await settle(t, rounds: 3);
    expect(find.text('Taille'), findsOneWidget);
    expect(
      _key('editor-edit-text'),
      findsNothing,
      reason: 'seul le texte se modifie',
    );
    await t.tap(_key('editor-delete-item'));
    await t.pump();
    expect(find.text('Taille'), findsNothing);
  });

  testUi('terminer : renvoie un PNG 512×512 transparent, valide', (t) async {
    final bytes = (await t.runAsync(_png))!;
    final host = await openEditor(t, bytes);
    await _tool(t, 'draw');
    await _drag(t, t.getCenter(_key('editor-document')), const Offset(60, 10));
    await t.tap(_key('editor-done'));
    for (var i = 0; i < 40 && !host.closed; i++) {
      await settle(t, rounds: 1);
    }
    expect(host.closed, isTrue);
    final r = host.result!;
    expect(r.width, 512);
    expect(r.height, 512);
    final info = StickerImageCheck.validate(r.png);
    expect(info.hasAlpha, isTrue);
    final px = (await t.runAsync(() => decodePixels(r.png)))!;
    expect(px.alphaAt(3, 3), 0, reason: 'fond transparent');
  });

  testUi('photo : formats de cadre proposés, export au format de l\'image', (
    t,
  ) async {
    final bytes = (await t.runAsync(() => _png(80, 40)))!;
    final host = await openEditor(t, bytes, mode: MediaEditorMode.photo);
    expect(find.text('Retoucher l\'image'), findsOneWidget);
    expect(_key('editor-aspect-square'), findsOneWidget);
    expect(_key('editor-aspect-r16x9'), findsOneWidget);
    expect(find.textContaining('dans le cadre'), findsOneWidget);
    await t.tap(_key('editor-done'));
    for (var i = 0; i < 40 && !host.closed; i++) {
      await settle(t, rounds: 1);
    }
    final r = host.result!;
    expect(r.width, 80);
    expect(r.height, 40);
  });

  testUi('fermer sans modification : retour immédiat, résultat nul', (t) async {
    final bytes = (await t.runAsync(_png))!;
    final host = await openEditor(t, bytes);
    await t.tap(_key('editor-close'));
    await settle(t);
    expect(host.closed, isTrue);
    expect(host.result, isNull);
    expect(find.text('Abandonner les modifications ?'), findsNothing);
  });

  testUi('fermer après modification : confirmation, « Continuer » garde tout', (
    t,
  ) async {
    final bytes = (await t.runAsync(_png))!;
    final host = await openEditor(t, bytes);
    await t.tap(_key('editor-fit-cover'));
    await t.pump();
    await t.tap(_key('editor-close'));
    await settle(t, rounds: 3);
    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    await t.tap(find.text('Continuer'));
    await settle(t, rounds: 3);
    expect(host.closed, isFalse);
    expect(find.text('Modifier le sticker'), findsOneWidget);
    expect(_enabled(t, 'editor-undo'), isTrue);

    await t.tap(_key('editor-close'));
    await settle(t, rounds: 3);
    await t.tap(find.widgetWithText(FilledButton, 'Abandonner'));
    await settle(t);
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  testUi('retour système après modification : même confirmation', (t) async {
    final bytes = (await t.runAsync(_png))!;
    final host = await openEditor(t, bytes);
    await t.tap(_key('editor-fit-cover'));
    await t.pump();
    await t.binding.handlePopRoute();
    await settle(t, rounds: 3);
    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    expect(host.closed, isFalse);
  });

  testUi('image illisible : message traduit, pas d\'export possible', (
    t,
  ) async {
    await openEditor(t, Uint8List.fromList([1, 2, 3, 4]));
    expect(find.textContaining('Image illisible'), findsOneWidget);
    expect(t.widget<TextButton>(_key('editor-done')).onPressed, isNull);
    expect(_enabled(t, 'editor-undo'), isFalse);
  });

  group('clair / sombre × fr / en / zh', () {
    for (final b in Brightness.values) {
      for (final (lang, titre, outils, fin) in [
        (
          'fr',
          'Modifier le sticker',
          ['Rogner', 'Crayon', 'Texte', 'Emoji'],
          'Terminer',
        ),
        ('en', 'Edit sticker', ['Crop', 'Draw', 'Text', 'Emoji'], 'Done'),
        ('zh', '编辑贴纸', ['裁剪', '画笔', '文字', '表情'], '完成'),
      ]) {
        testUi('écran principal ($lang, $b)', (t) async {
          final sem = t.ensureSemantics();
          final bytes = (await t.runAsync(_png))!;
          await openEditor(t, bytes, lang: lang, b: b);
          expect(find.text(titre), findsOneWidget);
          expect(find.text(fin), findsOneWidget);
          for (final o in outils) {
            expect(find.text(o), findsWidgets);
            // Chaque outil est un bouton nommé pour l'accessibilité.
            expect(
              t.getSemantics(find.bySemanticsLabel(o).first),
              matchesSemantics(
                label: o,
                isButton: true,
                hasTapAction: true,
                hasEnabledState: true,
                isEnabled: true,
                hasSelectedState: true,
                isSelected: o == outils.first,
              ),
            );
          }
          // Cibles tactiles d'au moins 48 dp.
          for (final k in ['crop', 'draw', 'text', 'sticker']) {
            final s = t.getSize(_key('editor-tool-$k'));
            expect(s.width, greaterThanOrEqualTo(48), reason: k);
            expect(s.height, greaterThanOrEqualTo(48), reason: k);
          }
          for (final k in ['editor-undo', 'editor-redo', 'editor-close']) {
            final s = t.getSize(_key(k));
            expect(s.shortestSide, greaterThanOrEqualTo(48), reason: k);
          }
          // Couleurs du thème : le damier suit le mode.
          final damier = t.widget<CustomPaint>(_key('editor-checkerboard'));
          final p = damier.painter! as dynamic;
          final colors =
              (b == Brightness.light ? AppTheme.light : AppTheme.dark)
                  .colorScheme;
          expect(p.a, colors.surfaceContainerHighest);
          expect(p.b, colors.surface);
          expect(t.takeException(), isNull);

          // Outil crayon : réglages traduits.
          await _tool(t, 'draw');
          expect(t.takeException(), isNull);
          sem.dispose();
        });
      }
    }
  });

  testUi('accessibilité : cibles tactiles Android (crayon, texte)', (t) async {
    final sem = t.ensureSemantics();
    final bytes = (await t.runAsync(_png))!;
    await openEditor(t, bytes);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await _tool(t, 'draw');
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    sem.dispose();
  });

  test('source fichier : taille vérifiée avant lecture', () async {
    final src = MediaEditorSource.file('/chemin/inexistant.png');
    await expectLater(src.readBytes(), throwsA(isA<Exception>()));
  });

  test('source octets : rendus tels quels', () async {
    final b = Uint8List.fromList([1, 2, 3]);
    expect(await MediaEditorSource.bytes(b).readBytes(), same(b));
    expect(ui.PlatformDispatcher.instance, isNotNull);
  });
}
