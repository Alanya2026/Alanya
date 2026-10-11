import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import '../../features/media_editor/media_editor_screen.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_image_adapter.dart';
import '../../core/services/stickers/sticker_image_check.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_bottom_sheet.dart';
import 'sticker_creation_flows.dart';
import 'sticker_image.dart';

/// Choisit une image dans la galerie. Injectable pour les tests ; **sans**
/// `maxWidth` ni `imageQuality` : le sélecteur ne doit rien ré-encoder, c'est
/// [StickerImageAdapter] qui l'ajuste (contain 512×512, PNG).
typedef StickerImagePicker =
    Future<({Uint8List bytes, String name})?> Function();

Future<({Uint8List bytes, String name})?> _pickFromGallery() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  // Taille connue avant de lire : un fichier énorme n'est jamais chargé.
  if (await x.length() > StickerImageAdapter.maxInputBytes) {
    throw const StickerImageRejected(StickerImageIssue.inputTooBig);
  }
  return (bytes: await x.readAsBytes(), name: x.name);
}

/// Adapte l'image choisie en PNG 512×512 transparent. Injectable pour les
/// tests (le décodage `dart:ui` demande un moteur réel).
typedef StickerImageAdaptation = Future<Uint8List> Function(Uint8List bytes);

/// Ouvre l'éditeur sur [source] (image d'origine, ou image déjà retouchée) et
/// rend le PNG 512×512 retouché, ou `null` si l'utilisateur abandonne.
/// Injectable pour les tests.
typedef StickerImageEditor =
    Future<Uint8List?> Function(BuildContext context, Uint8List source);

Future<Uint8List?> openStickerEditor(BuildContext context, Uint8List source) async {
  final r = await MediaEditorScreen.open(
    context,
    source: MediaEditorSource.bytes(source),
    mode: MediaEditorMode.sticker,
  );
  return r?.png;
}

/// Partage système d'un texte. Injectable pour les tests.
typedef StickerTextSharer = Future<void> Function(String text, Rect? origin);

Future<void> _systemShare(String text, Rect? origin) => SharePlus.instance
    .share(ShareParams(text: text, sharePositionOrigin: origin));

/// Écran d'un de mes packs : grille de stickers, ajout depuis la galerie,
/// réordonnancement (appui long puis glisser), retrait, renommage,
/// partage par lien (feuille de partage du système), suppression.
class StickerCreatedPackScreen extends StatefulWidget {
  const StickerCreatedPackScreen({
    super.key,
    required this.packId,
    this.pickImage = _pickFromGallery,
    this.adaptImage = StickerImageAdapter.adapt,
    this.editImage = openStickerEditor,
    this.shareText = _systemShare,
  });

  final int packId;
  final StickerImagePicker pickImage;
  final StickerImageAdaptation adaptImage;
  final StickerImageEditor editImage;
  final StickerTextSharer shareText;

  @override
  State<StickerCreatedPackScreen> createState() =>
      _StickerCreatedPackScreenState();
}

enum _Menu { rename, revoke, delete }

