// Photo retouchée avant envoi : le PNG de l'éditeur est recompressé en JPEG
// (jamais plus lourd que nécessaire, sans métadonnées de l'original), rangé
// dans un fichier neuf ; l'original n'est jamais touché.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/services/image_thumbnail_service.dart';
import 'package:talky_flutter/core/services/photo_edit_service.dart';
import 'package:talky_flutter/core/utils/media_staging.dart';
import 'package:talky_flutter/features/media_editor/media_editor_screen.dart';

import 'support/media_editor_fakes.dart';

/// Image « photo » : dégradé + bruit (un PNG y est bien plus lourd qu'un JPEG).
Future<MediaEditorResult> _photoResult(int w, int h, {int alpha = 255}) async {
  final rnd = Random(7);
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      px[o] = (x * 255 ~/ w + rnd.nextInt(24)).clamp(0, 255);
      px[o + 1] = (y * 255 ~/ h + rnd.nextInt(24)).clamp(0, 255);
      px[o + 2] = (128 + rnd.nextInt(40)).clamp(0, 255);
      px[o + 3] = alpha;
    }
  }
  final comp = await _fromPixels(px, w, h);
  final data = await comp.toByteData(format: ui.ImageByteFormat.png);
  comp.dispose();
  return MediaEditorResult(
    png: data!.buffer.asUint8List(),
    width: w,
    height: h,
  );
}

Future<ui.Image> _fromPixels(Uint8List px, int w, int h) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

/// Hôte minimal : donne un BuildContext et le garde.
Future<BuildContext> _context(WidgetTester t) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return ctx;
}

