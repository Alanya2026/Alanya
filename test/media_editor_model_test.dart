// Éditeur d'image (T4b) : géométrie des éléments, document immuable, commandes
// et pile annuler/rétablir. Aucun moteur de rendu : tout est pur.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/features/media_editor/model/editor_commands.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';

const _canvas = Size(512, 512);
const _red = Color(0xFFFF0000);

EditorDoc _doc() =>
    EditorDoc.initial(canvas: _canvas, imageWidth: 400, imageHeight: 200);

EditorStroke _stroke(int id, {bool erase = false}) => EditorStroke(
  id: id,
  points: [Offset(id.toDouble(), 0), Offset(id.toDouble(), 10)],
  color: _red,
  width: 8,
  erase: erase,
);

EditorTextItem _text(int id, {Offset at = const Offset(100, 100)}) =>
    EditorTextItem(
      id: id,
      placement: EditorPlacement(center: at),
      text: 'Salut',
      color: _red,
    );

void main() {
  group('EditorPlacement : repères, hit-test, pincement', () {
    test('toLocal / toDoc sont inverses (rotation + échelle)', () {
      final p = EditorPlacement(
        center: const Offset(200, 150),
        scale: 2,
        rotation: math.pi / 3,
      );
      for (final pt in const [Offset(10, 20), Offset(-40, 7), Offset.zero]) {
        final back = p.toLocal(p.toDoc(pt));
        expect(back.dx, closeTo(pt.dx, 1e-9));
        expect(back.dy, closeTo(pt.dy, 1e-9));
      }
    });

    test('contains : rectangle de l\'élément, à l\'échelle', () {
      const size = Size(100, 40);
      final p = EditorPlacement(center: const Offset(200, 200), scale: 2);
      // Étendue réelle : 200 × 80 autour du centre.
      expect(p.contains(const Offset(299, 239), size), isTrue);
      expect(p.contains(const Offset(301, 200), size), isFalse);
      expect(p.contains(const Offset(200, 241), size), isFalse);
    });

    test('contains : l\'élément tourné suit sa rotation', () {
      const size = Size(100, 20);
      final p = EditorPlacement(
        center: const Offset(200, 200),
        rotation: math.pi / 2, // le grand côté devient vertical
      );
      expect(p.contains(const Offset(200, 245), size), isTrue);
      expect(p.contains(const Offset(245, 200), size), isFalse);
    });

    test('contains : cible tactile minimale pour un petit élément', () {
      const size = Size(10, 10);
      final p = EditorPlacement(center: const Offset(100, 100));
      expect(p.contains(const Offset(115, 100), size), isFalse);
      expect(p.contains(const Offset(115, 100), size, minTouch: 48), isTrue);
      expect(p.contains(const Offset(130, 100), size, minTouch: 48), isFalse);
    });

    test('corners : coins du rectangle tourné', () {
      final p = EditorPlacement(
        center: const Offset(0, 0),
        rotation: math.pi / 2,
      );
      final c = p.corners(const Size(20, 10));
      // Haut-gauche local (-10,-5) → (5,-10) après un quart de tour.
      expect(c[0].dx, closeTo(5, 1e-9));
      expect(c[0].dy, closeTo(-10, 1e-9));
    });

    test(
      'transformedBy : déplace, zoome (bornes), tourne (angle normalisé)',
      () {
        final p = EditorPlacement(center: const Offset(10, 10));
        final q = p.transformedBy(
          translate: const Offset(5, -5),
          scaleFactor: 3,
          rotationDelta: 0.5,
        );
        expect(q.center, const Offset(15, 5));
        expect(q.scale, 3);
        expect(q.rotation, 0.5);

        expect(
          p.transformedBy(scaleFactor: 1000).scale,
          EditorPlacement.maxScale,
        );
        expect(
          p.transformedBy(scaleFactor: 0.0001).scale,
          EditorPlacement.minScale,
        );

        final tourne = p.transformedBy(rotationDelta: 3 * math.pi);
        expect(tourne.rotation, closeTo(math.pi, 1e-9));
        expect(
          EditorPlacement.normalizeAngle(-3 * math.pi / 2),
          closeTo(math.pi / 2, 1e-9),
        );
      },
    );
  });

  group('EditorImageTransform : rognage', () {
    test('contain / cover sur une image 2:1 dans un carré', () {
      final contain = EditorImageTransform.contain(_canvas, 400, 200);
      expect(contain.scale, closeTo(512 / 400, 1e-9));
      expect(contain.center, const Offset(256, 256));
      final r = contain.rect(400, 200);
      expect(r.width, closeTo(512, 1e-9));
      expect(r.height, closeTo(256, 1e-9));

      final cover = EditorImageTransform.cover(_canvas, 400, 200);
      expect(cover.scale, closeTo(512 / 200, 1e-9));
      final c = cover.rect(400, 200);
      expect(c.height, closeTo(512, 1e-9));
      expect(c.contains(const Offset(0, 0)), isTrue);
    });

    test('clamped : zoom borné, centre gardé dans le cadre', () {
      const t = EditorImageTransform(center: Offset(5000, -300), scale: 1000);
      final c = t.clamped(_canvas, 400, 200);
      expect(c.center, const Offset(512, 0));
      expect(
        c.scale,
        closeTo(EditorImageTransform.cover(_canvas, 400, 200).scale * 8, 1e-9),
      );
      const tiny = EditorImageTransform(
        center: Offset(256, 256),
        scale: 0.0001,
      );
      expect(
        tiny.clamped(_canvas, 400, 200).scale,
        closeTo(
          EditorImageTransform.contain(_canvas, 400, 200).scale / 4,
          1e-9,
        ),
      );
    });
  });

  group('EditorDoc : document immuable', () {
    test('départ : image entière dans le cadre, aucun calque', () {
      final d = _doc();
      expect(d.imageTransform, EditorImageTransform.contain(_canvas, 400, 200));
      expect(d.cutout, isNull);
      expect(d.strokes, isEmpty);
      expect(d.items, isEmpty);
    });

    test(
      'les listes sont non modifiables ; copyWith ne touche pas l\'original',
      () {
        final d = _doc();
        final d2 = d.copyWith(strokes: [_stroke(1)], items: [_text(2)]);
        expect(d.strokes, isEmpty);
        expect(d2.strokes, hasLength(1));
        expect(() => d2.strokes.add(_stroke(3)), throwsUnsupportedError);
        expect(() => d2.items.removeLast(), throwsUnsupportedError);
        expect(
          () => d2.strokes.first.points.add(Offset.zero),
          throwsUnsupportedError,
        );
        expect(d2.itemById(2), isA<EditorTextItem>());
        expect(d2.itemById(99), isNull);
      },
    );
  });

  group('commandes : appliquer / annuler', () {
    test('trait ajouté puis annulé', () {
      final d = _doc();
      final c = AddStrokeCommand(_stroke(1));
      final a = c.apply(d);
      expect(a.strokes.map((s) => s.id), [1]);
      expect(c.undo(a).strokes, isEmpty);
    });

    test(
      'élément ajouté / retiré : l\'annulation rend le rang d\'empilement',
      () {
        var d = _doc();
        d = AddItemCommand(_text(1)).apply(d);
        d = AddItemCommand(
          EditorEmojiItem(
            id: 2,
            placement: EditorPlacement(center: const Offset(50, 50)),
            emoji: '😀',
          ),
        ).apply(d);
        d = AddItemCommand(_text(3)).apply(d);
        expect(d.items.map((i) => i.id), [1, 2, 3]);

        final rm = RemoveItemCommand(d.items[1], 1);
        final sans = rm.apply(d);
        expect(sans.items.map((i) => i.id), [1, 3]);
        expect(rm.undo(sans).items.map((i) => i.id), [1, 2, 3]);
      },
    );

    test('ReplaceItem : déplacement et texte, annulables', () {
      final avant = _text(1);
      final apres = avant.copyWith(
        text: 'Autre',
        placement: avant.placement.copyWith(center: const Offset(300, 40)),
      );
      final c = ReplaceItemCommand(avant, apres);
      final d = c.apply(AddItemCommand(avant).apply(_doc()));
      expect((d.items.single as EditorTextItem).text, 'Autre');
      expect(d.items.single.placement.center, const Offset(300, 40));
      final back = c.undo(d);
      expect((back.items.single as EditorTextItem).text, 'Salut');
      expect(back.items.single.placement.center, const Offset(100, 100));
    });

    test('SetImageTransform et SetCanvas', () {
      final d = _doc();
      final cover = EditorImageTransform.cover(_canvas, 400, 200);
      final t = SetImageTransformCommand(d.imageTransform, cover);
      expect(t.apply(d).imageTransform, cover);
      expect(t.undo(t.apply(d)).imageTransform, d.imageTransform);

      const wide = Size(512, 288);
      final cmd = SetCanvasCommand(
        beforeCanvas: _canvas,
        afterCanvas: wide,
        beforeTransform: d.imageTransform,
        afterTransform: EditorImageTransform.cover(wide, 400, 200),
      );
      final e = cmd.apply(d);
      expect(e.canvas, wide);
      final r = cmd.undo(e);
      expect(r.canvas, _canvas);
      expect(r.imageTransform, d.imageTransform);
    });

    test('masque de détourage : traits de gomme/pinceau, créé puis retiré', () {
      final d = _doc();
      final gomme = AddMaskStrokeCommand(
        EditorMaskStroke(id: 1, points: const [Offset(5, 5)], width: 10),
      );
      final pinceau = AddMaskStrokeCommand(
        EditorMaskStroke(
          id: 2,
          points: const [Offset(5, 5)],
          width: 10,
          restore: true,
        ),
      );
      final a = pinceau.apply(gomme.apply(d));
      expect(a.cutout!.strokes.map((s) => s.restore), [false, true]);
      expect(a.cutout!.baseMask, isNull);
      final b = pinceau.undo(a);
      expect(b.cutout!.strokes, hasLength(1));
      expect(
        gomme.undo(b).cutout,
        isNull,
        reason: 'plus rien : pas de détourage',
      );
    });
  });

  group('EditorHistory : annuler / rétablir', () {
    test('exécuter, annuler, rétablir', () {
      final h = EditorHistory();
      var d = _doc();
      d = h.execute(d, AddStrokeCommand(_stroke(1)));
      d = h.execute(d, AddStrokeCommand(_stroke(2)));
      expect(d.strokes, hasLength(2));
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
      expect(h.hasChanges, isTrue);

      d = h.undo(d);
      expect(d.strokes.map((s) => s.id), [1]);
      expect(h.canRedo, isTrue);
      d = h.redo(d);
      expect(d.strokes.map((s) => s.id), [1, 2]);
      expect(h.canRedo, isFalse);

      d = h.undo(h.undo(d));
      expect(d.strokes, isEmpty);
      expect(h.canUndo, isFalse);
      expect(h.hasChanges, isFalse, reason: 'tout annulé = document de départ');
      // Annuler à vide ne fait rien.
      expect(identical(h.undo(d), d), isTrue);
    });

    test('une nouvelle action vide le rétablissement', () {
      final h = EditorHistory();
      var d = h.execute(_doc(), AddStrokeCommand(_stroke(1)));
      d = h.undo(d);
      expect(h.canRedo, isTrue);
      d = h.execute(d, AddStrokeCommand(_stroke(2)));
      expect(h.canRedo, isFalse);
      expect(d.strokes.map((s) => s.id), [2]);
    });

    test('limite de 50 actions : les plus anciennes sont oubliées', () {
      expect(EditorHistory.defaultLimit, 50);
      final h = EditorHistory();
      var d = _doc();
      for (var i = 1; i <= 60; i++) {
        d = h.execute(d, AddStrokeCommand(_stroke(i)));
      }
      expect(h.undoDepth, 50);
      expect(d.strokes, hasLength(60));
      var n = 0;
      while (h.canUndo) {
        d = h.undo(d);
        n++;
      }
      expect(n, 50);
      // Les 10 premiers traits ne sont plus annulables.
      expect(d.strokes.map((s) => s.id), [for (var i = 1; i <= 10; i++) i]);
      expect(
        h.hasChanges,
        isTrue,
        reason: 'des actions sont sorties de la pile',
      );
    });

    test('limite configurable', () {
      final h = EditorHistory(limit: 3);
      var d = _doc();
      for (var i = 1; i <= 5; i++) {
        d = h.execute(d, AddStrokeCommand(_stroke(i)));
      }
      expect(h.undoDepth, 3);
      expect(h.undoLabels, ['trait', 'trait', 'trait']);
    });
  });
}