class _StickerCreatedPackScreenState extends State<StickerCreatedPackScreen> {
  late final StickerCreationRepository _repo = context
      .read<StickerCreationRepository>();
  late final Stream<LocalStickerPack?> _pack = _repo.watchCreated().map(
    (l) => l.where((p) => p.packId == widget.packId).firstOrNull,
  );
  late final Stream<List<LocalSticker>> _stickers = _repo.watchStickers(
    widget.packId,
  );
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showStickerCreationError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() => _run(() async {
    final picked = await widget.pickImage();
    if (picked == null) return;
    // Adaptation (contain 512×512, PNG), puis confirmation sur damier ; refus
    // clair (format, taille, animé) avant tout envoi. « Ajouter » envoie
    // l'image adaptée telle quelle ; « Modifier » ouvre l'éditeur, qui part de
    // l'image d'origine (puis de la dernière retouche) et revient à l'aperçu.
    var png = await widget.adaptImage(picked.bytes);
    var editorSource = picked.bytes;
    while (true) {
      if (!mounted) return;
      final choice = await confirmStickerPreview(context, png);
      if (!mounted || choice == StickerPreviewChoice.cancel) return;
      if (choice == StickerPreviewChoice.add) break;
      final edited = await widget.editImage(context, editorSource);
      if (edited != null) {
        png = edited;
        editorSource = edited;
      }
    }
    if (!mounted) return;
    final r = await _repo.addStickerFromImage(
      widget.packId,
      png,
      filename: picked.name,
    );
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          r.reused ? l10n.stickerAlreadyOwned : l10n.stickerAddedSticker,
        ),
      ),
    );
  });

  Future<void> _rename(LocalStickerPack pack) async {
    final name = await promptStickerPackName(context, initial: pack.name);
    if (name == null) return;
    await _run(() => _repo.renamePack(pack.packId, name));
  }

  Future<void> _delete(LocalStickerPack pack) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.stickerDeletePack),
        content: Text(l10n.stickerDeletePackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.error,
              foregroundColor: ctx.colors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await _repo.archivePack(pack.packId);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.stickerPackDeleted)));
      Navigator.of(context).pop();
    });
  }

  Future<void> _share(LocalStickerPack pack) async {
    final l10n = context.l10n;
    if (pack.stickerCount == 0) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.stickerShareEmpty)));
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await _run(() async {
      // `POST /share` rend le même jeton s'il existe déjà : pas de rotation.
      final token = await _repo.sharePack(pack.packId);
      await widget.shareText(
        l10n.stickerShareMessage(
          pack.name,
          StickerShareLink.build(token),
          token,
        ),
        origin,
      );
    });
  }

  Future<void> _revoke(LocalStickerPack pack) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.stickerShareRevoke),
        content: Text(l10n.stickerShareRevokeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.stickerShareRevoke),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await _repo.unsharePack(pack.packId);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.stickerShareRevoked)));
    });
  }

  Future<void> _stickerActions(LocalStickerPack pack, LocalSticker s) {
    final l10n = context.l10n;
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StickerImage(
              url: s.url,
              thumbUrl: s.thumbUrl,
              emoji: s.emoji,
              size: 160,
            ),
            AppSpacing.vGapMd,
            ListTile(
              leading: Icon(Icons.image_outlined, color: ctx.colors.primary),
              title: Text(l10n.stickerSetCover),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_run(() => _repo.setCover(pack.packId, s.stickerId)));
              },
            ),
            ListTile(
              leading: Icon(
                Icons.remove_circle_outline,
                color: ctx.colors.error,
              ),
              title: Text(l10n.stickerRemoveFromPack),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(
                  _run(() => _repo.removeSticker(pack.packId, s.stickerId)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _move(List<LocalSticker> list, int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= list.length ||
        to >= list.length) {
      return;
    }
    final ids = reorderedIds(list.map((s) => s.stickerId).toList(), from, to);
    unawaited(_run(() => _repo.reorderStickers(widget.packId, ids)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<LocalStickerPack?>(
      stream: _pack,
      builder: (context, packSnap) {
        final pack = packSnap.data;
        final shared = pack?.shareToken != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(pack?.name ?? l10n.stickerMyCreations),
            actions: [
              if (pack != null) ...[
                IconButton(
                  tooltip: l10n.stickerShareByLink,
                  icon: const Icon(Icons.ios_share),
                  onPressed: _busy ? null : () => _share(pack),
                ),
                PopupMenuButton<_Menu>(
                  onSelected: (m) {
                    switch (m) {
                      case _Menu.rename:
                        unawaited(_rename(pack));
                      case _Menu.revoke:
                        unawaited(_revoke(pack));
                      case _Menu.delete:
                        unawaited(_delete(pack));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _Menu.rename,
                      child: Text(l10n.stickerRename),
                    ),
                    if (shared)
                      PopupMenuItem(
                        value: _Menu.revoke,
                        child: Text(l10n.stickerShareRevoke),
                      ),
                    PopupMenuItem(
                      value: _Menu.delete,
                      child: Text(l10n.stickerDeletePack),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: StreamBuilder<List<LocalSticker>>(
            stream: _stickers,
            builder: (context, snap) {
              final list = snap.data ?? const <LocalSticker>[];
              final colors = context.colors;
              final canAdd = list.length < kMaxStickersPerPack;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.stickerCreatedCount(
                            list.length,
                            kMaxStickersPerPack,
                          ),
                          style: context.text.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        AppSpacing.hGapSm,
                        if (shared)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              Icons.link,
                              size: 16,
                              color: colors.primary,
                            ),
                            label: Text(l10n.stickerShared),
                          ),
                        const Spacer(),
                        if (_busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        l10n.stickerPackEmpty,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                          ),
                      itemCount: list.length + (canAdd ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == list.length) {
                          return _AddCell(onTap: _busy ? null : _add);
                        }
                        final s = list[i];
                        return _StickerCell(
                          key: ValueKey('created_${s.stickerId}'),
                          sticker: s,
                          index: i,
                          onTap: pack == null
                              ? null
                              : () => _stickerActions(pack, s),
                          onMove: (from) => _move(list, from, i),
                        );
                      },
                    ),
                  ),
                  if (list.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        l10n.stickerPackReorderHint,
                        style: context.text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Nouvel ordre des identifiants après avoir déposé l'élément [from] à la
/// place de l'élément [to] (les autres se décalent). Pure, testée.
List<int> reorderedIds(List<int> ids, int from, int to) {
  final out = [...ids];
  out.insert(to, out.removeAt(from));
  return out;
}

class _StickerCell extends StatelessWidget {
  const _StickerCell({
    super.key,
    required this.sticker,
    required this.index,
    required this.onTap,
    required this.onMove,
  });

  final LocalSticker sticker;
  final int index;
  final VoidCallback? onTap;
  final void Function(int from) onMove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = StickerImage(
      url: sticker.url,
      thumbUrl: sticker.thumbUrl,
      emoji: sticker.emoji,
      size: 72,
      showRemovedLabel: false,
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMove(d.data),
      builder: (context, candidates, _) => LongPressDraggable<int>(
        data: index,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 84, height: 84, child: image),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: image),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: candidates.isEmpty
                  ? null
                  : Border.all(color: colors.primary, width: 2),
            ),
            child: Center(child: image),
          ),
        ),
      ),
    );
  }
}

class _AddCell extends StatelessWidget {
  const _AddCell({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: context.l10n.stickerAddFromGallery,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.semantic.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: colors.primary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
