// Aperçu avant envoi d'une photo (discussions et groupes, galerie et caméra,
// vue unique, albums) : bouton « Modifier » facultatif. L'éditeur est injecté.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/utils/media_album.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/chats/media_send_screen.dart';

import 'support/media_editor_fakes.dart';

class _Host {
  MediaSendResult? result;
  bool closed = false;
  final List<File> editorSources = [];
  int editorCalls = 0;
}

/// Éditeur factice : écrit un fichier dans le dossier des retouches, comme le
/// vrai service, ou rend [outcome] (null = abandon).
class _FakeEditor {
  _FakeEditor(this.dir);
  final Directory dir;
  final List<File> sources = [];
  final List<File> produced = [];
  Completer<void>? gate;
  bool cancel = false;

  Future<File?> call(
    BuildContext context,
    File source, {
    PhotoEditTarget target = PhotoEditTarget.photo,
  }) async {
    sources.add(source);
    if (gate != null) await gate!.future;
    if (cancel) return null;
    final f = File(
      p.join(dir.path, 'edited_${produced.length + 1}.jpg'),
    )..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
    produced.add(f);
    return f;
  }
}

Future<void> _pump(
  WidgetTester t, {
  required List<AlbumSendItem> items,
  required _FakeEditor editor,
  required _Host host,
  bool viewOnce = false,
  String lang = 'fr',
  Brightness brightness = Brightness.dark,
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
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
              host.result = await Navigator.push<MediaSendResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaSendScreen(
                    items: items,
                    isViewOnce: viewOnce,
                    editPhoto: editor.call,
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
  await t.pumpAndSettle();
}

Finder get _editButton => find.byKey(const ValueKey('media-send-edit'));

Finder _imageOf(File f) => find.byWidgetPredicate(
  (w) => w is Image && w.image is FileImage && (w.image as FileImage).file.path == f.path,
);

Future<void> _send(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.send));
  await t.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late Directory editedDir;
  late _FakeEditor editor;
  late _Host host;
  late File photoA;
  late File photoB;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('media_send_edit');
    editedDir = Directory(p.join(tmp.path, PhotoEditService.directoryName))
      ..createSync();
    editor = _FakeEditor(editedDir);
    host = _Host();
    final png = await solidPng(8, 8);
    photoA = File(p.join(tmp.path, 'a.png'))..writeAsBytesSync(png);
    photoB = File(p.join(tmp.path, 'b.png'))..writeAsBytesSync(png);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('envoyer sans modifier : fichier original, résultat inchangé',
      (t) async {
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    await _send(t);
    expect(host.closed, isTrue);
    expect(host.result, isNotNull);
    expect(host.result!.items, isNull); // l'appelant garde ses éléments
    expect(editor.sources, isEmpty);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('Modifier : l\'image est remplacée, l\'envoi porte le nouveau fichier',
      (t) async {
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    expect(_imageOf(photoA), findsOneWidget);
    await t.tap(_editButton);
    await t.pumpAndSettle();

    // L'éditeur a reçu l'original.
    expect(editor.sources.single.path, photoA.path);
    // Retour à l'aperçu avec l'image modifiée.
    expect(_imageOf(editor.produced.single), findsOneWidget);
    expect(_imageOf(photoA), findsNothing);

    await t.enterText(find.byType(TextField), 'ma légende');
    await _send(t);
    final r = host.result!;
    expect(r.caption, 'ma légende');
    expect(r.items, hasLength(1));
    expect(r.items!.single.file.path, editor.produced.single.path);
    expect(r.items!.single.type, 1);
    // L'original n'est jamais modifié ni supprimé.
    expect(photoA.existsSync(), isTrue);
    // La retouche envoyée est conservée pour l'outbox.
    expect(editor.produced.single.existsSync(), isTrue);
  });

  testWidgets('abandon de l\'éditeur : on revient à l\'original, rien n\'a changé',
      (t) async {
    editor.cancel = true;
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    await t.tap(_editButton);
    await t.pumpAndSettle();
    expect(_imageOf(photoA), findsOneWidget);
    expect(editor.produced, isEmpty);
    // Le bouton est de nouveau actif.
    expect(t.widget<TextButton>(_editButton).onPressed, isNotNull);
    await _send(t);
    expect(host.result!.items, isNull);
  });

  testWidgets('fermer l\'aperçu : aucun envoi, retouches supprimées', (t) async {
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    await t.tap(_editButton);
    await t.pumpAndSettle();
    final edited = editor.produced.single;
    expect(edited.existsSync(), isTrue);

    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
    expect(edited.existsSync(), isFalse);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('modifier deux fois : la retouche précédente est supprimée',
      (t) async {
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    await t.tap(_editButton);
    await t.pumpAndSettle();
    final first = editor.produced.single;
    await t.tap(_editButton);
    await t.pumpAndSettle();
    // La seconde retouche part de la première (cumul des retouches).
    expect(editor.sources.last.path, first.path);
    expect(editor.produced, hasLength(2));
    expect(first.existsSync(), isFalse);
    expect(editor.produced.last.existsSync(), isTrue);
    expect(photoA.existsSync(), isTrue);
    await _send(t);
    expect(host.result!.items!.single.file.path, editor.produced.last.path);
  });

  testWidgets('album : édition par photo, les autres restent inchangées',
      (t) async {
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: photoB, type: 1),
      ],
      editor: editor,
      host: host,
    );
    expect(find.text('1/2'), findsOneWidget);
    // Page suivante, puis retouche de la 2e photo seulement.
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    await t.tap(_editButton);
    await t.pumpAndSettle();
    expect(editor.sources.single.path, photoB.path);

    await _send(t);
    final items = host.result!.items!;
    expect(items, hasLength(2));
    expect(items[0].file.path, photoA.path);
    expect(items[1].file.path, editor.produced.single.path);
  });

  testWidgets('album : retoucher chaque photo', (t) async {
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: photoB, type: 1),
      ],
      editor: editor,
      host: host,
    );
    await t.tap(_editButton);
    await t.pumpAndSettle();
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    await t.tap(_editButton);
    await t.pumpAndSettle();
    await _send(t);
    final items = host.result!.items!;
    expect(items.map((e) => e.file.path), [
      editor.produced[0].path,
      editor.produced[1].path,
    ]);
    expect(editor.sources.map((f) => f.path), [photoA.path, photoB.path]);
  });

  testWidgets('une vidéo n\'a pas de bouton Modifier ; la photo voisine oui',
      (t) async {
    final video = File(p.join(tmp.path, 'v.mp4'))..writeAsBytesSync([0]);
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: video, type: 2, duration: 3),
      ],
      editor: editor,
      host: host,
    );
    expect(_editButton, findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(_editButton, findsNothing);
    // Envoyer l'album tel quel : les éléments ne sont pas touchés.
    await _send(t);
    expect(host.result!.items, isNull);
  });

  testWidgets('vue unique : le bouton Modifier est là, le minuteur aussi',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      editor: editor,
      host: host,
      viewOnce: true,
    );
    expect(find.byIcon(Icons.timer), findsOneWidget);
    await t.tap(_editButton);
    await t.pumpAndSettle();
    await _send(t);
    expect(host.result!.items!.single.file.path, editor.produced.single.path);
  });

  testWidgets('envoi impossible pendant une retouche ; pas de double ouverture',
      (t) async {
    editor.gate = Completer<void>();
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    await t.tap(_editButton);
    await t.pump();
    expect(t.widget<TextButton>(_editButton).onPressed, isNull);
    // Envoyer pendant la retouche ne fait rien.
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    expect(host.closed, isFalse);
    editor.gate!.complete();
    await t.pumpAndSettle();
    expect(editor.sources, hasLength(1));
    expect(t.widget<TextButton>(_editButton).onPressed, isNotNull);
  });

  testWidgets('accessibilité : libellé « Modifier », cible ≥ 48 dp', (t) async {
    await _pump(t, items: [AlbumSendItem(file: photoA, type: 1)], editor: editor, host: host);
    expect(find.descendant(of: _editButton, matching: find.text('Modifier')), findsOneWidget);
    final size = t.getSize(_editButton);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    final handle = t.ensureSemantics();
    expect(find.bySemanticsLabel('Modifier'), findsWidgets);
    handle.dispose();
  });

  for (final (lang, label) in [('en', 'Edit'), ('zh', '编辑')]) {
    testWidgets('libellé du bouton en $lang', (t) async {
      await _pump(
        t,
        items: [AlbumSendItem(file: photoA, type: 1)],
        editor: editor,
        host: host,
        lang: lang,
        brightness: Brightness.light,
      );
      expect(find.descendant(of: _editButton, matching: find.text(label)), findsOneWidget);
    });
  }
}
