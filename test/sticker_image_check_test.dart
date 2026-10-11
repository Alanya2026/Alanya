// Contrôle d'image avant envoi (contrat §8) : PNG/WebP ≤ 1 Mo, exactement
// 512×512, alpha obligatoire. Octets d'en-tête fabriqués : seul l'en-tête est
// lu (le serveur décode et tranche).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';

Uint8List _png(int w, int h, {int colorType = 6, bool trns = false, int pad = 0}) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void be32(int v) => b.add([v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255]);
  be32(13);
  b.add('IHDR'.codeUnits);
  be32(w);
  be32(h);
  b.add([8, colorType, 0, 0, 0]);
  be32(0); // CRC (non lu)
  if (trns) {
    be32(1);
    b.add('tRNS'.codeUnits);
    b.add([0]);
    be32(0);
  }
  be32(0);
  b.add('IDAT'.codeUnits);
  be32(0);
  b.add(List.filled(pad, 0));
  return b.toBytes();
}

Uint8List _vp8x(int w, int h, {bool alpha = true, bool anim = false}) {
  final d = Uint8List(30);
  d.setAll(0, 'RIFF'.codeUnits);
  d.setAll(8, 'WEBP'.codeUnits);
  d.setAll(12, 'VP8X'.codeUnits);
  d[16] = 10;
  d[20] = (alpha ? 0x10 : 0) | (anim ? 0x02 : 0);
  final cw = w - 1, ch = h - 1;
  d[24] = cw & 255;
  d[25] = cw >> 8 & 255;
  d[26] = cw >> 16 & 255;
  d[27] = ch & 255;
  d[28] = ch >> 8 & 255;
  d[29] = ch >> 16 & 255;
  return d;
}

Uint8List _vp8l(int w, int h, {bool alpha = true}) {
  final d = Uint8List(30);
  d.setAll(0, 'RIFF'.codeUnits);
  d.setAll(8, 'WEBP'.codeUnits);
  d.setAll(12, 'VP8L'.codeUnits);
  d[20] = 0x2F;
  final bits = (w - 1) | ((h - 1) << 14) | ((alpha ? 1 : 0) << 28);
  d[21] = bits & 255;
  d[22] = bits >> 8 & 255;
  d[23] = bits >> 16 & 255;
  d[24] = bits >> 24 & 255;
  return d;
}

Uint8List _vp8(int w, int h) {
  final d = Uint8List(30);
  d.setAll(0, 'RIFF'.codeUnits);
  d.setAll(8, 'WEBP'.codeUnits);
  d.setAll(12, 'VP8 '.codeUnits);
  d[23] = 0x9D;
  d[24] = 0x01;
  d[25] = 0x2A;
  d[26] = w & 255;
  d[27] = w >> 8 & 255;
  d[28] = h & 255;
  d[29] = h >> 8 & 255;
  return d;
}

StickerImageIssue? _issue(Uint8List d) {
  try {
    StickerImageCheck.validate(d);
    return null;
  } on StickerImageRejected catch (e) {
    return e.issue;
  }
}

void main() {
  test('PNG RGBA 512×512 : accepté', () {
    final i = StickerImageCheck.validate(_png(512, 512));
    expect((i.mime, i.width, i.height, i.hasAlpha), ('image/png', 512, 512, true));
  });

  test('PNG gris+alpha et palette avec tRNS : alpha reconnu', () {
    expect(_issue(_png(512, 512, colorType: 4)), isNull);
    expect(_issue(_png(512, 512, colorType: 3, trns: true)), isNull);
  });

  test('PNG sans alpha (RGB, palette sans tRNS) : refusé', () {
    expect(_issue(_png(512, 512, colorType: 2)), StickerImageIssue.noAlpha);
    expect(_issue(_png(512, 512, colorType: 3)), StickerImageIssue.noAlpha);
  });

  test('taille : tout ce qui n\'est pas 512×512 est refusé', () {
    expect(_issue(_png(500, 500)), StickerImageIssue.size);
    expect(_issue(_png(512, 256)), StickerImageIssue.size);
    expect(_issue(_png(1024, 1024)), StickerImageIssue.size);
  });

  test('plus d\'1 Mo : refusé avant tout le reste', () {
    expect(_issue(_png(512, 512, pad: 1024 * 1024)), StickerImageIssue.tooBig);
    expect(_issue(_png(10, 10, pad: 1024 * 1024)), StickerImageIssue.tooBig);
  });

  test('ni PNG ni WebP : format', () {
    expect(_issue(Uint8List.fromList([1, 2, 3])), StickerImageIssue.format);
    expect(_issue(Uint8List(0)), StickerImageIssue.format);
    // JPEG
    expect(_issue(Uint8List.fromList(List.filled(64, 0xFF))), StickerImageIssue.format);
  });

  test('WebP VP8X : alpha, taille, animation', () {
    expect(_issue(_vp8x(512, 512)), isNull);
    expect(_issue(_vp8x(512, 512, alpha: false)), StickerImageIssue.noAlpha);
    expect(_issue(_vp8x(256, 512)), StickerImageIssue.size);
    expect(_issue(_vp8x(512, 512, anim: true)), StickerImageIssue.animated);
  });

  test('WebP VP8L (sans perte) et VP8 (avec perte, sans alpha)', () {
    expect(_issue(_vp8l(512, 512)), isNull);
    expect(_issue(_vp8l(512, 512, alpha: false)), StickerImageIssue.noAlpha);
    expect(_issue(_vp8l(100, 100)), StickerImageIssue.size);
    expect(_issue(_vp8(512, 512)), StickerImageIssue.noAlpha);
    expect(_issue(_vp8(300, 300)), StickerImageIssue.size);
  });
}
