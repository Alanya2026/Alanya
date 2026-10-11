import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/stickers/sticker_image_check.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/stickers/sticker_creation_flows.dart'
    show stickerImageIssueText;
import 'cutout/ml_kit_person_segmenter.dart';
import 'cutout/person_segmenter.dart';
import 'editor_controller.dart';
import 'media_editor_source.dart';
import 'model/editor_document.dart';
import 'render/editor_exporter.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/editor_controls.dart';
import 'widgets/editor_panels.dart';
import 'widgets/editor_sheets.dart';

export 'media_editor_source.dart' show MediaEditorSource;
export 'model/editor_document.dart' show MediaEditorMode;
export 'render/editor_exporter.dart' show MediaEditorResult;

/// Éditeur d'image réutilisable : rogner, crayon (couleur, épaisseur, gomme),
/// texte, emoji, annuler/rétablir.
///
/// ```dart
/// final r = await MediaEditorScreen.open(
///   context,
///   source: MediaEditorSource.bytes(bytes),
///   mode: MediaEditorMode.sticker,
/// );
/// if (r != null) use(r.png); // PNG ; 512×512 transparent pour un sticker
/// ```
///
/// Mode [MediaEditorMode.sticker] : cadre carré 1:1 imposé, export 512×512 avec
/// transparence, contrôlé par `StickerImageCheck` (≤ 1 Mo). Mode
/// [MediaEditorMode.photo] : cadre au format de l'image (ou 1:1, 4:3…), export
/// PNG ≤ 1024 px côté long.
///
/// L'écran se ferme sur un [MediaEditorResult], ou `null` si l'utilisateur
/// abandonne. L'image est décodée à 1024 px au plus ; annuler/rétablir
/// rejouent des commandes (50 au plus), sans copie de bitmap.
class MediaEditorScreen extends StatefulWidget {
  const MediaEditorScreen({
    super.key,
    required this.source,
    this.mode = MediaEditorMode.photo,
    this.pickEmoji = showEditorEmojiPicker,
    this.personSegmenter,
  });

  final MediaEditorSource source;
  final MediaEditorMode mode;

  /// Sélecteur d'emoji (injectable pour les tests).
  final EditorEmojiPicker pickEmoji;

  /// Détourage automatique des personnes (injectable pour les tests). Par
  /// défaut : ML Kit, sur l'appareil (Android et iOS seulement) ; sans
  /// détourage automatique, le pinceau reste disponible.
  final PersonSegmenter? personSegmenter;

