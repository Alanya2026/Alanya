import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/theme/app_colors.dart';
import 'cutout/person_segmenter.dart';
import 'model/editor_commands.dart';
import 'model/editor_document.dart';
import 'model/editor_geometry.dart';
import 'render/editor_renderer.dart';

enum EditorTool { crop, draw, text, sticker, cutout }

/// Pinceau du détourage manuel : [keep] fait revenir des pixels (garder),
/// [erase] les cache (effacer le fond).
enum CutoutBrush { keep, erase }

/// Issue du détourage automatique, pour que l'écran dise quoi à l'utilisateur.
enum AutoCutoutOutcome { done, noPerson, failed, busy, cancelled }

/// Formats de cadre du mode photo (le sticker est toujours carré).
enum EditorAspect {
  original(null),
  square(1),
  r4x3(4 / 3),
  r3x4(3 / 4),
  r16x9(16 / 9),
  r9x16(9 / 16);

  const EditorAspect(this.ratio);

  /// Largeur / hauteur ; `null` = celui de l'image.
  final double? ratio;
}

/// État de l'éditeur : le document (immuable) + la pile de commandes + l'outil
/// courant et la sélection. Les gestes continus (tracé, pincement, glissement)
/// modifient un document **provisoire** ; une seule commande est enregistrée à
/// la fin du geste, donc un geste = une annulation.
///
/// Mémoire : le contrôleur possède l'image de travail (≤ 1024 px, la seule
/// grande bitmap) et la libère dans [dispose] ; annuler/rétablir ne copient
/// aucun bitmap.
class EditorController extends ChangeNotifier {
  /// [fixedAspect] (mode photo seulement) impose le format du cadre : le
  /// document démarre à ce format, l'image remplit le cadre et le choix du
  /// format disparaît (photo de profil : `EditorAspect.square`). `original` ou
  /// `null` : cadre libre, comme avant. [roundFrame] : l'écran montre le cadre
  /// vu par un cercle (repère, jamais exporté).
  EditorController({
    required this.mode,
    required this.image,
    EditorAspect? fixedAspect,
    this.roundFrame = false,
    int historyLimit = EditorHistory.defaultLimit,
  }) : fixedAspect = mode == MediaEditorMode.photo && fixedAspect?.ratio != null
           ? fixedAspect
           : null,
       history = EditorHistory(limit: historyLimit),
       _doc = _initialDoc(mode, image, fixedAspect),
       tool = EditorTool.crop;

  static EditorDoc _initialDoc(
    MediaEditorMode mode,
    ui.Image image,
    EditorAspect? fixed,
  ) {
    final w = image.width;
    final h = image.height;
    if (mode == MediaEditorMode.sticker) {
      return EditorDoc.initial(canvas: stickerCanvas, imageWidth: w, imageHeight: h);
    }
    final ratio = fixed?.ratio;
    if (ratio == null) {
      return EditorDoc.initial(
        canvas: ui.Size(w.toDouble(), h.toDouble()),
        imageWidth: w,
        imageHeight: h,
      );
    }
    final canvas = _canvasFor(ratio, w, h);
    return EditorDoc(
      canvas: canvas,
      imageWidth: w,
      imageHeight: h,
      imageTransform: EditorImageTransform.cover(canvas, w, h),
    );
  }

  /// Cadre de format [ratio] dont le grand côté est celui de l'image.
  static ui.Size _canvasFor(double ratio, int imageW, int imageH) {
    final longSide = math.max(imageW, imageH).toDouble();
    return ratio >= 1
        ? ui.Size(longSide, (longSide / ratio).roundToDouble())
        : ui.Size((longSide * ratio).roundToDouble(), longSide);
  }

  /// Cadre d'un sticker, en unités du document = pixels de l'export.
  static const ui.Size stickerCanvas = ui.Size(512, 512);

  final MediaEditorMode mode;

  /// Format de cadre imposé (mode photo), `null` si libre.
  final EditorAspect? fixedAspect;

  /// Repère circulaire sur le cadre (photo de profil ou de groupe).
  final bool roundFrame;

  /// Image de travail, possédée par le contrôleur.
  final ui.Image image;
  final EditorHistory history;

  EditorDoc _doc;
  EditorDoc? _live;
  int _nextId = 1;
  bool _disposed = false;

  EditorTool tool;
  int? selectedId;

  // Réglages du crayon.
  ui.Color penColor = AppColors.black;
  double penWidth = 12;
  bool erasing = false;

  // Réglages du détourage manuel. Taille en unités du **document** (même
  // rendu à l'écran quel que soit le zoom de l'image) ; convertie en pixels de
  // l'image au tracé.
  CutoutBrush cutoutBrush = CutoutBrush.erase;
  double cutoutBrushSize = 36;
  bool cutoutSoftEdges = false;

