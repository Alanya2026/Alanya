// Éditeur d'image (T4b) : rendu partagé écran/export. Export PNG par dart:ui
// seulement (aucun paquet `image`), contrôlé par StickerImageCheck. Les pixels
// attendus se lisent sur un fond transparent ; en test, tout texte est dessiné
// en carrés pleins (police Ahem), ce qui rend le contrôle exact.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/media_editor_source.dart';
import 'package:talky_flutter/features/media_editor/model/editor_commands.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';
import 'package:talky_flutter/features/media_editor/render/editor_exporter.dart';

import 'support/media_editor_fakes.dart';

const _blue = ui.Color(0xFF0000FF);
const _green = ui.Color(0xFF00FF00);

/// Image 100×50 pleine rouge : en « contain » dans 512×512 elle occupe
/// y ∈ [128, 384] ; le reste du cadre est transparent.
Future<EditorController> _sticker({int w = 100, int h = 50}) async =>
    EditorController(
      mode: MediaEditorMode.sticker,
      image: await solidImage(w, h),
    );

Future<MediaEditorResult> _export(
  EditorController c, {
  int max = StickerImageCheck.maxBytes,
}) => MediaEditorExporter.export(c.doc, c.image, c.mode, maxOutputBytes: max);

void main() {
  test(
    'sticker : PNG 512×512 valide, ≤ 1 Mo, alpha, contrôle d\'envoi passé',
    () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final r = await _export(c);
      expect(r.width, 512);
      expect(r.height, 512);
      // Signature PNG.
      expect(r.png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      expect(r.png.length, lessThanOrEqualTo(StickerImageCheck.maxBytes));
      final info = StickerImageCheck.validate(r.png);
      expect(info.mime, 'image/png');
      expect(info.width, 512);
      expect(info.height, 512);
      expect(info.hasAlpha, isTrue);
      expect(info.animated, isFalse);
    },
  );

  test(
    'le fond hors de l\'image reste transparent, l\'image est au centre',
    () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final px = await decodePixels((await _export(c)).png);
      expect(px.width, 512);
      expect(px.alphaAt(5, 5), 0);
      expect(px.alphaAt(506, 506), 0);
      expect(px.alphaAt(256, 64), 0, reason: 'au-dessus de l\'image');
      expect(px.alphaAt(256, 448), 0, reason: 'en dessous de l\'image');
      final centre = px.at(256, 256);
      expect(centre[0], greaterThan(180)); // rouge
      expect(centre[3], 255);
    },
  );

  test(
    'rognage : « remplir » couvre tout le cadre, le zoom suit le geste',
    () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.fitImage(cover: true);
      final px = await decodePixels((await _export(c)).png);
      expect(px.alphaAt(5, 5), 255);
      expect(px.alphaAt(506, 300), 255);

      // Image déplacée tout à gauche : la droite du cadre redevient transparente.
      c.fitImage(cover: false);
      c.beginImageGesture();
      c.updateImageTransform(
        c.doc.imageTransform.copyWith(center: const ui.Offset(0, 256)),
      );
      c.endImageGesture();
      final moved = await decodePixels((await _export(c)).png);
      expect(moved.alphaAt(100, 256), 255);
      expect(moved.alphaAt(500, 256), 0);
    },
  );

  test(
    'un trait : pixels de la couleur attendue sur fond transparent',
    () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setPenColor(_blue);
      c.setPenWidth(20);
      // Trait horizontal à y = 64, hors de l'image (transparente).
      c.beginStroke(const ui.Offset(60, 64));
      for (var x = 70.0; x <= 450; x += 10) {
        c.extendStroke(ui.Offset(x, 64));
      }
      c.endStroke();
      final px = await decodePixels((await _export(c)).png);
      final sur = px.at(256, 64);
      expect(sur, [0, 0, 255, 255]);
      expect(px.alphaAt(256, 64 + 14), 0, reason: 'au-delà de l\'épaisseur');
      expect(px.alphaAt(256, 64 - 14), 0);
      expect(px.alphaAt(20, 64), 0, reason: 'avant le début du trait');
      // L'image dessous n'a pas bougé.
      expect(px.at(256, 256)[0], greaterThan(180));
    },
  );

  test('un point isolé donne un disque', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    c.setPenColor(_green);
    c.setPenWidth(30);
    c.beginStroke(const ui.Offset(100, 60));
    c.endStroke();
    final px = await decodePixels((await _export(c)).png);
    expect(px.at(100, 60), [0, 255, 0, 255]);
    expect(px.alphaAt(100, 60 + 25), 0);
  });

  test('la gomme du crayon efface les traits, jamais l\'image', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    c.setPenColor(_blue);
    c.setPenWidth(40);
    // Trait épais sur l'image (y = 256) et au-dessus (y = 64).
    for (final y in [256.0, 64.0]) {
      c.beginStroke(ui.Offset(60, y));
      c.extendStroke(ui.Offset(450, y));
      c.endStroke();
    }
    // Gomme : bande verticale à x = 256.
    c.setErasing(true);
    c.setPenWidth(40);
    c.beginStroke(const ui.Offset(256, 10));
    c.extendStroke(const ui.Offset(256, 500));
    c.endStroke();
    final px = await decodePixels((await _export(c)).png);
    expect(px.alphaAt(256, 64), 0, reason: 'trait effacé hors image');
    // Sur l'image : le trait est effacé, l'image rouge reste (pas de trou).
    final sur = px.at(256, 256);
    expect(sur[3], 255);
    expect(sur[0], greaterThan(180));
    expect(sur[2], lessThan(60));
    // Hors de la bande, le trait reste bleu.
    expect(px.at(120, 256), [0, 0, 255, 255]);
    expect(px.at(120, 64), [0, 0, 255, 255]);
  });

  test(
    'un texte : pixels de sa couleur au bon endroit, fond transparent',
    () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final id = c.addText('X', EditorFont.standard, _green);
      // Hors de l'image, au-dessus.
      c.beginItemGesture(id);
      c.updateItemPlacement(
        c.doc
            .itemById(id)!
            .placement
            .copyWith(center: const ui.Offset(256, 64)),
      );
      c.endItemGesture();
      final px = await decodePixels((await _export(c)).png);
      expect(px.at(256, 64), [0, 255, 0, 255]);
      expect(px.alphaAt(10, 10), 0);
      expect(px.alphaAt(500, 64), 0);
    },
  );

  test('texte pivoté / agrandi : l\'export suit la transformation', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    final id = c.addText('X', EditorFont.standard, _green);
    c.beginItemGesture(id);
    c.updateItemPlacement(
      EditorPlacement(
        center: const ui.Offset(100, 64),
        scale: 2,
        rotation: pi / 4,
      ),
    );
    c.endItemGesture();
    final px = await decodePixels((await _export(c)).png);
    expect(px.at(100, 64)[1], 255);
    // Le carré (64 → 128 px de côté) tourné de 45° : son coin touche (100, 64-90),
    // mais un point à 70 px de distance en diagonale du centre est vide.
    expect(px.alphaAt(100 + 62, 64 + 62), 0);
    // …et un point à 50 px sur l'axe est plein (côté 128 ⇒ rayon 64 sur l'axe).
    expect(px.alphaAt(100 + 40, 64), 255);
  });

  test('emoji : élément dessiné, centré et dans le cadre', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    c.addEmoji('😀');
    final px = await decodePixels((await _export(c)).png);
    // Police d'essai : un carré plein de 128 px au centre (+ décalage éventuel).
    expect(px.alphaAt(256, 256), greaterThan(0));
    expect(px.alphaAt(5, 5), 0);
  });

  test(
    'détourage : masque + gomme + pinceau, dans le repère de l\'image',
    () async {
      // Image carrée 100×100 : « contain » = tout le cadre, échelle 5,12.
      final c = await _sticker(w: 100, h: 100);
      addTearDown(c.dispose);
      // Gomme : disque de 40 px image autour de (50, 50) → centre transparent.
      c.addMaskStroke(const [ui.Offset(50, 50)], 40, restore: false);
      var px = await decodePixels((await _export(c)).png);
      expect(px.alphaAt(256, 256), 0);
      expect(px.alphaAt(20, 20), 255);
      // Pinceau : restaure un petit disque au centre.
      c.addMaskStroke(const [ui.Offset(50, 50)], 10, restore: true);
      px = await decodePixels((await _export(c)).png);
      expect(px.alphaAt(256, 256), 255);
      expect(px.alphaAt(256 + 100, 256), 0, reason: 'anneau toujours effacé');
      // Annuler le pinceau, puis la gomme : image entière.
      c.undo();
      c.undo();
      px = await decodePixels((await _export(c)).png);
      expect(px.alphaAt(256, 256), 255);
    },
  );

  test('détourage : masque calculé (moitié gauche) appliqué', () async {
    final c = await _sticker(w: 100, h: 100);
    addTearDown(c.dispose);
    // Masque 100×100 : moitié gauche opaque, droite transparente.
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
      const ui.Rect.fromLTWH(0, 0, 50, 100),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final pic = rec.endRecording();
    final mask = await pic.toImage(100, 100);
    pic.dispose();
    c.setCutoutMask(mask);
    final px = await decodePixels((await _export(c)).png);
    expect(px.alphaAt(100, 256), 255);
    expect(px.alphaAt(400, 256), 0);
  });

  test(
    'image volumineuse (bruit 1024²) : toujours ≤ 1 Mo, 512×512, alpha',
    () async {
      final rnd = Random(3);
      final raw = Uint8List(1024 * 1024 * 4);
      for (var i = 0; i < raw.length; i++) {
        raw[i] = (i % 4 == 3) ? 255 : rnd.nextInt(256);
      }
      final buf = await ui.ImmutableBuffer.fromUint8List(raw);
      final desc = ui.ImageDescriptor.raw(
        buf,
        width: 1024,
        height: 1024,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      desc.dispose();
      buf.dispose();
      final c = EditorController(mode: MediaEditorMode.sticker, image: image);
      addTearDown(c.dispose);
      final r = await _export(c);
      final info = StickerImageCheck.validate(r.png);
      expect(info.width, 512);
      expect(info.bytes, lessThanOrEqualTo(StickerImageCheck.maxBytes));
    },
  );

  test(
    'PNG trop lourd : le contenu est réduit, le canevas reste 512×512',
    () async {
      final rnd = Random(5);
      final raw = Uint8List(512 * 512 * 4);
      for (var i = 0; i < raw.length; i++) {
        raw[i] = (i % 4 == 3) ? 255 : rnd.nextInt(256);
      }
      final buf = await ui.ImmutableBuffer.fromUint8List(raw);
      final desc = ui.ImageDescriptor.raw(
        buf,
        width: 512,
        height: 512,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      desc.dispose();
      buf.dispose();
      final c = EditorController(mode: MediaEditorMode.sticker, image: image);
      addTearDown(c.dispose);
      final plein = await _export(c);
      final limite = plein.png.length - 1000;
      final reduit = await _export(c, max: limite);
      expect(reduit.png.length, lessThanOrEqualTo(limite));
      expect(reduit.width, 512);
      expect(reduit.height, 512);
      final px = await decodePixels(reduit.png);
      expect(
        px.alphaAt(2, 2),
        0,
        reason: 'le contenu réduit laisse un bord transparent',
      );

      await expectLater(
        _export(c, max: 1000),
        throwsA(
          isA<StickerImageRejected>().having(
            (e) => e.issue,
            'issue',
            StickerImageIssue.tooBig,
          ),
        ),
      );
    },
  );

  test('photo : PNG au format du cadre, jamais plus de 1024 px', () async {
    final c = EditorController(
      mode: MediaEditorMode.photo,
      image: await solidImage(300, 200),
    );
    addTearDown(c.dispose);
    final r = await _export(c);
    expect(r.width, 300);
    expect(r.height, 200);
    final px = await decodePixels(r.png);
    expect(px.width, 300);
    expect(px.alphaAt(150, 100), 255);
    c.setAspect(EditorAspect.square);
    final carre = await _export(c);
    expect(carre.width, 300);
    expect(carre.height, 300);
  });

  test(
    'chargement : image décodée à 1024 px au plus, formats refusés',
    () async {
      final big = await solidPng(3000, 1500);
      final img = await EditorImageLoader.decode(big);
      expect(img.width, 1024);
      expect(img.height, 512);
      img.dispose();

      expect(
        EditorImageLoader.decode(Uint8List(0)),
        throwsA(isA<MediaEditorLoadException>()),
      );
      expect(
        EditorImageLoader.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<MediaEditorLoadException>().having(
            (e) => e.issue,
            'issue',
            MediaEditorLoadIssue.unreadable,
          ),
        ),
      );
      expect(
        EditorImageLoader.decode(
          Uint8List(EditorImageLoader.maxInputBytes + 1),
        ),
        throwsA(
          isA<MediaEditorLoadException>().having(
            (e) => e.issue,
            'issue',
            MediaEditorLoadIssue.tooBig,
          ),
        ),
      );
    },
  );

  test('historique : exporter après annulations rend l\'état annulé', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    c.setPenColor(_blue);
    c.setPenWidth(20);
    c.beginStroke(const ui.Offset(60, 64));
    c.extendStroke(const ui.Offset(450, 64));
    c.endStroke();
    var px = await decodePixels((await _export(c)).png);
    expect(px.alphaAt(256, 64), 255);
    c.undo();
    px = await decodePixels((await _export(c)).png);
    expect(px.alphaAt(256, 64), 0);
    c.redo();
    px = await decodePixels((await _export(c)).png);
    expect(px.alphaAt(256, 64), 255);
    // Une commande directe passe aussi par l'historique.
    c.execute(AddStrokeCommand(c.doc.strokes.first));
    expect(c.canUndo, isTrue);
  });
}
