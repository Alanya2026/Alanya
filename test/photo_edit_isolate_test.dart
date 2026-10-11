// Garde-fous du paquet `image` (autorisé pour le seul encodage JPEG des photos
// retouchées) : jamais importé ailleurs, et son travail lourd tourne hors du
// fil de l'interface.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:talky_flutter/core/services/photo_edit_service.dart';

List<File> _dartFilesUnder(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('package:image n\'est importé que par photo_edit_service.dart', () {
    final importers = <String>[];
    final pattern = RegExp(r'''['"]package:image/''');
    for (final f in _dartFilesUnder('lib')) {
      if (pattern.hasMatch(f.readAsStringSync())) importers.add(f.path);
    }
    expect(importers, ['lib/core/services/photo_edit_service.dart']);
  });

  test('la variante synchrone de l\'encodage n\'est jamais appelée par l\'app',
      () {
    final callers = <String>[];
    for (final f in _dartFilesUnder('lib')) {
      if (f.path.endsWith('photo_edit_service.dart')) continue;
      if (f.readAsStringSync().contains('encodeJpegSync')) callers.add(f.path);
    }
    expect(callers, isEmpty);
  });

  test('l\'encodage par défaut est asynchrone (Future, non résolu d\'emblée)',
      () {
    final f = PhotoEditService.encodeJpegInIsolate(
      Uint8List(16 * 16 * 4)..fillRange(0, 16 * 16 * 4, 255),
      16,
      16,
      80,
    );
    expect(f, isA<Future<Uint8List>>());
    return f.then((b) => expect(b.sublist(0, 2), [0xFF, 0xD8]));
  });

  testWidgets('pendant l\'encodage d\'une grande photo, la boucle d\'événements '
      'du fil principal continue de tourner', (t) async {
    const w = 1024;
    const h = 1024;
    final rnd = Random(3);
    final px = Uint8List(w * h * 4);
    for (var i = 0; i < px.length; i++) {
      px[i] = rnd.nextInt(256);
    }
    final ticks = await t.runAsync(() async {
      var n = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => n++);
      final jpeg = await PhotoEditService.encodeJpegInIsolate(px, w, h, 80);
      timer.cancel();
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      return n;
    });
    // Encodé sur le fil principal, aucun tick n'aurait pu passer.
    expect(ticks, greaterThan(3));
  });
}