  /// Détourage automatique en cours (calcul natif).
  bool cutoutBusy = false;

  /// Position du doigt pendant un trait de masque (document), pour l'aperçu
  /// du pinceau ; `null` hors tracé.
  ui.Offset? maskCursor;

  /// Le document à afficher (provisoire pendant un geste).
  EditorDoc get doc => _live ?? _doc;

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  bool get hasChanges => history.hasChanges;

  EditorItem? get selectedItem {
    final id = selectedId;
    return id == null ? null : doc.itemById(id);
  }

  int newId() => _nextId++;

  /// Redessine sans changer le document (une police vient de se charger).
  void refresh() => _changed();

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // ───────────────────────── Outils et réglages ─────────────────────────

  void selectTool(EditorTool t) {
    if (t == tool) return;
    _abortLive();
    tool = t;
    // La sélection d'un élément n'a de sens que dans les outils qui les
    // manipulent.
    if (t == EditorTool.crop ||
        t == EditorTool.draw ||
        t == EditorTool.cutout) {
      selectedId = null;
    }
    _changed();
  }

  void setPenColor(ui.Color c) {
    penColor = c;
    erasing = false;
    _changed();
  }

  void setPenWidth(double w) {
    penWidth = w.clamp(2, 64);
    _changed();
  }

  void setErasing(bool e) {
    erasing = e;
    _changed();
  }

  void select(int? id) {
    if (selectedId == id) return;
    selectedId = id;
    _changed();
  }

  // ───────────────────────── Commandes ─────────────────────────

  /// Exécute [cmd] et l'enregistre pour annuler.
  void execute(EditorCommand cmd) {
    _live = null;
    _doc = history.execute(_doc, cmd);
    _changed();
  }

  void undo() {
    if (!history.canUndo) return;
    _live = null;
    _doc = history.undo(_doc);
    _afterHistoryMove();
  }

  void redo() {
    if (!history.canRedo) return;
    _live = null;
    _doc = history.redo(_doc);
    _afterHistoryMove();
  }

  void _afterHistoryMove() {
    final id = selectedId;
    if (id != null && _doc.itemById(id) == null) selectedId = null;
    _changed();
  }

  void _abortLive() {
    _live = null;
    _liveStrokePoints = null;
    _liveStroke = null;
    _liveItemBefore = null;
    _imageBefore = null;
    _liveMaskPoints = null;
    _liveMaskStroke = null;
    maskCursor = null;
  }

  // ───────────────────────── Crayon ─────────────────────────

  EditorStroke? _liveStroke;
  List<ui.Offset>? _liveStrokePoints;

  /// Distance minimale entre deux points d'un trait (unités du document).
  static const double _minPointGap = 1.5;

  void beginStroke(ui.Offset p) {
    _liveStrokePoints = [p];
    _liveStroke = EditorStroke(
      id: newId(),
      points: [p],
      color: penColor,
      width: penWidth,
      erase: erasing,
    );
    _live = _doc.copyWith(strokes: [..._doc.strokes, _liveStroke!]);
    _changed();
  }

  void extendStroke(ui.Offset p) {
    final pts = _liveStrokePoints;
    final s = _liveStroke;
    if (pts == null || s == null) return;
    if ((pts.last - p).distance < _minPointGap) return;
    pts.add(p);
    _live = _doc.copyWith(strokes: [..._doc.strokes, s.withPoints(pts)]);
    _changed();
  }

  void endStroke() {
    final pts = _liveStrokePoints;
    final s = _liveStroke;
    _liveStrokePoints = null;
    _liveStroke = null;
    if (pts == null || s == null) return;
    execute(AddStrokeCommand(s.withPoints(pts)));
  }

  // ───────────────────── Textes et emoji ─────────────────────

  /// Centre d'un nouvel élément : milieu du cadre, légèrement décalé pour que
  /// des ajouts successifs ne se superposent pas exactement.
  EditorPlacement _newPlacement() {
    final n = _doc.items.length % 5;
    final c = ui.Offset(_doc.canvas.width / 2, _doc.canvas.height / 2);
    return EditorPlacement(center: c + ui.Offset(14.0 * n, 14.0 * n));
  }

  int addText(String text, EditorFont font, ui.Color color) {
    final item = EditorTextItem(
      id: newId(),
      placement: _newPlacement(),
      text: text,
      font: font,
      color: color,
    );
    execute(AddItemCommand(item));
    selectedId = item.id;
    _changed();
    return item.id;
  }

