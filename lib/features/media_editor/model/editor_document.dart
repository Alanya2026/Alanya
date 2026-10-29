import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'editor_geometry.dart';

/// Ce que l'éditeur produit : un sticker (carré 512×512 transparent, contrôlé
/// par `StickerImageCheck`) ou une photo retouchée avant envoi.
enum MediaEditorMode { sticker, photo }

/// Polices proposées pour le texte : celles du projet (police du système, et
/// la manuscrite Caveat déjà utilisée par les messages).
enum EditorFont { standard, bold, handwriting }

/// Pinceaux du crayon : stylo, surligneur (translucide, large), néon (cœur
/// clair et halo de la couleur) et flou (floute l'image sous le trait, pour
/// masquer un visage ou une plaque ; la couleur ne compte pas).
enum EditorBrush { pen, highlighter, neon, blur }

/// Alignement d'un texte de plusieurs lignes.
enum EditorTextAlign { left, center, right }

/// Fond d'un texte : aucun, plein (la couleur choisie devient le fond, le
/// texte prend la teinte lisible dessus) ou voile sombre translucide.
enum EditorTextBackground { none, solid, translucent }

/// Filtres prêts à l'emploi (matrices de couleur, `editor_look.dart`).
enum EditorFilter { none, vivid, warm, soft, mono, night }

/// Rendu des couleurs de l'image de base : un filtre (et son intensité) puis
/// des réglages fins, tous neutres à 0. Ne touche que l'image : ni les
/// traits, ni les textes.
@immutable
class EditorLook {
  const EditorLook({
    this.filter = EditorFilter.none,
    this.intensity = 1,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
  });

  static const EditorLook neutral = EditorLook();

  final EditorFilter filter;

  /// Intensité du filtre, de 0 (sans effet) à 1.
  final double intensity;

  /// Réglages, de −1 à 1 (0 = inchangé).
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  bool get isNeutral =>
      (filter == EditorFilter.none || intensity == 0) &&
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0;

  EditorLook copyWith({
    EditorFilter? filter,
    double? intensity,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) => EditorLook(
    filter: filter ?? this.filter,
    intensity: (intensity ?? this.intensity).clamp(0, 1),
    brightness: (brightness ?? this.brightness).clamp(-1, 1),
    contrast: (contrast ?? this.contrast).clamp(-1, 1),
    saturation: (saturation ?? this.saturation).clamp(-1, 1),
    warmth: (warmth ?? this.warmth).clamp(-1, 1),
  );

  @override
  bool operator ==(Object other) =>
      other is EditorLook &&
      other.filter == filter &&
      other.intensity == intensity &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth;

  @override
  int get hashCode =>
      Object.hash(filter, intensity, brightness, contrast, saturation, warmth);
}

/// Un trait au crayon, en coordonnées du **document**. [erase] : la gomme du
/// crayon, qui efface les traits dessinés avant elle (jamais l'image ni le
/// flou). [brush] : le pinceau (ignoré par la gomme).
@immutable
class EditorStroke {
  EditorStroke({
    required this.id,
    required List<ui.Offset> points,
    required this.color,
    required this.width,
    this.erase = false,
    this.brush = EditorBrush.pen,
  }) : points = List.unmodifiable(points);

  final int id;
  final List<ui.Offset> points;
  final ui.Color color;
  final double width;
  final bool erase;
  final EditorBrush brush;

  /// Trait de flou (peint avec l'image, pas avec les traits).
  bool get isBlur => !erase && brush == EditorBrush.blur;

  EditorStroke withPoints(List<ui.Offset> pts) => EditorStroke(
    id: id,
    points: pts,
    color: color,
    width: width,
    erase: erase,
    brush: brush,
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
    this.align = EditorTextAlign.center,
    this.background = EditorTextBackground.none,
  });

  final String text;
  final EditorFont font;
  final ui.Color color;
  final EditorTextAlign align;
  final EditorTextBackground background;

  EditorTextItem copyWith({
    String? text,
    EditorFont? font,
    ui.Color? color,
    EditorTextAlign? align,
    EditorTextBackground? background,
    EditorPlacement? placement,
  }) => EditorTextItem(
    id: id,
    placement: placement ?? this.placement,
    text: text ?? this.text,
    font: font ?? this.font,
    color: color ?? this.color,
    align: align ?? this.align,
    background: background ?? this.background,
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
/// Calques, du dessous au dessus : image de base (avec son rendu [look] et son
/// masque de détourage éventuel) → zones floutées → traits → éléments
/// (textes, emoji). Le fond hors de l'image reste **transparent**.
@immutable
class EditorDoc {
  EditorDoc({
    required this.canvas,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageTransform,
    this.cutout,
    this.look = EditorLook.neutral,
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
  final EditorLook look;
  final List<EditorStroke> strokes;
  final List<EditorItem> items;

  /// Plus grand identifiant utilisé (traits, éléments, masque) : un éditeur
  /// rouvert sur ce document numérote à partir du suivant.
  int get maxId {
    var m = 0;
    for (final s in strokes) {
      if (s.id > m) m = s.id;
    }
    for (final i in items) {
      if (i.id > m) m = i.id;
    }
    for (final s in cutout?.strokes ?? const <EditorMaskStroke>[]) {
      if (s.id > m) m = s.id;
    }
    return m;
  }

  EditorItem? itemById(int id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  EditorDoc copyWith({
    ui.Size? canvas,
    EditorImageTransform? imageTransform,
    EditorLook? look,
    List<EditorStroke>? strokes,
    List<EditorItem>? items,
  }) => EditorDoc(
    canvas: canvas ?? this.canvas,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageTransform: imageTransform ?? this.imageTransform,
    cutout: cutout,
    look: look ?? this.look,
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
    look: look,
    strokes: strokes,
    items: items,
  );
}
