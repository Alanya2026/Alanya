// Statut photo / vidéo : bouton « Modifier » facultatif sur l'aperçu de chaque
// média, qui ouvre l'éditeur des discussions. Éditeur et sélecteur de photos
// injectés ; la publication est interceptée.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/utils/media_album.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/providers/status_provider.dart';
import 'package:talky_flutter/screens/chats/media_send_screen.dart';
import 'package:talky_flutter/screens/status/status_create_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';

import 'support/media_editor_fakes.dart';

class _RecordingStatusProvider extends StatusProvider {
  _RecordingStatusProvider() : super(api: TalkyApiClient());

  final List<File> published = [];
  final List<String?> captions = [];

  @override
  Future<Statut?> createMedia({
    required File file,
    required int type,
    String? caption,
    int? mediaDurationMs,
  }) async {
    published.add(file);
    captions.add(caption);
    return null;
  }
}

class _FakeEditor {
  _FakeEditor(this.dir);
  final Directory dir;

  /// Fichiers reçus, un appel par liste.
  final List<List<String>> calls = [];
  final List<int> types = [];
  final List<List<String>> captionsIn = [];
  final List<File> produced = [];
  bool cancel = false;

  /// Rangs retirés dans l'éditeur.
  Set<int> drop = {};

  /// Légendes rendues (par média gardé) ; `null` : celles reçues.
  List<String>? captionsOut;

  List<String> get sources => [for (final c in calls) ...c];

  Future<MediaSendResult?> call(
    BuildContext context,
    List<AlbumSendItem> items,
    List<String> captions,
  ) async {
    calls.add([for (final i in items) i.file.path]);
    types.addAll(items.map((i) => i.type));
    captionsIn.add(captions);
    if (cancel) return null;
    final origins = [
      for (var k = 0; k < items.length; k++)
        if (!drop.contains(k)) k,
    ];
    final out = <AlbumSendItem>[];
    for (final k in origins) {
      final f = File(p.join(dir.path, 'edited_${produced.length + 1}.jpg'))
        ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
      produced.add(f);
      out.add(AlbumSendItem(file: f, type: items[k].type, duration: 4));
    }
    return MediaSendResult(
      items: out,
      origins: origins,
      captions: captionsOut ?? [for (final k in origins) captions[k]],
    );
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
          editMedia: editor.call,
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

Finder get _edit => find.byKey(const ValueKey('status-edit-media'));

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

  testWidgets('un seul média : l\'éditeur s\'ouvre tout seul', (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    expect(editor.calls.single, [photoA.path]);
    expect(editor.types.single, 1);
    expect(editor.captionsIn.single, ['']);
    expect(_imageOf(editor.produced.single), findsWidgets);
    expect(_imageOf(photoA), findsNothing);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [editor.produced.single.path]);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('éditeur fermé sans valider : les originaux sont publiés',
      (t) async {
    editor.cancel = true;
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path), XFile(photoB.path)],
    ]);
    expect(editor.calls, hasLength(1));
    expect(_edit, findsWidgets);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [photoA.path, photoB.path]);
  });

  testWidgets('plusieurs médias : l\'éditeur s\'ouvre sur tous, une légende '
      'chacun', (t) async {
    editor.captionsOut = ['Un', 'Deux'];
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path), XFile(photoB.path)],
    ]);
    expect(editor.calls.single, [photoA.path, photoB.path]);
    expect(editor.captionsIn.single, ['', '']);
    await _publish(t);
    expect(
      provider.published.map((f) => f.path),
      [for (final f in editor.produced) f.path],
    );
    expect(provider.captions, ['Un', 'Deux']);
  });

  testWidgets('un média retiré dans l\'éditeur n\'est pas publié', (t) async {
    editor.drop = {0};
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path), XFile(photoB.path)],
    ]);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [editor.produced.single.path]);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('Modifier rouvre l\'éditeur sur ce média ; la retouche '
      'précédente est supprimée', (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    final first = editor.produced.single;
    await t.tap(_edit);
    await t.pumpAndSettle();
    expect(editor.calls.last, [first.path]);
    final second = editor.produced.last;
    expect(first.existsSync(), isFalse);
    await _publish(t);
    expect(provider.published.map((f) => f.path), [second.path]);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('retirer une photo retouchée supprime sa retouche', (t) async {
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    final edited = editor.produced.single;
    expect(edited.existsSync(), isTrue);
    await t.tap(find.byTooltip('Retirer'));
    await t.pumpAndSettle();
    expect(edited.existsSync(), isFalse);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('accessibilité : Modifier est nommé et fait au moins 48 dp',
      (t) async {
    editor.cancel = true;
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    expect(find.byTooltip('Modifier'), findsOneWidget);
    final size = t.getSize(find.descendant(of: _edit, matching: find.byType(IconButton)));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('la légende passe dans l\'éditeur et en revient', (t) async {
    editor.cancel = true;
    await _pump(t, editor: editor, provider: provider, picks: [
      [XFile(photoA.path)],
    ]);
    editor
      ..cancel = false
      ..captionsOut = ['Au marché'];
    await t.enterText(find.byType(TextField), 'Bonjour');
    await t.tap(_edit);
    await t.pumpAndSettle();
    expect(editor.captionsIn.last, ['Bonjour']);
    expect(find.text('Au marché'), findsOneWidget);
    await _publish(t);
    expect(provider.captions, ['Au marché']);
  });
}