  int addEmoji(String emoji) {
    final item = EditorEmojiItem(
      id: newId(),
      placement: _newPlacement(),
      emoji: emoji,
    );
    execute(AddItemCommand(item));
    selectedId = item.id;
    _changed();
    return item.id;
  }

  void editText(int id, {String? text, EditorFont? font, ui.Color? color}) {
    final before = _doc.itemById(id);
    if (before is! EditorTextItem) return;
    final after = before.copyWith(text: text, font: font, color: color);
    execute(ReplaceItemCommand(before, after, name: 'texte'));
  }

  void removeItem(int id) {
    final index = _doc.items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    execute(RemoveItemCommand(_doc.items[index], index));
    if (selectedId == id) selectedId = null;
    _changed();
  }

  /// Élément le plus haut sous [docPoint] (point du document). [minTouch] :
  /// cible tactile minimale en unités du document.
  int? hitTestItem(ui.Offset docPoint, {double minTouch = 0}) {
    final d = doc;
    for (var i = d.items.length - 1; i >= 0; i--) {
      final item = d.items[i];
      final size = EditorItemMetrics.sizeOf(item, d.canvas);
      if (item.placement.contains(docPoint, size, minTouch: minTouch)) {
        return item.id;
      }
    }
    return null;
  }

  EditorItem? _liveItemBefore;

  /// Début d'un geste sur l'élément [id] (déplacement, pincement, curseur).
  void beginItemGesture(int id) {
    final item = _doc.itemById(id);
    if (item == null) return;
    _liveItemBefore = item;
    selectedId = id;
    _changed();
  }

  void updateItemPlacement(EditorPlacement p) {
    final before = _liveItemBefore;
    if (before == null) return;
    final after = before.withPlacement(p);
    _live = _doc.copyWith(
      items: [for (final i in _doc.items) i.id == after.id ? after : i],
    );
    _changed();
  }

  void endItemGesture() {
    final before = _liveItemBefore;
    _liveItemBefore = null;
    final live = _live;
    _live = null;
    if (before == null || live == null) {
      _changed();
      return;
    }
    final after = live.itemById(before.id);
    if (after == null || after.placement == before.placement) {
      _changed();
      return;
    }
    execute(ReplaceItemCommand(before, after, name: 'transformation'));
  }

  // ───────────────────────── Image (rognage) ─────────────────────────

  EditorImageTransform? _imageBefore;

  void beginImageGesture() {
    _imageBefore = _doc.imageTransform;
  }

  void updateImageTransform(EditorImageTransform t) {
    if (_imageBefore == null) return;
    _live = _doc.copyWith(
      imageTransform: t.clamped(_doc.canvas, _doc.imageWidth, _doc.imageHeight),
    );
    _changed();
  }

  void endImageGesture() {
    final before = _imageBefore;
    _imageBefore = null;
    final live = _live;
    _live = null;
    if (before == null || live == null || live.imageTransform == before) {
      _changed();
      return;
    }
    execute(SetImageTransformCommand(before, live.imageTransform));
  }

  /// Image entière dans le cadre (`cover = false`) ou cadre rempli
  /// (`cover = true`).
  void fitImage({required bool cover}) {
    final d = _doc;
    final t = cover
        ? EditorImageTransform.cover(d.canvas, d.imageWidth, d.imageHeight)
        : EditorImageTransform.contain(d.canvas, d.imageWidth, d.imageHeight);
    if (t == d.imageTransform) return;
    execute(SetImageTransformCommand(d.imageTransform, t));
  }

  /// Mode photo : change le format du cadre (l'image le remplit).
  void setAspect(EditorAspect a) {
    if (mode != MediaEditorMode.photo || fixedAspect != null) return;
    final d = _doc;
    final ratio = a.ratio ?? d.imageWidth / d.imageHeight;
    final size = _canvasFor(ratio, d.imageWidth, d.imageHeight);
    if (size == d.canvas) return;
    execute(
      SetCanvasCommand(
        beforeCanvas: d.canvas,
        afterCanvas: size,
        beforeTransform: d.imageTransform,
        afterTransform: EditorImageTransform.cover(
          size,
          d.imageWidth,
          d.imageHeight,
        ),
      ),
    );
  }

  // ───────────────────────── Détourage (T4c) ─────────────────────────

  /// Pose le masque calculé par le détourage automatique ; le contrôleur
  /// possède [mask]. `null` retire le détourage automatique.
  void setCutoutMask(ui.Image? mask) {
    execute(SetCutoutMaskCommand(before: _doc.cutout?.baseMask, after: mask));
  }

  /// Trait de gomme (cache) ou de pinceau (restaure) sur le masque, en
  /// pixels de l'image de travail.
  void addMaskStroke(
    List<ui.Offset> points,
    double width, {
    required bool restore,
  }) {
    execute(
      AddMaskStrokeCommand(
        EditorMaskStroke(
          id: newId(),
          points: points,
          width: width,
          restore: restore,
        ),
      ),
    );
  }

