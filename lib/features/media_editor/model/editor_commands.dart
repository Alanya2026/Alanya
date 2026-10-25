import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'editor_document.dart';
import 'editor_geometry.dart';

/// Une modification du document, **réversible** : annuler/rétablir rejoue des
/// commandes, jamais des copies de bitmap (économie de mémoire sur les
/// téléphones d'entrée de gamme).
abstract class EditorCommand {
  const EditorCommand();

  /// Nom court, pour les journaux et les tests.
  String get label;

  EditorDoc apply(EditorDoc doc);
  EditorDoc undo(EditorDoc doc);

  /// La commande possède une ressource native (image de masque) à libérer.
  bool get ownsResources => false;

  /// Libère ce que la commande possède quand elle est abandonnée **sans plus
  /// pouvoir être rejouée** (rétablissement écrasé par une nouvelle action) ou
  /// à la fermeture de l'éditeur. Idempotent.
  void disposeResources() {}
}

class AddStrokeCommand extends EditorCommand {
  const AddStrokeCommand(this.stroke);
  final EditorStroke stroke;

  @override
  String get label => stroke.erase ? 'gomme' : 'trait';

  @override
  EditorDoc apply(EditorDoc d) => d.copyWith(strokes: [...d.strokes, stroke]);

  @override
  EditorDoc undo(EditorDoc d) =>
      d.copyWith(strokes: d.strokes.where((s) => s.id != stroke.id).toList());
}

class AddItemCommand extends EditorCommand {
  const AddItemCommand(this.item);
  final EditorItem item;

  @override
  String get label => 'ajout';

  @override
  EditorDoc apply(EditorDoc d) => d.copyWith(items: [...d.items, item]);

  @override
  EditorDoc undo(EditorDoc d) =>
      d.copyWith(items: d.items.where((i) => i.id != item.id).toList());
}

class RemoveItemCommand extends EditorCommand {
  const RemoveItemCommand(this.item, this.index);
  final EditorItem item;

  /// Position d'origine, pour que l'annulation remette l'élément au même rang
  /// d'empilement.
  final int index;

  @override
  String get label => 'suppression';

  @override
  EditorDoc apply(EditorDoc d) =>
      d.copyWith(items: d.items.where((i) => i.id != item.id).toList());

  @override
  EditorDoc undo(EditorDoc d) {
    final items = [...d.items];
    items.insert(index.clamp(0, items.length), item);
    return d.copyWith(items: items);
  }
}

/// Remplace un élément par sa nouvelle version : déplacement, pincement,
/// rotation, changement de texte, de police, de couleur. Même identifiant.
class ReplaceItemCommand extends EditorCommand {
  ReplaceItemCommand(this.before, this.after, {this.name = 'modif'})
    : assert(before.id == after.id);
  final EditorItem before;
  final EditorItem after;
  final String name;

  @override
  String get label => name;

  EditorDoc _swap(EditorDoc d, EditorItem to) =>
      d.copyWith(items: [for (final i in d.items) i.id == to.id ? to : i]);

  @override
  EditorDoc apply(EditorDoc d) => _swap(d, after);

  @override
  EditorDoc undo(EditorDoc d) => _swap(d, before);
}

/// Zoom / déplacement de l'image dans le cadre (le rognage).
class SetImageTransformCommand extends EditorCommand {
  const SetImageTransformCommand(this.before, this.after);
  final EditorImageTransform before;
  final EditorImageTransform after;

  @override
  String get label => 'rognage';

  @override
  EditorDoc apply(EditorDoc d) => d.copyWith(imageTransform: after);

  @override
  EditorDoc undo(EditorDoc d) => d.copyWith(imageTransform: before);
}

/// Filtre et réglages de couleur de l'image de base.
class SetLookCommand extends EditorCommand {
  const SetLookCommand(this.before, this.after, {this.name = 'filtre'});
  final EditorLook before;
  final EditorLook after;
  final String name;

  @override
  String get label => name;

  @override
  EditorDoc apply(EditorDoc d) => d.copyWith(look: after);

  @override
  EditorDoc undo(EditorDoc d) => d.copyWith(look: before);
}

/// Change le format du cadre (mode photo : 4:3, 16:9…) avec la position de
/// l'image qui va avec. Les calques gardent leurs coordonnées : on rogne
/// avant de dessiner.
class SetCanvasCommand extends EditorCommand {
  const SetCanvasCommand({
    required this.beforeCanvas,
    required this.afterCanvas,
    required this.beforeTransform,
    required this.afterTransform,
  });

  final ui.Size beforeCanvas;
  final ui.Size afterCanvas;
  final EditorImageTransform beforeTransform;
  final EditorImageTransform afterTransform;

  @override
  String get label => 'format';

  @override
  EditorDoc apply(EditorDoc d) =>
      d.copyWith(canvas: afterCanvas, imageTransform: afterTransform);

  @override
  EditorDoc undo(EditorDoc d) =>
      d.copyWith(canvas: beforeCanvas, imageTransform: beforeTransform);
}

/// Trait de gomme / pinceau sur le masque de détourage (créé au besoin).
class AddMaskStrokeCommand extends EditorCommand {
  const AddMaskStrokeCommand(this.stroke);
  final EditorMaskStroke stroke;