  /// Ouvre l'éditeur plein écran ; `null` si l'utilisateur abandonne.
  static Future<MediaEditorResult?> open(
    BuildContext context, {
    required MediaEditorSource source,
    MediaEditorMode mode = MediaEditorMode.photo,
  }) {
    return Navigator.of(context).push<MediaEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaEditorScreen(source: source, mode: mode),
      ),
    );
  }

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  EditorController? _controller;
  MediaEditorLoadIssue? _error;
  bool _busy = false;

  /// Détourage automatique : celui qu'on a injecté, sinon ML Kit (créé ici,
  /// donc fermé ici). Le sticker seul se détoure (une photo reste opaque).
  PersonSegmenter? _segmenter;
  bool _ownsSegmenter = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == MediaEditorMode.sticker) {
      final injected = widget.personSegmenter;
      if (injected != null) {
        _segmenter = injected;
      } else {
        _segmenter = MlKitPersonSegmenter();
        _ownsSegmenter = true;
      }
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readBytes();
      final image = await EditorImageLoader.decode(
        bytes,
        rejectAnimated: widget.mode == MediaEditorMode.sticker,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(
        () => _controller = EditorController(mode: widget.mode, image: image),
      );
    } on MediaEditorLoadException catch (e) {
      if (mounted) setState(() => _error = e.issue);
    } catch (_) {
      if (mounted) setState(() => _error = MediaEditorLoadIssue.unreadable);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_ownsSegmenter) unawaited(_segmenter?.dispose());
    super.dispose();
  }

  String _loadErrorText(AppLocalizations l10n, MediaEditorLoadIssue issue) =>
      switch (issue) {
        MediaEditorLoadIssue.unreadable => l10n.stickerImageFormat,
        MediaEditorLoadIssue.tooBig => l10n.stickerImageInputTooBig,
        MediaEditorLoadIssue.animated => l10n.stickerImageAnimated,
      };

  Future<void> _finish() async {
    final c = _controller;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await MediaEditorExporter.export(
        c.doc,
        c.image,
        widget.mode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on StickerImageRejected catch (e) {
      _fail(stickerImageIssueText(context.l10n, e.issue));
    } catch (_) {
      _fail(context.l10n.stickerImageFormat);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Fermeture : confirmation si des retouches seraient perdues.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    final sticker = widget.mode == MediaEditorMode.sticker;
    return ListenableBuilder(
      listenable: c ?? const _NoListenable(),
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_close());
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const ValueKey('editor-close'),
                tooltip: l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: _busy ? null : _close,
              ),
              title: Text(
                sticker
                    ? l10n.mediaEditorTitleSticker
                    : l10n.mediaEditorTitlePhoto,
              ),
              actions: [
                IconButton(
                  key: const ValueKey('editor-undo'),
                  tooltip: l10n.mediaEditorUndo,
                  icon: const Icon(Icons.undo),
                  onPressed: c != null && c.canUndo && !_busy ? c.undo : null,
                ),
                IconButton(
                  key: const ValueKey('editor-redo'),
                  tooltip: l10n.mediaEditorRedo,
                  icon: const Icon(Icons.redo),
                  onPressed: c != null && c.canRedo && !_busy ? c.redo : null,
                ),
                TextButton(
                  key: const ValueKey('editor-done'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSizes.minTapTarget,
                      AppSizes.minTapTarget,
                    ),
                  ),
                  onPressed: c == null || _busy ? null : _finish,
                  child: Text(l10n.mediaEditorDone),
                ),
                AppSpacing.hGapXs,
              ],
            ),
            body: _body(context, c),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, EditorController? c) {
    final l10n = context.l10n;
    final sticker = widget.mode == MediaEditorMode.sticker;
    final colors = context.colors;
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            _loadErrorText(l10n, error),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Column(
          children: [
            Expanded(child: EditorCanvas(controller: c)),
            EditorOptionsPanel(
              controller: c,
              pickEmoji: widget.pickEmoji,
              segmenter: _segmenter,
            ),
            _ToolBar(controller: c, sticker: sticker),
          ],
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: colors.scrim.withValues(alpha: 0.4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    AppSpacing.vGapMd,
                    Text(
                      l10n.mediaEditorExporting,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.onPrimary,
                      ),
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

/// Barre des outils : rogner, crayon, texte, emoji et, pour un sticker,
/// détourer.
class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.controller, required this.sticker});
  final EditorController controller;
  final bool sticker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tools = [
          (EditorTool.crop, Icons.crop, l10n.mediaEditorToolCrop),
          (EditorTool.draw, Icons.brush_outlined, l10n.mediaEditorToolDraw),
          (EditorTool.text, Icons.text_fields, l10n.mediaEditorToolText),
          (
            EditorTool.sticker,
            Icons.emoji_emotions_outlined,
            l10n.mediaEditorToolEmoji,
          ),
          if (sticker)
            (
              EditorTool.cutout,
              Icons.content_cut,
              l10n.mediaEditorToolCutout,
            ),
        ];
        return Material(
          color: colors.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Semantics(
                container: true,
                label: l10n.mediaEditorTools,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      for (final (tool, icon, label) in tools)
                        Expanded(
                          child: Center(
                            child: EditorToolButton(
                              key: ValueKey('editor-tool-${tool.name}'),
                              icon: icon,
                              label: label,
                              selected: controller.tool == tool,
                              onTap: () => controller.selectTool(tool),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Écouteur inerte tant que l'image n'est pas chargée.
class _NoListenable implements Listenable {
  const _NoListenable();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
