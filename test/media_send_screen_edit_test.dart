// Écran d'envoi d'une photo / vidéo (discussions et groupes, galerie et
// caméra, albums) : outils de retouche sur l'écran, reprise et annulation des
// retouches, miniatures de l'album, vue unique près de la légende. La retouche
// est injectée.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/utils/media_album.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';
import 'package:talky_flutter/features/media_editor/video/video_retouch.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/chats/media_send_screen.dart';

import 'support/media_editor_fakes.dart';

class _Host {
  MediaSendResult? result;
  bool closed = false;
}

/// Un appel reçu par la retouche factice.
class _Call {
  _Call(this.original, this.tool, this.previous);
  final File original;
  final EditorTool tool;
  final EditorDoc? previous;
}

/// Retouche factice : écrit un fichier dans le dossier des retouches, comme le
/// vrai service, avec un document neuf ; ou rend `null` (abandon).
class _FakeRetoucher {
  _FakeRetoucher(this.dir);
  final Directory dir;
  final List<_Call> calls = [];
  final List<PhotoRetouch> produced = [];
  Completer<void>? gate;
  bool cancel = false;

  Future<PhotoRetouch?> call(
    BuildContext context,
    File original,
    EditorTool tool,
    EditorDoc? previous,
  ) async {
    calls.add(_Call(original, tool, previous));
    if (gate != null) await gate!.future;
    if (cancel) return null;
    final f = File(p.join(dir.path, 'edited_${produced.length + 1}.jpg'))
      ..writeAsBytesSync(solidPngSync);
    final r = PhotoRetouch(
      file: f,
      doc: EditorDoc(
        canvas: const Size(8, 8),
        imageWidth: 8,
        imageHeight: 8,
        imageTransform: EditorImageTransform(
          center: const Offset(4, 4),
          scale: 1.0 + produced.length,
        ),
      ),
    );
    produced.add(r);
    return r;
  }

  static late List<int> solidPngSync;
}

/// Moteur vidéo factice : 10 s, 640×360 ; le rendu écrit un fichier dans le
/// dossier des retouches, ou attend [gate] (pour annuler).
class _FakeEngine implements VideoEngine {
  _FakeEngine(this.dir);
  final Directory dir;
  final List<VideoRetouch> rendered = [];
  final List<bool> withOverlay = [];
  Completer<void>? gate;
  final _progress = StreamController<double>.broadcast();
  bool canceled = false;

  @override
  Future<VideoInfo> info(File video) async => const VideoInfo(
    duration: Duration(seconds: 10),
    size: Size(640, 360),
  );

  @override
  Future<Uint8List?> frame(File video, Duration at, Size box) async =>
      Uint8List.fromList(_FakeRetoucher.solidPngSync);

  @override
  Future<List<Uint8List>> strip(File v, List<Duration> at, Size s) async => [];

  @override
  Future<File> render(
    File video,
    VideoRetouch retouch, {
    required String taskId,
    Uint8List? overlayPng,
  }) async {
    rendered.add(retouch);
    withOverlay.add(overlayPng != null);
    _progress.add(0.5);
    if (gate != null) await gate!.future;
    if (canceled) throw const VideoRenderCanceled();
    return File(p.join(dir.path, 'edited_v${rendered.length}.mp4'))
      ..writeAsBytesSync([1, 2, 3]);
  }

  @override
  Stream<double> progress(String taskId) => _progress.stream;

  @override
  Future<void> cancel(String taskId) async {
    canceled = true;
    gate?.complete();
  }
}

