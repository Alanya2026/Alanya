// Statut photo : bouton « Modifier » facultatif sur l'aperçu de chaque photo.
// Éditeur et sélecteur de photos injectés ; la publication est interceptée.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/providers/status_provider.dart';
import 'package:talky_flutter/screens/status/status_create_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';

import 'support/media_editor_fakes.dart';

class _RecordingStatusProvider extends StatusProvider {
  _RecordingStatusProvider() : super(api: TalkyApiClient());

  final List<File> published = [];

  @override
  Future<Statut?> createMedia({
    required File file,
    required int type,
    String? caption,
    int? mediaDurationMs,
  }) async {
    published.add(file);
    return null;
  }
}

class _FakeEditor {
  _FakeEditor(this.dir);
  final Directory dir;
  final List<File> sources = [];
  final List<File> produced = [];
  bool cancel = false;

  Future<File?> call(
    BuildContext context,
    File source, {
    PhotoEditTarget target = PhotoEditTarget.photo,
  }) async {
    sources.add(source);
    if (cancel) return null;
    final f = File(p.join(dir.path, 'edited_${produced.length + 1}.jpg'))
      ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
    produced.add(f);
    return f;
  }
}

Future<void> _pump(
  WidgetTester t, {
  required _FakeEditor editor,
  required _RecordingStatusProvider provider,
  required List<List<XFile>> picks,
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ChangeNotifierProvider<StatusProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: StatusCreateScreen(
          editPhoto: editor.call,
          pickPhotos: (source, limit) async => picks.removeAt(0),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  // Onglet « Photo » puis galerie.
  await t.tap(find.text('Photo'));
  await t.pumpAndSettle();
  await t.tap(find.text('Galerie'));
  await t.pumpAndSettle();
}

Finder get _edit => find.byKey(const ValueKey('status-edit-photo'));

Finder _imageOf(File f) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is FileImage &&
      (w.image as FileImage).file.path == f.path,
);

Future<void> _publish(WidgetTester t) async {
  await t.tap(find.text('Publier'));
  await t.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late _FakeEditor editor;
  late _RecordingStatusProvider provider;
  late File photoA;
  late File photoB;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('status_edit');
    final dir = Directory(p.join(tmp.path, PhotoEditService.directoryName))
      ..createSync();
    editor = _FakeEditor(dir);
    provider = _RecordingStatusProvider();
    final png = await solidPng(8, 8);
    photoA = File(p.join(tmp.path, 'a.png'))..writeAsBytesSync(png);
    photoB = File(p.join(tmp.path, 'b.png'))..writeAsBytesSync(png);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('sans modification : le fichier choisi est publié tel quel',
      (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    expect(_edit, findsOneWidget);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [photoA.path]);
    expect(editor.sources, isEmpty);
  });

  testWidgets('Modifier : l\'image modifiée remplace l\'original à la publication',
      (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    await t.tap(_edit);
    await t.pumpAndSettle();
    expect(editor.sources.single.path, photoA.path);
    expect(_imageOf(editor.produced.single), findsWidgets);
    expect(_imageOf(photoA), findsNothing);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [editor.produced.single.path]);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('abandon de l\'éditeur : l\'original reste publié', (t) async {
    editor.cancel = true;
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    await t.tap(_edit);
    await t.pumpAndSettle();
    expect(_imageOf(photoA), findsWidgets);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [photoA.path]);
  });

  testWidgets('plusieurs photos : seule celle retouchée change', (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path), XFile(photoB.path)],
    ]);
    // Après la sélection, on cadre sur la première des photos ajoutées ; on
    // retouche la photo affichée (la première).
    await t.tap(_edit);
    await t.pumpAndSettle();
    final edited = editor.produced.single;
    await _publish(t);
    final names = provider.published.map((f) => f.path).toList();
    expect(names, hasLength(2));
    expect(names, contains(edited.path));
    expect(names.where((n) => n == photoA.path || n == photoB.path), hasLength(1));
  });

  testWidgets('retirer une photo retouchée supprime sa retouche', (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    await t.tap(_edit);
    await t.pumpAndSettle();
    final edited = editor.produced.single;
    expect(edited.existsSync(), isTrue);
    await t.tap(find.byTooltip('Retirer'));
    await t.pumpAndSettle();
    expect(edited.existsSync(), isFalse);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('accessibilité : Modifier est nommé et fait au moins 48 dp',
      (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    expect(find.byTooltip('Modifier'), findsOneWidget);
    final size = t.getSize(find.descendant(of: _edit, matching: find.byType(IconButton)));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