void main() {
  late Directory tmp;
  late Directory out;
  late File original;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('photo_edit_test');
    out = Directory(p.join(tmp.path, PhotoEditService.directoryName))
      ..createSync();
    original = File(p.join(tmp.path, 'IMG_0001.jpg'))
      ..writeAsBytesSync(List<int>.generate(900000, (i) => i % 251));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('la retouche devient un JPEG neuf, bien plus léger que le PNG',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(640, 480));
    MediaEditorSource? seen;
    PhotoEditTarget? seenTarget;
    final before = original.readAsBytesSync();

    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, source, target) async {
          seen = source;
          seenTarget = target;
          return result;
        },
      ),
    );

    expect(file, isNotNull);
    expect(seenTarget, PhotoEditTarget.photo);
    expect(seen, isNotNull);
    expect(file!.path, startsWith(out.path));
    expect(p.extension(file.path), '.jpg');
    final bytes = file.readAsBytesSync();
    expect(_isJpeg(bytes), isTrue);
    // Poids : JPEG de photo, pas le PNG de l'éditeur (jamais « doublé »).
    expect(bytes.length, lessThan(result!.png.length ~/ 2));
    // Aucune métadonnée de l'original dans le fichier envoyé.
    expect(String.fromCharCodes(bytes.take(600)).contains('Exif'), isFalse);
    // Mêmes dimensions que l'export de l'éditeur.
    final px = await t.runAsync(() => decodePixels(bytes));
    expect((px!.width, px.height), (640, 480));
    // L'original n'a pas bougé.
    expect(original.readAsBytesSync(), before);
  });

  testWidgets('abandon de l\'éditeur : rien n\'est écrit', (t) async {
    final ctx = await _context(t);
    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, s, target) async => null,
      ),
    );
    expect(file, isNull);
    expect(out.listSync(), isEmpty);
  });

  testWidgets('photo de profil : cible « avatar », qualité 85', (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(64, 64));
    PhotoEditTarget? seen;
    final qualities = <int>[];
    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        target: PhotoEditTarget.avatar,
        outputDirectory: out,
        opener: (c, s, target) async {
          seen = target;
          return result;
        },
        encode: (rgba, w, h, q) async {
          qualities.add(q);
          return PhotoEditService.encodeJpegSync(rgba, w, h, q);
        },
      ),
    );
    expect(file, isNotNull);
    expect(seen, PhotoEditTarget.avatar);
    expect(qualities, [PhotoEditService.avatarQuality]);
  });

  testWidgets('photo ordinaire : qualité 80 (celle du sélecteur remplacé)',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(64, 64));
    final qualities = <int>[];
    await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, s, target) async => result,
        encode: (rgba, w, h, q) async {
          qualities.add(q);
          return PhotoEditService.encodeJpegSync(rgba, w, h, q);
        },
      ),
    );
    expect(qualities, [PhotoEditService.photoQuality]);
  });

  testWidgets('plus lourd que l\'original : on baisse la qualité, par paliers',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(320, 240));
    final small = File(p.join(tmp.path, 'petite.jpg'))
      ..writeAsBytesSync(List<int>.filled(5000, 1));
    final qualities = <int>[];
    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        small,
        outputDirectory: out,
        opener: (c, s, target) async => result,
        encode: (rgba, w, h, q) async {
          qualities.add(q);
          return PhotoEditService.encodeJpegSync(rgba, w, h, q);
        },
      ),
    );
    // Toujours trop lourd à 5 Ko : on s'arrête au plancher, sans boucler.
    expect(qualities, [80, 70, 60]);
    expect(file, isNotNull);
    expect(_isJpeg(file!.readAsBytesSync()), isTrue);
  });

  testWidgets('original léger et JPEG plus léger encore : un seul essai',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(64, 64));
    final qualities = <int>[];
    await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original, // 900 Ko
        outputDirectory: out,
        opener: (c, s, target) async => result,
        encode: (rgba, w, h, q) async {
          qualities.add(q);
          return PhotoEditService.encodeJpegSync(rgba, w, h, q);
        },
      ),
    );
    expect(qualities, [80]);
  });

  testWidgets('les zones transparentes passent sur fond blanc', (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(32, 32, alpha: 0));
    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, s, target) async => result,
      ),
    );
    final px = await t.runAsync(() => decodePixels(file!.readAsBytesSync()));
    final c = px!.at(16, 16);
    expect(c[0], greaterThan(245));
    expect(c[1], greaterThan(245));
    expect(c[2], greaterThan(245));
  });

  testWidgets('échec de l\'encodage : exception nette, aucun fichier',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(32, 32));
    await t.runAsync(() async {
      await expectLater(
        PhotoEditService.edit(
          ctx,
          original,
          outputDirectory: out,
          opener: (c, s, target) async => result,
          encode: (rgba, w, h, q) async => throw StateError('boum'),
        ),
        throwsA(isA<StateError>()),
      );
    });
    expect(out.listSync(), isEmpty);
  });

  testWidgets('PNG illisible : PhotoEditException', (t) async {
    final ctx = await _context(t);
    await t.runAsync(() async {
      await expectLater(
        PhotoEditService.edit(
          ctx,
          original,
          outputDirectory: out,
          opener: (c, s, target) async => MediaEditorResult(
            png: Uint8List.fromList([1, 2, 3]),
            width: 1,
            height: 1,
          ),
        ),
        throwsA(isA<PhotoEditException>()),
      );
    });
    expect(out.listSync(), isEmpty);
  });

  testWidgets('les retouches de plus d\'un jour sont purgées, pas les autres',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(16, 16));
    final old = File(p.join(out.path, 'edited_vieux.jpg'))
      ..writeAsBytesSync([1]);
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final recent = File(p.join(out.path, 'edited_recent.jpg'))
      ..writeAsBytesSync([1]);
    await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, s, target) async => result,
      ),
    );
    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
  });

  test('discard ne supprime que nos retouches, jamais un fichier utilisateur',
      () async {
    final mine = File(p.join(out.path, 'edited_1.jpg'))..writeAsBytesSync([1]);
    final lookalike = File(p.join(tmp.path, 'edited_2.jpg'))
      ..writeAsBytesSync([1]);
    expect(PhotoEditService.isEdited(mine), isTrue);
    expect(PhotoEditService.isEdited(lookalike), isFalse);
    expect(PhotoEditService.isEdited(original), isFalse);

    await PhotoEditService.discard(mine);
    await PhotoEditService.discard(lookalike);
    await PhotoEditService.discard(original);
    await PhotoEditService.discard(null);
    expect(mine.existsSync(), isFalse);
    expect(lookalike.existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
  });

  testWidgets('encodeur par défaut (isolat) : JPEG valide', (t) async {
    final r = await t.runAsync(() => _photoResult(48, 32));
    final jpeg = await t.runAsync(() async {
      final px = Uint8List(48 * 32 * 4)..fillRange(0, 48 * 32 * 4, 200);
      return PhotoEditService.encodeJpegInIsolate(px, 48, 32, 80);
    });
    expect(_isJpeg(jpeg!), isTrue);
    expect(r, isNotNull);
  });

  testWidgets('la retouche suit le circuit d\'envoi : outbox (.jpg) et vignette',
      (t) async {
    final ctx = await _context(t);
    final result = await t.runAsync(() => _photoResult(160, 120));
    final file = await t.runAsync(
      () => PhotoEditService.edit(
        ctx,
        original,
        outputDirectory: out,
        opener: (c, s, target) async => result,
      ),
    );
    final outbox = Directory(p.join(tmp.path, 'outbox'));
    final staged = await t.runAsync(
      () => stageMediaFile(file!, outboxDirectory: outbox),
    );
    // Même fichier, copié tel quel dans l'outbox : c'est lui le pendingUploadPath.
    expect(p.extension(staged!.path), '.jpg');
    expect(staged.readAsBytesSync(), file!.readAsBytesSync());
    final thumb = await t.runAsync(
      () => ImageThumbnailService.base64ForFile(staged.path),
    );
    expect(thumb, isNotNull);
    expect(thumb, isNotEmpty);
  });
}