  // Réglages.

  void setCutoutBrush(CutoutBrush b) {
    if (cutoutBrush == b) return;
    cutoutBrush = b;
    _changed();
  }

  static const double minCutoutBrush = 8;
  static const double maxCutoutBrush = 120;

  void setCutoutBrushSize(double v) {
    cutoutBrushSize = v.clamp(minCutoutBrush, maxCutoutBrush);
    _changed();
  }

  void setCutoutSoftEdges(bool v) {
    cutoutSoftEdges = v;
    _changed();
  }

  /// Il y a quelque chose à réinitialiser (masque ou traits).
  bool get hasCutout => _doc.cutout != null;

  /// Réinitialise le détourage : tout redevient visible. Une seule action
  /// annulable.
  void resetCutout() {
    final before = _doc.cutout;
    if (before == null) return;
    execute(ReplaceCutoutCommand(before: before, name: 'réinitialisation'));
  }

  // Trait de masque en cours. Les points sont en pixels de l'image de travail.
  EditorMaskStroke? _liveMaskStroke;
  List<ui.Offset>? _liveMaskPoints;

  ui.Offset _docToImage(ui.Offset p) {
    final t = _doc.imageTransform;
    return (p - t.center) / t.scale +
        ui.Offset(_doc.imageWidth / 2, _doc.imageHeight / 2);
  }

  void _showLiveMask() {
    final s = _liveMaskStroke;
    final pts = _liveMaskPoints;
    if (s == null || pts == null) return;
    final cut = _doc.cutout ?? EditorCutout();
    _live = _doc.withCutout(
      cut.withStrokes([...cut.strokes, s.withPoints(pts)]),
    );
  }

  /// Début d'un trait de pinceau/gomme sur le masque ; [docPoint] en
  /// coordonnées du document.
  void beginMaskStroke(ui.Offset docPoint) {
    if (cutoutBusy) return;
    final scale = _doc.imageTransform.scale;
    final p = _docToImage(docPoint);
    _liveMaskPoints = [p];
    _liveMaskStroke = EditorMaskStroke(
      id: newId(),
      points: [p],
      width: cutoutBrushSize / scale,
      restore: cutoutBrush == CutoutBrush.keep,
      soft: cutoutSoftEdges,
    );
    maskCursor = docPoint;
    _showLiveMask();
    _changed();
  }

  void extendMaskStroke(ui.Offset docPoint) {
    final pts = _liveMaskPoints;
    if (pts == null || _liveMaskStroke == null) return;
    final p = _docToImage(docPoint);
    maskCursor = docPoint;
    final scale = _doc.imageTransform.scale;
    if ((pts.last - p).distance * scale < _minPointGap) {
      _changed();
      return;
    }
    pts.add(p);
    _showLiveMask();
    _changed();
  }

  void endMaskStroke() {
    final pts = _liveMaskPoints;
    final s = _liveMaskStroke;
    _liveMaskPoints = null;
    _liveMaskStroke = null;
    maskCursor = null;
    if (pts == null || s == null) {
      _changed();
      return;
    }
    execute(AddMaskStrokeCommand(s.withPoints(pts)));
  }

  /// Détourage automatique des **personnes** par [segmenter] (sur l'appareil).
  /// Remplace le détourage en cours (masque et traits) en une seule action
  /// annulable ; le contrôleur possède l'image du masque.
  Future<AutoCutoutOutcome> autoCutout(PersonSegmenter segmenter) async {
    if (cutoutBusy) return AutoCutoutOutcome.busy;
    cutoutBusy = true;
    _abortLive();
    _changed();
    ui.Image? maskImage;
    try {
      final mask = await segmenter.segment(image);
      if (_disposed) return AutoCutoutOutcome.cancelled;
      maskImage = await mask.toImage();
      if (_disposed) return AutoCutoutOutcome.cancelled;
      execute(
        ReplaceCutoutCommand(
          before: _doc.cutout,
          after: EditorCutout(baseMask: maskImage),
        ),
      );
      maskImage = null; // possédée par la commande
      return AutoCutoutOutcome.done;
    } on PersonSegmentationException catch (e) {
      return e.issue == PersonSegmentationIssue.noPerson
          ? AutoCutoutOutcome.noPerson
          : AutoCutoutOutcome.failed;
    } catch (_) {
      return AutoCutoutOutcome.failed;
    } finally {
      maskImage?.dispose();
      cutoutBusy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    history.dispose();
    image.dispose();
    super.dispose();
  }
}