Future<void> _pump(
  WidgetTester t, {
  required List<AlbumSendItem> items,
  required _FakeRetoucher retoucher,
  required _Host host,
  bool allowViewOnce = false,
  String? recipient,
  MediaAddMore? onAddMore,
  int? maxItems,
  String lang = 'fr',
  VideoEngine? engine,
  VideoLayerEditor? editVideo,
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
                    allowViewOnce: allowViewOnce,
                    recipientName: recipient,
                    onAddMore: onAddMore,
                    maxItems: maxItems,
                    retouch: retoucher.call,
                    videoEngine: engine ?? const ProVideoEngine(),
                    editVideo: editVideo ?? editVideoLayers,
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

Finder _tool(EditorTool tool) =>
    find.byKey(ValueKey('media-send-tool-${tool.name}'));

Finder get _undo => find.byKey(const ValueKey('media-send-undo'));

Finder _imageOf(File f) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is FileImage &&
      (w.image as FileImage).file.path == f.path,
);

/// Laisse avancer les opérations réellement asynchrones (rendu `toImage` du
/// calque) que l'horloge simulée ne fait pas avancer.
Future<void> _settleReal(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _send(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('media-send-send')));
  await t.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late Directory editedDir;
  late _FakeRetoucher retoucher;
  late _Host host;
  late File photoA;
  late File photoB;
  late File video;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('media_send_edit');
    editedDir = Directory(p.join(tmp.path, PhotoEditService.directoryName))
      ..createSync();
    retoucher = _FakeRetoucher(editedDir);
    host = _Host();
    final png = await solidPng(8, 8);
    _FakeRetoucher.solidPngSync = png;
    photoA = File(p.join(tmp.path, 'a.png'))..writeAsBytesSync(png);
    photoB = File(p.join(tmp.path, 'b.png'))..writeAsBytesSync(png);
    video = File(p.join(tmp.path, 'v.mp4'))..writeAsBytesSync([0, 0, 0]);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('envoyer sans retoucher : fichier original, résultat inchangé',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await _send(t);
    expect(host.closed, isTrue);
    expect(host.result, isNotNull);
    expect(host.result!.items, isNull); // l'appelant garde ses éléments
    expect(host.result!.viewOnce, isFalse);
    expect(retoucher.calls, isEmpty);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('chaque outil s\'ouvre sur l\'original ; l\'envoi porte la retouche',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    for (final tool in [
      EditorTool.crop,
      EditorTool.sticker,
      EditorTool.text,
      EditorTool.draw,
      EditorTool.look,
    ]) {
      expect(_tool(tool), findsOneWidget, reason: tool.name);
    }
    await t.tap(_tool(EditorTool.text));
    await t.pumpAndSettle();
    final call = retoucher.calls.single;
    expect(call.original.path, photoA.path);
    expect(call.tool, EditorTool.text);
    expect(call.previous, isNull);
    expect(_imageOf(retoucher.produced.single.file), findsOneWidget);
    expect(_imageOf(photoA), findsNothing);

    await t.enterText(
      find.byKey(const ValueKey('media-send-caption')),
      'ma légende',
    );
    await _send(t);
    final r = host.result!;
    expect(r.caption, 'ma légende');
    expect(r.items!.single.file.path, retoucher.produced.single.file.path);
    expect(r.items!.single.type, 1);
    expect(photoA.existsSync(), isTrue);
    expect(retoucher.produced.single.file.existsSync(), isTrue);
  });

  testWidgets('deuxième retouche : repart de l\'original avec le document précédent',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(_tool(EditorTool.crop));
    await t.pumpAndSettle();
    await t.tap(_tool(EditorTool.draw));
    await t.pumpAndSettle();
    expect(retoucher.calls[1].original.path, photoA.path);
    expect(retoucher.calls[1].previous, same(retoucher.produced[0].doc));
    expect(find.text('2 retouches'), findsOneWidget);

    await _send(t);
    // Seule la dernière part ; l'étape intermédiaire est supprimée.
    expect(host.result!.items!.single.file.path,
        retoucher.produced[1].file.path);
    expect(retoucher.produced[0].file.existsSync(), isFalse);
    expect(retoucher.produced[1].file.existsSync(), isTrue);
  });

  testWidgets('annuler la dernière retouche : on revient à la précédente',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(_tool(EditorTool.crop));
    await t.pumpAndSettle();
    await t.tap(_tool(EditorTool.look));
    await t.pumpAndSettle();
    await t.tap(_undo);
    await t.pumpAndSettle();
    expect(retoucher.produced[1].file.existsSync(), isFalse);
    expect(_imageOf(retoucher.produced[0].file), findsOneWidget);
    expect(find.text('1 retouche'), findsOneWidget);

    await t.tap(_undo);
    await t.pumpAndSettle();
    expect(_imageOf(photoA), findsOneWidget);
    expect(_undo, findsNothing);
    await _send(t);
    expect(host.result!.items, isNull);
  });

  testWidgets('abandon de l\'outil : rien ne change', (t) async {
    retoucher.cancel = true;
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(_tool(EditorTool.crop));
    await t.pumpAndSettle();
    expect(_imageOf(photoA), findsOneWidget);
    expect(_undo, findsNothing);
    await _send(t);
    expect(host.result!.items, isNull);
  });

  testWidgets('fermer : aucun envoi, retouches supprimées', (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(_tool(EditorTool.crop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('media-send-close')));
    await t.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
    expect(retoucher.produced.single.file.existsSync(), isFalse);
    expect(photoA.existsSync(), isTrue);
  });

  testWidgets('une vidéo n\'a pas d\'outils photo ; la photo voisine oui',
      (t) async {
    await _pump(
      t,
      items: [
        AlbumSendItem(file: video, type: 2, duration: 14),
        AlbumSendItem(file: photoA, type: 1),
      ],
      retoucher: retoucher,
      host: host,
    );
    expect(_tool(EditorTool.crop), findsNothing);
    await t.tap(find.byKey(const ValueKey('media-send-thumb-1')));
    await t.pumpAndSettle();
    expect(_tool(EditorTool.crop), findsOneWidget);
  });

  testWidgets('album : chaque photo garde ses retouches', (t) async {
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: photoB, type: 1),
      ],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(find.byKey(const ValueKey('media-send-thumb-1')));
    await t.pumpAndSettle();
    await t.tap(_tool(EditorTool.draw));
    await t.pumpAndSettle();
    expect(retoucher.calls.single.original.path, photoB.path);
    await _send(t);
    final items = host.result!.items!;
    expect(items[0].file.path, photoA.path);
    expect(items[1].file.path, retoucher.produced.single.file.path);
  });

  testWidgets('album : retirer un média, en ajouter dans la limite',
      (t) async {
    var asked = 0;
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: photoB, type: 1),
      ],
      retoucher: retoucher,
      host: host,
      maxItems: 3,
      onAddMore: () async {
        asked++;
        return [
          AlbumSendItem(file: photoA, type: 1),
          AlbumSendItem(file: photoB, type: 1),
        ];
      },
    );
    await t.tap(find.byKey(const ValueKey('media-send-add')));
    await t.pumpAndSettle();
    expect(asked, 1);
    // Une seule place restait.
    expect(find.byKey(const ValueKey('media-send-thumb-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-send-thumb-3')), findsNothing);
    expect(find.byKey(const ValueKey('media-send-add')), findsNothing);

    await t.tap(find.byKey(const ValueKey('media-send-thumb-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('media-send-remove')));
    await t.pumpAndSettle();
    await _send(t);
    final items = host.result!.items!;
    expect(items, hasLength(2));
    expect(items[0].file.path, photoB.path);
  });

  testWidgets('vue unique : proposée pour un seul média en discussion à deux',
      (t) async {
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
      allowViewOnce: true,
      recipient: 'Awa',
    );
    expect(find.text('Awa'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('media-send-view-once')));
    await t.pumpAndSettle();
    expect(find.byTooltip('Vue unique activée'), findsOneWidget);
    await _send(t);
    expect(host.result!.viewOnce, isTrue);
  });

  testWidgets('vue unique : absente pour un album ou un groupe', (t) async {
    await _pump(
      t,
      items: [
        AlbumSendItem(file: photoA, type: 1),
        AlbumSendItem(file: photoB, type: 1),
      ],
      retoucher: retoucher,
      host: host,
      allowViewOnce: true,
    );
    expect(find.byKey(const ValueKey('media-send-view-once')), findsNothing);
    await _send(t);
    expect(host.result!.viewOnce, isFalse);
  });

  testWidgets('envoi impossible pendant une retouche ; pas de double ouverture',
      (t) async {
    retoucher.gate = Completer<void>();
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    await t.tap(_tool(EditorTool.crop));
    await t.pump();
    await t.tap(_tool(EditorTool.crop), warnIfMissed: false);
    await t.tap(find.byKey(const ValueKey('media-send-send')));
    await t.pump();
    expect(retoucher.calls, hasLength(1));
    expect(host.closed, isFalse);
    retoucher.gate!.complete();
    await t.pumpAndSettle();
    await _send(t);
    expect(host.result!.items!.single.file.path,
        retoucher.produced.single.file.path);
  });

  testWidgets('accessibilité : outils nommés, cibles ≥ 48 dp', (t) async {
    final handle = t.ensureSemantics();
    await _pump(
      t,
      items: [AlbumSendItem(file: photoA, type: 1)],
      retoucher: retoucher,
      host: host,
    );
    for (final label in ['Rogner', 'Emoji', 'Texte', 'Crayon', 'Filtres']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    final size = t.getSize(_tool(EditorTool.crop));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  for (final lang in ['en', 'zh']) {
    testWidgets('libellés des outils en $lang', (t) async {
      await _pump(
        t,
        items: [AlbumSendItem(file: photoA, type: 1)],
        retoucher: retoucher,
        host: host,
        lang: lang,
      );
      final l10n = lookupAppLocalizations(Locale(lang));
      expect(find.byTooltip(l10n.mediaEditorToolFilters), findsOneWidget);
      expect(find.byTooltip(l10n.mediaEditorToolCrop), findsOneWidget);
    });
  }

  group('vidéo', () {
    late _FakeEngine engine;
    setUp(() => engine = _FakeEngine(editedDir));

    Future<void> pumpVideo(WidgetTester t, {VideoLayerEditor? layers}) async {
      await _pump(
        t,
        items: [AlbumSendItem(file: video, type: 2, duration: 10)],
        retoucher: retoucher,
        host: host,
        engine: engine,
        editVideo: layers,
      );
      await t.pumpAndSettle();
    }

    testWidgets('outils vidéo : son, emoji, texte, crayon, filtres ; pas de rognage',
        (t) async {
      await pumpVideo(t);
      expect(find.byKey(const ValueKey('media-send-mute')), findsOneWidget);
      expect(_tool(EditorTool.crop), findsNothing);
      for (final tool in [
        EditorTool.sticker,
        EditorTool.text,
        EditorTool.draw,
        EditorTool.look,
      ]) {
        expect(_tool(tool), findsOneWidget, reason: tool.name);
      }
      expect(find.byKey(const ValueKey('media-send-trim')), findsOneWidget);
      expect(find.textContaining('0:10 sur 0:10'), findsOneWidget);
    });

    testWidgets('sans retouche : aucun rendu, la vidéo part telle quelle',
        (t) async {
      await pumpVideo(t);
      await _send(t);
      expect(engine.rendered, isEmpty);
      expect(host.result!.items, isNull);
    });

    testWidgets('son coupé puis texte : un rendu avec calque à l\'envoi',
        (t) async {
      EditorDoc? seenPrevious;
      await pumpVideo(
        t,
        layers: (context, frame, tool, previous) async {
          seenPrevious = previous;
          return EditorDoc(
            canvas: const Size(8, 8),
            imageWidth: 8,
            imageHeight: 8,
            imageTransform: const EditorImageTransform(
              center: Offset(4, 4),
              scale: 1,
            ),
            items: const [
              EditorEmojiItem(
                id: 1,
                placement: EditorPlacement(center: Offset(4, 4)),
                emoji: 'A',
              ),
            ],
          );
        },
      );
      await t.tap(find.byKey(const ValueKey('media-send-mute')));
      await t.pumpAndSettle();
      expect(find.text('1 retouche'), findsOneWidget);
      await t.tap(_tool(EditorTool.text));
      await _settleReal(t);
      expect(seenPrevious, isNull);
      expect(find.text('2 retouches'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('media-send-send')));
      await _settleReal(t);
      await t.pumpAndSettle();
      expect(engine.rendered.single.muted, isTrue);
      expect(engine.withOverlay.single, isTrue);
      final item = host.result!.items!.single;
      expect(p.basename(item.file.path), 'edited_v1.mp4');
      expect(item.duration, 10);
    });

    testWidgets('annuler la retouche : plus de rendu nécessaire', (t) async {
      await pumpVideo(t);
      await t.tap(find.byKey(const ValueKey('media-send-mute')));
      await t.pumpAndSettle();
      await t.tap(_undo);
      await t.pumpAndSettle();
      await _send(t);
      expect(engine.rendered, isEmpty);
    });

    testWidgets('annuler le rendu : on reste sur l\'écran, rien n\'est envoyé',
        (t) async {
      engine.gate = Completer<void>();
      await pumpVideo(t);
      await t.tap(find.byKey(const ValueKey('media-send-mute')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('media-send-send')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('media-send-render-progress')),
          findsOneWidget);
      await t.tap(find.byKey(const ValueKey('media-send-render-cancel')));
      await _settleReal(t);
      await t.pumpAndSettle();
      expect(host.closed, isFalse);
      expect(find.byKey(const ValueKey('media-send-render-progress')),
          findsNothing);
    });
  });
}
