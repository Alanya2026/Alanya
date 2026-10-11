import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'editor_geometry.dart';

/// Ce que l'éditeur produit : un sticker (carré 512×512 transparent, contrôlé
/// par `StickerImageCheck`) ou une photo retouchée avant envoi.
enum MediaEditorMode { sticker, photo }

/// Polices proposées pour le texte : celles du projet (police du système, et
/// la manuscrite Caveat déjà utilisée par les messages).
enum EditorFont { standard, bold, handwriting }

/// Un trait au crayon, en coordonnées du **document**. [erase] : la gomme du
/// crayon, qui efface les traits dessinés avant elle (jamais l'image).
@immutable
class EditorStroke {
  EditorStroke({
    required this.id,
    required List<ui.Offset> points,
    required this.color,
    required this.width,
    this.erase = false,
  }) : points = List.unmodifiable(points);

  final int id;
  final List<ui.Offset> points;
  final ui.Color color;
  final double width;
  final bool erase;

  EditorStroke withPoints(List<ui.Offset> pts) => EditorStroke(
    id: id,
    points: pts,
    color: color,
    width: width,
    erase: erase,
  );
}

/// Un trait de pinceau sur le **masque de détourage**, en pixels de l'image de
/// travail (le masque suit l'image quand on la déplace). [restore] : fait
/// revenir des pixels cachés ; sinon le trait les cache (gomme). [soft] :
/// bords doux (le trait est flouté, la transition est progressive).
@immutable
class EditorMaskStroke {
  EditorMaskStroke({
    required this.id,
    required List<ui.Offset> points,
    required this.width,
    this.restore = false,
    this.soft = false,
  }) : points = List.unmodifiable(points);

  final int id;
  final List<ui.Offset> points;
  final double width;
  final bool restore;
  final bool soft;

  EditorMaskStroke withPoints(List<ui.Offset> pts) => EditorMaskStroke(
    id: id,
    points: pts,
    width: width,
    restore: restore,
    soft: soft,
  );
}

/// Détourage : un masque calculé (T4c : ML Kit, un canal alpha de la taille de
/// l'image de travail ; `null` = tout visible) corrigé à la main par des
/// traits de gomme et de pinceau. Absent du document (`null`) tant qu'on n'a
/// pas détouré.
///
/// L'image du masque, quand il y en a une, appartient au contrôleur de
/// l'éditeur (il la libère) : le modèle ne fait que la référencer.
@immutable
class EditorCutout {
  EditorCutout({this.baseMask, List<EditorMaskStroke> strokes = const []})
    : strokes = List.unmodifiable(strokes);

  final ui.Image? baseMask;
  final List<EditorMaskStroke> strokes;

  bool get isEmpty => baseMask == null && strokes.isEmpty;

  EditorCutout withStrokes(List<EditorMaskStroke> s) =>
      EditorCutout(baseMask: baseMask, strokes: s);

  EditorCutout withBaseMask(ui.Image? mask) =>
      EditorCutout(baseMask: mask, strokes: strokes);
}

/// Un élément posé sur l'image : texte ou emoji. L'ordre de la liste du
/// document est l'ordre d'empilement (le dernier est dessus).
@immutable
sealed class EditorItem {
  const EditorItem({required this.id, required this.placement});

  final int id;
  final EditorPlacement placement;

  EditorItem withPlacement(EditorPlacement p);
}

@immutable
class EditorTextItem extends EditorItem {
  const EditorTextItem({
    required super.id,
    required super.placement,
    required this.text,
    this.font = EditorFont.standard,
    required this.color,
  });

  final String text;
  final EditorFont font;
  final ui.Color color;

  EditorTextItem copyWith({
    String? text,
    EditorFont? font,
    ui.Color? color,
    EditorPlacement? placement,
  }) => EditorTextItem(
    id: id,
    placement: placement ?? this.placement,
    text: text ?? this.text,
    font: font ?? this.font,
    color: color ?? this.color,
  );

  @override
  EditorTextItem withPlacement(EditorPlacement p) => copyWith(placement: p);
}

@immutable
class EditorEmojiItem extends EditorItem {
  const EditorEmojiItem({
    required super.id,
    required super.placement,
    required this.emoji,
  });

  final String emoji;

  @override
  EditorEmojiItem withPlacement(EditorPlacement p) =>
      EditorEmojiItem(id: id, placement: p, emoji: emoji);
}

/// Le document édité : **immuable**, modifié uniquement par des commandes
/// (`editor_commands.dart`), donc annulable sans copie de bitmap.
///
/// Calques, du dessous au dessus : image de base (avec son masque de
/// détourage éventuel) → traits → éléments (textes, emoji). Le fond hors de
/// l'image reste **transparent**.
@immutable
class EditorDoc {
  EditorDoc({
    required this.canvas,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageTransform,
    this.cutout,
    List<EditorStroke> strokes = const [],
    List<EditorItem> items = const [],
  }) : strokes = List.unmodifiable(strokes),
       items = List.unmodifiable(items);

  /// Document neuf : l'image entière visible dans le cadre (« contain », le
  /// même point de départ que `StickerImageAdapter`).
  factory EditorDoc.initial({
    required ui.Size canvas,
    required int imageWidth,
    required int imageHeight,
  }) => EditorDoc(
    canvas: canvas,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageTransform: EditorImageTransform.contain(
      canvas,
      imageWidth,
      imageHeight,
    ),
  );

  /// Taille du cadre en unités du document (512×512 pour un sticker).
  final ui.Size canvas;
  final int imageWidth;
  final int imageHeight;
  final EditorImageTransform imageTransform;
  final EditorCutout? cutout;
  final List<EditorStroke> strokes;
  final List<EditorItem> items;

  EditorItem? itemById(int id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  EditorDoc copyWith({
    ui.Size? canvas,
    EditorImageTransform? imageTransform,
    List<EditorStroke>? strokes,
    List<EditorItem>? items,
  }) => EditorDoc(
    canvas: canvas ?? this.canvas,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageTransform: imageTransform ?? this.imageTransform,
    cutout: cutout,
    strokes: strokes ?? this.strokes,
    items: items ?? this.items,
  );

  /// Remplace (ou retire, avec `null`) le détourage.
  EditorDoc withCutout(EditorCutout? c) => EditorDoc(
    canvas: canvas,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageTransform: imageTransform,
    cutout: c,
    strokes: strokes,
    items: items,
  );
}
