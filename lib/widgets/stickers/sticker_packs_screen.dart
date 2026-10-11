import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../billing/open_plus_offer.dart';
import 'sticker_image.dart';

/// Gestion des stickers : « Mes packs » (réordonner, retirer) et catalogue
/// (ajouter). Le serveur tranche : un pack Royal sans droit renvoie
/// `SUBSCRIPTION_REQUIRED`, qui ouvre le panneau Plus.
class StickerPacksScreen extends StatefulWidget {
  const StickerPacksScreen({super.key, this.focusPackCode});

  /// Pack à mettre en avant (« Voir le pack » de la fiche).
  final String? focusPackCode;

  @override
  State<StickerPacksScreen> createState() => _StickerPacksScreenState();
}

class _StickerPacksScreenState extends State<StickerPacksScreen> {
  late final StickerRepository _repo = context.read<StickerRepository>();
  late final Stream<List<LocalStickerPack>> _installed = _repo.watchInstalled();
  late final Stream<List<LocalStickerPack>> _catalog = _repo.watchCatalog();

  @override
  void initState() {
    super.initState();
    unawaited(_repo.ensureFresh(every: Duration.zero));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) afficherErreur(context, e, domaine: ErrorDomain.stickers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.stickerManage)),
      body: StreamBuilder<List<LocalStickerPack>>(
        stream: _installed,
        builder: (context, installedSnap) {
          final installed = installedSnap.data ?? const <LocalStickerPack>[];
          return StreamBuilder<List<LocalStickerPack>>(
            stream: _catalog,
            builder: (context, catalogSnap) {
              final catalog = (catalogSnap.data ?? const <LocalStickerPack>[])
                  .where((p) => !p.installed)
                  .toList();
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Header(l10n.stickerMyPacks)),
                  if (installed.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(l10n.stickerNoPacks,
                            style: context.text.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant)),
                      ),
                    )
                  else
                    SliverReorderableList(
                      itemCount: installed.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final ids = installed.map((p) => p.packId).toList();
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        unawaited(_run(() => _repo.reorderPacks(ids)));
                      },
                      itemBuilder: (context, i) {
                        final p = installed[i];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey('mine_${p.packId}'),
                          index: i,
                          child: _PackTile(
                            pack: p,
                            highlighted: p.code == widget.focusPackCode,
                            trailing: IconButton(
                              tooltip: l10n.stickerRemovePack,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  _run(() => _repo.removePack(p.packId)),
                            ),
                          ),
                        );
                      },
                    ),
                  if (installed.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: Text(l10n.stickerPackReorderHint,
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant)),
                      ),
                    ),
                  SliverToBoxAdapter(child: _Header(l10n.stickerCatalog)),
                  SliverList.builder(
                    itemCount: catalog.length,
                    itemBuilder: (context, i) {
                      final p = catalog[i];
                      return _PackTile(
                        pack: p,
                        highlighted: p.code == widget.focusPackCode,
                        trailing: p.locked
                            ? IconButton(
                                tooltip: l10n.stickerUnlockCta,
                                icon: Icon(Icons.lock_outline,
                                    color: context.colors.primary),
                                onPressed: () => openPlusOffer(context),
                              )
                            : IconButton(
                                tooltip: l10n.stickerAddPack,
                                icon: Icon(Icons.add_circle_outline,
                                    color: context.colors.primary),
                                onPressed: () =>
                                    _run(() => _repo.installPack(p)),
                              ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: AppSpacing.vGapXxl),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
        child: Text(text,
            style: context.text.titleSmall
                ?.copyWith(color: context.colors.primary)),
      );
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.pack,
    required this.trailing,
    this.highlighted = false,
  });

  final LocalStickerPack pack;
  final Widget trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cover = pack.coverUrl;
    return ListTile(
      tileColor: highlighted ? context.semantic.brandContainer : null,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          children: [
            Positioned.fill(
              child: cover == null
                  ? const Icon(Icons.emoji_emotions_outlined)
                  : Opacity(
                      opacity: pack.locked ? 0.45 : 1,
                      child: StickerImage(
                        url: cover,
                        emoji: '',
                        size: 48,
                        showRemovedLabel: false,
                        semanticLabel: pack.name,
                      ),
                    ),
            ),
            if (pack.locked)
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.lock,
                  size: 16,
                  color: context.colors.primary,
                  semanticLabel: l10n.stickerPackLockedSemantics,
                ),
              ),
          ],
        ),
      ),
      title: Text(pack.name),
      subtitle: Text([
        l10n.stickerPackCount(pack.stickerCount),
        if (pack.isPremium) l10n.stickerBadgePlus,
      ].join(' · ')),
      trailing: trailing,
    );
  }
}
