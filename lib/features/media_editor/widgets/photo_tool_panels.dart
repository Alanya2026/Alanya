import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../editor_controller.dart';
import '../model/editor_document.dart';
import '../model/editor_geometry.dart';
import '../render/editor_look.dart';
import 'editor_controls.dart';
import 'editor_panels.dart';

/// Panneaux des écrans d'outil de la retouche avant envoi (un outil à la fois,
/// thème sombre) : rogner, crayon, texte, emoji, filtres.

// ───────────────────────────── Rogner ─────────────────────────────

class PhotoCropPanel extends StatelessWidget {
  const PhotoCropPanel({super.key, required this.controller});
  final EditorController controller;

  static String _aspectLabel(EditorAspect a, AppLocalizations l10n) =>
      switch (a) {
        EditorAspect.original => l10n.mediaEditorAspectOriginal,
        EditorAspect.square => '1:1',
        EditorAspect.r4x3 => '4:3',
        EditorAspect.r3x4 => '3:4',
        EditorAspect.r16x9 => '16:9',
        EditorAspect.r9x16 => '9:16',
      };

  /// Format courant du cadre, s'il correspond à l'un des formats proposés.
  static EditorAspect? currentAspect(EditorDoc d) {
    final ratio = d.canvas.width / d.canvas.height;
    final o = EditorImageTransform.orientedSize(
      d.imageWidth,
      d.imageHeight,
      d.imageTransform.quarterTurns,
    );
    for (final a in EditorAspect.values) {
      final r = a.ratio ?? o.width / o.height;
      if ((r - ratio).abs() < 0.01) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final doc = controller.doc;
        final current = currentAspect(doc);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationDial(
              key: const ValueKey('photo-crop-dial'),
              label: l10n.mediaEditorStraighten,
              value: doc.imageTransform.rotation,
              onStart: controller.beginRotation,
              onChanged: controller.updateRotation,
              onEnd: controller.endRotation,
            ),
            if (controller.fixedAspect == null) ...[
              AppSpacing.vGapSm,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    for (final a in EditorAspect.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.sm,
                        ),
                        child: ChoiceChip(
                          key: ValueKey('photo-aspect-${a.name}'),
                          label: Text(_aspectLabel(a, l10n)),
                          selected: a == current,
                          onSelected: (_) => controller.setAspect(a),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            AppSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                EditorToolButton(
                  key: const ValueKey('photo-rotate'),
                  icon: Icons.rotate_90_degrees_cw_outlined,
                  label: l10n.mediaEditorRotate90,
                  selected: false,
                  onTap: controller.rotateQuarter,
                ),
                EditorToolButton(
                  key: const ValueKey('photo-flip'),
                  icon: Icons.flip_outlined,
                  label: l10n.mediaEditorFlip,
                  selected: false,
                  onTap: controller.flipImage,
                ),
                EditorToolButton(
                  key: const ValueKey('photo-reset-crop'),
                  icon: Icons.restart_alt,
                  label: l10n.mediaEditorReset,
                  selected: false,
                  onTap: controller.resetCrop,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Molette de redressement : glisser horizontalement tourne l'image de ±45°
/// (1° par graduation). Accessible comme un curseur (±1° par action).
class RotationDial extends StatefulWidget {
  const RotationDial({
    super.key,
    required this.label,
    required this.value,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  final String label;

  /// Angle courant, en radians.
  final double value;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;

  /// Écart entre deux graduations (1°), en pixels logiques.
  static const double pixelsPerDegree = 7;

  @override
  State<RotationDial> createState() => _RotationDialState();
}

class _RotationDialState extends State<RotationDial> {
  double _angle = 0;
  int _lastWholeDegree = 0;

  static double _deg(double rad) => rad * 180 / math.pi;
  static double _rad(double deg) => deg * math.pi / 180;

  void _step(double deltaDegrees) {
    widget.onStart();
    widget.onChanged(widget.value + _rad(deltaDegrees));
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final degrees = _deg(widget.value);
    final shown = degrees.round();
    return Semantics(
      slider: true,
      label: widget.label,
      value: '$shown°',
      increasedValue: '${shown + 1}°',
      decreasedValue: '${shown - 1}°',
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _angle = widget.value;
            _lastWholeDegree = shown;
            widget.onStart();
          },
          onHorizontalDragUpdate: (d) {
            final max = EditorImageTransform.maxFineRotation;
            // Glisser vers la gauche fait défiler la règle : l'angle monte.
            _angle = (_angle -
                    _rad(d.delta.dx / RotationDial.pixelsPerDegree))
                .clamp(-max, max);
            widget.onChanged(_angle);
            final whole = _deg(_angle).round();
            if (whole != _lastWholeDegree && whole % 5 == 0) {
              HapticFeedback.selectionClick();
            }
            _lastWholeDegree = whole;
          },
          onHorizontalDragEnd: (_) => widget.onEnd(),
          onHorizontalDragCancel: widget.onEnd,
          onDoubleTap: () {
            widget.onStart();
            widget.onChanged(0);
            widget.onEnd();
          },
          child: SizedBox(
            height: 56,
            child: Column(
              children: [
                Text(
                  '$shown°',
                  style: context.text.labelLarge?.copyWith(
                    color: colors.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                AppSpacing.vGapXs,
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DialPainter(
                      degrees: degrees,
                      tick: colors.onSurfaceVariant,
                      major: colors.onSurface,
                      indicator: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.degrees,
    required this.tick,
    required this.major,
    required this.indicator,
  });

  final double degrees;
  final Color tick;
  final Color major;
  final Color indicator;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    const step = RotationDial.pixelsPerDegree;
    final p = Paint()..strokeCap = StrokeCap.round;
    for (var d = -45; d <= 45; d++) {
      final x = mid + (d - degrees) * step;
      if (x < 0 || x > size.width) continue;
      final isMajor = d % 5 == 0;
      p
        ..color = isMajor ? major : tick.withValues(alpha: 0.6)
        ..strokeWidth = isMajor ? 2 : 1.2;
      final h = isMajor ? size.height * 0.8 : size.height * 0.45;
      canvas.drawLine(
        Offset(x, size.height - h),
        Offset(x, size.height),
        p,
      );
    }
    canvas.drawLine(
      Offset(mid, 0),
      Offset(mid, size.height),
      Paint()
        ..color = indicator
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.degrees != degrees ||
      old.tick != tick ||
      old.major != major ||
      old.indicator != indicator;
}

// ───────────────────────────── Crayon ─────────────────────────────

class PhotoDrawPanel extends StatelessWidget {
  const PhotoDrawPanel({
    super.key,
    required this.controller,
    this.allowBlur = true,
  });
  final EditorController controller;

  /// Flou de zone proposé (pas sur une vidéo).
  final bool allowBlur;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final brushes = [
          (EditorBrush.pen, Icons.edit_outlined, l10n.mediaEditorBrushPen),
          (
            EditorBrush.highlighter,
            Icons.border_color_outlined,
            l10n.mediaEditorBrushHighlighter,
          ),
          (EditorBrush.neon, Icons.flare, l10n.mediaEditorBrushNeon),
          if (allowBlur)
            (EditorBrush.blur, Icons.blur_on, l10n.mediaEditorBrushBlur),
        ];
        final colorless = c.erasing || c.brush == EditorBrush.blur;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (b, icon, label) in brushes)
                  EditorToolButton(
                    key: ValueKey('photo-brush-${b.name}'),
                    icon: icon,
                    label: label,
                    selected: !c.erasing && c.brush == b,
                    onTap: () => c.setBrush(b),
                  ),
                EditorToolButton(
                  key: const ValueKey('photo-brush-eraser'),
                  icon: Icons.auto_fix_normal_outlined,
                  label: l10n.mediaEditorEraser,
                  selected: c.erasing,
                  onTap: () => c.setErasing(true),
                ),
              ],
            ),
            AppSpacing.vGapXs,
            SizedBox(
              height: AppSizes.minTapTarget,
              child: c.brush == EditorBrush.blur && !c.erasing
                  ? Center(
                      child: Text(
                        l10n.mediaEditorBlurHint,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : IgnorePointer(
                      ignoring: colorless,
                      child: Opacity(
                        opacity: colorless ? 0.4 : 1,
                        child: Center(
                          child: EditorColorPalette(
                            selected: c.penColor,
                            onSelected: c.setPenColor,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Épaisseur du trait, en curseur vertical posé sur le bord de l'image (le
/// pouce le trouve sans quitter le dessin). L'aperçu montre la taille réelle.
class PhotoBrushSizeSlider extends StatelessWidget {
  const PhotoBrushSizeSlider({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: Container(
                width: (c.penWidth / 2).clamp(4, 28),
                height: (c.penWidth / 2).clamp(4, 28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.erasing || c.brush == EditorBrush.blur
                      ? colors.onSurface
                      : c.penColor,
                  border: Border.all(color: colors.onSurface, width: 1.5),
                ),
              ),
            ),
            SizedBox(
              height: 200,
              width: AppSizes.minTapTarget,
              child: RotatedBox(
                quarterTurns: 3,
                child: Semantics(
                  label: l10n.mediaEditorThickness,
                  child: Slider(
                    key: const ValueKey('photo-brush-size'),
                    value: c.penWidth.clamp(4, 64),
                    min: 4,
                    max: 64,
                    onChanged: c.setPenWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Texte et emoji ─────────────────────────

/// Après l'ajout : déplacer, pincer, et l'alternative accessible aux gestes
/// (taille, rotation, suppression) de l'élément sélectionné.
class PhotoItemPanel extends StatelessWidget {
  const PhotoItemPanel({
    super.key,
    required this.controller,
    required this.addLabel,
    required this.addIcon,
    required this.onAdd,
    this.onEdit,
  });

  final EditorController controller;
  final String addLabel;
  final IconData addIcon;
  final VoidCallback onAdd;

  /// Modifier le texte sélectionné ; `null` pour les emoji.
  final ValueChanged<EditorTextItem>? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sel = controller.selectedItem;
        final edit = onEdit;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mediaEditorItemHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapXs,
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  key: const ValueKey('photo-item-add'),
                  avatar: Icon(addIcon, size: 18),
                  label: Text(addLabel),
                  onPressed: onAdd,
                ),
                if (sel is EditorTextItem && edit != null)
                  ActionChip(
                    key: const ValueKey('photo-item-edit'),
                    avatar: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.mediaEditorEditText),
                    onPressed: () => edit(sel),
                  ),
                if (sel != null)
                  EditorDeleteButton(controller: controller, item: sel),
              ],
            ),
            if (sel != null)
              EditorItemControls(controller: controller, item: sel),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── Filtres ─────────────────────────────

String editorFilterLabel(EditorFilter f, AppLocalizations l10n) => switch (f) {
  EditorFilter.none => l10n.mediaEditorFilterNone,
  EditorFilter.vivid => l10n.mediaEditorFilterVivid,
  EditorFilter.warm => l10n.mediaEditorFilterWarm,
  EditorFilter.soft => l10n.mediaEditorFilterSoft,
  EditorFilter.mono => l10n.mediaEditorFilterMono,
  EditorFilter.night => l10n.mediaEditorFilterNight,
};

class PhotoLookPanel extends StatefulWidget {
  const PhotoLookPanel({super.key, required this.controller});
  final EditorController controller;

  @override
  State<PhotoLookPanel> createState() => _PhotoLookPanelState();
}

class _PhotoLookPanelState extends State<PhotoLookPanel> {
  int _tab = 0;

  EditorController get _c => widget.controller;

  Widget _lookSlider(
    String label,
    double value,
    double min,
    EditorLook Function(EditorLook look, double v) apply, {
    Key? key,
  }) {
    return EditorSlider(
      key: key,
      label: label,
      value: value,
      min: min,
      max: 1,
      onChangeStart: _c.beginLook,
      onChanged: (v) => _c.updateLook(apply(_c.doc.look, v)),
      onChangeEnd: _c.endLook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final look = _c.doc.look;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SegmentedButton<int>(
                key: const ValueKey('photo-look-tabs'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(l10n.mediaEditorTabFilters),
                  ),
                  ButtonSegment(value: 1, label: Text(l10n.mediaEditorTabAdjust)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            AppSpacing.vGapSm,
            if (_tab == 0) ...[
              SizedBox(
                height: AppSizes.minTapTarget,
                child: look.filter == EditorFilter.none
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: _lookSlider(
                          l10n.mediaEditorIntensity,
                          look.intensity,
                          0,
                          (l, v) => l.copyWith(intensity: v),
                          key: const ValueKey('photo-look-intensity'),
                        ),
                      ),
              ),
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    for (final f in EditorFilter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.sm,
                        ),
                        child: _FilterThumb(
                          key: ValueKey('photo-filter-${f.name}'),
                          controller: _c,
                          filter: f,
                          label: editorFilterLabel(f, l10n),
                          selected: look.filter == f,
                          onTap: () => _c.setFilter(f),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _lookSlider(
                      l10n.mediaEditorBrightness,
                      look.brightness,
                      -1,
                      (l, v) => l.copyWith(brightness: v),
                      key: const ValueKey('photo-look-brightness'),
                    ),
                    _lookSlider(
                      l10n.mediaEditorContrast,
                      look.contrast,
                      -1,
                      (l, v) => l.copyWith(contrast: v),
                    ),
                    _lookSlider(
                      l10n.mediaEditorSaturation,
                      look.saturation,
                      -1,
                      (l, v) => l.copyWith(saturation: v),
                    ),
                    _lookSlider(
                      l10n.mediaEditorWarmth,
                      look.warmth,
                      -1,
                      (l, v) => l.copyWith(warmth: v),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Vignette d'un filtre : l'image de travail elle-même, filtrée par le GPU
/// (aucun bitmap en plus).
class _FilterThumb extends StatelessWidget {
  const _FilterThumb({
    super.key,
    required this.controller,
    required this.filter,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final EditorController controller;
  final EditorFilter filter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget thumb = RawImage(
      image: controller.image,
      width: 62,
      height: 78,
      fit: BoxFit.cover,
    );
    if (filter != EditorFilter.none) {
      thumb = ColorFiltered(
        colorFilter: ColorFilter.matrix(EditorLookMatrix.preset(filter)),
        child: thumb,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 62,
                height: 78,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: thumb,
              ),
              AppSpacing.vGapXs,
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
