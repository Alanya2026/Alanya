import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../cutout/person_segmenter.dart';
import '../editor_controller.dart';
import '../model/editor_document.dart';
import '../model/editor_geometry.dart';
import '../render/editor_renderer.dart';
import 'editor_controls.dart';
import 'editor_sheets.dart';

/// Réglages de l'outil courant, sous la zone de retouche.
class EditorOptionsPanel extends StatelessWidget {
  const EditorOptionsPanel({
    super.key,
    required this.controller,
    required this.pickEmoji,
    this.segmenter,
  });

  final EditorController controller;
  final EditorEmojiPicker pickEmoji;

  /// Détourage automatique des personnes ; `null` ou non pris en charge :
  /// le bouton est masqué, le pinceau reste là.
  final PersonSegmenter? segmenter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final Widget body;
        switch (controller.tool) {
          case EditorTool.crop:
            body = _CropOptions(controller: controller);
          case EditorTool.draw:
            body = _DrawOptions(controller: controller);
          case EditorTool.text:
            body = _TextOptions(controller: controller);
          case EditorTool.sticker:
            body = _EmojiOptions(controller: controller, pickEmoji: pickEmoji);
          case EditorTool.cutout:
            body = _CutoutOptions(controller: controller, segmenter: segmenter);
          case EditorTool.look:
            // Les filtres n'existent que dans la retouche avant envoi.
            body = const SizedBox.shrink();
        }
        // Hauteur **constante** : sélectionner un élément (qui fait apparaître
        // ses curseurs) ne doit pas redimensionner la zone de retouche, sinon
        // l'image bouge sous le doigt.
        return SizedBox(
          // Le détourage a plus de réglages (texte d'aide, trois pastilles,
          // pinceaux et taille) : panneau plus haut, toujours constant.
          height: controller.tool == EditorTool.cutout
              ? (MediaQuery.sizeOf(context).height * 0.34).clamp(
                  230.0,
                  290.0,
                )
              : (MediaQuery.sizeOf(context).height * 0.27).clamp(
                  150.0,
                  220.0,
                ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: body,
          ),
        );
      },
    );
  }
}

class _CropOptions extends StatelessWidget {
  const _CropOptions({required this.controller});
  final EditorController controller;

