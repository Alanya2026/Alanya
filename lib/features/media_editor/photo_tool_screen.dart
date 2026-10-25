import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'editor_controller.dart';
import 'media_editor_source.dart';
import 'model/editor_document.dart';
import 'render/editor_exporter.dart';
import 'render/editor_renderer.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/editor_sheets.dart';
import 'widgets/photo_text_composer.dart';
import 'widgets/photo_tool_panels.dart';

/// Retouche d'une photo avant envoi, **un outil à la fois** : on ouvre l'outil
/// touché sur l'écran d'envoi (rogner, crayon, texte, emoji, filtres), on
/// valide par « OK » et on revient à l'envoi. Thème sombre, comme l'écran
/// d'envoi.
///
/// [initialDoc] reprend la retouche précédente de la même photo : ses textes
/// et ses traits restent modifiables. L'écran se ferme sur un
/// [MediaEditorResult] (PNG + document), ou `null` si rien n'a changé ou si
/// l'on abandonne.
class PhotoToolScreen extends StatefulWidget {
  const PhotoToolScreen({
    super.key,
    required this.source,
    required this.tool,
    this.initialDoc,
    this.forVideo = false,
    this.pickEmoji = showEditorEmojiPicker,
  });

  final MediaEditorSource source;
  final EditorTool tool;
  final EditorDoc? initialDoc;

  /// Calques d'une vidéo, posés sur une de ses images : pas de flou de zone
  /// (il ne suivrait pas le mouvement).
  final bool forVideo;

  /// Sélecteur d'emoji (injectable pour les tests).
  final EditorEmojiPicker pickEmoji;

  static Future<MediaEditorResult?> open(
    BuildContext context, {
    required MediaEditorSource source,
    required EditorTool tool,
    EditorDoc? initialDoc,
    bool forVideo = false,
  }) {
    return Navigator.of(context).push<MediaEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoToolScreen(
          source: source,
          tool: tool,
          initialDoc: initialDoc,
          forVideo: forVideo,
        ),
      ),
    );
  }

  @override
  State<PhotoToolScreen> createState() => _PhotoToolScreenState();
}

