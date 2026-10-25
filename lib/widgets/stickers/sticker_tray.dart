import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../billing/open_plus_offer.dart';
import 'non_looping_animated_sticker.dart';
import 'sticker_image.dart';
import 'sticker_packs_screen.dart';
import 'sticker_quick_create.dart';

/// Plateau Émojis · Stickers : onglets **Émojis** et **Stickers**.
///
/// L'onglet Stickers n'existe que si le module est ouvert côté serveur
/// (`StickerRepository.available`) : fermé, le plateau reste celui d'avant.
class EmojiStickerPicker extends StatefulWidget {
  const EmojiStickerPicker({
    super.key,
    required this.emojiPicker,
    required this.onSendSticker,
    this.height,
    this.createHooks = const StickerCreateHooks(),
  });

  /// Le sélecteur d'émojis existant, inchangé.
  final Widget emojiPicker;
  final void Function(StickerEntry entry) onSendSticker;

  /// Hauteur fixe ; `null` : le plateau remplit la place que lui donne son
  /// parent (panneau extensible).
  final double? height;

  /// Points d'injection du bouton « Créer » (tests).
  final StickerCreateHooks createHooks;

  /// Dernier onglet ouvert (mémoire de session).
  static bool _lastWasStickers = false;

  @override
  State<EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends State<EmojiStickerPicker> {
  StickerRepository? _repo;
  bool _stickers = EmojiStickerPicker._lastWasStickers;

  @override
  void initState() {
    super.initState();
    try {
      _repo = context.read<StickerRepository>();
    } catch (_) {
      _repo = null;
    }
    if (_repo != null) unawaited(_repo!.ensureFresh());
  }

  void _select(bool stickers) {
    EmojiStickerPicker._lastWasStickers = stickers;
    setState(() => _stickers = stickers);
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) return widget.emojiPicker;
    return ValueListenableBuilder<bool>(
      valueListenable: repo.available,
      builder: (context, available, _) {
        if (!available) return widget.emojiPicker;
        final l10n = context.l10n;
        final body = Column(
            children: [
              SizedBox(
                height: AppSizes.minTapTarget,
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                        segments: [
                          ButtonSegment(
                              value: false, label: Text(l10n.stickerTabEmojis)),
                          ButtonSegment(
                              value: true, label: Text(l10n.stickerTabStickers)),
                        ],
                        selected: {_stickers},
                        onSelectionChanged: (s) => _select(s.first),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _stickers
                    ? StickerTray(
                        repo: repo,
                        onSend: widget.onSendSticker,
                        createHooks: widget.createHooks,
                      )
                    : widget.emojiPicker,
              ),
            ],
          );
        final h = widget.height;
        return h == null ? body : SizedBox(height: h, child: body);
      },
    );
  }
}

/// Contenu de l'onglet Stickers : récents, favoris, un onglet par pack
/// installé. Toucher envoie ; appui long ouvre l'aperçu (★ favori).
class StickerTray extends StatefulWidget {
  const StickerTray({
    super.key,
    required this.repo,
    required this.onSend,
    this.creation,
    this.createHooks = const StickerCreateHooks(),
  });

  final StickerRepository repo;
  final void Function(StickerEntry entry) onSend;

  /// Création de stickers (bouton « Créer » des Récents). Par défaut, celle du
  /// `Provider` ; absente (tests V1a) : pas de bouton.
  final StickerCreationRepository? creation;

  /// Points d'injection du bouton « Créer » (tests).
  final StickerCreateHooks createHooks;

  @override
  State<StickerTray> createState() => _StickerTrayState();
}

/// Entrée d'onglet : récents, favoris, ou un pack.
class _Tab {
  const _Tab.recents()
      : pack = null,
        favorites = false;
  const _Tab.favorites()
      : pack = null,
        favorites = true;
  const _Tab.pack(LocalStickerPack this.pack) : favorites = false;
  final LocalStickerPack? pack;
  final bool favorites;
  bool get isRecents => pack == null && !favorites;
}

class _StickerTrayState extends State<StickerTray> {
  int _index = 0;

  /// Pack à ouvrir dès que son onglet existe (« Voir » après une création).
  int? _wantedPackId;
  StickerCreationRepository? _creation;

