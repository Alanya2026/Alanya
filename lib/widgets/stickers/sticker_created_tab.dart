import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'sticker_created_pack_screen.dart';
import 'sticker_creation_flows.dart';
import 'sticker_image.dart';
import 'sticker_share_screens.dart';

/// Onglet « Mes créations » de la gestion des stickers : mes packs perso,
/// nouveau pack, ouverture d'un lien de pack reçu.
class StickerCreatedTab extends StatefulWidget {
  const StickerCreatedTab({super.key, required this.repo});
  final StickerCreationRepository repo;

  @override
  State<StickerCreatedTab> createState() => _StickerCreatedTabState();
}

class _StickerCreatedTabState extends State<StickerCreatedTab> {
  late final Stream<List<LocalStickerPack>> _created = widget.repo
      .watchCreated();

  Future<void> _newPack() async {
    final id = await createStickerPackFlow(context, widget.repo);
    if (id == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StickerCreatedPackScreen(packId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return StreamBuilder<List<LocalStickerPack>>(
      stream: _created,
      builder: (context, snap) {
        final packs = snap.data ?? const <LocalStickerPack>[];
        return ListView(
          children: [
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: colors.primary),
              title: Text(l10n.stickerNewPack),
              trailing: Text(
                l10n.stickerCreatedCount(packs.length, kMaxCreatedPacks),
                style: context.text.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              // À 20 packs le serveur répond `STICKER_PACK_LIMIT` : on le laisse
              // trancher plutôt que de désactiver le bouton sur une valeur locale.
              onTap: _newPack,
            ),
            ListTile(
              leading: Icon(Icons.link, color: colors.primary),
              title: Text(l10n.stickerOpenLink),
              onTap: () => showOpenStickerLinkDialog(context),
            ),
            if (packs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.stickerCreatedEmpty,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final p in packs)
              _CreatedPackTile(
                pack: p,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StickerCreatedPackScreen(packId: p.packId),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _CreatedPackTile extends StatelessWidget {
  const _CreatedPackTile({required this.pack, required this.onTap});
  final LocalStickerPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cover = pack.coverUrl;
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: cover == null
            ? const Icon(Icons.emoji_emotions_outlined)
            : StickerImage(
                url: cover,
                emoji: '',
                size: 48,
                showRemovedLabel: false,
                staticFrame: true,
                semanticLabel: pack.name,
              ),
      ),
      title: Text(pack.name),
      subtitle: Text(
        [
          l10n.stickerPackCount(pack.stickerCount),
          if (pack.shareToken != null) l10n.stickerShared,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
