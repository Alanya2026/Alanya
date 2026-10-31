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
import '../../core/services/safebox/safebox_backup.dart';
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
import 'safebox_backup_screens.dart';
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

/// Le coffre-fort, en un seul écran (30/10/2026) : l'espace, l'état des envois
/// et de la sauvegarde, les six dossiers, les albums récents. Les transferts
/// s'ouvrent depuis la carte d'état ou l'icône de la barre ; Partager, comme
/// les autres dossiers.
class SafeboxHomeScreen extends StatefulWidget {
  const SafeboxHomeScreen({super.key});

  @override
  State<SafeboxHomeScreen> createState() => _SafeboxHomeScreenState();
}

class _SafeboxHomeScreenState extends State<SafeboxHomeScreen> {
  @override
  void initState() {
    super.initState();
    final c = context.read<SafeboxController>();
    c.ensureStarted();
    c.refreshOverview();
  }

  @override
  Widget build(BuildContext context) => const _Accueil();
}

class _Accueil extends StatelessWidget {
  const _Accueil();

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
    final actifs = c.uploads.jobs.where(safeboxUploadActive).length + c.exports.tasks.where((t) => !t.finished).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.safeboxTitle),
        actions: [
          IconButton(
            tooltip: l10n.safeboxTabTransfers,
            icon: Badge(isLabelVisible: actifs > 0, label: Text('$actifs'), child: const Icon(Icons.swap_vert)),
            onPressed: () => showSafeboxTransfers(context),
          ),
        ],
      ),
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
              const _CarteEtat(),
              const _CarteMemoire(),
              _Titre(l10n.safeboxMyFolders),
              const _GrilleRacines(roots: SafeboxRoot.values),
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
                // Sans enfant, une ColoredBox prend la hauteur minimale : étirée,
                // elle remplit les 10 px de la barre.
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
/// L'état du coffre en une carte : les envois (qui ouvrent les transferts),
/// puis la sauvegarde automatique.
class _CarteEtat extends StatelessWidget {
  const _CarteEtat();

  @override
  Widget build(BuildContext context) {
    // Rien en route : la ligne des envois n'apprend rien (« Tous vos fichiers
    // sont en sécurité ») ; les transferts restent à l'icône du haut. L'attente
    // du Wi-Fi est dite par la ligne de la sauvegarde.
    final calme = context.select<SafeboxController, bool>((c) => c.uploads.jobs.every(
        (j) => j.state == SafeboxUploadState.completed || j.state == SafeboxUploadState.waitingWifi));
    return _Carte(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!calme) ...[
            const _LigneEnvois(),
            Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: context.colors.outlineVariant),
          ],
          const _LigneSauvegarde(),
        ],
      ),
    );
  }
}

class _LigneEnvois extends StatelessWidget {
  const _LigneEnvois();

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
    return ListTile(
      leading: CircleAvatar(backgroundColor: fond, child: Icon(icone, color: couleur)),
      title: Text(titre, style: context.text.titleSmall),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showSafeboxTransfers(context),
    );
  }
}

/// La sauvegarde automatique (lot 10) : « Activer », ou son état — à jour,
/// fichiers en route, en attente de Wi-Fi (« Envoyer avec les données
/// mobiles »), de la charge, espace plein, accès refusé.
class _LigneSauvegarde extends StatelessWidget {
  const _LigneSauvegarde();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final r = c.backupSettings;
    Widget petitBouton(String label, VoidCallback onPressed) => FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
          onPressed: onPressed,
          child: Text(label),
        );
    if (!r.enabled) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: context.semantic.brandContainer,
          child: Icon(Icons.cloud_sync_outlined, color: context.colors.primary),
        ),
        title: Text(l10n.safeboxBackupTitle, style: context.text.titleSmall),
        subtitle: Text(l10n.safeboxBackupPitch),
        trailing: petitBouton(l10n.safeboxBackupActivate, () => showSafeboxBackupSetup(context)),
        onTap: () => showSafeboxBackupSetup(context),
      );
    }
    final dernier = c.lastBackup;
    final wifi = c.backupWaitingWifi;
    final enRoute = c.backupUploading;
    final restants = c.backupRemaining;
    final (IconData icone, Color couleur, String detail, (String, VoidCallback)? action) =
        c.mediaAccess == SafeboxMediaAccess.denied && r.documentFolders.isEmpty
            ? (Icons.block, context.colors.error, l10n.safeboxBackupNoAccess,
                (l10n.safeboxBackupAllow, () => showSafeboxBackupSetup(context)))
            : dernier?.stop == SafeboxBackupStop.spaceFull
                ? (Icons.cloud_off_outlined, context.colors.error, l10n.safeboxBackupSpaceFull,
                    (l10n.safeboxGoPlus, () => showPaywall(context, null)))
                : wifi > 0
                    ? (Icons.wifi_off, context.semantic.warning, l10n.safeboxBackupWaitingWifi(wifi),
                        (l10n.safeboxBackupUseMobile, c.allowMobileData))
                    : enRoute + restants > 0
                        ? (Icons.cloud_upload_outlined, context.colors.primary,
                            l10n.safeboxBackupRemaining(enRoute + restants), null)
                        : (dernier?.waitingCharge ?? 0) > 0
                            ? (Icons.battery_charging_full, context.semantic.warning,
                                l10n.safeboxBackupWaitingCharge(dernier!.waitingCharge), null)
                            : c.mediaAccess == SafeboxMediaAccess.limited
                                ? (Icons.photo_library_outlined, context.semantic.warning, l10n.safeboxBackupLimited,
                                    (l10n.safeboxBackupWiden, () => showSafeboxBackupSetup(context)))
                                : (Icons.check, context.semantic.success, l10n.safeboxBackupUpToDate, null);
    return ListTile(
      leading: CircleAvatar(backgroundColor: couleur.withValues(alpha: 0.12), child: Icon(icone, color: couleur)),
      title: Text(l10n.safeboxBackupTitle, style: context.text.titleSmall),
      subtitle: Text(detail, style: TextStyle(color: couleur)),
      trailing: action != null ? petitBouton(action.$1, action.$2) : const Icon(Icons.chevron_right),
      onTap: () => showSafeboxBackupSetup(context),
    );
  }
}

