//  Le coffre-fort (lot 8, maquettes validées le 24/10/2026) : quatre onglets,
//  Accueil · Fichiers · Partager · Transferts.
//
//  L'accueil réunit les versions A et B des maquettes, sans le bouton
//  « Ajouter des fichiers » du bas de A : la carte de l'espace et sa
//  répartition par dossier, l'état des envois, la carte Partager, les quatre
//  dossiers remplis depuis le téléphone, les albums récents, « Libérer de
//  l'espace » et la corbeille, et un bouton « + ».

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/billing/entitlement_service.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_folder_screen.dart';
import 'safebox_free_up_screen.dart';
import 'safebox_transfers_screen.dart';
import 'safebox_trash_screen.dart';
import 'safebox_widgets.dart';

/// Couleur d'un dossier racine dans la barre de l'espace.
Color safeboxRootColor(SafeboxRoot r) => switch (r) {
      SafeboxRoot.photos => AppColors.safeboxPhotos,
      SafeboxRoot.videos => AppColors.safeboxVideos,
      SafeboxRoot.audios => AppColors.safeboxAudios,
      SafeboxRoot.documents => AppColors.safeboxDocuments,
      SafeboxRoot.albums => AppColors.safeboxAlbums,
      SafeboxRoot.partager => AppColors.safeboxShare,
    };

/// Ouvre un dossier racine, puis relit l'espace au retour.
Future<void> _ouvrirRacine(BuildContext context, SafeboxRoot r, {bool ajouter = false}) async {
  final c = context.read<SafeboxController>();
  final id = c.overview?.rootIds[r];
  if (id == null) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => SafeboxFolderScreen(folderId: id, root: r, openPickerOnStart: ajouter)),
  );
  if (context.mounted) await c.refreshOverview();
}

class SafeboxHomeScreen extends StatefulWidget {
  const SafeboxHomeScreen({super.key, this.initialTab = 0});

  /// 0 Accueil, 1 Fichiers, 2 Partager, 3 Transferts.
  final int initialTab;

  @override
  State<SafeboxHomeScreen> createState() => _SafeboxHomeScreenState();
}

class _SafeboxHomeScreenState extends State<SafeboxHomeScreen> {
  late int _onglet = widget.initialTab;

  @override
  void initState() {
    super.initState();
    final c = context.read<SafeboxController>();
    c.ensureStarted();
    c.refreshOverview();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final partager = c.overview?.rootIds[SafeboxRoot.partager];
    final actifs = c.uploads.jobs.where(safeboxUploadActive).length + c.exports.tasks.where((t) => !t.finished).length;
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          _Accueil(onTab: (i) => setState(() => _onglet = i)),
          const _Fichiers(),
          if (partager == null)
            const Scaffold(body: Center(child: CircularProgressIndicator()))
          else
            SafeboxFolderScreen(key: ValueKey(partager), folderId: partager, root: SafeboxRoot.partager),
          const SafeboxTransfersView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.safeboxTabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l10n.safeboxTabFiles,
          ),
          NavigationDestination(
            icon: const Icon(Icons.send_outlined),
            selectedIcon: const Icon(Icons.send),
            label: l10n.safeboxRootShare,
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: actifs > 0, label: Text('$actifs'), child: const Icon(Icons.swap_vert)),
            label: l10n.safeboxTabTransfers,
          ),
        ],
      ),
    );
  }
}

// ── Accueil ────────────────────────────────────────────────────────────────

class _Accueil extends StatelessWidget {
  const _Accueil({required this.onTab});
  final void Function(int tab) onTab;

