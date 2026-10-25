// Adaptation d'une photo de la galerie avant envoi : contain dans un canevas
// 512×512 transparent, export PNG par dart:ui, puis contrôle d'envoi. Images
// synthétiques : fixtures JPEG/WebP/GIF minuscules (test/fixtures/stickers/
// images) et PNG fabriqués ici par dart:ui — aucun paquet `image`.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_adapter.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';

Uint8List _fixture(String nom) =>
    File('test/fixtures/stickers/images/$nom').readAsBytesSync();

/// PNG w×h : fond [bg], rectangle [fg] au centre (moitié de chaque côté).
Future<Uint8List> _pngSynth(
  int w,
  int h, {
  ui.Color bg = const ui.Color(0xFF0A78C8),
  ui.Color fg = const ui.Color(0xFFF0F014),
}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = bg);
  c.drawRect(
    ui.Rect.fromLTWH(w / 4, h / 4, w / 2, h / 2),
    ui.Paint()..color = fg,
  );
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// PNG de bruit aléatoire (incompressible) w×h, opaque.
Future<Uint8List> _pngNoise(int w, int h, {bool randomAlpha = false}) async {
  final rnd = Random(7);
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < px.length; i++) {
    px[i] = (i % 4 == 3 && !randomAlpha) ? 255 : rnd.nextInt(256);
    if (randomAlpha && i % 4 != 3) px[i] = rnd.nextInt(256);
  }
  final buf = await ui.ImmutableBuffer.fromUint8List(px);
  final desc = ui.ImageDescriptor.raw(
    buf,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final img = (await codec.getNextFrame()).image;
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  codec.dispose();
  desc.dispose();
  buf.dispose();
  return data!.buffer.asUint8List();
}

/// Pixels RGBA d'un PNG de sortie.
class _Px {
  _Px(this.w, this.h, this.rgba);
  final int w, h;
  final Uint8List rgba;
  (int, int, int, int) at(int x, int y) {
    final o = (y * w + x) * 4;
    return (rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3]);
  }
}

Future<_Px> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final img = (await codec.getNextFrame()).image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final r = _Px(img.width, img.height, data!.buffer.asUint8List());
  img.dispose();
  codec.dispose();
  return r;
}

Future<StickerImageIssue?> _issue(Uint8List d) async {
  try {
    await StickerImageAdapter.adapt(d);
    return null;
  } on StickerImageRejected catch (e) {
    return e.issue;
  }
}

/// La sortie doit passer le contrôle d'envoi tel quel.
void _assertEnvoyable(Uint8List out) {
  final info = StickerImageCheck.validate(out);
  expect((info.mime, info.width, info.height, info.hasAlpha), ('image/png', 512, 512, true));
  expect(out.length, lessThanOrEqualTo(StickerImageCheck.maxBytes));
}

bool _near(int a, int b, [int tol = 40]) => (a - b).abs() <= tol;

