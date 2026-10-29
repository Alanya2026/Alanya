// Détection d'un GIF / WebP animé par octets magiques (V1c, T5b) : GIF87a /
// GIF89a (≥ 2 images), RIFF…WEBP avec chunk ANIM ; ≤ 3 Mo ; sinon refus clair.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_animated_check.dart';

Uint8List _img(String nom) =>
    File('test/fixtures/stickers/images/$nom').readAsBytesSync();

/// GIF minimal : en-tête, écran logique 1×1 sans table de couleurs, puis
/// [frames] images 1×1 (descripteur + code LZW + un sous-bloc), terminateur.
Uint8List _gif(int frames, {String magic = 'GIF89a', bool trailer = true}) {
  final b = BytesBuilder();
  b.add(magic.codeUnits);
  b.add([1, 0, 1, 0, 0x00, 0, 0]); // largeur, hauteur, flags, fond, ratio
  for (var i = 0; i < frames; i++) {
    // Extension de contrôle graphique (obligatoire avant chaque image animée).
    b.add([0x21, 0xF9, 4, 0, 5, 0, 0, 0]);
    b.add([0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0]); // descripteur d'image, 1×1
    b.add([2, 2, 0x44, 0x01, 0]); // taille de code, sous-bloc de 2 octets, fin
  }
  if (trailer) b.add([0x3B]);
  return b.toBytes();
}

/// WebP RIFF minimal avec les chunks demandés (contenu sans importance : seule
/// la structure des chunks est lue).
Uint8List _webp(List<String> chunks) {
  final body = BytesBuilder();
  body.add('WEBP'.codeUnits);
  for (final tag in chunks) {
    body.add(tag.codeUnits);
    body.add([6, 0, 0, 0]); // taille 6 (paire)
    body.add(List.filled(6, 0));
  }
  final data = body.toBytes();
  final out = BytesBuilder();
  out.add('RIFF'.codeUnits);
  out.add([
    data.length & 255,
    (data.length >> 8) & 255,
    (data.length >> 16) & 255,
    (data.length >> 24) & 255,
  ]);
  out.add(data);
  return out.toBytes();
}

