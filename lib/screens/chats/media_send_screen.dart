import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/photo_edit_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_album.dart';
import '../../features/media_editor/editor_controller.dart' show EditorTool;

/// Résultat de l'écran de composition média : légende optionnelle, fichiers
/// à envoyer (les photos retouchées y ont remplacé leur original ; l'album a
/// pu perdre ou gagner des médias) et vue unique.
class MediaSendResult {
  const MediaSendResult({this.caption, this.items, this.viewOnce = false});

  final String? caption;

  /// `null` : aucun changement par rapport aux éléments passés à l'écran.
  final List<AlbumSendItem>? items;

  /// Envoi en vue unique (un seul média, discussion à deux).
  final bool viewOnce;
}

/// Ajoute des médias à l'album depuis l'écran d'envoi (même sélecteur que
/// celui d'origine) ; liste vide si l'on n'a rien choisi.
typedef MediaAddMore = Future<List<AlbumSendItem>> Function();

/// Écran d'envoi d'une photo / vidéo (ou d'un album), en plein écran sombre :
/// les outils de retouche sont **sur l'écran** (rogner, emoji, texte, crayon,
/// filtres ; un outil s'ouvre, on valide, on revient ici), les miniatures de
/// l'album permettent de passer d'un média à l'autre, d'en retirer ou d'en
/// ajouter, et la légende porte le choix « vue unique ».
///
/// Chaque retouche repart de l'**original** avec le document précédent : on
/// peut rouvrir un texte pour le corriger, et annuler la dernière retouche.
/// L'original n'est jamais modifié ni supprimé ; envoyer sans retoucher ne
/// change rien.
class MediaSendScreen extends StatefulWidget {
  const MediaSendScreen({
    super.key,
    required this.items,
    this.isViewOnce = false,
    this.allowViewOnce = false,
    this.recipientName,
    this.onAddMore,
    this.maxItems,
    this.retouch = retouchPhotoWithFeedback,
  });

  final List<AlbumSendItem> items;

  /// Vue unique au départ.
  final bool isViewOnce;

  /// Le choix « vue unique » est proposé (discussion à deux, un seul média).
  final bool allowViewOnce;

  /// Nom du destinataire, rappelé sous la légende.
  final String? recipientName;

  /// `null` : pas de bouton « ajouter ».
  final MediaAddMore? onAddMore;

  /// Taille maximale de l'album (bouton « ajouter » masqué au-delà).
  final int? maxItems;

  /// Retouche d'une photo (injectable pour les tests).
  final PhotoRetoucher retouch;

  @override
  State<MediaSendScreen> createState() => _MediaSendScreenState();
}

/// Un média de l'album et ses retouches successives (la dernière est celle
/// qu'on voit et qu'on enverra).
class _Slot {
  _Slot(this.original);
  final AlbumSendItem original;
  final List<PhotoRetouch> retouches = [];

  bool get isPhoto => original.type == 1;

  AlbumSendItem get current {
    if (retouches.isEmpty) return original;
    return AlbumSendItem(
      file: retouches.last.file,
      type: original.type,
      mediaName: original.mediaName,
      duration: original.duration,
    );
  }
}

class _MediaSendScreenState extends State<MediaSendScreen> {
  final _captionCtrl = TextEditingController();
  final _pageCtrl = PageController();
  late final List<_Slot> _slots = [for (final i in widget.items) _Slot(i)];
  late bool _viewOnce = widget.isViewOnce;
  int _page = 0;
  bool _isSending = false;
  bool _editing = false;
  bool _albumChanged = false;

  _Slot get _currentSlot => _slots[_page.clamp(0, _slots.length - 1)];

  @override
  void dispose() {
    _captionCtrl.dispose();
    _pageCtrl.dispose();
    // Fermé sans envoyer : aucune retouche ne sert plus.
    if (!_isSending) {
      for (final s in _slots) {
        for (final r in s.retouches) {
          unawaited(PhotoEditService.discard(r.file));
        }
      }
    }
    super.dispose();
  }

  bool get _canViewOnce => widget.allowViewOnce && _slots.length == 1;

  void _send() {
    if (_isSending || _editing) return;
    _isSending = true;
    // Seule la dernière retouche de chaque photo part : les étapes
    // intermédiaires n'ont plus d'utilité.
    var changed = _albumChanged;
    for (final s in _slots) {
      if (s.retouches.isEmpty) continue;
      changed = true;
      for (final r in s.retouches.sublist(0, s.retouches.length - 1)) {
        unawaited(PhotoEditService.discard(r.file));
      }
    }
    final caption = _captionCtrl.text.trim();
    Navigator.pop(
      context,
      MediaSendResult(
        caption: caption.isEmpty ? null : caption,
        items: changed
            ? List.unmodifiable([for (final s in _slots) s.current])
            : null,
        viewOnce: _canViewOnce && _viewOnce,
      ),
    );
  }