void main() {
  group('contain dans 512×512 transparent', () {
    test('JPEG paysage 300×100 : barres transparentes haut/bas, pas déformé', () async {
      final out = await StickerImageAdapter.adapt(_fixture('paysage-300x100.jpg'));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect((p.w, p.h), (512, 512));
      // 300×100 → 512×170,7 centré : vertical de ~171 à ~341.
      expect(p.at(256, 20).$4, 0, reason: 'barre du haut transparente');
      expect(p.at(256, 490).$4, 0, reason: 'barre du bas transparente');
      expect(p.at(100, 256).$4, 255);
      expect(p.at(400, 256).$4, 255);
      // Gauche rouge, droite bleue : le contenu occupe toute la largeur.
      final left = p.at(100, 256), right = p.at(400, 256);
      expect(left.$1, greaterThan(left.$3));
      expect(right.$3, greaterThan(right.$1));
      // Bords du contenu (non déformé : hauteur 512/3 ≈ 171).
      expect(p.at(256, 180).$4, 255);
      expect(p.at(256, 160).$4, 0);
      expect(p.at(256, 332).$4, 255);
      expect(p.at(256, 352).$4, 0);
    });

    test('JPEG portrait 90×270 : barres transparentes à gauche/droite', () async {
      final out = await StickerImageAdapter.adapt(_fixture('portrait-90x270.jpg'));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect(p.at(20, 256).$4, 0);
      expect(p.at(490, 256).$4, 0);
      final c = p.at(256, 256);
      expect(c.$4, 255);
      expect(c.$2, greaterThan(c.$1)); // vert
      // Largeur du contenu ≈ 170 : transparent à x=150, opaque à x=180.
      expect(p.at(150, 256).$4, 0);
      expect(p.at(180, 256).$4, 255);
    });

    test('JPEG carré opaque : la sortie garde un canal alpha', () async {
      final out = await StickerImageAdapter.adapt(_fixture('carre-256.jpg'));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect(p.at(2, 2).$4, 255);
      expect(p.at(509, 509).$4, 255);
    });

    test('WebP avec alpha 200×100 : transparence conservée', () async {
      final out = await StickerImageAdapter.adapt(_fixture('alpha-200x100.webp'));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect(p.at(5, 140).$4, 0, reason: 'coin du contenu hors ellipse');
      expect(p.at(256, 256).$4, 255);
      final c = p.at(256, 256);
      expect(_near(c.$1, 250), isTrue);
      expect(_near(c.$2, 200), isTrue);
      expect(p.at(256, 20).$4, 0, reason: 'barre transparente');
    });

    test('petite image 40×40 : agrandie pour remplir le canevas', () async {
      final out = await StickerImageAdapter.adapt(await _pngSynth(40, 40));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect(p.at(5, 5).$4, 255);
      expect(p.at(506, 506).$4, 255);
    });
  });

  group('grandes images et mémoire', () {
    test('JPEG 1500×500 (> 1024) : décodé borné, sortie 512×512', () async {
      final out = await StickerImageAdapter.adapt(_fixture('grand-1500x500.jpg'));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect(p.at(256, 20).$4, 0);
      final c = p.at(256, 256);
      expect(c.$4, 255);
      expect(c.$1, greaterThan(200)); // jaune au centre
    });

    test('PNG 4000×3000 : sortie 512×512 alpha PNG < 1 Mo', () async {
      final big = await _pngSynth(4000, 3000);
      final out = await StickerImageAdapter.adapt(big);
      _assertEnvoyable(out);
      final p = await _decode(out);
      // 4:3 dans un carré : barres haut et bas de 64 px.
      expect(p.at(256, 20).$4, 0);
      expect(p.at(256, 256).$4, 255);
      expect(p.at(256, 256).$1, greaterThan(200));
    });

    test('PNG de bruit 1400×1400 (≈ 8 Mo en entrée) : sortie < 1 Mo', () async {
      final noise = await _pngNoise(1400, 1400);
      expect(noise.length, lessThanOrEqualTo(StickerImageAdapter.maxInputBytes));
      final out = await StickerImageAdapter.adapt(noise);
      _assertEnvoyable(out);
    });

    test('PNG 512×512 déjà conforme : rendu tel quel, sans ré-encodage', () async {
      final ok = await _pngSynth(512, 512);
      expect(ok.length, lessThan(StickerImageCheck.maxBytes));
      final out = await StickerImageAdapter.adapt(ok);
      expect(identical(out, ok), isTrue);
    });

    test('sortie trop lourde : réessayée plus petit dans le canevas', () async {
      // L'encodeur PNG tient du bruit pur sous 1 Mo : on abaisse le plafond
      // pour forcer les échelles réduites (le canevas reste 512×512).
      final noise = await _pngNoise(900, 900);
      final plein = await StickerImageAdapter.adapt(noise);
      final limit = (plein.length * 0.8).round();
      final out = await StickerImageAdapter.adapt(noise, maxOutputBytes: limit);
      expect(out.length, lessThanOrEqualTo(limit));
      expect(out.length, lessThan(plein.length));
      _assertEnvoyable(out);
      final p = await _decode(out);
      expect((p.w, p.h), (512, 512));
      expect(p.at(2, 2).$4, 0, reason: 'le contenu rétréci laisse un bord transparent');
    });

    test('toujours trop lourd après les réessais : tooBig', () async {
      final noise = await _pngNoise(900, 900);
      await expectLater(
        StickerImageAdapter.adapt(noise, maxOutputBytes: 1000),
        throwsA(isA<StickerImageRejected>()
            .having((e) => e.issue, 'issue', StickerImageIssue.tooBig)),
      );
    });
  });

  group('refus', () {
    test('octets quelconques ou vides : format', () async {
      expect(await _issue(Uint8List.fromList([1, 2, 3, 4, 5])), StickerImageIssue.format);
      expect(await _issue(Uint8List(0)), StickerImageIssue.format);
      expect(await _issue(Uint8List.fromList('pas une image du tout'.codeUnits)), StickerImageIssue.format);
    });

    test('PNG tronqué (signature seule) : format', () async {
      expect(
        await _issue(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0])),
        StickerImageIssue.format,
      );
    });

    test('plus de 20 Mo en entrée : inputTooBig, sans décoder', () async {
      expect(
        await _issue(Uint8List(StickerImageAdapter.maxInputBytes + 1)),
        StickerImageIssue.inputTooBig,
      );
    });

    test('GIF animé : refusé (animated)', () async {
      expect(await _issue(_fixture('anime.gif')), StickerImageIssue.animated);
    });

    test('WebP animé : refusé (animated)', () async {
      expect(await _issue(_fixture('anime.webp')), StickerImageIssue.animated);
    });

    test('GIF statique : accepté et adapté', () async {
      final out = await StickerImageAdapter.adapt(_fixture('statique-32x32.gif'));
      _assertEnvoyable(out);
    });

    test('dimensions démesurées (> 50 mégapixels) : inputTooBig', () async {
      // En-tête PNG 10000×10000 : le descripteur le lit sans décoder les pixels.
      final b = BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13])
        ..add('IHDR'.codeUnits)
        ..add([0, 0, 0x27, 0x10, 0, 0, 0x27, 0x10, 8, 6, 0, 0, 0, 0, 0, 0, 0]);
      final issue = await _issue(b.toBytes());
      // Selon le moteur, l'en-tête seul est refusé comme illisible : dans les
      // deux cas rien n'est décodé et l'utilisateur a un message.
      expect(issue, anyOf(StickerImageIssue.inputTooBig, StickerImageIssue.format));
    });
  });
}
