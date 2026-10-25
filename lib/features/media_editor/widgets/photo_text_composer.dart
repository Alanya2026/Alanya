import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../model/editor_document.dart';
import '../model/editor_geometry.dart';
import '../render/editor_renderer.dart';
import 'editor_controls.dart';
import 'editor_sheets.dart';

/// Saisie d'un texte **par-dessus l'image** (voile sombre, aperçu en direct) :
/// police, couleur, alignement et fond. `null` si l'on annule ou si le texte
/// est vide.
Future<EditorTextEdit?> showPhotoTextComposer(
  BuildContext context, {
  EditorTextItem? initial,
  required Color defaultColor,
}) {
  return Navigator.of(context).push<EditorTextEdit>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.black.withValues(alpha: 0.6),
      pageBuilder: (_, _, _) =>
          _PhotoTextComposer(initial: initial, defaultColor: defaultColor),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

class _PhotoTextComposer extends StatefulWidget {
  const _PhotoTextComposer({this.initial, required this.defaultColor});
  final EditorTextItem? initial;
  final Color defaultColor;

  @override
  State<_PhotoTextComposer> createState() => _PhotoTextComposerState();
}

class _PhotoTextComposerState extends State<_PhotoTextComposer> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.text ?? '',
  );
  late EditorFont _font = widget.initial?.font ?? EditorFont.standard;
  late Color _color = widget.initial?.color ?? widget.defaultColor;
  late EditorTextAlign _align = widget.initial?.align ?? EditorTextAlign.center;
  late EditorTextBackground _background =
      widget.initial?.background ?? EditorTextBackground.none;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _text.text.trim();
    if (t.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      EditorTextEdit(
        text: t,
        font: _font,
        color: _color,
        align: _align,
        background: _background,
      ),
    );
  }

  TextAlign get _textAlign => switch (_align) {
    EditorTextAlign.left => TextAlign.left,
    EditorTextAlign.center => TextAlign.center,
    EditorTextAlign.right => TextAlign.right,
  };

  IconData get _alignIcon => switch (_align) {
    EditorTextAlign.left => Icons.format_align_left,
    EditorTextAlign.center => Icons.format_align_center,
    EditorTextAlign.right => Icons.format_align_right,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    // Même règle que le rendu exporté : sur fond plein, lettres lisibles.
    final preview = EditorTextItem(
      id: 0,
      placement: const EditorPlacement(center: Offset.zero),
      text: '',
      color: _color,
      background: _background,
    );
    final letters = EditorItemMetrics.textColorOf(preview);
    final style = EditorFonts.style(_font, letters, 32);
    final fonts = {
      EditorFont.standard: l10n.mediaEditorFontStandard,
      EditorFont.bold: l10n.mediaEditorFontBold,
      EditorFont.handwriting: l10n.mediaEditorFontHandwriting,
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('photo-text-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('photo-text-align'),
                    tooltip: l10n.mediaEditorAlign,
                    icon: Icon(_alignIcon),
                    onPressed: () => setState(
                      () => _align = EditorTextAlign.values[
                          (_align.index + 1) % EditorTextAlign.values.length],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('photo-text-background'),
                    tooltip: l10n.mediaEditorTextBackground,
                    isSelected: _background != EditorTextBackground.none,
                    icon: Icon(switch (_background) {
                      EditorTextBackground.none => Icons.text_fields,
                      EditorTextBackground.solid => Icons.format_color_fill,
                      EditorTextBackground.translucent => Icons.opacity,
                    }),
                    onPressed: () => setState(
                      () => _background = EditorTextBackground.values[
                          (_background.index + 1) %
                              EditorTextBackground.values.length],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('photo-text-done'),
                    // Le thème étire les boutons pleins sur toute la largeur.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, AppSizes.minTapTarget),
                    ),
                    onPressed: _submit,
                    child: Text(l10n.commonOk),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: IntrinsicWidth(
                    child: Container(
                      padding: _background == EditorTextBackground.none
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                      decoration: BoxDecoration(
                        color: switch (_background) {
                          EditorTextBackground.none => null,
                          EditorTextBackground.solid => _color,
                          EditorTextBackground.translucent =>
                            AppColors.black.withValues(alpha: 0.55),
                        },
                        borderRadius: AppRadius.brMd,
                      ),
                      child: TextField(
                        key: const ValueKey('photo-text-field'),
                        controller: _text,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 120,
                        textAlign: _textAlign,
                        style: style,
                        cursorColor: letters,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: l10n.mediaEditorTextHint,
                          hintStyle: style.copyWith(
                            color: letters.withValues(alpha: 0.5),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  for (final e in fonts.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: ChoiceChip(
                        key: ValueKey('photo-text-font-${e.key.name}'),
                        label: Text(
                          e.value,
                          style: EditorFonts.style(
                            e.key,
                            colors.onSurface,
                            14,
                          ),
                        ),
                        selected: _font == e.key,
                        onSelected: (_) => setState(() => _font = e.key),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: EditorColorPalette(
                selected: _color,
                onSelected: (c) => setState(() => _color = c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