  Future<void> _openTool(EditorTool tool) async {
    if (_editing || _isSending) return;
    final slot = _currentSlot;
    if (!slot.isPhoto) return;
    setState(() => _editing = true);
    PhotoRetouch? r;
    try {
      r = await widget.retouch(
        context,
        slot.original.file,
        tool,
        slot.retouches.isEmpty ? null : slot.retouches.last.doc,
      );
    } finally {
      if (mounted) setState(() => _editing = false);
    }
    if (r == null) return;
    if (!mounted || _isSending) {
      // Écran fermé pendant la retouche : rien à envoyer.
      await PhotoEditService.discard(r.file);
      return;
    }
    setState(() => slot.retouches.add(r!));
  }

  void _undoRetouch() {
    final slot = _currentSlot;
    if (slot.retouches.isEmpty || _editing) return;
    HapticFeedback.lightImpact();
    final r = slot.retouches.removeLast();
    setState(() {});
    unawaited(PhotoEditService.discard(r.file));
  }

  void _goTo(int index) {
    if (index == _page) return;
    setState(() => _page = index);
    _pageCtrl.jumpToPage(index);
  }

  void _removeCurrent() {
    if (_slots.length < 2 || _editing) return;
    final index = _page;
    final slot = _slots[index];
    setState(() {
      _slots.removeAt(index);
      _albumChanged = true;
      _page = index.clamp(0, _slots.length - 1);
    });
    for (final r in slot.retouches) {
      unawaited(PhotoEditService.discard(r.file));
    }
    _pageCtrl.jumpToPage(_page);
  }

