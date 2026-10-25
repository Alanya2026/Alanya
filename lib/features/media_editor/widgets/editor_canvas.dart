import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../editor_controller.dart';
import '../model/editor_geometry.dart';
import '../render/editor_renderer.dart';

/// Zone de retouche : damier (la transparence reste visible), document
/// (`EditorPainter`, le même dessin que l'export), repères (cadre, grille,
/// sélection) et gestes.
///
/// - rogner : un doigt déplace l'image, deux doigts la zooment ;
/// - détourer : pinceau/gomme du masque, même tracé immédiat que le crayon ;
/// - crayon : tracé immédiat, au premier contact (événements bruts, sans le
///   seuil de glissement d'un geste) ;
/// - texte / emoji : toucher sélectionne, glisser déplace, pincer
///   agrandit et tourne l'élément sélectionné.
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key, required this.controller, this.background});
  final EditorController controller;

  /// Fond autour du cadre ; par défaut la surface atténuée du thème.
  final Color? background;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  EditorController get _c => widget.controller;

  // Géométrie de l'écran courant : décalage et échelle du cadre dans la zone.
  Offset _origin = Offset.zero;
  double _scale = 1;

  Offset _toDoc(Offset local) => (local - _origin) / _scale;

  // Rognage.
  EditorImageTransform? _cropBase;
  double _cropBaseScale = 1;
  Offset _cropBaseFocal = Offset.zero;
  int _lastPointers = 0;

  // Éléments.
  bool _itemActive = false;
  EditorPlacement? _itemBase;
  double _itemBaseScale = 1;
  double _itemBaseRotation = 0;
  Offset _itemBaseFocal = Offset.zero;

  // Crayon.
  int? _penPointer;

  void _onScaleStart(ScaleStartDetails d) {
    _lastPointers = d.pointerCount;
    switch (_c.tool) {
      case EditorTool.crop:
        _c.beginImageGesture();
        _rebaseCrop(d.localFocalPoint, 1);
      case EditorTool.text || EditorTool.sticker:
        _itemActive = false;
        final hit = _c.hitTestItem(
          _toDoc(d.localFocalPoint),
          minTouch: AppSizes.minTapTarget / _scale,
        );
        if (hit != null) {
          _startItem(hit, d.localFocalPoint, 1, 0);
        } else if (d.pointerCount >= 2 && _c.selectedId != null) {
          _startItem(_c.selectedId!, d.localFocalPoint, 1, 0);
        }
      case EditorTool.draw || EditorTool.cutout || EditorTool.look:
        break;
    }
  }

  void _startItem(int id, Offset focal, double scale, double rotation) {
    _c.beginItemGesture(id);
    final item = _c.doc.itemById(id);
    if (item == null) return;
    _itemActive = true;
    _itemBase = item.placement;
    _itemBaseScale = scale;
    _itemBaseRotation = rotation;
    _itemBaseFocal = focal;
  }

  void _rebaseCrop(Offset focal, double scale) {
    _cropBase = _c.doc.imageTransform;
    _cropBaseScale = scale;
    _cropBaseFocal = focal;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final rebase = d.pointerCount != _lastPointers;
    _lastPointers = d.pointerCount;
    switch (_c.tool) {
      case EditorTool.crop:
        if (rebase) _rebaseCrop(d.localFocalPoint, d.scale);
        final base = _cropBase;
        if (base == null) return;
        final factor = d.scale / _cropBaseScale;
        final newScale = base.scale * factor;
        // L'image sous le doigt reste sous le doigt pendant le zoom.
        final anchorStart = _toDoc(_cropBaseFocal);
        final anchorNow = _toDoc(d.localFocalPoint);
        _c.updateImageTransform(
          base.copyWith(
            center: anchorNow + (base.center - anchorStart) * factor,
            scale: newScale,
          ),
        );
      case EditorTool.text || EditorTool.sticker:
        if (!_itemActive) {
          // Un second doigt arrive sur un élément sélectionné : on le pince.
          final sel = _c.selectedId;
          if (d.pointerCount >= 2 && sel != null) {
            _startItem(sel, d.localFocalPoint, d.scale, d.rotation);
          }
          return;
        }
        if (rebase) {
          _itemBase = _c.selectedItem?.placement ?? _itemBase;
          _itemBaseScale = d.scale;
          _itemBaseRotation = d.rotation;
          _itemBaseFocal = d.localFocalPoint;
        }
        final base = _itemBase;
        if (base == null) return;
        _c.updateItemPlacement(
          base.transformedBy(
            translate: (d.localFocalPoint - _itemBaseFocal) / _scale,
            scaleFactor: d.scale / _itemBaseScale,
            rotationDelta: d.rotation - _itemBaseRotation,
          ),
        );
      case EditorTool.draw || EditorTool.cutout || EditorTool.look:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    switch (_c.tool) {
      case EditorTool.crop:
        _cropBase = null;
        _c.endImageGesture();
      case EditorTool.text || EditorTool.sticker:
        if (_itemActive) _c.endItemGesture();
        _itemActive = false;
        _itemBase = null;
      case EditorTool.draw || EditorTool.cutout || EditorTool.look:
        break;
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (_c.tool == EditorTool.text || _c.tool == EditorTool.sticker) {
      _c.select(
        _c.hitTestItem(
          _toDoc(d.localPosition),
          minTouch: AppSizes.minTapTarget / _scale,
        ),
      );
    }
  }

  // Crayon et pinceau de détourage : événements bruts.
  void _penDown(PointerDownEvent e) {
    if (_penPointer != null) return;
    _penPointer = e.pointer;
    if (_c.tool == EditorTool.cutout) {
      _c.beginMaskStroke(_toDoc(e.localPosition));
    } else {
      _c.beginStroke(_toDoc(e.localPosition));
    }
  }

  void _penMove(PointerMoveEvent e) {
    if (e.pointer != _penPointer) return;
    if (_c.tool == EditorTool.cutout) {
      _c.extendMaskStroke(_toDoc(e.localPosition));
    } else {
      _c.extendStroke(_toDoc(e.localPosition));
    }
  }

  void _penUp(PointerEvent e) {
    if (e.pointer != _penPointer) return;
    _penPointer = null;
    if (_c.tool == EditorTool.cutout) {
      _c.endMaskStroke();
    } else {
      _c.endStroke();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final drawing =
            _c.tool == EditorTool.draw || _c.tool == EditorTool.cutout;
        final canvasSize = _c.doc.canvas;
        return LayoutBuilder(
          builder: (context, box) {
            const pad = AppSpacing.md;
            final availW = math.max(1.0, box.maxWidth - 2 * pad);
            final availH = math.max(1.0, box.maxHeight - 2 * pad);
            _scale = math.min(
              availW / canvasSize.width,
              availH / canvasSize.height,
            );
            final frame = Size(
              canvasSize.width * _scale,
              canvasSize.height * _scale,
            );
            _origin = Offset(
              (box.maxWidth - frame.width) / 2,
              (box.maxHeight - frame.height) / 2,
            );
            final stack = Stack(
              children: [
                Positioned(
                  left: _origin.dx,
                  top: _origin.dy,
                  width: frame.width,
                  height: frame.height,
                  child: ExcludeSemantics(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRect(
                            child: CustomPaint(
                              key: const ValueKey('editor-checkerboard'),
                              painter: EditorCheckerPainter(
                                colors.surfaceContainerHighest,
                                colors.surface,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey('editor-document'),
                              painter: EditorPainter(
                                docOf: () => _c.doc,
                                image: _c.image,
                                repaint: _c,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey('editor-overlay'),
                              painter: EditorOverlayPainter(
                                controller: _c,
                                frameColor: colors.outline,
                                guideColor: colors.primary,
                                scrimColor: _c.roundFrame
                                    ? colors.scrim.withValues(alpha: 0.55)
                                    : null,
                                repaint: _c,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
            final Widget interactive = drawing
                ? Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _penDown,
                    onPointerMove: _penMove,
                    onPointerUp: _penUp,
                    onPointerCancel: _penUp,
                    child: stack,
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onTapUp: _onTapUp,
                    child: stack,
                  );
            return Semantics(
              container: true,
              image: true,
              label: l10n.mediaEditorCanvas,
              child: ColoredBox(
                color: widget.background ?? context.semantic.surfaceMuted,
                child: interactive,
              ),
            );
          },
        );
      },
    );
  }
}

/// Damier à deux teintes du thème : rend la transparence visible.
class EditorCheckerPainter extends CustomPainter {
  const EditorCheckerPainter(this.a, this.b);
  final Color a;
  final Color b;

  static const double _cell = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = 0; x * _cell < size.width; x++) {
        paint.color = (x + y).isEven ? a : b;
        canvas.drawRect(
          Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(EditorCheckerPainter old) => old.a != a || old.b != b;
}

/// Repères posés sur le document, **jamais exportés** : contour du cadre,
/// grille des tiers pendant le rognage, cadre de l'élément sélectionné.
class EditorOverlayPainter extends CustomPainter {
  EditorOverlayPainter({
    required this.controller,
    required this.frameColor,
    required this.guideColor,
    this.scrimColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final EditorController controller;
  final Color frameColor;
  final Color guideColor;

  /// Photo de profil ou de groupe : voile hors du cercle inscrit dans le cadre
  /// (ce que l'on verra une fois rogné) ; `null` pour un cadre ordinaire.
  final Color? scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final doc = controller.doc;
    final k = size.width / doc.canvas.width;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = frameColor;
    canvas.drawRect(Offset.zero & size, line);

    final scrim = scrimColor;
    if (scrim != null) {
      final rect = Offset.zero & size;
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect),
          Path()..addOval(rect),
        ),
        Paint()..color = scrim,
      );
      canvas.drawOval(rect, line);
    }

    if (controller.tool == EditorTool.crop) {
      line.color = guideColor.withValues(alpha: 0.6);
      for (var i = 1; i <= 2; i++) {
        canvas.drawLine(
          Offset(size.width * i / 3, 0),
          Offset(size.width * i / 3, size.height),
          line,
        );
        canvas.drawLine(
          Offset(0, size.height * i / 3),
          Offset(size.width, size.height * i / 3),
          line,
        );
      }
    }

    final cursor = controller.maskCursor;
    if (cursor != null && controller.tool == EditorTool.cutout) {
      // Aperçu du pinceau pendant le tracé (jamais exporté).
      canvas.drawCircle(
        cursor * k,
        controller.cutoutBrushSize * k / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = guideColor,
      );
    }

    final sel = controller.selectedItem;
    if (sel != null &&
        (controller.tool == EditorTool.text ||
            controller.tool == EditorTool.sticker)) {
      final itemSize = EditorItemMetrics.sizeOf(sel, doc.canvas);
      final pts = [for (final p in sel.placement.corners(itemSize)) p * k];
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = guideColor,
      );
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = guideColor);
      }
    }
  }

  @override
  bool shouldRepaint(EditorOverlayPainter old) =>
      old.frameColor != frameColor ||
      old.guideColor != guideColor ||
      old.scrimColor != scrimColor;
}