  Future<void> _ajouter(BuildContext context) async {
    final l10n = context.l10n;
    final vue = context.read<SafeboxController>().overview;
    if (vue == null) return;
    final r = await showAppBottomSheet<SafeboxRoot>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.safeboxAddTo, style: ctx.text.titleSmall)),
            const Divider(height: 1),
            for (final r in [SafeboxRoot.albums, SafeboxRoot.partager, ...SafeboxFamily.values.map((f) => f.root)])
              if (vue.rootIds[r] != null)
                ListTile(
                  leading: Icon(safeboxRootIcon(r), color: ctx.colors.primary),
                  title: Text(SafeboxController.rootLabel(r, l10n)),
                  onTap: () => Navigator.pop(ctx, r),
                ),
          ],
        ),
      ),
    );
    if (r != null && context.mounted) await _ouvrirRacine(context, r, ajouter: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final vue = c.overview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxTitle)),
      floatingActionButton: vue == null
          ? null
          : FloatingActionButton(
              heroTag: 'coffre_ajouter',
              tooltip: l10n.safeboxAddFiles,
              onPressed: () => _ajouter(context),
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: c.refreshOverview,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 96),
          children: [
            if (vue == null && c.overviewError != null)
              Padding(
                padding: AppSpacing.card,
                child: Text(
                  presenterErreur(l10n, c.overviewError, domaine: ErrorDomain.media),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.error),
                ),
              )
            else if (vue == null)
              const Padding(padding: EdgeInsets.all(AppSpacing.xxxl), child: Center(child: CircularProgressIndicator()))
            else ...[
              _CarteEspace(quota: vue.quota),
              _CarteEtat(onOpen: () => onTab(3)),
              _Carte(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.safeboxShareContainer, borderRadius: AppRadius.brSm),
                    child: const Icon(Icons.send_outlined, color: AppColors.safeboxShare),
                  ),
                  title: Text(l10n.safeboxRootShare, style: context.text.titleSmall),
                  subtitle: Text(l10n.safeboxShareCardHint(
                    vue.quota.byRoot[SafeboxRoot.partager]?.files ?? 0,
                    formatBytes(vue.limits.maxFileBytes, l10n),
                  )),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onTab(2),
                ),
              ),
              _Titre(l10n.safeboxMyFolders),
              _GrilleRacines(roots: [for (final f in SafeboxFamily.values) f.root]),
              _AlbumsRecents(albumsId: vue.rootIds[SafeboxRoot.albums]),
              const _LignesBas(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarteEspace extends StatelessWidget {
  const _CarteEspace({required this.quota});
  final SafeboxQuota quota;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = quota.quotaBytes <= 0 ? 1 : quota.quotaBytes;
    final parts = [
      for (final r in SafeboxRoot.values)
        if ((quota.byRoot[r]?.bytes ?? 0) > 0) (root: r, bytes: quota.byRoot[r]!.bytes),
    ];
    // Pour mille de l'espace : une part non nulle reste visible.
    final flex = [for (final p in parts) (p.bytes * 1000 / total).round().clamp(4, 1000)];
    final reste = (1000 - flex.fold<int>(0, (s, f) => s + f)).clamp(0, 1000);
    final plan = quota.plus
        ? l10n.safeboxPlanPlus(formatBytes(quota.quotaBytes, l10n))
        : l10n.safeboxPlanFree(formatBytes(quota.quotaBytes, l10n));
    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.safeboxSpaceTitle,
                    style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brPill),
                child: Text(plan, style: context.text.labelMedium?.copyWith(color: context.colors.primary)),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          Text.rich(TextSpan(children: [
            TextSpan(
              text: formatBytes(quota.usedBytes, l10n),
              style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: '  ${l10n.safeboxQuotaOutOf(formatBytes(quota.quotaBytes, l10n))}',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ])),
          AppSpacing.vGapSm,
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < parts.length; i += 1) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(flex: flex[i], child: ColoredBox(color: safeboxRootColor(parts[i].root))),
                  ],
                  if (reste > 0) Expanded(flex: reste, child: ColoredBox(color: context.colors.surfaceContainerHighest)),
                ],
              ),
            ),
          ),
          AppSpacing.vGapSm,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: safeboxRootColor(p.root), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${SafeboxController.rootLabel(p.root, l10n)} ${formatBytes(p.bytes, l10n)}',
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(l10n.safeboxFreeSpace(formatBytes(quota.freeBytes, l10n)),
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
              if (!quota.plus)
                TextButton(onPressed: () => showPaywall(context, null), child: Text(l10n.safeboxGoPlus)),
            ],
          ),
          if (quota.overQuota) ...[
            AppSpacing.vGapSm,
            _Depassement(purgeAfter: context.watch<EntitlementService>().current.purgeAfter),
          ],
        ],
      ),
    );
  }
}