  StickerRepository get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _creation = widget.creation;
    if (_creation == null) {
      try {
        _creation = context.read<StickerCreationRepository>();
      } catch (_) {
        _creation = null; // pas de module création (tests V1a)
      }
    }
  }

  void _viewPack(int packId) {
    if (!mounted) return;
    setState(() => _wantedPackId = packId);
  }

  // Flux créés une fois : un `StreamBuilder` dont le flux change à chaque
  // build se réabonne (et relance sa requête Drift) à chaque image.
  late final Stream<List<LocalStickerPack>> _installed = repo.watchTray();
  late final Stream<List<StickerEntry>> _favorites = repo.watchFavorites();
  late final Stream<List<StickerEntry>> _recents = repo.watchRecents();
  final Map<int, Stream<List<LocalSticker>>> _packStreams = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocalStickerPack>>(
      stream: _installed,
      builder: (context, snap) {
        final packs = snap.data ?? const <LocalStickerPack>[];
        final tabs = [
          const _Tab.recents(),
          const _Tab.favorites(),
          for (final p in packs) _Tab.pack(p),
        ];
        final wanted = _wantedPackId;
        if (wanted != null) {
          final at = tabs.indexWhere((t) => t.pack?.packId == wanted);
          if (at >= 0) {
            _index = at;
            _wantedPackId = null;
          }
        }
        final index = _index.clamp(0, tabs.length - 1);
        return Column(
          children: [
            _TabStrip(
              tabs: tabs,
              index: index,
              onSelect: (i) => setState(() => _index = i),
              onManage: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StickerPacksScreen()),
              ),
            ),
            Expanded(child: _body(context, tabs[index], packs.isEmpty)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, _Tab tab, bool noPacks) {
    final l10n = context.l10n;
    if (tab.pack != null) {
      final pack = tab.pack!;
      return StreamBuilder<List<LocalSticker>>(
        stream: _packStreams.putIfAbsent(
            pack.packId, () => repo.watchStickers(pack.packId)),
        builder: (context, snap) {
          final list = snap.data ?? const <LocalSticker>[];
          return Column(
            children: [
              if (pack.locked) _LockedBanner(),
              Expanded(
                child: _Grid(
                  count: list.length,
                  empty: pack.owned ? l10n.stickerPackEmpty : l10n.stickerLoadError,
                  builder: (i) => StickerEntry(list[i], pack),
                  onSend: widget.onSend,
                  repo: repo,
                ),
              ),
            ],
          );
        },
      );
    }
    final stream = tab.favorites ? _favorites : _recents;
    return StreamBuilder<List<StickerEntry>>(
      stream: stream,
      builder: (context, snap) {
        final list = snap.data ?? const <StickerEntry>[];
        Widget grid(bool withCreate) => _Grid(
              count: list.length,
              empty: noPacks
                  ? l10n.stickerNoPacks
                  : (tab.favorites
                      ? l10n.stickerEmptyFavorites
                      : l10n.stickerEmptyRecents),
              builder: (i) => list[i],
              onSend: widget.onSend,
              repo: repo,
              leading: withCreate
                  ? StickerCreateTile(
                      creation: _creation!,
                      stickers: repo,
                      onViewPack: _viewPack,
                      hooks: widget.createHooks,
                    )
                  : null,
              leadingHint: withCreate ? l10n.stickerCreateHint : null,
            );
        final creation = _creation;
        // Le bouton « Créer » n'existe que dans les Récents, et seulement si
        // le serveur ouvre la création (le serveur tranche).
        if (tab.favorites || creation == null) return grid(false);
        return ValueListenableBuilder<bool>(
          valueListenable: creation.creationAvailable,
          builder: (context, open, _) => grid(open),
        );
      },
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.onManage,
  });

  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: AppSizes.minTapTarget,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, i) {
                final t = tabs[i];
                final selected = i == index;
                final Widget icon;
                if (t.pack != null) {
                  final cover = t.pack!.coverUrl;
                  icon = Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: t.pack!.locked ? 0.45 : 1,
                        child: cover == null
                            ? const Icon(Icons.emoji_emotions_outlined)
                            : StickerImage(
                                url: cover,
                                emoji: '',
                                size: 28,
                                showRemovedLabel: false,
                                staticFrame: true,
                                semanticLabel: t.pack!.name,
                              ),
                      ),
                      if (t.pack!.locked)
                        Icon(Icons.lock, size: 14, color: colors.primary),
                    ],
                  );
                } else {
                  icon = Icon(
                    t.favorites ? Icons.star_border : Icons.access_time,
                    size: 24,
                    semanticLabel: t.favorites
                        ? context.l10n.stickerFavorites
                        : context.l10n.stickerRecents,
                  );
                }
                return Semantics(
                  button: true,
                  selected: selected,
                  // Un pack verrouillé s'annonce comme tel : sans quoi le
                  // lecteur d'écran ne dirait pas pourquoi l'onglet reste
                  // inerte. L'icône interne est exclue pour éviter un doublon,
                  // et l'action est reportée ici pour rester activable.
                  label: _tabLabel(context, t),
                  excludeSemantics: true,
                  onTap: () => onSelect(i),
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Container(
                      width: AppSizes.minTapTarget,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                selected ? colors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant),
                        child: icon,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: context.l10n.stickerManage,
            icon: const Icon(Icons.add),
            onPressed: onManage,
          ),
        ],
      ),
    );
  }

  /// Libellé d'accessibilité d'un onglet du plateau.
  String _tabLabel(BuildContext context, _Tab t) {
    final l10n = context.l10n;
    final pack = t.pack;
    if (pack == null) {
      return t.favorites ? l10n.stickerFavorites : l10n.stickerRecents;
    }
    return pack.locked ? l10n.stickerLockedLabel(pack.name) : pack.name;
  }
}