  static String _aspectLabel(EditorAspect a, String original) => switch (a) {
    EditorAspect.original => original,
    EditorAspect.square => '1:1',
    EditorAspect.r4x3 => '4:3',
    EditorAspect.r3x4 => '3:4',
    EditorAspect.r16x9 => '16:9',
    EditorAspect.r9x16 => '9:16',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sticker = controller.mode == MediaEditorMode.sticker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sticker
              ? l10n.mediaEditorCropHintSticker
              : controller.roundFrame
              ? l10n.mediaEditorCropHintRound
              : l10n.mediaEditorCropHintPhoto,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        AppSpacing.vGapXs,
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ActionChip(
              key: const ValueKey('editor-fit-contain'),
              avatar: const Icon(Icons.fit_screen_outlined, size: 18),
              label: Text(l10n.mediaEditorFitContain),
              onPressed: () => controller.fitImage(cover: false),
            ),
            ActionChip(
              key: const ValueKey('editor-fit-cover'),
              avatar: const Icon(Icons.crop_free, size: 18),
              label: Text(l10n.mediaEditorFitCover),
              onPressed: () => controller.fitImage(cover: true),
            ),
          ],
        ),
        // Cadre imposé (photo de profil) : pas de choix de format.
        if (!sticker && controller.fixedAspect == null) ...[
          AppSpacing.vGapXs,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final a in EditorAspect.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: ActionChip(
                      key: ValueKey('editor-aspect-${a.name}'),
                      label: Text(
                        _aspectLabel(a, l10n.mediaEditorAspectOriginal),
                      ),
                      onPressed: () => controller.setAspect(a),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DrawOptions extends StatelessWidget {
  const _DrawOptions({required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            EditorToolButton(
              key: const ValueKey('editor-pen'),
              icon: Icons.edit_outlined,
              label: l10n.mediaEditorPen,
              selected: !controller.erasing,
              onTap: () => controller.setErasing(false),
            ),
            AppSpacing.hGapSm,
            EditorToolButton(
              key: const ValueKey('editor-eraser'),
              icon: Icons.auto_fix_normal_outlined,
              label: l10n.mediaEditorEraser,
              selected: controller.erasing,
              onTap: () => controller.setErasing(true),
            ),
            AppSpacing.hGapLg,
            Expanded(
              child: IgnorePointer(
                ignoring: controller.erasing,
                child: Opacity(
                  opacity: controller.erasing ? 0.4 : 1,
                  child: EditorColorPalette(
                    selected: controller.penColor,
                    onSelected: controller.setPenColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        EditorSlider(
          label: l10n.mediaEditorThickness,
          value: controller.penWidth,
          min: 2,
          max: 48,
          onChangeStart: () {},
          onChanged: controller.setPenWidth,
          onChangeEnd: () {},
        ),
      ],
    );
  }
}

/// Outil « Détourer » : détourage automatique des personnes (si le téléphone
/// le permet), pinceau « garder », gomme « effacer », taille, bords doux,
/// réinitialisation. Le pinceau est **toujours** là : c'est lui qui détoure
/// tout ce qui n'est pas une personne.
class _CutoutOptions extends StatelessWidget {
  const _CutoutOptions({required this.controller, required this.segmenter});
  final EditorController controller;
  final PersonSegmenter? segmenter;

  Future<void> _auto(BuildContext context) async {
    final seg = segmenter;
    if (seg == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final outcome = await controller.autoCutout(seg);
    final message = switch (outcome) {
      AutoCutoutOutcome.noPerson => l10n.mediaEditorCutoutNoPerson,
      AutoCutoutOutcome.failed => l10n.mediaEditorCutoutFailed,
      _ => null,
    };
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = controller.cutoutBusy;
    final auto = segmenter?.isSupported ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mediaEditorCutoutHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        AppSpacing.vGapXs,
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (auto)
              ActionChip(
                key: const ValueKey('editor-cutout-auto'),
                avatar: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_outline, size: 18),
                label: Text(
                  busy
                      ? l10n.mediaEditorCutoutBusy
                      : l10n.mediaEditorCutoutAuto,
                ),
                onPressed: busy ? null : () => _auto(context),
              ),
            FilterChip(
              key: const ValueKey('editor-cutout-soft'),
              label: Text(l10n.mediaEditorCutoutSoft),
              selected: controller.cutoutSoftEdges,
              onSelected: controller.setCutoutSoftEdges,
            ),
            ActionChip(
              key: const ValueKey('editor-cutout-reset'),
              avatar: const Icon(Icons.restart_alt, size: 18),
              label: Text(l10n.mediaEditorCutoutReset),
              onPressed: busy || !controller.hasCutout
                  ? null
                  : controller.resetCutout,
            ),
          ],
        ),
        Row(
          children: [
            EditorToolButton(
              key: const ValueKey('editor-cutout-keep'),
              icon: Icons.brush_outlined,
              label: l10n.mediaEditorCutoutKeep,
              selected: controller.cutoutBrush == CutoutBrush.keep,
              onTap: () => controller.setCutoutBrush(CutoutBrush.keep),
            ),
            AppSpacing.hGapSm,
            EditorToolButton(
              key: const ValueKey('editor-cutout-erase'),
              icon: Icons.auto_fix_normal_outlined,
              label: l10n.mediaEditorCutoutErase,
              selected: controller.cutoutBrush == CutoutBrush.erase,
              onTap: () => controller.setCutoutBrush(CutoutBrush.erase),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: EditorSlider(
                label: l10n.mediaEditorCutoutSize,
                value: controller.cutoutBrushSize,
                min: EditorController.minCutoutBrush,
                max: EditorController.maxCutoutBrush,
                onChangeStart: () {},
                onChanged: controller.setCutoutBrushSize,
                onChangeEnd: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextOptions extends StatelessWidget {
  const _TextOptions({required this.controller});
  final EditorController controller;

  Future<void> _add(BuildContext context) async {
    final r = await showEditorTextSheet(
      context,
      defaultColor: controller.penColor,
    );
    if (r == null) return;
    controller.addText(r.text, r.font, r.color);
    await EditorFonts.ensureLoaded([r.font]);
    controller.refresh();
  }

  Future<void> _edit(BuildContext context, EditorTextItem item) async {
    final r = await showEditorTextSheet(
      context,
      initial: item,
      defaultColor: item.color,
    );
    if (r == null) return;
    controller.editText(item.id, text: r.text, font: r.font, color: r.color);
    await EditorFonts.ensureLoaded([r.font]);
    controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sel = controller.selectedItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              key: const ValueKey('editor-add-text'),
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.mediaEditorAddText),
              onPressed: () => _add(context),
            ),
            if (sel is EditorTextItem)
              ActionChip(
                key: const ValueKey('editor-edit-text'),
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.mediaEditorEditText),
                onPressed: () => _edit(context, sel),
              ),
            if (sel != null)
              EditorDeleteButton(controller: controller, item: sel),
          ],
        ),
        if (sel != null) EditorItemControls(controller: controller, item: sel),
      ],
    );
  }
}

class _EmojiOptions extends StatelessWidget {
  const _EmojiOptions({required this.controller, required this.pickEmoji});
  final EditorController controller;
  final EditorEmojiPicker pickEmoji;

  Future<void> _add(BuildContext context) async {
    final e = await pickEmoji(context);
    if (e == null || e.isEmpty) return;
    controller.addEmoji(e);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sel = controller.selectedItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              key: const ValueKey('editor-add-emoji'),
              avatar: const Icon(Icons.add_reaction_outlined, size: 18),
              label: Text(l10n.mediaEditorAddEmoji),
              onPressed: () => _add(context),
            ),
            if (sel != null)
              EditorDeleteButton(controller: controller, item: sel),
          ],
        ),
        if (sel != null) EditorItemControls(controller: controller, item: sel),
      ],
    );
  }
}

