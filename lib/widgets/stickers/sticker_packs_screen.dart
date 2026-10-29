import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_order.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../billing/open_plus_offer.dart';
import 'sticker_created_tab.dart';
import 'sticker_image.dart';
import 'sticker_share_screens.dart';

/// Gestion des stickers : « Mes packs » (réordonner, retirer) et catalogue
/// (ajouter). Le serveur tranche : un pack Royal sans droit renvoie
/// `SUBSCRIPTION_REQUIRED`, qui ouvre le panneau Plus.
///
/// V1b : quand la création est ouverte côté serveur, un second onglet « Mes
/// créations » apparaît (packs perso, partage). Fermée (`404 NOT_FOUND`),
/// l'écran reste exactement celui de la V1a.
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
  StickerCreationRepository? _creation;

  @override
  void initState() {
    super.initState();
    try {
      _creation = context.read<StickerCreationRepository>();
    } catch (_) {
      _creation = null; // pas de module création (tests) : écran V1a
    }
    unawaited(_repo.ensureFresh(every: Duration.zero));
    unawaited(_creation?.syncCreated());
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
    final creation = _creation;
    if (creation == null) return _scaffold(context, null);
    return ValueListenableBuilder<bool>(
      valueListenable: creation.creationAvailable,
      builder: (context, open, _) => _scaffold(context, open ? creation : null),
    );
  }

  Widget _scaffold(BuildContext context, StickerCreationRepository? creation) {
    final l10n = context.l10n;
    if (creation == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.stickerManage)),
        body: _installedBody(context),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.stickerManage),
          actions: [
            IconButton(
              tooltip: l10n.stickerOpenLink,
              icon: const Icon(Icons.link),
              onPressed: () => showOpenStickerLinkDialog(context),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.stickerTabInstalled),
              Tab(text: l10n.stickerMyCreations),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _installedBody(context),
            StickerCreatedTab(repo: creation),
          ],
        ),
      ),
    );
  }

  Widget _installedBody(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<List<LocalStickerPack>>(
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
                      child: Text(
                        l10n.stickerNoPacks,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverReorderableList(
                    itemCount: installed.length,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 6,
                      color: context.colors.surface,
                      child: child,
                    ),
                    onReorderItem: (oldIndex, newIndex) {
                      final ids = installed.map((p) => p.packId).toList();
                      final reordered = reorderedIds(ids, oldIndex, newIndex);
                      unawaited(_run(() => _repo.reorderPacks(reordered)));
                    },
                    itemBuilder: (context, i) {
                      final p = installed[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey('mine_${p.packId}'),
                        index: i,
                        child: _PackTile(
                          pack: p,
                          highlighted: p.code == widget.focusPackCode,
                          trailing: PopupMenuButton<_PackAction>(
                            tooltip: l10n.stickerPackActions,
                            onSelected: (action) {
                              final index = installed.indexOf(p);
                              if (action == _PackAction.up && index > 0) {
                                final ids = installed
                                    .map((pack) => pack.packId)
                                    .toList();
                                unawaited(
                                  _run(
                                    () => _repo.reorderPacks(
                                      movePackBy(ids, index, -1),
                                    ),
                                  ),
                                );
                              } else if (action == _PackAction.down &&
                                  index < installed.length - 1) {
                                final ids = installed
                                    .map((pack) => pack.packId)
                                    .toList();
                                unawaited(
                                  _run(
                                    () => _repo.reorderPacks(
                                      movePackBy(ids, index, 1),
                                    ),
                                  ),
                                );
                              } else if (action == _PackAction.remove) {
                                unawaited(
                                  _run(() => _repo.removePack(p.packId)),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: _PackAction.up,
                                enabled: installed.indexOf(p) > 0,
                                child: Text(l10n.stickerMoveUp),
                              ),
                              PopupMenuItem(
                                value: _PackAction.down,
                                enabled:
                                    installed.indexOf(p) < installed.length - 1,
                                child: Text(l10n.stickerMoveDown),
                              ),
                              PopupMenuItem(
                                value: _PackAction.remove,
                                child: Text(l10n.stickerRemovePack),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if (installed.length > 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        l10n.stickerPackReorderHint,
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
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
                              icon: Icon(
                                Icons.lock_outline,
                                color: context.colors.primary,
                              ),
                              onPressed: () => openPlusOffer(context),
                            )
                          : IconButton(
                              tooltip: l10n.stickerAddPack,
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: context.colors.primary,
                              ),
                              onPressed: () => _run(() => _repo.installPack(p)),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Text(
      text,
      style: context.text.titleSmall?.copyWith(color: context.colors.primary),
    ),
  );
}

enum _PackAction { up, down, remove }

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
                        staticFrame: true,
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
      subtitle: Text(
        [
          l10n.stickerPackCount(pack.stickerCount),
          if (pack.isPremium) l10n.stickerBadgePlus,
        ].join(' · '),
      ),
      trailing: trailing,
    );
  }
}
