import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common/app_bottom_sheet.dart';
import '../model/editor_document.dart';
import 'editor_controls.dart';

/// Choisit un emoji. Injectable pour les tests (le sélecteur charge ses
/// données d'emoji au démarrage).
typedef EditorEmojiPicker = Future<String?> Function(BuildContext context);

Future<String?> showEditorEmojiPicker(BuildContext context) {
  return showAppBottomSheet<String>(
    context: context,
    builder: (ctx) => AppBottomSheet(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SizedBox(
        height: 320,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) =>
              Navigator.of(ctx).pop(emoji.emoji),
          config: const Config(height: 320),
        ),
      ),
    ),
  );
}

/// Ce que la feuille de texte renvoie.
class EditorTextEdit {
  const EditorTextEdit({
    required this.text,
    required this.font,
    required this.color,
  });
  final String text;
  final EditorFont font;
  final Color color;
}

/// Saisie d'un texte : contenu, police du projet, couleur. `null` si fermée.
Future<EditorTextEdit?> showEditorTextSheet(
  BuildContext context, {
  EditorTextItem? initial,
  required Color defaultColor,
}) {
  return showAppBottomSheet<EditorTextEdit>(
    context: context,
    builder: (ctx) => AppBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _TextSheet(initial: initial, defaultColor: defaultColor),
      ),
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({this.initial, required this.defaultColor});
  final EditorTextItem? initial;
  final Color defaultColor;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.text ?? '',
  );
  late EditorFont _font = widget.initial?.font ?? EditorFont.standard;
  late Color _color = widget.initial?.color ?? widget.defaultColor;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    Navigator.of(
      context,
    ).pop(EditorTextEdit(text: t, font: _font, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fonts = {
      EditorFont.standard: l10n.mediaEditorFontStandard,
      EditorFont.bold: l10n.mediaEditorFontBold,
      EditorFont.handwriting: l10n.mediaEditorFontHandwriting,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('editor-text-field'),
          controller: _text,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          maxLength: 120,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(hintText: l10n.mediaEditorTextHint),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final e in fonts.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _font == e.key,
                onSelected: (_) => setState(() => _font = e.key),
              ),
          ],
        ),
        AppSpacing.vGapSm,
        EditorColorPalette(
          selected: _color,
          onSelected: (c) => setState(() => _color = c),
        ),
        AppSpacing.vGapSm,
        FilledButton(
          onPressed: _text.text.trim().isEmpty ? null : _submit,
          child: Text(
            widget.initial == null
                ? l10n.mediaEditorAddText
                : l10n.mediaEditorEditText,
          ),
        ),
      ],
    );
  }
}