/// Taille, rotation et suppression de l'élément sélectionné : l'alternative
/// aux gestes (pincement) pour qui ne peut pas les faire.
class EditorItemControls extends StatelessWidget {
  const EditorItemControls({
    super.key,
    required this.controller,
    required this.item,
  });

  final EditorController controller;
  final EditorItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = item.placement;
    return Column(
      children: [
        EditorSlider(
          label: l10n.mediaEditorSize,
          value: p.scale,
          min: 0.3,
          max: 4,
          onChangeStart: () => controller.beginItemGesture(item.id),
          onChanged: (v) => controller.updateItemPlacement(
            p.copyWith(scale: v.clamp(EditorPlacement.minScale, 8)),
          ),
          onChangeEnd: controller.endItemGesture,
        ),
        EditorSlider(
          label: l10n.mediaEditorRotation,
          value: p.rotation,
          min: -math.pi,
          max: math.pi,
          onChangeStart: () => controller.beginItemGesture(item.id),
          onChanged: (v) =>
              controller.updateItemPlacement(p.copyWith(rotation: v)),
          onChangeEnd: controller.endItemGesture,
        ),
      ],
    );
  }
}

/// Supprime l'élément sélectionné (annulable).
class EditorDeleteButton extends StatelessWidget {
  const EditorDeleteButton({
    super.key,
    required this.controller,
    required this.item,
  });

  final EditorController controller;
  final EditorItem item;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('editor-delete-item'),
      tooltip: context.l10n.mediaEditorDeleteItem,
      icon: Icon(Icons.delete_outline, color: context.colors.error),
      onPressed: () => controller.removeItem(item.id),
    );
  }
}
