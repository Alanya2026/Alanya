// Éditeur d'image (T4b) : contrôleur (gestes → une commande, sélection,
// hit-test des éléments, transformations, mémoire).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/features/media_editor/editor_controller.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';

import 'support/media_editor_fakes.dart';

const _red = Color(0xFFFF0000);

Future<EditorController> _controller(
  MediaEditorMode mode, {
  int w = 400,
  int h = 200,
  int limit = 50,
}) async => EditorController(
  mode: mode,
  image: await solidImage(w, h),
  historyLimit: limit,
);

void main() {
  test('sticker : cadre carré 512, image entière « contain »', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    expect(c.doc.canvas, const Size(512, 512));
    expect(
      c.doc.imageTransform,
      EditorImageTransform.contain(const Size(512, 512), 400, 200),
    );
    expect(c.tool, EditorTool.crop);
    expect(c.hasChanges, isFalse);
  });

  test('photo : cadre au format de l\'image ; formats proposés', () async {
    final c = await _controller(MediaEditorMode.photo);
    addTearDown(c.dispose);
    expect(c.doc.canvas, const Size(400, 200));
    c.setAspect(EditorAspect.square);
    expect(c.doc.canvas, const Size(400, 400));
    expect(c.doc.imageTransform.scale, closeTo(2, 1e-9)); // cover : 400/200
    c.setAspect(EditorAspect.r16x9);
    expect(c.doc.canvas.width, 400);
    expect(c.doc.canvas.height, closeTo(225, 1));
    c.undo();
    expect(c.doc.canvas, const Size(400, 400));
    c.undo();
    expect(c.doc.canvas, const Size(400, 200));
  });

  test(
    'sticker : le format du cadre ne change pas (1:1 obligatoire)',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      c.setAspect(EditorAspect.r16x9);
      expect(c.doc.canvas, const Size(512, 512));
      expect(c.canUndo, isFalse);
    },
  );

  test('un tracé = une seule commande annulable', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    c.setPenColor(_red);
    c.setPenWidth(10);
    c.beginStroke(const Offset(10, 10));
    for (var i = 1; i <= 30; i++) {
      c.extendStroke(Offset(10.0 + i * 5, 10));
    }
    expect(c.doc.strokes, hasLength(1), reason: 'provisoire à l\'écran');
    expect(c.canUndo, isFalse, reason: 'rien d\'enregistré avant la fin');
    c.endStroke();
    expect(c.history.undoDepth, 1);
    final s = c.doc.strokes.single;
    expect(s.points.length, 31);
    expect(s.color, _red);
    expect(s.width, 10);
    expect(s.erase, isFalse);

    c.undo();
    expect(c.doc.strokes, isEmpty);
    c.redo();
    expect(c.doc.strokes, hasLength(1));
  });

  test(
    'gomme du crayon : trait marqué `erase`, points trop proches ignorés',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      c.setErasing(true);
      c.beginStroke(const Offset(10, 10));
      c.extendStroke(const Offset(10.5, 10)); // < 1,5 : ignoré
      c.extendStroke(const Offset(20, 10));
      c.endStroke();
      final s = c.doc.strokes.single;
      expect(s.erase, isTrue);
      expect(s.points, hasLength(2));
      c.setPenColor(_red);
      expect(
        c.erasing,
        isFalse,
        reason: 'choisir une couleur revient au crayon',
      );
    },
  );

  test(
    'texte : ajout sélectionné, geste de déplacement = une commande',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      final id = c.addText('Salut', EditorFont.bold, _red);
      expect(c.selectedId, id);
      final item = c.doc.items.single as EditorTextItem;
      expect(item.text, 'Salut');
      expect(item.font, EditorFont.bold);
      expect(item.placement.center, const Offset(256, 256));
      expect(c.history.undoDepth, 1);

      c.beginItemGesture(id);
      final base = c.doc.itemById(id)!.placement;
      c.updateItemPlacement(base.transformedBy(translate: const Offset(30, 0)));
      c.updateItemPlacement(
        base.transformedBy(
          translate: const Offset(60, -20),
          scaleFactor: 2,
          rotationDelta: 0.4,
        ),
      );
      expect(c.history.undoDepth, 1, reason: 'geste en cours : rien d\'empilé');
      c.endItemGesture();
      expect(c.history.undoDepth, 2);
      final moved = c.doc.itemById(id)!.placement;
      expect(moved.center, const Offset(316, 236));
      expect(moved.scale, 2);
      expect(moved.rotation, closeTo(0.4, 1e-9));

      c.undo();
      expect(c.doc.itemById(id)!.placement, base);
      c.redo();
      expect(c.doc.itemById(id)!.placement, moved);
    },
  );

  test('geste sans effet : aucune commande', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    final id = c.addEmoji('😀');
    c.beginItemGesture(id);
    c.endItemGesture();
    c.beginImageGesture();
    c.endImageGesture();
    expect(c.history.undoDepth, 1);
  });

  test(
    'hit-test : l\'élément du dessus gagne ; cible tactile minimale',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      final dessous = c.addEmoji('😀');
      final dessus = c.addEmoji('🎉');
      // Les deux sont au même endroit (décalés de 14) : le dernier ajouté gagne.
      final p = c.doc.itemById(dessus)!.placement.center;
      expect(c.hitTestItem(p), dessus);
      expect(c.hitTestItem(const Offset(2, 2)), isNull);
      expect(c.hitTestItem(const Offset(2, 2), minTouch: 20), isNull);
      expect(dessous, isNot(dessus));

      // Après suppression de celui du dessus, l'autre redevient atteignable.
      c.removeItem(dessus);
      expect(c.hitTestItem(c.doc.itemById(dessous)!.placement.center), dessous);
      expect(c.selectedId, isNull);
      c.undo();
      expect(c.doc.items.map((i) => i.id), [dessous, dessus]);
    },
  );

  test('un élément petit reste attrapable avec une cible de 48', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    final id = c.addText('i', EditorFont.standard, _red);
    c.beginItemGesture(id);
    c.updateItemPlacement(
      c.doc.itemById(id)!.placement.copyWith(scale: EditorPlacement.minScale),
    );
    c.endItemGesture();
    final centre = c.doc.itemById(id)!.placement.center;
    final dehors = centre + const Offset(30, 0);
    expect(c.hitTestItem(dehors), isNull);
    expect(c.hitTestItem(dehors, minTouch: 100), id);
  });

  test('édition du texte : même identifiant, annulable', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    final id = c.addText('Avant', EditorFont.standard, _red);
    c.editText(id, text: 'Après', font: EditorFont.handwriting);
    final t = c.doc.itemById(id) as EditorTextItem;
    expect(t.text, 'Après');
    expect(t.font, EditorFont.handwriting);
    expect(t.color, _red);
    c.undo();
    expect((c.doc.itemById(id) as EditorTextItem).text, 'Avant');
  });

  test(
    'rognage : geste = une commande, bornes respectées, ajuster/remplir',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      final depart = c.doc.imageTransform;
      c.beginImageGesture();
      c.updateImageTransform(
        EditorImageTransform(center: const Offset(9999, 256), scale: 5000),
      );
      expect(
        c.doc.imageTransform.center.dx,
        512,
        reason: 'centre gardé dans le cadre',
      );
      expect(c.doc.imageTransform.scale, lessThan(5000));
      c.endImageGesture();
      expect(c.history.undoDepth, 1);
      c.undo();
      expect(c.doc.imageTransform, depart);

      c.fitImage(cover: true);
      expect(c.doc.imageTransform.scale, closeTo(512 / 200, 1e-9));
      c.fitImage(cover: false);
      expect(c.doc.imageTransform, depart);
      expect(c.history.undoDepth, 2);
    },
  );

  test('changer d\'outil abandonne le geste et désélectionne', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    c.selectTool(EditorTool.text);
    final id = c.addText('x', EditorFont.standard, _red);
    expect(c.selectedId, id);
    c.selectTool(EditorTool.draw);
    expect(c.selectedId, isNull);
    c.beginStroke(const Offset(1, 1));
    c.selectTool(EditorTool.crop);
    expect(
      c.doc.strokes,
      isEmpty,
      reason: 'tracé abandonné, rien d\'enregistré',
    );
  });

  test('annuler un ajout désélectionne l\'élément disparu', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    c.addEmoji('😀');
    expect(c.selectedId, isNotNull);
    c.undo();
    expect(c.selectedId, isNull);
  });

  test('historique : 60 actions → 50 annulables, document intact', () async {
    final c = await _controller(MediaEditorMode.sticker);
    addTearDown(c.dispose);
    for (var i = 0; i < 60; i++) {
      c.beginStroke(Offset(i.toDouble(), 0));
      c.extendStroke(Offset(i.toDouble(), 20));
      c.endStroke();
    }
    expect(c.history.undoDepth, 50);
    expect(c.doc.strokes, hasLength(60));
    for (var i = 0; i < 50; i++) {
      c.undo();
    }
    expect(c.canUndo, isFalse);
    expect(c.doc.strokes, hasLength(10));
  });

  test(
    'mémoire : un seul bitmap, libéré à la fermeture ; masque libéré',
    () async {
      final c = await _controller(MediaEditorMode.sticker, w: 800, h: 800);
      final mask = await solidImage(800, 800);
      final img = c.image;
      expect(img.width, 800);
      c.setCutoutMask(mask);
      expect(c.doc.cutout!.baseMask, same(mask));
      c.addMaskStroke(
        const [Offset(10, 10), Offset(50, 50)],
        20,
        restore: false,
      );
      c.undo(); // trait de masque
      c.undo(); // masque lui-même, désormais « rétablissable »
      expect(c.doc.cutout, isNull);
      c.dispose();
      expect(img.debugDisposed, isTrue);
      expect(
        mask.debugDisposed,
        isTrue,
        reason: 'le masque appartient à l\'historique',
      );
    },
  );

  test(
    'masque écrasé par une nouvelle action : image libérée tout de suite',
    () async {
      final c = await _controller(MediaEditorMode.sticker);
      addTearDown(c.dispose);
      final mask = await solidImage(400, 200);
      c.setCutoutMask(mask);
      c.undo();
      expect(mask.debugDisposed, isFalse, reason: 'encore rétablissable');
      c.addEmoji('😀'); // vide le rétablissement
      expect(mask.debugDisposed, isTrue);
    },
  );
}