  @override
  String get label => stroke.restore ? 'pinceau masque' : 'gomme masque';

  @override
  EditorDoc apply(EditorDoc d) {
    final cut = d.cutout ?? EditorCutout();
    return d.withCutout(cut.withStrokes([...cut.strokes, stroke]));
  }

  @override
  EditorDoc undo(EditorDoc d) {
    final cut = d.cutout;
    if (cut == null) return d;
    final rest = cut.strokes.where((s) => s.id != stroke.id).toList();
    final next = cut.withStrokes(rest);
    return d.withCutout(next.isEmpty ? null : next);
  }
}

/// Pose (ou retire, avec `after == null`) le masque calculé par le détourage
/// automatique (T4c). La commande **possède** l'image [after] : elle la
/// libère si elle est abandonnée avant d'avoir pu être rejouée.
class SetCutoutMaskCommand extends EditorCommand {
  SetCutoutMaskCommand({this.before, this.after});
  final ui.Image? before;
  final ui.Image? after;

  @override
  String get label => 'détourage';

  EditorDoc _with(EditorDoc d, ui.Image? mask) {
    final cut = (d.cutout ?? EditorCutout()).withBaseMask(mask);
    return d.withCutout(cut.isEmpty ? null : cut);
  }

  @override
  EditorDoc apply(EditorDoc d) => _with(d, after);

  @override
  EditorDoc undo(EditorDoc d) => _with(d, before);

  bool _disposed = false;

  @override
  bool get ownsResources => after != null;

  @override
  void disposeResources() {
    if (_disposed) return;
    _disposed = true;
    after?.dispose();
  }
}

/// Remplace **tout** le détourage (masque calculé et traits à la main) :
/// résultat du détourage automatique (`after` = masque neuf, sans trait) ou
/// « réinitialiser le masque » (`after == null`). Un seul pas d'annulation,
/// sans copie de bitmap : l'ancien détourage est simplement gardé par la
/// commande (l'image de son masque appartient à la commande qui l'a posé).
///
/// La commande **possède** l'image du masque de [after] : elle la libère si
/// elle est abandonnée avant d'avoir pu être rejouée.
class ReplaceCutoutCommand extends EditorCommand {
  ReplaceCutoutCommand({this.before, this.after, this.name = 'détourage'});
  final EditorCutout? before;
  final EditorCutout? after;
  final String name;

  @override
  String get label => name;

  @override
  EditorDoc apply(EditorDoc d) =>
      d.withCutout(after == null || after!.isEmpty ? null : after);

  @override
  EditorDoc undo(EditorDoc d) =>
      d.withCutout(before == null || before!.isEmpty ? null : before);

  bool _disposed = false;

  @override
  bool get ownsResources => after?.baseMask != null;

  @override
  void disposeResources() {
    if (_disposed) return;
    _disposed = true;
    after?.baseMask?.dispose();
  }
}

/// Pile annuler / rétablir du document : seules des commandes y vivent.
class EditorHistory {
  EditorHistory({this.limit = defaultLimit}) : assert(limit > 0);

  /// Nombre maximal d'actions annulables conservées (les plus anciennes sont
  /// oubliées au-delà).
  static const int defaultLimit = 50;

  final int limit;
  final List<EditorCommand> _undo = [];
  final List<EditorCommand> _redo = [];
  int _dropped = 0;

  /// Commandes sorties de la pile mais qui possèdent encore une image vivante
  /// (utilisée par le document) : libérées à la fermeture.
  final List<EditorCommand> _retired = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;

  /// Des modifications existent par rapport au document de départ (y compris
  /// des actions trop anciennes, déjà sorties de la pile).
  bool get hasChanges => _undo.isNotEmpty || _dropped > 0;

  /// Exécute [cmd] sur [doc] et l'empile ; vide le rétablissement.
  EditorDoc execute(EditorDoc doc, EditorCommand cmd) {
    final next = cmd.apply(doc);
    _undo.add(cmd);
    if (_undo.length > limit) {
      // Pas de `disposeResources` ici : son effet est encore dans le document.
      final old = _undo.removeAt(0);
      if (old.ownsResources) _retired.add(old);
      _dropped++;
    }
    _clearRedo();
    return next;
  }

  EditorDoc undo(EditorDoc doc) {
    if (_undo.isEmpty) return doc;
    final cmd = _undo.removeLast();
    _redo.add(cmd);
    return cmd.undo(doc);
  }

  EditorDoc redo(EditorDoc doc) {
    if (_redo.isEmpty) return doc;
    final cmd = _redo.removeLast();
    _undo.add(cmd);
    return cmd.apply(doc);
  }

  void _clearRedo() {
    for (final c in _redo) {
      c.disposeResources();
    }
    _redo.clear();
  }

  /// Fermeture : libère les ressources de toutes les commandes connues.
  void dispose() {
    _clearRedo();
    for (final c in _undo) {
      c.disposeResources();
    }
    for (final c in _retired) {
      c.disposeResources();
    }
    _undo.clear();
    _retired.clear();
  }

  @visibleForTesting
  List<String> get undoLabels => _undo.map((c) => c.label).toList();
}