class _PhotoToolScreenState extends State<PhotoToolScreen> {
  EditorController? _controller;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readBytes();
      final image = await EditorImageLoader.decode(
        bytes,
        bound: EditorImageLoader.photoWorkBound,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      final c = EditorController(
        mode: MediaEditorMode.photo,
        image: image,
        initialDoc: widget.initialDoc,
        initialTool: widget.tool,
      );
      c.penColor = AppColors.white;
      setState(() => _controller = c);
      // Texte et emoji : on commence directement par la saisie.
      if (widget.tool == EditorTool.text) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _addText(true));
      } else if (widget.tool == EditorTool.sticker) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _addEmoji(true));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// [first] : saisie ouverte d'office ; l'annuler sans rien avoir fait
  /// referme l'outil.
  Future<void> _addText(bool first) async {
    final c = _controller;
    if (c == null) return;
    final r = await showPhotoTextComposer(context, defaultColor: c.penColor);
    if (!mounted) return;
    if (r == null) {
      if (first && !c.hasChanges) Navigator.of(context).pop();
      return;
    }
    c.addText(
      r.text,
      r.font,
      r.color,
      align: r.align,
      background: r.background,
    );
    await EditorFonts.ensureLoaded([r.font]);
    c.refresh();
  }

  Future<void> _editText(EditorTextItem item) async {
    final c = _controller;
    if (c == null) return;
    final r = await showPhotoTextComposer(
      context,
      initial: item,
      defaultColor: item.color,
    );
    if (r == null || !mounted) return;
    c.editText(
      item.id,
      text: r.text,
      font: r.font,
      color: r.color,
      align: r.align,
      background: r.background,
    );
    await EditorFonts.ensureLoaded([r.font]);
    c.refresh();
  }

  Future<void> _addEmoji(bool first) async {
    final c = _controller;
    if (c == null) return;
    final e = await widget.pickEmoji(context);
    if (!mounted) return;
    if (e == null || e.isEmpty) {
      if (first && !c.hasChanges) Navigator.of(context).pop();
      return;
    }
    c.addEmoji(e);
  }

  Future<void> _finish() async {
    final c = _controller;
    if (c == null || _busy) return;
    if (!c.hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await MediaEditorExporter.export(
        c.doc,
        c.image,
        MediaEditorMode.photo,
      );
      if (mounted) Navigator.of(context).pop(r);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.mediaEditorEditFailed)),
      );
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    final c = _controller;
    if (c == null || !c.hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mediaEditorDiscardTitle),
        content: Text(l10n.mediaEditorDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.mediaEditorKeepEditing),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.error,
              foregroundColor: ctx.colors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.mediaEditorDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.tool) {
      EditorTool.crop => l10n.mediaEditorToolCrop,
      EditorTool.draw => l10n.mediaEditorToolDraw,
      EditorTool.text => l10n.mediaEditorToolText,
      EditorTool.sticker => l10n.mediaEditorToolEmoji,
      EditorTool.look => l10n.mediaEditorToolFilters,
      EditorTool.cutout => l10n.mediaEditorToolCutout,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) {
          final c = _controller;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_close());
            },
            child: Scaffold(
              backgroundColor: AppColors.immersiveBackground,
              body: SafeArea(
                child: c == null
                    ? _placeholder(context)
                    : ListenableBuilder(
                        listenable: c,
                        builder: (context, _) => _body(context, c),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: Center(
            child: _failed
                ? Text(
                    l10n.stickerImageFormat,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, EditorController c) {
    final l10n = context.l10n;
    final leading = widget.tool == EditorTool.draw
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('photo-undo'),
                tooltip: l10n.mediaEditorUndo,
                icon: const Icon(Icons.undo),
                onPressed: c.canUndo && !_busy ? c.undo : null,
              ),
              IconButton(
                key: const ValueKey('photo-redo'),
                tooltip: l10n.mediaEditorRedo,
                icon: const Icon(Icons.redo),
                onPressed: c.canRedo && !_busy ? c.redo : null,
              ),
            ],
          )
        : TextButton(
            key: const ValueKey('photo-cancel'),
            onPressed: _busy ? null : _close,
            child: Text(l10n.commonCancel),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          leading,
          Expanded(
            child: Text(
              _title(context),
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
          ),
          FilledButton(
            key: const ValueKey('photo-done'),
            // Le thème étire les boutons pleins sur toute la largeur.
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, AppSizes.minTapTarget),
            ),
            onPressed: _busy ? null : _finish,
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, EditorController c) {
    final l10n = context.l10n;
    return switch (widget.tool) {
      EditorTool.crop => PhotoCropPanel(controller: c),
      EditorTool.draw => PhotoDrawPanel(controller: c, allowBlur: !widget.forVideo),
      EditorTool.look => PhotoLookPanel(controller: c),
      EditorTool.text => PhotoItemPanel(
        controller: c,
        addLabel: l10n.mediaEditorAddText,
        addIcon: Icons.add,
        onAdd: () => _addText(false),
        onEdit: _editText,
      ),
      EditorTool.sticker || EditorTool.cutout => PhotoItemPanel(
        controller: c,
        addLabel: l10n.mediaEditorAddEmoji,
        addIcon: Icons.add_reaction_outlined,
        onAdd: () => _addEmoji(false),
      ),
    };
  }

  Widget _body(BuildContext context, EditorController c) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Stack(
      children: [
        Column(
          children: [
            _topBar(context, c),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: EditorCanvas(
                      controller: c,
                      background: AppColors.immersiveBackground,
                    ),
                  ),
                  if (widget.tool == EditorTool.draw)
                    PositionedDirectional(
                      end: AppSpacing.xs,
                      top: AppSpacing.lg,
                      child: PhotoBrushSizeSlider(controller: c),
                    ),
                  if (widget.tool == EditorTool.look)
                    PositionedDirectional(
                      end: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: _CompareButton(controller: c),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.md,
              ),
              child: _panel(context, c),
            ),
          ],
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: colors.scrim.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    AppSpacing.vGapMd,
                    Text(
                      l10n.mediaEditorExporting,
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Maintenir : l'image sans filtre ni réglage ; relâcher : retour à la
/// retouche. Rien n'est enregistré dans l'historique.
class _CompareButton extends StatefulWidget {
  const _CompareButton({required this.controller});
  final EditorController controller;

  @override
  State<_CompareButton> createState() => _CompareButtonState();
}

class _CompareButtonState extends State<_CompareButton> {
  EditorLook? _kept;

  void _press() {
    final c = widget.controller;
    if (_kept != null || c.doc.look.isNeutral) return;
    _kept = c.doc.look;
    c.beginLook();
    c.updateLook(EditorLook.neutral);
  }

  void _release() {
    final k = _kept;
    if (k == null) return;
    _kept = null;
    widget.controller.updateLook(k);
    widget.controller.endLook();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: context.l10n.mediaEditorCompare,
      child: GestureDetector(
        key: const ValueKey('photo-compare'),
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: Container(
          height: AppSizes.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppSizes.minTapTarget / 2),
          ),
          child: const Icon(Icons.compare_outlined),
        ),
      ),
    );
  }
}