void main() {
  group('GIF', () {
    test('GIF89a à plusieurs images : animé', () {
      final i = StickerAnimatedCheck.inspect(_gif(3))!;
      expect(i.kind, StickerAnimatedKind.gif);
      expect(i.animated, isTrue);
      expect(StickerAnimatedCheck.isAnimated(_gif(3)), isTrue);
    });

    test('GIF87a à plusieurs images : animé', () {
      expect(StickerAnimatedCheck.inspect(_gif(2, magic: 'GIF87a'))!.animated,
          isTrue);
    });

    test('GIF à une seule image : reconnu, mais fixe', () {
      final i = StickerAnimatedCheck.inspect(_gif(1))!;
      expect(i.kind, StickerAnimatedKind.gif);
      expect(i.animated, isFalse);
      expect(() => StickerAnimatedCheck.validate(_gif(1)),
          throwsA(isA<StickerAnimatedRejected>().having(
              (e) => e.issue, 'issue', StickerAnimatedIssue.notAnimated)));
    });

    test('fichiers de test existants : anime.gif animé, statique-32x32.gif fixe',
        () {
      expect(StickerAnimatedCheck.inspect(_img('anime.gif'))!.animated, isTrue);
      expect(StickerAnimatedCheck.inspect(_img('statique-32x32.gif'))!.animated,
          isFalse);
    });

    test('GIF tronqué : aucune exception, jamais « animé » à tort', () {
      final full = _gif(4);
      for (var cut = 0; cut < full.length; cut += 3) {
        final part = Uint8List.sublistView(full, 0, cut);
        final i = StickerAnimatedCheck.inspect(part);
        if (cut < 13) {
          expect(i, isNull, reason: 'cut=$cut');
        } else {
          expect(i, isNotNull, reason: 'cut=$cut');
        }
      }
      // Coupé juste après la première image : une seule image vue.
      expect(
          StickerAnimatedCheck.inspect(Uint8List.sublistView(_gif(4), 0, 13 + 8 + 10 + 5))!
              .animated,
          isFalse);
    });
  });

  group('WebP', () {
    test('WebP animé réel (Pillow, 5 images) : animé, 5 images comptées', () {
      final i = StickerAnimatedCheck.inspect(_img('anime-5x50ms.webp'))!;
      expect(i.kind, StickerAnimatedKind.webp);
      expect(i.animated, isTrue);
      expect(i.frames, 5);
    });

    test('anime.webp existant : animé', () {
      expect(StickerAnimatedCheck.inspect(_img('anime.webp'))!.animated, isTrue);
    });

    test('WebP fixe (alpha-200x100.webp) : reconnu, mais fixe', () {
      final i = StickerAnimatedCheck.inspect(_img('alpha-200x100.webp'))!;
      expect(i.kind, StickerAnimatedKind.webp);
      expect(i.animated, isFalse);
    });

    test('RIFF…WEBP avec chunk ANIM : animé ; sans ANIM : fixe', () {
      expect(StickerAnimatedCheck.inspect(_webp(['VP8X', 'ANIM', 'ANMF']))!.animated,
          isTrue);
      expect(StickerAnimatedCheck.inspect(_webp(['VP8X', 'VP8 ']))!.animated,
          isFalse);
    });

    test('RIFF qui n\'est pas du WebP (WAVE) : refusé', () {
      final b = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add([4, 0, 0, 0])
        ..add('WAVE'.codeUnits)
        ..add(List.filled(8, 0));
      expect(StickerAnimatedCheck.inspect(b.toBytes()), isNull);
    });
  });

  group('validate', () {
    test('accepte un GIF et un WebP animés ≤ 3 Mo', () {
      expect(StickerAnimatedCheck.validate(_gif(3)).kind, StickerAnimatedKind.gif);
      expect(StickerAnimatedCheck.validate(_img('anime-5x50ms.webp')).kind,
          StickerAnimatedKind.webp);
    });

    test('plus de 3 Mo : tooBig (avant toute lecture du format)', () {
      final big = Uint8List(StickerAnimatedCheck.maxBytes + 1);
      expect(() => StickerAnimatedCheck.validate(big),
          throwsA(isA<StickerAnimatedRejected>().having(
              (e) => e.issue, 'issue', StickerAnimatedIssue.tooBig)));
      // Exactement 3 Mo de GIF animé : passe.
      final exact = Uint8List(StickerAnimatedCheck.maxBytes)
        ..setAll(0, _gif(3));
      expect(StickerAnimatedCheck.validate(exact).animated, isTrue);
    });

    test('PNG, JPEG, texte, vide : format', () {
      for (final data in [
        _img('carre-256.jpg'),
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, 0, 0]),
        Uint8List.fromList('hello world, not an image'.codeUnits),
        Uint8List(0),
      ]) {
        expect(() => StickerAnimatedCheck.validate(data),
            throwsA(isA<StickerAnimatedRejected>().having(
                (e) => e.issue, 'issue', StickerAnimatedIssue.format)));
      }
    });

    test('hostile : octets aléatoires et en-têtes tronqués ne lèvent rien d\'autre',
        () {
      for (var seed = 0; seed < 60; seed++) {
        final data = Uint8List.fromList(
            List.generate(200 + seed, (i) => (i * 31 + seed * 7) & 255));
        // Faux en-têtes suivis de bruit.
        for (final head in ['GIF89a', 'GIF87a', 'RIFF']) {
          final x = Uint8List.fromList([...head.codeUnits, ...data]);
          expect(() => StickerAnimatedCheck.inspect(x), returnsNormally);
        }
      }
    });
  });
}