/// Bandeau d'un pack Plus verrouillé : mène au panneau d'offre existant.
class _LockedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.semantic.brandContainer,
      child: InkWell(
        onTap: () => openPlusOffer(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 18, color: context.semantic.onBrandContainer),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  l10n.stickerLockedBanner,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.onBrandContainer),
                ),
              ),
              Text(
                l10n.stickerUnlockCta,
                style: context.text.labelMedium?.copyWith(
                    color: context.semantic.onBrandContainer,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.count,
    required this.empty,
    required this.builder,
    required this.onSend,
    required this.repo,
    this.leading,
    this.leadingHint,
  });

  final int count;
  final String empty;
  final StickerEntry Function(int i) builder;
  final void Function(StickerEntry) onSend;
  final StickerRepository repo;

  /// Première case de la grille (tuile « Créer »), avant tout sticker.
  final Widget? leading;

  /// Texte d'aide sous la tuile quand il n'y a encore aucun sticker.
  final String? leadingHint;

  /// Toujours tirable, butée franche : une grille courte, ou vide, laisse quand
  /// même le panneau se réduire quand on la tire vers le bas.
  static const ScrollPhysics _physics = AlwaysScrollableScrollPhysics(
    parent: ClampingScrollPhysics(),
  );

  static const SliverGridDelegate _delegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 84,
    mainAxisSpacing: AppSpacing.xs,
    crossAxisSpacing: AppSpacing.xs,
  );

  @override
  Widget build(BuildContext context) {
    if (count == 0 && leading == null) {
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: _physics,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final extra = leading == null ? 0 : 1;
    Widget item(BuildContext context, int i) {
      if (leading != null && i == 0) return leading!;
      return _cell(context, builder(i - extra));
    }

    return Semantics(
      container: true,
      label: context.l10n.stickerTrayLabel,
      child: count == 0
          // Aucun récent : la tuile « Créer » seule, avec un texte d'aide.
          ? CustomScrollView(
              physics: _physics,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  sliver: SliverGrid.builder(
                    gridDelegate: _delegate,
                    itemCount: extra,
                    itemBuilder: item,
                  ),
                ),
                if (leadingHint != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
                      child: Text(
                        leadingHint!,
                        key: const ValueKey('sticker-create-hint'),
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            )
          : GridView.builder(
              physics: _physics,
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: _delegate,
              itemCount: count + extra,
              itemBuilder: item,
            ),
    );
  }

  Widget _cell(BuildContext context, StickerEntry entry) {
    final s = entry.sticker;
    // Chaque vignette est un bouton « envoyer ». Un sticker verrouillé
    // l'annonce, faute de quoi le lecteur d'écran ne dirait pas pourquoi
    // l'appui reste sans effet. L'image interne est exclue (doublon).
    final label = entry.locked
        ? '${context.l10n.stickerSemantics(s.emoji)}.'
            ' ${context.l10n.stickerPackLockedSemantics}'
        : context.l10n.stickerSemantics(s.emoji);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => onSend(entry),
      onLongPress: () => _preview(context, entry),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => onSend(entry),
        onLongPress: () => _preview(context, entry),
        child: Opacity(
          opacity: entry.locked ? 0.4 : 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              StickerImage(
                url: s.thumbUrl ?? s.url,
                emoji: s.emoji,
                size: 76,
                showRemovedLabel: false,
                // Plateau : image fixe, jamais de boucle dans une grille.
                staticFrame: s.animated,
              ),
              if (entry.locked)
                Icon(Icons.lock, size: 20, color: context.colors.onSurface),
            ],
          ),
        ),
      ),
    );
  }

  /// Appui long : aperçu agrandi + actions.
  Future<void> _preview(BuildContext context, StickerEntry entry) async {
    final s = entry.sticker;
    final favs = await repo.watchFavoriteIds().first;
    if (!context.mounted) return;
    var fav = favs.contains(s.stickerId);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.l10n.stickerPreviewTitle),
          // Un sticker animé s'aperçoit en image fixe (première image).
          content: s.animated
              ? NonLoopingAnimatedSticker(
                  url: s.url,
                  thumbUrl: s.thumbUrl,
                  emoji: s.emoji,
                  size: 200,
                  animate: false,
                  semanticLabel: ctx.l10n.stickerAnimatedSemantics(s.emoji),
                )
              : StickerImage(
                  url: s.url, thumbUrl: s.thumbUrl, emoji: s.emoji, size: 200),
          actions: [
            TextButton.icon(
              icon: Icon(fav ? Icons.star : Icons.star_border),
              label: Text(fav
                  ? ctx.l10n.stickerFavoriteRemove
                  : ctx.l10n.stickerFavoriteAdd),
              onPressed: () async {
                try {
                  await repo.setFavorite(s.stickerId, !fav);
                  setState(() => fav = !fav);
                } catch (e) {
                  if (ctx.mounted) {
                    afficherErreur(ctx, e, domaine: ErrorDomain.stickers);
                  }
                }
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSend(entry);
              },
              child: Text(ctx.l10n.commonSend),
            ),
          ],
        ),
      ),
    );
  }
}
