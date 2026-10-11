import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/sticker_payload.dart';
import '../common/app_bottom_sheet.dart';
import 'sticker_image.dart';
import 'sticker_packs_screen.dart';

/// Fiche d'un sticker, au tap sur sa bulle : aperçu, métadonnées, ★ favori,
/// ＋ ajouter le pack, 📦 voir le pack, ↪ transférer.
///
/// V1a : pas de ✏️ Modifier ni de ⚑ Signaler (stickers perso, V1b).
Future<void> showStickerSheet(
  BuildContext context, {
  required StickerPayload payload,
  required String? mediaUrl,
  String? senderName,
  VoidCallback? onForward,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => StickerSheet(
      payload: payload,
      mediaUrl: mediaUrl,
      senderName: senderName,
      onForward: onForward,
    ),
  );
}

class StickerSheet extends StatefulWidget {
  const StickerSheet({
    super.key,
    required this.payload,
    required this.mediaUrl,
    this.senderName,
    this.onForward,
  });

  final StickerPayload payload;
  final String? mediaUrl;
  final String? senderName;
  final VoidCallback? onForward;

  @override
  State<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<StickerSheet> {
  StickerRepository? _repo;
  StickerEntry? _entry;
  bool _favorite = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    try {
      _repo = context.read<StickerRepository>();
    } catch (_) {
      _repo = null; // pas de module stickers (tests) : fiche en lecture seule
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = _repo;
    final sid = widget.payload.sid;
    if (repo == null || sid == null) return;
    final e = await repo.entryFor(sid);
    final favs = await repo.watchFavoriteIds().first;
    if (!mounted) return;
    setState(() {
      _entry = e;
      _favorite = favs.contains(sid);
    });
  }

  Future<void> _toggleFavorite() async {
    final repo = _repo;
    final sid = widget.payload.sid;
    if (repo == null || sid == null || _busy) return;
    setState(() => _busy = true);
    try {
      await repo.setFavorite(sid, !_favorite);
      if (mounted) setState(() => _favorite = !_favorite);
    } catch (e) {
      if (mounted) afficherErreur(context, e, domaine: ErrorDomain.stickers);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPack() async {
    final repo = _repo;
    final pack = _entry?.pack;
    if (repo == null || pack == null || _busy) return;
    setState(() => _busy = true);
    try {
      await repo.installPack(pack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(context.l10n.stickerAdded)));
        setState(() => _entry = StickerEntry(_entry!.sticker, pack));
      }
    } catch (e) {
      // `SUBSCRIPTION_REQUIRED` (pack Royal) ouvre le panneau Plus.
      if (mounted) afficherErreur(context, e, domaine: ErrorDomain.stickers);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewPack() {
    final nav = Navigator.of(context);
    nav.pop();
    unawaited(nav.push(MaterialPageRoute(
      builder: (_) => StickerPacksScreen(focusPackCode: widget.payload.pack),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.payload;
    final colors = context.colors;
    final entry = _entry;
    final pack = entry?.pack;
    final url = widget.mediaUrl;
    final renderable = p.isRenderable && url != null && url.isNotEmpty;

    final meta = <String>[
      if (pack != null) l10n.stickerSheetPack(pack.name),
      if (widget.senderName != null && widget.senderName!.trim().isNotEmpty)
        l10n.stickerSheetSender(widget.senderName!.trim()),
      if (renderable) l10n.stickerSheetSize(p.w, p.h),
      if (entry?.sticker.bytes != null)
        l10n.stickerSheetWeight(formatBytes(entry!.sticker.bytes!, l10n)),
    ];

    return AppBottomSheet(
      // La fiche est une zone nommée : le lecteur d'écran l'annonce comme
      // « Aperçu du sticker » et y entre, plutôt que de tomber sur des
      // éléments isolés sans contexte.
      child: Semantics(
        container: true,
        label: l10n.stickerPreviewTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: renderable
                  ? StickerImage(
                      url: url,
                      emoji: p.emoji,
                      thumbUrl: entry?.sticker.thumbUrl,
                      size: 200,
                    )
                  : StickerFallback(
                      emoji: p.emoji,
                      size: 200,
                      label: p.isRenderable ? null : l10n.stickerUnsupported,
                    ),
            ),
            AppSpacing.vGapMd,
            if (pack != null)
              Center(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(pack.isPremium
                          ? l10n.stickerBadgePlus
                          : l10n.stickerBadgeOfficial),
                      avatar: pack.isPremium
                          ? Icon(Icons.workspace_premium_outlined,
                              size: 16, color: colors.primary)
                          : null,
                    ),
                  ],
                ),
              ),
            for (final line in meta)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            AppSpacing.vGapMd,
            if (renderable && _repo != null)
              ListTile(
                leading: Icon(_favorite ? Icons.star : Icons.star_border,
                    color: colors.primary),
                title: Text(_favorite
                    ? l10n.stickerFavoriteRemove
                    : l10n.stickerFavoriteAdd),
                onTap: _busy ? null : _toggleFavorite,
              ),
            if (pack != null && !pack.installed)
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: colors.primary),
                title: Text(l10n.stickerAddPack),
                onTap: _busy ? null : _addPack,
              ),
            if (p.pack.isNotEmpty && _repo != null)
              ListTile(
                leading:
                    Icon(Icons.inventory_2_outlined, color: colors.primary),
                title: Text(l10n.stickerViewPack),
                onTap: _viewPack,
              ),
            if (widget.onForward != null && renderable)
              ListTile(
                leading: Icon(Icons.shortcut, color: colors.primary),
                title: Text(l10n.stickerForward),
                onTap: () {
                  Navigator.pop(context);
                  widget.onForward!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