/// « Libérer la mémoire du téléphone » (lot 10) : quand elle est presque
/// pleine, les photos et vidéos déjà dans le coffre en Original peuvent
/// quitter le téléphone. Android demande lui-même la confirmation.
class _CarteMemoire extends StatefulWidget {
  const _CarteMemoire();

  @override
  State<_CarteMemoire> createState() => _CarteMemoireState();
}

class _CarteMemoireState extends State<_CarteMemoire> {
  List<SafeboxDeviceItem> _liberables = const [];
  bool _occupe = false;

  /// Presque pleine : moins de 15 % ou moins de 2 Go libres.
  static bool _presquePleine(({int free, int total}) m) => m.free < 2 * (1 << 30) || m.free < m.total * 0.15;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final c = context.read<SafeboxController>();
    if (!c.backupSettings.enabled) return;
    try {
      final memoire = await c.device.storage();
      if (memoire == null || !_presquePleine(memoire)) return;
      final l = await c.backup.freeable(c.backupSettings);
      if (mounted) setState(() => _liberables = l);
    } catch (_) {}
  }

  Future<void> _liberer() async {
    final c = context.read<SafeboxController>();
    setState(() => _occupe = true);
    try {
      final retires = await c.backup.free(_liberables);
      if (!mounted) return;
      if (retires.isNotEmpty) safeboxSnack(context, context.l10n.safeboxFreePhoneDone(retires.length));
      await _charger();
      if (mounted) setState(() => _liberables = _liberables.where((i) => !retires.contains(i.key)).toList());
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_liberables.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final photos = _liberables.where((i) => i.family == SafeboxFamily.photos).length;
    final videos = _liberables.where((i) => i.family == SafeboxFamily.videos).length;
    final taille = _liberables.fold<int>(0, (s, i) => s + (i.size > 0 ? i.size : 0));
    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: context.semantic.warning),
              AppSpacing.hGapSm,
              Expanded(child: Text(l10n.safeboxFreePhoneTitle, style: context.text.titleSmall)),
            ],
          ),
          AppSpacing.vGapSm,
          Text(l10n.safeboxFreePhoneBody(photos, videos, formatBytes(taille, l10n)), style: context.text.bodySmall),
          AppSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: _occupe ? null : _liberer,
              child: Text(l10n.safeboxFreePhoneAction),
            ),
          ),
        ],
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
        childAspectRatio: 2.0,
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
                            // Le nombre et la taille sur deux lignes : sur une seule, la taille
                            // était coupée dans une demi-largeur d'écran.
                            Text(
                              switch (vue.quota.byRoot[r]) {
                                final u? when u.files > 0 =>
                                  '${l10n.safeboxFilesCount(u.files)}\n${formatBytes(u.bytes, l10n)}',
                                _ => l10n.safeboxRootSummary(0, ''),
                              },
                              maxLines: 2,
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

/// Les trois derniers albums remplis, chacun en mosaïque de quatre aperçus
/// (photos et vidéos d'abord), en une seule demande au serveur ; les autres
/// sont derrière « Tout voir ».
class _AlbumsRecents extends StatefulWidget {
  const _AlbumsRecents({required this.albumsId});
  final int? albumsId;

  @override
  State<_AlbumsRecents> createState() => _AlbumsRecentsState();
}

class _AlbumsRecentsState extends State<_AlbumsRecents> {
  static const _nombre = 3;
  List<SafeboxRecentAlbum>? _albums;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final albums = await context.read<SafeboxController>().api.fetchSafeboxRecentAlbums(limit: _nombre);
      if (mounted) setState(() => _albums = albums);
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
              IconButton(
                tooltip: l10n.safeboxNewAlbum,
                icon: Icon(Icons.add, color: context.colors.primary),
                onPressed: widget.albumsId == null ? null : _nouvelAlbum,
              ),
              TextButton(
                onPressed: () => _ouvrirRacine(context, SafeboxRoot.albums).then((_) => _charger()),
                child: Text(l10n.safeboxSeeAll),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: albums == null
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _nombre; i += 1) ...[
                      if (i > 0) AppSpacing.hGapSm,
                      Expanded(
                        child: i < albums.length
                            ? _CarteAlbum(key: ValueKey(albums[i].folder.id), album: albums[i], onTap: () => _ouvrir(albums[i].folder))
                            // La première place libre invite à créer un album.
                            : i == albums.length && widget.albumsId != null
                                ? _CarteNouvelAlbum(onTap: _nouvelAlbum)
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _CarteAlbum extends StatelessWidget {
  const _CarteAlbum({super.key, required this.album, required this.onTap});
  final SafeboxRecentAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couverture = album.cover;
    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.brMd,
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < 4; i += 1)
                    i < couverture.length
                        ? SafeboxFileThumb(file: couverture[i], fill: true)
                        : ColoredBox(color: context.semantic.brandContainer),
                ],
              ),
            ),
          ),
          AppSpacing.vGapXs,
          Text(album.folder.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
          Text(
            context.l10n.safeboxAlbumItems(album.fileCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: Icon(Icons.add, color: context.colors.primary, size: AppIconSize.lg),
              ),
            ),
            AppSpacing.vGapXs,
            Text(context.l10n.safeboxNewAlbum, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
          ],
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
