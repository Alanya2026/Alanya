// Aides des tests de l'éditeur d'image : images synthétiques fabriquées par
// dart:ui (aucun paquet `image`) et lecture des pixels d'un PNG exporté.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:talky_flutter/features/media_editor/cutout/person_segmenter.dart';

/// Image pleine de couleur [color], w×h.
Future<ui.Image> solidImage(
  int w,
  int h, {
  ui.Color color = const ui.Color(0xFFD03030),
}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = color,
  );
  final pic = rec.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  return img;
}

/// PNG d'une image pleine w×h.
Future<Uint8List> solidPng(
  int w,
  int h, {
  ui.Color color = const ui.Color(0xFFD03030),
}) async {
  final img = await solidImage(w, h, color: color);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// Pixels RGBA d'un PNG.
class Pixels {
  Pixels(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;

  /// (r, g, b, a) du pixel (x, y).
  List<int> at(int x, int y) {
    final o = (y * width + x) * 4;
    return [rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]];
  }

  int alphaAt(int x, int y) => at(x, y)[3];
}

Future<Pixels> decodePixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final p = Pixels(img.width, img.height, data!.buffer.asUint8List());
  img.dispose();
  codec.dispose();
  return p;
}

/// Détoureur de personnes factice : renvoie un masque synthétique (aucun ML
/// Kit en test) ou lève l'erreur demandée. [gate] permet de suspendre le calcul
/// pour tester l'état « en cours ».
class FakePersonSegmenter implements PersonSegmenter {
  FakePersonSegmenter({this.mask, this.error, this.supported = true, this.gate});

  PersonMask? mask;
  PersonSegmentationException? error;
  bool supported;
  Future<void>? gate;
  int calls = 0;
  bool disposed = false;
  ui.Image? lastImage;

  @override
  bool get isSupported => supported;

  @override
  Future<PersonMask> segment(ui.Image image) async {
    calls++;
    lastImage = image;
    if (gate != null) await gate;
    final e = error;
    if (e != null) throw e;
    return mask!;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// Masque [w]×[h] dont les colonnes `< splitX` sont « personne ».
PersonMask leftHalfMask(int w, int h, {int? splitX}) {
  final split = splitX ?? w ~/ 2;
  final a = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < split; x++) {
      a[y * w + x] = 255;
    }
  }
  return PersonMask(width: w, height: h, alpha: a);
}
