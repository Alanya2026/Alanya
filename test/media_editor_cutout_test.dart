// Éditeur d'image (T4c) : détourage. Segmenteur injecté (masque synthétique,
// jamais ML Kit), pinceau / gomme, annuler / rétablir, réinitialiser, erreurs,
// export transparent aux bons pixels, mémoire.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/features/media_editor/cutout/person_segmenter.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/render/editor_exporter.dart';

import 'support/media_editor_fakes.dart';

/// Image carrée 100×100 : « contain » dans 512×512 = tout le cadre, ×5,12
/// (le pixel d'image (50, 50) tombe en (256, 256) à l'export).
Future<EditorController> _sticker({int w = 100, int h = 100}) async =>
    EditorController(
      mode: MediaEditorMode.sticker,
      image: await solidImage(w, h),
    );

Future<Pixels> _export(EditorController c) async =>
    decodePixels((await MediaEditorExporter.export(c.doc, c.image, c.mode)).png);

/// Trace un trait de masque complet entre deux points du document.
void _stroke(
  EditorController c,
  ui.Offset a, [
  ui.Offset? b,
]) {
  c.beginMaskStroke(a);
  if (b != null) c.extendMaskStroke(b);
  c.endMaskStroke();
}

void main() {
  group('PersonMask.fromConfidences', () {
    test('seuil et adoucissement : personne = opaque, fond = transparent', () {
      // 20×20, bloc 8×8 de confiance 1 au centre, le reste à 0.
      final c = List<double>.filled(400, 0);
      for (var y = 6; y < 14; y++) {
        for (var x = 6; x < 14; x++) {
          c[y * 20 + x] = 1;
        }
      }
      final m = PersonMask.fromConfidences(c, width: 20, height: 20);
      expect(m.width, 20);
      expect(m.alpha.length, 400, reason: 'un octet par pixel');
      expect(m.alpha[10 * 20 + 10], 255, reason: 'cœur de la personne');
      expect(m.alpha[0], 0, reason: 'fond');
      final bord = m.alpha[10 * 20 + 6]; // première colonne du bloc
      expect(bord, inExclusiveRange(0, 255), reason: 'bord adouci');
      expect(m.coverage, closeTo(64 / 400, 0.05));
    });

    test('confiances faibles : rampe lissée entre les deux seuils', () {
      final c = List<double>.filled(100, 0.55); // milieu de la rampe
      final m = PersonMask.fromConfidences(c, width: 10, height: 10);
      expect(m.alpha[55], inExclusiveRange(100, 160));
      final bas = PersonMask.fromConfidences(
        List<double>.filled(100, 0.3)..[0] = 1,
        width: 10,
        height: 10,
        minCoverage: 0,
      );
      expect(bas.alpha[99], 0, reason: 'sous le seuil bas');
    });

    test('aucune personne → noPerson', () {
      expect(
        () => PersonMask.fromConfidences(
          List<double>.filled(256, 0.1),
          width: 16,
          height: 16,
        ),
        throwsA(
          isA<PersonSegmentationException>().having(
            (e) => e.issue,
            'issue',
            PersonSegmentationIssue.noPerson,
          ),
        ),
      );
    });

    test('quelques pixels isolés ne font pas une personne', () {
      final c = List<double>.filled(10000, 0)..[5050] = 1;
      expect(
        () => PersonMask.fromConfidences(c, width: 100, height: 100),
        throwsA(isA<PersonSegmentationException>()),
      );
    });

    test('dimensions incohérentes → failed ; NaN toléré', () {
      expect(
        () => PersonMask.fromConfidences([1, 1, 1], width: 2, height: 2),
        throwsA(
          isA<PersonSegmentationException>().having(
            (e) => e.issue,
            'issue',
            PersonSegmentationIssue.failed,
          ),
        ),
      );
      final c = List<double>.filled(100, 1)..[3] = double.nan;
      expect(
        PersonMask.fromConfidences(c, width: 10, height: 10).alpha[3],
        lessThan(255),
      );
    });

    test('toImage : une image de la taille du masque, alpha = masque', () async {
      final m = leftHalfMask(10, 4);
      final img = await m.toImage();
      expect(img.width, 10);
      expect(img.height, 4);
      final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(d.getUint8(3), 255); // pixel (0,0) : alpha
      expect(d.getUint8(9 * 4 + 3), 0); // pixel (9,0)
      img.dispose();
    });
  });

  group('détourage automatique (segmenteur injecté)', () {
    test('masque synthétique → export transparent aux bons pixels', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final seg = FakePersonSegmenter(mask: leftHalfMask(10, 10));
      expect(await c.autoCutout(seg), AutoCutoutOutcome.done);
      expect(seg.calls, 1);
      expect(seg.lastImage, same(c.image), reason: 'image de travail seule');
      expect(c.canUndo, isTrue);
      expect(c.cutoutBusy, isFalse);
      expect(c.doc.cutout!.baseMask!.width, 10, reason: 'masque à part');

      final px = await _export(c);
      expect(px.alphaAt(100, 256), 255, reason: 'moitié gauche : personne');
      expect(px.alphaAt(400, 256), 0, reason: 'moitié droite : fond');
      expect(px.alphaAt(100, 20), 255);
      expect(px.alphaAt(400, 500), 0);
      expect(px.at(100, 256)[0], greaterThan(180), reason: 'couleur conservée');
    });

    test('annuler / rétablir : un seul pas, sans copie de bitmap', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(8, 8)));
      expect(c.history.undoDepth, 1);
      c.undo();
      expect(c.doc.cutout, isNull);
      expect((await _export(c)).alphaAt(400, 256), 255);
      c.redo();
      expect((await _export(c)).alphaAt(400, 256), 0);
      expect((await _export(c)).alphaAt(100, 256), 255);
    });

    test('aucune personne : message clair, document intact', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final seg = FakePersonSegmenter(
        error: const PersonSegmentationException(
          PersonSegmentationIssue.noPerson,
        ),
      );
      expect(await c.autoCutout(seg), AutoCutoutOutcome.noPerson);
      expect(c.doc.cutout, isNull);
      expect(c.canUndo, isFalse);
      expect(c.cutoutBusy, isFalse);
    });

    test('échec natif (n\'importe quelle erreur) → failed, rien ne change', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      for (final seg in [
        FakePersonSegmenter(
          error: const PersonSegmentationException(
            PersonSegmentationIssue.failed,
            'modèle indisponible',
          ),
        ),
        _ThrowingSegmenter(),
      ]) {
        expect(await c.autoCutout(seg), AutoCutoutOutcome.failed);
        expect(c.canUndo, isFalse);
        expect(c.cutoutBusy, isFalse);
      }
    });

    test('deux demandes à la fois : la seconde est refusée', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      final gate = Completer<void>();
      final seg = FakePersonSegmenter(
        mask: leftHalfMask(8, 8),
        gate: gate.future,
      );
      final first = c.autoCutout(seg);
      expect(c.cutoutBusy, isTrue);
      expect(await c.autoCutout(seg), AutoCutoutOutcome.busy);
      gate.complete();
      expect(await first, AutoCutoutOutcome.done);
      expect(seg.calls, 1);
    });

    test('éditeur fermé pendant le calcul : annulé, aucune fuite', () async {
      final c = await _sticker();
      final gate = Completer<void>();
      final seg = FakePersonSegmenter(
        mask: leftHalfMask(8, 8),
        gate: gate.future,
      );
      final pending = c.autoCutout(seg);
      c.dispose();
      gate.complete();
      expect(await pending, AutoCutoutOutcome.cancelled);
    });

    test('relancer le détourage remplace masque ET traits, annulable', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(10, 10)));
      final first = c.doc.cutout!.baseMask!;
      _stroke(c, const ui.Offset(256, 256)); // gomme au centre
      expect(c.doc.cutout!.strokes, hasLength(1));

      await c.autoCutout(
        FakePersonSegmenter(mask: leftHalfMask(10, 10, splitX: 8)),
      );
      expect(c.doc.cutout!.strokes, isEmpty);
      expect((await _export(c)).alphaAt(350, 256), 255);

      c.undo(); // retour au premier masque avec son trait
      expect(c.doc.cutout!.baseMask, same(first));
      expect(c.doc.cutout!.strokes, hasLength(1));
      expect(first.debugDisposed, isFalse);
    });
  });

  group('pinceau et gomme', () {
    test('gomme : efface le fond ; un trait = une action', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutBrushSize(60); // 60 unités du document
      _stroke(c, const ui.Offset(256, 256));
      expect(c.history.undoDepth, 1);
      final px = await _export(c);
      expect(px.alphaAt(256, 256), 0, reason: 'effacé');
      expect(px.alphaAt(256 + 60, 256), 255, reason: 'hors du pinceau');
      expect(px.alphaAt(20, 20), 255);
    });

    test('trait continu : plusieurs points, une seule commande', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutBrushSize(40);
      c.beginMaskStroke(const ui.Offset(100, 256));
      for (var x = 110; x <= 400; x += 10) {
        c.extendMaskStroke(ui.Offset(x.toDouble(), 256));
      }
      expect(c.maskCursor, isNotNull);
      // En cours de tracé : aperçu provisoire, rien d'annulable encore.
      expect(c.doc.cutout!.strokes, hasLength(1));
      expect(c.canUndo, isFalse);
      c.endMaskStroke();
      expect(c.maskCursor, isNull);
      expect(c.history.undoDepth, 1);
      final px = await _export(c);
      expect(px.alphaAt(250, 256), 0);
      expect(px.alphaAt(390, 256), 0);
      expect(px.alphaAt(250, 300), 255);
    });

    test('pinceau « garder » : fait revenir ce que la gomme a caché', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutBrushSize(100);
      _stroke(c, const ui.Offset(256, 256)); // gomme large
      c.setCutoutBrush(CutoutBrush.keep);
      c.setCutoutBrushSize(30);
      _stroke(c, const ui.Offset(256, 256)); // on garde un petit disque
      final px = await _export(c);
      expect(px.alphaAt(256, 256), 255, reason: 'gardé');
      expect(px.alphaAt(256 + 40, 256), 0, reason: 'anneau toujours effacé');
    });

    test('pinceau sur un détourage automatique : récupère un bout de fond',
        () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(10, 10)));
      c.setCutoutBrush(CutoutBrush.keep);
      c.setCutoutBrushSize(40);
      _stroke(c, const ui.Offset(400, 100));
      final px = await _export(c);
      expect(px.alphaAt(400, 100), 255, reason: 'repeint à la main');
      expect(px.alphaAt(400, 400), 0, reason: 'fond ailleurs');
      expect(px.alphaAt(100, 400), 255);
    });

    test('annuler / rétablir chaque trait, dans l\'ordre', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutBrushSize(60);
      _stroke(c, const ui.Offset(150, 256));
      _stroke(c, const ui.Offset(350, 256));
      expect(c.history.undoDepth, 2);
      var px = await _export(c);
      expect(px.alphaAt(150, 256), 0);
      expect(px.alphaAt(350, 256), 0);

      c.undo();
      px = await _export(c);
      expect(px.alphaAt(350, 256), 255);
      expect(px.alphaAt(150, 256), 0);
      c.undo();
      expect(c.doc.cutout, isNull);
      px = await _export(c);
      expect(px.alphaAt(150, 256), 255);

      c.redo();
      c.redo();
      px = await _export(c);
      expect(px.alphaAt(150, 256), 0);
      expect(px.alphaAt(350, 256), 0);
    });

    test('la taille suit le zoom : même taille à l\'écran', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutBrushSize(50);
      _stroke(c, const ui.Offset(256, 256));
      final w1 = c.doc.cutout!.strokes.single.width;
      expect(w1, closeTo(50 / 5.12, 1e-6), reason: 'pixels de l\'image');
      c.fitImage(cover: true); // même cadre carré : pas de changement
      c.setCutoutBrushSize(200); // borné
      expect(c.cutoutBrushSize, EditorController.maxCutoutBrush);
      c.setCutoutBrushSize(1);
      expect(c.cutoutBrushSize, EditorController.minCutoutBrush);
    });

    test('bords doux : le trait mord progressivement', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.setCutoutSoftEdges(true);
      c.setCutoutBrushSize(120);
      _stroke(c, const ui.Offset(256, 256));
      expect(c.doc.cutout!.strokes.single.soft, isTrue);
      final px = await _export(c);
      expect(px.alphaAt(256, 256), lessThan(30), reason: 'cœur effacé');
      expect(px.alphaAt(256 + 200, 256), 255, reason: 'loin : intact');
      // Quelque part entre le centre et le bord du pinceau : transparence
      // partielle (transition), alors qu'un trait net n'en a pas.
      var partiel = false;
      for (var x = 256; x < 256 + 100; x++) {
        final a = px.alphaAt(x, 256);
        if (a > 20 && a < 235) partiel = true;
      }
      expect(partiel, isTrue);
    });

    test('changer d\'outil abandonne un trait en cours', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.selectTool(EditorTool.cutout);
      c.beginMaskStroke(const ui.Offset(256, 256));
      c.selectTool(EditorTool.crop);
      expect(c.doc.cutout, isNull);
      expect(c.maskCursor, isNull);
      c.endMaskStroke();
      expect(c.canUndo, isFalse);
    });
  });

  group('réinitialiser le masque', () {
    test('tout redevient visible, une seule action, annulable', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(10, 10)));
      _stroke(c, const ui.Offset(100, 100));
      expect(c.hasCutout, isTrue);
      final depth = c.history.undoDepth;

      c.resetCutout();
      expect(c.history.undoDepth, depth + 1);
      expect(c.doc.cutout, isNull);
      expect(c.hasCutout, isFalse);
      var px = await _export(c);
      expect(px.alphaAt(400, 256), 255);
      expect(px.alphaAt(100, 100), 255);

      c.undo(); // le masque et le trait reviennent
      expect(c.doc.cutout!.strokes, hasLength(1));
      px = await _export(c);
      expect(px.alphaAt(400, 256), 0);
      expect(px.alphaAt(100, 100), 0);
    });

    test('rien à réinitialiser : aucune action', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      c.resetCutout();
      expect(c.canUndo, isFalse);
    });

    test('mémoire : l\'image du masque survit à la réinitialisation', () async {
      final c = await _sticker();
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(10, 10)));
      final mask = c.doc.cutout!.baseMask!;
      c.resetCutout();
      expect(mask.debugDisposed, isFalse, reason: 'annulable');
      c.undo();
      expect((await _export(c)).alphaAt(400, 256), 0);
      c.dispose();
      expect(mask.debugDisposed, isTrue);
    });

    test('rétablissement écrasé : masque libéré tout de suite', () async {
      final c = await _sticker();
      addTearDown(c.dispose);
      await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(10, 10)));
      final mask = c.doc.cutout!.baseMask!;
      c.undo();
      expect(mask.debugDisposed, isFalse);
      c.addEmoji('😀');
      expect(mask.debugDisposed, isTrue);
    });
  });

  test('export : fond détouré transparent dans le PNG 512×512 valide', () async {
    final c = await _sticker();
    addTearDown(c.dispose);
    await c.autoCutout(FakePersonSegmenter(mask: leftHalfMask(16, 16)));
    final r = await MediaEditorExporter.export(c.doc, c.image, c.mode);
    expect(r.width, 512);
    expect(r.height, 512);
    final px = await decodePixels(r.png);
    expect(px.width, 512);
    expect(px.alphaAt(400, 256), 0);
    expect(px.alphaAt(100, 256), 255);
    expect(Uint8List.sublistView(r.png, 1, 4), [0x50, 0x4E, 0x47]);
  });
}

class _ThrowingSegmenter implements PersonSegmenter {
  @override
  bool get isSupported => true;
  @override
  Future<PersonMask> segment(ui.Image image) async =>
      throw StateError('plantage natif');
  @override
  Future<void> dispose() async {}
}