  Future<void> _addMore() async {
    final add = widget.onAddMore;
    if (add == null || _editing || _isSending) return;
    final picked = await add();
    if (!mounted || picked.isEmpty) return;
    final room = (widget.maxItems ?? 1 << 30) - _slots.length;
    final kept = picked.take(room.clamp(0, picked.length)).toList();
    if (kept.isEmpty) return;
    final first = _slots.length;
    setState(() {
      _slots.addAll(kept.map(_Slot.new));
      _albumChanged = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final slot = _currentSlot;
    final showStrip =
        _slots.length > 1 ||
        (widget.onAddMore != null &&
            _slots.length < (widget.maxItems ?? 1 << 30));

    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.immersiveBackground,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  photo: slot.isPhoto,
                  enabled: !_editing && !_isSending,
                  onClose: () => Navigator.pop(context),
                  onTool: _openTool,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pageCtrl,
                          itemCount: _slots.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) {
                            final item = _slots[i].current;
                            if (item.type == 2) {
                              return _LocalVideoPreview(
                                key: ValueKey(item.file.path),
                                file: item.file,
                              );
                            }
                            return InteractiveViewer(
                              key: ValueKey(item.file.path),
                              minScale: 1,
                              maxScale: 4,
                              child: Center(
                                child: Image.file(
                                  item.file,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (slot.retouches.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: AppSpacing.sm,
                          child: Center(
                            child: _UndoPill(
                              count: slot.retouches.length,
                              onUndo: _editing ? null : _undoRetouch,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showStrip) ...[
                          _ThumbStrip(
                            slots: _slots,
                            page: _page,
                            canAdd:
                                widget.onAddMore != null &&
                                _slots.length <
                                    (widget.maxItems ?? 1 << 30),
                            enabled: !_editing && !_isSending,
                            onSelect: _goTo,
                            onAdd: _addMore,
                            onRemove: _slots.length > 1 ? _removeCurrent : null,
                          ),
                          AppSpacing.vGapSm,
                        ],
                        _CaptionRow(
                          controller: _captionCtrl,
                          viewOnce: _viewOnce,
                          canViewOnce: _canViewOnce,
                          onViewOnce: () =>
                              setState(() => _viewOnce = !_viewOnce),
                          sending: _isSending,
                          onSend: _send,
                        ),
                        if (widget.recipientName != null) ...[
                          AppSpacing.vGapSm,
                          _Recipient(name: widget.recipientName!),
                        ],
                      ],
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

/// Fermer, et pour une photo les outils de retouche.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.photo,
    required this.enabled,
    required this.onClose,
    required this.onTool,
  });

  final bool photo;
  final bool enabled;
  final VoidCallback onClose;
  final ValueChanged<EditorTool> onTool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tools = [
      (EditorTool.crop, Icons.crop_rotate, l10n.mediaEditorToolCrop),
      (
        EditorTool.sticker,
        Icons.emoji_emotions_outlined,
        l10n.mediaEditorToolEmoji,
      ),
      (EditorTool.text, Icons.text_fields, l10n.mediaEditorToolText),
      (EditorTool.draw, Icons.edit_outlined, l10n.mediaEditorToolDraw),
      (EditorTool.look, Icons.tune, l10n.mediaEditorToolFilters),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('media-send-close'),
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: l10n.commonCancel,
          ),
          const Spacer(),
          if (photo)
            Semantics(
              container: true,
              label: l10n.mediaEditorTools,
              child: Row(
                children: [
                  for (final (tool, icon, label) in tools)
                    IconButton(
                      key: ValueKey('media-send-tool-${tool.name}'),
                      tooltip: label,
                      icon: Icon(icon),
                      onPressed: enabled ? () => onTool(tool) : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// « ↶ N retouches » : annule la dernière retouche de la photo affichée.
class _UndoPill extends StatelessWidget {
  const _UndoPill({required this.count, required this.onUndo});
  final int count;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.black.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey('media-send-undo'),
        customBorder: const StadiumBorder(),
        onTap: onUndo,
        child: Semantics(
          button: true,
          label: l10n.mediaSendUndoEdit,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.undo, size: 18),
                    AppSpacing.hGapSm,
                    Text(
                      l10n.mediaSendEdits(count),
                      style: context.text.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatures de l'album : choisir le média affiché, en ajouter, retirer
/// celui qu'on regarde.
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.slots,
    required this.page,
    required this.canAdd,
    required this.enabled,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_Slot> slots;
  final int page;
  final bool canAdd;
  final bool enabled;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  static const double _side = 52;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final remove = onRemove;
    return SizedBox(
      height: _side,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < slots.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: _Thumb(
                      key: ValueKey('media-send-thumb-$i'),
                      slot: slots[i],
                      label: l10n.mediaSendItemLabel(
                        slots[i].isPhoto ? l10n.photo2 : l10n.video2,
                        i + 1,
                        slots.length,
                      ),
                      selected: i == page,
                      onTap: enabled ? () => onSelect(i) : null,
                    ),
                  ),
                if (canAdd)
                  Semantics(
                    button: true,
                    label: l10n.mediaSendAddMore,
                    child: ExcludeSemantics(
                      child: InkWell(
                        key: const ValueKey('media-send-add'),
                        borderRadius: AppRadius.brSm,
                        onTap: enabled ? onAdd : null,
                        child: Container(
                          width: _side,
                          height: _side,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brSm,
                            border: Border.all(color: colors.outline),
                          ),
                          child: Icon(Icons.add, color: colors.onSurface),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (remove != null)
            IconButton(
              key: const ValueKey('media-send-remove'),
              tooltip: l10n.mediaSendRemoveItem,
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled ? remove : null,
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.slot,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _Slot slot;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = slot.current;
    final seconds = item.duration;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: _ThumbStrip._side,
            height: _ThumbStrip._side,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: AppRadius.brSm,
              border: Border.all(
                color: selected ? colors.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (slot.isPhoto)
                  Image.file(
                    item.file,
                    key: ValueKey(item.file.path),
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                  )
                else
                  Icon(Icons.videocam_outlined, color: colors.onSurfaceVariant),
                if (!slot.isPhoto && seconds != null)
                  Positioned(
                    left: 4,
                    bottom: 2,
                    child: Text(
                      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      style: context.text.labelSmall,
                    ),
                  ),
                if (slot.retouches.isNotEmpty)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 10,
                        color: colors.onPrimary,
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

/// Légende, vue unique et envoi.
class _CaptionRow extends StatelessWidget {
  const _CaptionRow({
    required this.controller,
    required this.viewOnce,
    required this.canViewOnce,
    required this.onViewOnce,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool viewOnce;
  final bool canViewOnce;
  final VoidCallback onViewOnce;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('media-send-caption'),
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.onSurface.withValues(alpha: 0.10),
              hintText: l10n.addACaption,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              suffixIcon: canViewOnce
                  ? IconButton(
                      key: const ValueKey('media-send-view-once'),
                      tooltip: viewOnce
                          ? l10n.mediaSendViewOnceOn
                          : l10n.mediaSendViewOnceOff,
                      isSelected: viewOnce,
                      color: viewOnce ? colors.primary : null,
                      icon: Icon(
                        viewOnce ? Icons.timer : Icons.timer_outlined,
                      ),
                      onPressed: onViewOnce,
                    )
                  : null,
            ),
          ),
        ),
        AppSpacing.hGapSm,
        Material(
          color: colors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('media-send-send'),
            customBorder: const CircleBorder(),
            onTap: sending ? null : onSend,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                Icons.send,
                semanticLabel: l10n.commonSend,
                color: sending
                    ? colors.onPrimary.withValues(alpha: 0.5)
                    : colors.onPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Recipient extends StatelessWidget {
  const _Recipient({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.arrow_forward, size: 14, color: colors.onSurfaceVariant),
        AppSpacing.hGapXs,
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aperçu d'une vidéo locale avant envoi.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({super.key, required this.file});

  final File file;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_onVideoUpdate);
      await controller.setLooping(true);
      await controller.setVolume(1);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await controller.dispose();
      _controller = null;
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    HapticFeedback.lightImpact();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      );
    }

    final playing = controller.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlayback,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: playing ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              // Center : évite que StackFit.expand étire le cercle play.
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