/// L'état des envois : en échec, en attente du réseau, en cours, en pause, ou
/// tout est en sécurité. Un appui ouvre les transferts.
class _CarteEtat extends StatelessWidget {
  const _CarteEtat({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final jobs = context.watch<SafeboxController>().uploads.jobs;
    int n(SafeboxUploadState s) => jobs.where((j) => j.state == s).length;
    final enCours =
        jobs.where((j) => j.state == SafeboxUploadState.running || j.state == SafeboxUploadState.queued).toList();
    final total = enCours.fold<int>(0, (s, j) => s + j.storedSize);
    final envoye = enCours.fold<int>(0, (s, j) => s + j.sentBytes);
    final (IconData icone, Color couleur, Color fond, String titre, String detail) = n(SafeboxUploadState.failed) > 0
        ? (Icons.error_outline, context.colors.error, context.colors.errorContainer,
            l10n.safeboxStatusFailed(n(SafeboxUploadState.failed)), l10n.safeboxStatusOpen)
        : n(SafeboxUploadState.waitingNetwork) > 0
            ? (Icons.wifi_off, context.semantic.warning, context.semantic.warningContainer,
                l10n.safeboxStatusWaiting(n(SafeboxUploadState.waitingNetwork)), l10n.safeboxUploadWaitingNetwork)
            : enCours.isNotEmpty
                ? (Icons.cloud_upload_outlined, context.colors.primary, context.semantic.brandContainer,
                    l10n.safeboxTransfersCount(enCours.length),
                    l10n.safeboxUploadRunning(total <= 0 ? 0 : (envoye * 100 ~/ total)))
                : n(SafeboxUploadState.paused) > 0
                    ? (Icons.pause_circle_outline, context.colors.onSurfaceVariant,
                        context.colors.surfaceContainerHighest, l10n.safeboxStatusPaused(n(SafeboxUploadState.paused)),
                        l10n.safeboxStatusOpen)
                    : (Icons.check, context.semantic.success, context.semantic.successContainer,
                        l10n.safeboxStatusSafe, l10n.safeboxStatusSafeHint);
    return _Carte(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: fond, child: Icon(icone, color: couleur)),
        title: Text(titre, style: context.text.titleSmall),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}

class _GrilleRacines extends StatelessWidget {
  const _GrilleRacines({required this.roots});
  final List<SafeboxRoot> roots;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vue = context.watch<SafeboxController>().overview;
    if (vue == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.3,
        children: [
          for (final r in roots)
            Material(
              color: context.colors.surface,
              borderRadius: AppRadius.brMd,
              child: InkWell(
                borderRadius: AppRadius.brMd,
                onTap: vue.rootIds[r] == null ? null : () => _ouvrirRacine(context, r),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
                        child: Icon(safeboxRootIcon(r), color: context.colors.primary, size: AppIconSize.sm),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(SafeboxController.rootLabel(r, l10n),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                            Text(
                              l10n.safeboxRootSummary(
                                vue.quota.byRoot[r]?.files ?? 0,
                                formatBytes(vue.quota.byRoot[r]?.bytes ?? 0, l10n),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les albums récents, chacun en mosaïque de ses quatre premiers aperçus.
class _AlbumsRecents extends StatefulWidget {
  const _AlbumsRecents({required this.albumsId});
  final int? albumsId;

  @override
  State<_AlbumsRecents> createState() => _AlbumsRecentsState();
}

class _AlbumsRecentsState extends State<_AlbumsRecents> {
  List<SafeboxFolder>? _albums;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final id = widget.albumsId;
    if (id == null) return;
    try {
      final p = await context.read<SafeboxController>().api.fetchSafeboxFolder(id);
      final tries = [...p.folders]..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      if (mounted) setState(() => _albums = tries.take(8).toList());
    } catch (_) {
      if (mounted) setState(() => _albums = const []);
    }
  }

  Future<void> _ouvrir(SafeboxFolder d) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SafeboxFolderScreen(folderId: d.id, root: SafeboxRoot.albums)),
    );
    if (mounted) await _charger();
  }

  Future<void> _nouvelAlbum() async {
    final l10n = context.l10n;
    final c = context.read<SafeboxController>();
    final nom = await safeboxAskName(
      context,
      title: l10n.safeboxNewAlbum,
      label: l10n.safeboxFolderName,
      action: l10n.safeboxCreate,
      maxLength: c.overview?.limits.folderNameMax ?? 80,
    );
    if (nom == null || widget.albumsId == null || !mounted) return;
    try {
      final d = await c.api.createSafeboxFolder(parentId: widget.albumsId!, name: nom);
      if (mounted) await _ouvrir(d);
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final albums = _albums;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
          child: Row(
            children: [
              Expanded(child: Text(l10n.safeboxRecentAlbums, style: context.text.titleMedium)),
              TextButton(
                onPressed: () => _ouvrirRacine(context, SafeboxRoot.albums).then((_) => _charger()),
                child: Text(l10n.safeboxSeeAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 204,
          child: albums == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    for (final a in albums) _CarteAlbum(album: a, onTap: () => _ouvrir(a)),
                    _CarteNouvelAlbum(onTap: _nouvelAlbum),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CarteAlbum extends StatefulWidget {
  const _CarteAlbum({required this.album, required this.onTap});
  final SafeboxFolder album;
  final VoidCallback onTap;

  @override
  State<_CarteAlbum> createState() => _CarteAlbumState();
}

class _CarteAlbumState extends State<_CarteAlbum> {
  SafeboxFolderPage? _page;

  @override
  void initState() {
    super.initState();
    context.read<SafeboxController>().api.fetchSafeboxFolder(widget.album.id).then((p) {
      if (mounted) setState(() => _page = p);
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = _page;
    final fichiers = page?.files ?? const <SafeboxFile>[];
    final n = fichiers.length;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: widget.onTap,
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.brMd,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < 4; i += 1)
                        i < n
                            ? SafeboxFileThumb(file: fichiers[i], fill: true)
                            : ColoredBox(color: context.semantic.brandContainer),
                    ],
                  ),
                ),
              ),
              AppSpacing.vGapXs,
              Text(widget.album.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              if (page != null)
                Text(
                  page.nextCursor != null ? l10n.safeboxAlbumItemsMore(n) : l10n.safeboxAlbumItems(n + page.folders.length),
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteNouvelAlbum extends StatelessWidget {
  const _CarteNouvelAlbum({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: AppRadius.brMd,
        onTap: onTap,
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: Icon(Icons.add, color: context.colors.primary, size: AppIconSize.lg),
              ),
              AppSpacing.vGapXs,
              Text(context.l10n.safeboxNewAlbum, style: context.text.titleSmall),
            ],
          ),
        ),
      );
}

/// « Libérer de l'espace » et la corbeille, sous l'accueil et l'onglet Fichiers.
class _LignesBas extends StatelessWidget {
  const _LignesBas();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final corbeille = c.overview?.quota.trashBytes ?? 0;
    return _Carte(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.cleaning_services_outlined, color: context.colors.onSurfaceVariant),
            title: Text(l10n.safeboxFreeUpTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeboxFreeUpScreen()));
              if (context.mounted) await c.refreshOverview();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colors.onSurfaceVariant),
            title: Text(l10n.safeboxTrash),
            subtitle: corbeille > 0 ? Text(formatBytes(corbeille, l10n)) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeboxTrashScreen()));
              if (context.mounted) await c.refreshOverview();
            },
          ),
        ],
      ),
    );
  }
}

// ── Fichiers ───────────────────────────────────────────────────────────────

class _Fichiers extends StatelessWidget {
  const _Fichiers();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxTabFiles)),
      body: RefreshIndicator(
        onRefresh: c.refreshOverview,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            if (c.overview == null)
              const Padding(padding: EdgeInsets.all(AppSpacing.xxxl), child: Center(child: CircularProgressIndicator()))
            else ...[
              const _GrilleRacines(roots: SafeboxRoot.values),
              AppSpacing.vGapSm,
              const _LignesBas(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Petits morceaux ────────────────────────────────────────────────────────

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
        child: Text(
          texte.toUpperCase(),
          style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.4),
        ),
      );
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child, this.padding = AppSpacing.card});
  final Widget child;
  final EdgeInsetsGeometry padding;

  // Le fond est un Material, et non une décoration : les ListTile y peignent
  // leur effet d'appui.
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        decoration: BoxDecoration(borderRadius: AppRadius.brMd, boxShadow: AppShadows.subtle),
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadius.brMd,
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Fin d'Alanya Plus avec un coffre plus gros que l'espace offert : lecture
/// seule, puis suppression de l'excédent à la date de purge de l'abonnement
/// (30 jours après l'échéance, décision du 15/10/2026).
class _Depassement extends StatelessWidget {
  const _Depassement({required this.purgeAfter});
  final DateTime? purgeAfter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(color: context.colors.errorContainer, borderRadius: AppRadius.brSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.safeboxOverQuotaTitle,
              style: context.text.titleSmall?.copyWith(color: context.colors.onErrorContainer)),
          AppSpacing.vGapXs,
          Text(
            [
              l10n.safeboxOverQuotaBody,
              if (purgeAfter != null) l10n.safeboxOverQuotaPurge(safeboxDate(context, purgeAfter)),
            ].join(' '),
            style: context.text.bodySmall?.copyWith(color: context.colors.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
