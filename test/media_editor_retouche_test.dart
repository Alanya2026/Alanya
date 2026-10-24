// Éditeur d'image, refonte de la retouche avant envoi : filtres et réglages,
// orientation (quart de tour, miroir, rotation fine), pinceaux, texte sur fond,
// reprise d'une retouche. Rendu vérifié sur les pixels exportés.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';
import 'package:talky_flutter/features/media_editor/render/editor_exporter.dart';
import 'package:talky_flutter/features/media_editor/render/editor_look.dart';
import 'package:talky_flutter/features/media_editor/render/editor_renderer.dart';

import 'support/media_editor_fakes.dart';

Future<EditorController> _photo({
  int w = 400,
  int h = 200,
  Color color = const Color(0xFFD03030),
  EditorDoc? initialDoc,
}) async => EditorController(
  mode: MediaEditorMode.photo,
  image: await solidImage(w, h, color: color),
  initialDoc: initialDoc,
);

void main() {
  group('matrices de couleur', () {
    test('rendu neutre : aucune matrice', () {
      expect(EditorLookMatrix.of(EditorLook.neutral), isNull);
      expect(
        EditorLookMatrix.of(
          const EditorLook(filter: EditorFilter.mono, intensity: 0),
        ),
        isNull,
      );
    });

    test('composition avec l\'identité : inchangée', () {
      final m = EditorLookMatrix.contrastMatrix(1.3);
      expect(EditorLookMatrix.multiply(EditorLookMatrix.identity, m), m);
      expect(EditorLookMatrix.multiply(m, EditorLookMatrix.identity), m);
    });

    test('noir et blanc : les trois canaux reçoivent les mêmes poids', () {
      final m = EditorLookMatrix.preset(EditorFilter.mono);
      for (var k = 0; k < 3; k++) {
        expect(m[k], closeTo(m[5 + k], 1e-9));
        expect(m[k], closeTo(m[10 + k], 1e-9));
      }
    });

    test('intensité 50 % : à mi-chemin de l\'identité', () {
      final full = EditorLookMatrix.preset(EditorFilter.vivid);
      final half = EditorLookMatrix.of(
        const EditorLook(filter: EditorFilter.vivid, intensity: 0.5),
      )!;
      for (var i = 0; i < 20; i++) {
        expect(
          half[i],
          closeTo((EditorLookMatrix.identity[i] + full[i]) / 2, 1e-9),
        );
      }
    });

    test('export : le filtre noir et blanc rend des pixels gris', () async {
      final c = await _photo(w: 40, h: 20);
      addTearDown(c.dispose);
      c.setFilter(EditorFilter.mono);
      final r = await MediaEditorExporter.export(
        c.doc,
        c.image,
        MediaEditorMode.photo,
      );
      final px = (await decodePixels(r.png)).at(20, 10);
      expect((px[0] - px[1]).abs(), lessThanOrEqualTo(2));
      expect((px[1] - px[2]).abs(), lessThanOrEqualTo(2));
    });

    test('filtre puis curseur : deux annulations', () async {
      final c = await _photo();
      addTearDown(c.dispose);
      c.setFilter(EditorFilter.warm);
      c.beginLook();
      c.updateLook(c.doc.look.copyWith(intensity: 0.4));
      c.updateLook(c.doc.look.copyWith(intensity: 0.3));
      c.endLook();
      expect(c.doc.look.intensity, closeTo(0.3, 1e-9));
      c.undo();
      expect(c.doc.look, const EditorLook(filter: EditorFilter.warm));
      c.undo();
      expect(c.doc.look.isNeutral, isTrue);
    });
  });

  group('orientation', () {
    test('pixel du document → pixel de l\'image : inverse de la peinture', () {
      const t = EditorImageTransform(
        center: Offset(120, 80),
        scale: 0.5,
        rotation: 0.3,
        quarterTurns: 1,
        flipX: true,
      );
      // Le centre de l'image tombe au centre de la transformation.
      final c = t.docToImage(const Offset(120, 80), 400, 200);
      expect(c.dx, closeTo(200, 1e-9));
      expect(c.dy, closeTo(100, 1e-9));
    });

    test('couverture tournée : les coins du cadre restent dans l\'image', () {
      const canvas = Size(400, 200);
      const a = 0.35;
      final t = EditorImageTransform.cover(canvas, 400, 200, rotation: a);
      for (final corner in const [
        Offset(0, 0),
        Offset(400, 0),
        Offset(400, 200),
        Offset(0, 200),
      ]) {
        final p = t.docToImage(corner, 400, 200);
        expect(p.dx, inInclusiveRange(-1e-6, 400 + 1e-6));
        expect(p.dy, inInclusiveRange(-1e-6, 200 + 1e-6));
      }
    });

    test('quart de tour : le cadre libre tourne avec l\'image', () async {
      final c = await _photo();
      addTearDown(c.dispose);
      c.rotateQuarter();
      expect(c.doc.canvas, const Size(200, 400));
      expect(c.doc.imageTransform.quarterTurns, 1);
      c.undo();
      expect(c.doc.canvas, const Size(400, 200));
      expect(c.doc.imageTransform.quarterTurns, 0);
    });

    test('miroir : bascule et s\'annule', () async {
      final c = await _photo();
      addTearDown(c.dispose);
      c.flipImage();
      expect(c.doc.imageTransform.flipX, isTrue);
      c.undo();
      expect(c.doc.imageTransform.flipX, isFalse);
    });

    test('rotation fine : bornée, garde le cadre rempli, une annulation',
        () async {
      final c = await _photo();
      addTearDown(c.dispose);
      c.beginRotation();
      c.updateRotation(0.1);
      c.updateRotation(2);
      c.endRotation();
      final t = c.doc.imageTransform;
      expect(t.rotation, EditorImageTransform.maxFineRotation);
      expect(
        t.scale,
        closeTo(
          EditorImageTransform.coverScale(
            c.doc.canvas,
            400,
            200,
            math.pi / 4,
            0,
          ),
          1e-9,
        ),
      );
      expect(c.history.undoDepth, 1);
      c.resetCrop();
      expect(c.doc.imageTransform.rotation, 0);
    });

    test('miroir exporté : la moitié rouge passe à droite', () async {
      final c = EditorController(
        mode: MediaEditorMode.photo,
        image: await _halfImage(),
      );
      addTearDown(c.dispose);
      c.flipImage();
      final r = await MediaEditorExporter.export(
        c.doc,
        c.image,
        MediaEditorMode.photo,
      );
      final px = await decodePixels(r.png);
      expect(px.at(5, 10)[2], greaterThan(200)); // bleu à gauche
      expect(px.at(35, 10)[0], greaterThan(200)); // rouge à droite
    });
  });

  group('pinceaux', () {
    test('le trait garde son pinceau ; la gomme reste un stylo', () async {
      final c = await _photo();
      addTearDown(c.dispose);
      c.setBrush(EditorBrush.neon);
      c.beginStroke(const Offset(10, 10));
      c.extendStroke(const Offset(50, 50));
      c.endStroke();
      expect(c.doc.strokes.single.brush, EditorBrush.neon);
      c.setErasing(true);
      c.beginStroke(const Offset(10, 10));
      c.endStroke();
      expect(c.doc.strokes.last.erase, isTrue);
      expect(c.doc.strokes.last.brush, EditorBrush.pen);
    });

    test('flou : mélange les couleurs sous le trait seulement', () async {
      final c = EditorController(
        mode: MediaEditorMode.photo,
        image: await _halfImage(),
      );
      addTearDown(c.dispose);
      c.setBrush(EditorBrush.blur);
      c.penWidth = 8;
      c.beginStroke(const Offset(20, 2));
      c.extendStroke(const Offset(20, 18));
      c.endStroke();
      expect(c.doc.strokes.single.isBlur, isTrue);
      final r = await MediaEditorExporter.export(
        c.doc,
        c.image,
        MediaEditorMode.photo,
      );
      final px = await decodePixels(r.png);
      // À la frontière, sous le trait : ni rouge pur ni bleu pur.
      final mid = px.at(20, 10);
      expect(mid[0], inExclusiveRange(20, 235));
      expect(mid[2], inExclusiveRange(20, 235));
      // Loin du trait : intact.
      expect(px.at(2, 10)[0], greaterThan(240));
    });
  });

  group('texte', () {
    test('fond : la taille inclut la marge, le texte devient lisible',
        () async {
      const canvas = Size(512, 512);
      const plain = EditorTextItem(
        id: 1,
        placement: EditorPlacement(center: Offset(256, 256)),
        text: 'Bonjour',
        color: Color(0xFFFFFFFF),
      );
      final solid = plain.copyWith(background: EditorTextBackground.solid);
      final a = EditorItemMetrics.sizeOf(plain, canvas);
      final b = EditorItemMetrics.sizeOf(solid, canvas);
      expect(b.width, greaterThan(a.width));
      expect(b.height, greaterThan(a.height));
      expect(EditorItemMetrics.textColorOf(solid), const Color(0xFF000000));
      expect(EditorItemMetrics.textColorOf(plain), const Color(0xFFFFFFFF));
    });

    test('alignement et fond se modifient en une annulation', () async {
      final c = await _photo();
      addTearDown(c.dispose);
      final id = c.addText('Salut', EditorFont.bold, const Color(0xFF3F51B5));
      c.editText(
        id,
        align: EditorTextAlign.left,
        background: EditorTextBackground.translucent,
      );
      final t = c.doc.itemById(id)! as EditorTextItem;
      expect(t.align, EditorTextAlign.left);
      expect(t.background, EditorTextBackground.translucent);
      c.undo();
      final u = c.doc.itemById(id)! as EditorTextItem;
      expect(u.background, EditorTextBackground.none);
    });
  });

  group('reprise d\'une retouche', () {
    test('le document repris garde ses calques et numérote après', () async {
      final first = await _photo();
      final id = first.addText('A', EditorFont.standard, const Color(0xFF000000));
      first.setFilter(EditorFilter.soft);
      final saved = first.doc;
      first.dispose();

      final again = await _photo(initialDoc: saved);
      addTearDown(again.dispose);
      expect(again.doc.itemById(id), isNotNull);
      expect(again.doc.look.filter, EditorFilter.soft);
      expect(again.hasChanges, isFalse);
      final next = again.addText('B', EditorFont.standard, const Color(0xFF000000));
      expect(next, greaterThan(id));
    });

    test('dimensions différentes : document ignoré', () async {
      final first = await _photo();
      first.setFilter(EditorFilter.mono);
      final saved = first.doc;
      first.dispose();
      final other = await _photo(w: 300, h: 300, initialDoc: saved);
      addTearDown(other.dispose);
      expect(other.doc.look.isNeutral, isTrue);
    });
  });
}

/// 40×20 : moitié gauche rouge, moitié droite bleue.
Future<Image> _halfImage() async {
  final rec = PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 20, 20),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 0, 20, 20),
    Paint()..color = const Color(0xFF0000FF),
  );
  final pic = rec.endRecording();
  final img = await pic.toImage(40, 20);
  pic.dispose();
  return img;
}
