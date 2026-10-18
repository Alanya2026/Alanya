//  Un dossier du coffre-fort : sous-dossiers, fichiers, envois en cours.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_dimens.dart';
import '../../talky_api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_chat_picker.dart';
import 'safebox_note_widgets.dart';
import 'safebox_photo_screen.dart';
import 'safebox_compression_sheet.dart';
import 'safebox_move_picker.dart';
import 'safebox_transfers_sheet.dart';
import 'safebox_widgets.dart';

class SafeboxFolderScreen extends StatefulWidget {
  const SafeboxFolderScreen({super.key, required this.folderId, required this.root});
  final int folderId;
  final SafeboxRoot root;

  @override
  State<SafeboxFolderScreen> createState() => _SafeboxFolderScreenState();
}

class _SafeboxFolderScreenState extends State<SafeboxFolderScreen> {
  SafeboxFolderPage? _page;
  final List<SafeboxFile> _fichiers = [];
  int? _suite;
  bool _chargeSuite = false;
  Object? _erreur;
  StreamSubscription<SafeboxFile>? _abonnement;
  final ScrollController _defilement = ScrollController();

  SafeboxController get _c => context.read<SafeboxController>();
  bool get _grille => widget.root == SafeboxRoot.albums || widget.root == SafeboxRoot.videos;

  @override
  void initState() {
    super.initState();
    _charger();
    _abonnement = _c.uploads.completed.listen((f) {
      if (f.folderId == widget.folderId) _charger();
    });
    _defilement.addListener(() {
      if (_defilement.position.extentAfter < 400) _chargerSuite();
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final p = await _c.api.fetchSafeboxFolder(widget.folderId);
      if (!mounted) return;
      setState(() {
        _page = p;
        _fichiers
          ..clear()
          ..addAll(p.files);
        _suite = p.nextCursor;
        _erreur = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _chargerSuite() async {
    if (_suite == null || _chargeSuite) return;
    _chargeSuite = true;
    try {
      final p = await _c.api.fetchSafeboxFolder(widget.folderId, cursor: _suite);
      if (!mounted) return;
      setState(() {
        _fichiers.addAll(p.files);
        _suite = p.nextCursor;
      });
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      _chargeSuite = false;
    }
  }

  // ── Ajouter ──────────────────────────────────────────────────────────────

  Future<void> _menuAjouter() async {
    final l10n = context.l10n;
    final choix = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.safeboxAddFiles),
              onTap: () => Navigator.pop(ctx, 'fichiers'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.safeboxNewFolder),
              onTap: () => Navigator.pop(ctx, 'dossier'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choix == 'fichiers') await _ajouterFichiers();
    if (choix == 'dossier') await _nouveauDossier();
  }

  Future<void> _nouveauDossier() async {
    final l10n = context.l10n;
    final nom = await safeboxAskName(
      context,
      title: l10n.safeboxNewFolder,
      label: l10n.safeboxFolderName,
      action: l10n.safeboxCreate,
      maxLength: _c.overview?.limits.folderNameMax ?? 80,
    );
    if (nom == null || !mounted) return;
    try {
      await _c.api.createSafeboxFolder(parentId: widget.folderId, name: nom);
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _ajouterFichiers() async {
    final l10n = context.l10n;
    final page = _page;
    if (page == null) return;
    final type = switch (widget.root) {
      SafeboxRoot.albums => FileType.image,
      SafeboxRoot.videos => FileType.video,
      SafeboxRoot.audios => FileType.audio,
      SafeboxRoot.documents => FileType.any,
    };
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: type, withData: false);
    if (res == null || !mounted) return;
    final choisis = [
      for (final f in res.files)
        if (f.path != null) SafeboxPick(path: f.path!, name: f.name, size: f.size),
    ];
    final tri = _c.triage(choisis, page.folder);
    if (tri.rejected.isNotEmpty) {
      final r = tri.rejected.first;
      final message = switch (r.reason) {
        SafeboxRejectReason.wrongFamily =>
          l10n.safeboxWrongFamily(SafeboxController.rootLabel(r.expectedRoot ?? SafeboxRoot.documents, l10n)),
        SafeboxRejectReason.tooLarge =>
          l10n.safeboxFileTooLarge(formatBytes(_c.overview?.limits.maxFileBytes ?? 0, l10n)),
        SafeboxRejectReason.empty || SafeboxRejectReason.unreadable => l10n.safeboxEmptyFile,
      };
      safeboxSnack(context, '${r.pick.name} : $message', error: true);
    }
    if (tri.ok.isEmpty) return;

    var compresser = false;
    final estimation = await _c.estimate(tri.ok, widget.root);
    if (estimation != null && mounted) {
      final retenu = await _c.rememberedChoice();
      if (retenu == SafeboxCompressionChoice.ask) {
        if (!mounted) return;
        final r = await showSafeboxCompressionSheet(
          context,
          originalBytes: estimation.original,
          compressedBytes: estimation.compressed,
        );
        if (r == null) return;
        compresser = r.compress;
        if (r.remember) {
          await _c.rememberChoice(r.compress ? SafeboxCompressionChoice.compressed : SafeboxCompressionChoice.original);
        }
      } else {
        compresser = retenu == SafeboxCompressionChoice.compressed;
      }
    }
    // Espace : on prévient tout de suite plutôt qu'à la réservation.
    final quota = _c.overview?.quota;
    final total = tri.ok.fold<int>(0, (s, p) => s + p.size);
    if (quota != null && !compresser && total > quota.freeBytes) {
      _espacePlein();
      return;
    }
    if (!mounted) return;
    safeboxSnack(context, l10n.safeboxPreparing);
    await _c.addFiles(tri.ok, page.folder, compress: compresser);
  }

  void _espacePlein() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.safeboxQuotaExceeded),
      action: SnackBarAction(label: l10n.safeboxGoPlus, onPressed: () => showPaywall(context, null)),
    ));
  }

  // ── Fichiers ─────────────────────────────────────────────────────────────

  Future<File?> _telecharger(SafeboxFile f) async {
    final dejaLa = await _c.downloads.cached(f);
    if (dejaLa != null) return dejaLa;
    if (!mounted) return null;
    final futur = _c.downloads.fetch(f);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogueTelechargement(file: f, futur: futur),
    ));
    try {
      return await futur;
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
      return null;
    }
  }

  Future<void> _ouvrir(SafeboxFile f) async {
    final fichier = await _telecharger(f);
    if (fichier == null || !mounted) return;
    final r = await OpenFilex.open(fichier.path);
    if (r.type != ResultType.done && mounted) safeboxSnack(context, context.l10n.safeboxOpenFailed, error: true);
  }

  /// Une photo s'ouvre dans l'application, avec son commentaire ; les autres
  /// fichiers, dans l'application du téléphone qui sait les lire.
  Future<void> _ouvrirFichier(SafeboxFile f) async {
    if (f.family != SafeboxRoot.albums) return _ouvrir(f);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SafeboxPhotoScreen(file: f)));
    if (mounted) await _charger(); // le commentaire a pu changer
  }

  Future<void> _commenter(SafeboxFile f) async {
    final r = await showSafeboxNoteEditor(context, f);
    if (r != null && mounted) await _charger();
  }

  Future<void> _exporter(SafeboxFile f) async {
    final fichier = await _telecharger(f);
    if (fichier == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(fichier.path)]));
  }

  /// Le fichier part dans les discussions choisies, sans quitter le coffre.
  Future<void> _envoyerDansDiscussion(SafeboxFile f) async {
    final ids = await pickSafeboxConversations(context, file: f);
    if (ids == null || ids.isEmpty || !mounted) return;
    try {
      final n = await _c.sendToConversations(f, ids);
      if (!mounted) return;
      safeboxSnack(context, context.l10n.safeboxSendDone(n));
      await _charger(); // le badge « envoyé » apparaît
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _renommerFichier(SafeboxFile f) async {
    final l10n = context.l10n;
    final nom = await safeboxAskName(
      context,
      title: l10n.safeboxRename,
      label: l10n.safeboxFileName,
      action: l10n.safeboxRename,
      initial: f.name,
      maxLength: _c.overview?.limits.fileNameMax ?? 180,
    );
    if (nom == null || nom == f.name || !mounted) return;
    try {
      await _c.api.updateSafeboxFile(f.id, name: nom);
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _deplacerFichier(SafeboxFile f) async {
    final racine = _c.overview?.rootIds[widget.root];
    if (racine == null) return;
    final cible = await pickSafeboxDestination(context, startFolderId: racine, currentParentId: widget.folderId);
    if (cible == null || !mounted) return;
    try {
      await _c.api.updateSafeboxFile(f.id, folderId: cible);
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _supprimerFichier(SafeboxFile f) async {
    try {
      await _c.api.trashSafeboxFile(f.id);
      await _c.downloads.evict(f.id);
      if (mounted) safeboxSnack(context, context.l10n.safeboxMovedToTrash);
      await _charger();
      unawaited(_c.refreshOverview());
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _menuFichier(SafeboxFile f) async {
    final l10n = context.l10n;
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.text.titleSmall)),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.open_in_new), title: Text(l10n.safeboxOpen), onTap: () => Navigator.pop(ctx, 'ouvrir')),
            if (f.family == SafeboxRoot.albums)
              ListTile(
                leading: const Icon(Icons.add_comment_outlined),
                title: Text(f.note == null ? l10n.safeboxNoteAdd : l10n.safeboxNoteEdit),
                onTap: () => Navigator.pop(ctx, 'commentaire'),
              ),
            ListTile(leading: const Icon(Icons.send_outlined), title: Text(l10n.safeboxSendToChat), onTap: () => Navigator.pop(ctx, 'envoyer')),
            ListTile(leading: const Icon(Icons.ios_share), title: Text(l10n.safeboxExport), onTap: () => Navigator.pop(ctx, 'exporter')),
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.safeboxRename), onTap: () => Navigator.pop(ctx, 'renommer')),
            ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(l10n.safeboxMove), onTap: () => Navigator.pop(ctx, 'deplacer')),
            ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.colors.error),
              title: Text(l10n.safeboxDelete, style: TextStyle(color: ctx.colors.error)),
              onTap: () => Navigator.pop(ctx, 'supprimer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'ouvrir':
        await _ouvrirFichier(f);
      case 'commentaire':
        await _commenter(f);
      case 'envoyer':
        await _envoyerDansDiscussion(f);
      case 'exporter':
        await _exporter(f);
      case 'renommer':
        await _renommerFichier(f);
      case 'deplacer':
        await _deplacerFichier(f);
      case 'supprimer':
        await _supprimerFichier(f);
    }
  }

  // ── Sous-dossiers ────────────────────────────────────────────────────────

  Future<void> _menuDossier(SafeboxFolder d) async {
    final l10n = context.l10n;
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.safeboxRename), onTap: () => Navigator.pop(ctx, 'renommer')),
            ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(l10n.safeboxMove), onTap: () => Navigator.pop(ctx, 'deplacer')),
            ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.colors.error),
              title: Text(l10n.safeboxDelete, style: TextStyle(color: ctx.colors.error)),
              onTap: () => Navigator.pop(ctx, 'supprimer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'renommer':
          final nom = await safeboxAskName(
            context,
            title: l10n.safeboxRename,
            label: l10n.safeboxFolderName,
            action: l10n.safeboxRename,
            initial: d.name ?? '',
            maxLength: _c.overview?.limits.folderNameMax ?? 80,
          );
          if (nom == null || nom == d.name) return;
          await _c.api.updateSafeboxFolder(d.id, name: nom);
        case 'deplacer':
          final racine = _c.overview?.rootIds[widget.root];
          if (racine == null) return;
          final cible = await pickSafeboxDestination(
            context,
            startFolderId: racine,
            currentParentId: widget.folderId,
            movingFolderId: d.id,
          );
          if (cible == null) return;
          await _c.api.updateSafeboxFolder(d.id, parentId: cible);
        case 'supprimer':
          await _c.api.trashSafeboxFolder(d.id);
          if (mounted) safeboxSnack(context, l10n.safeboxMovedToTrash);
          unawaited(_c.refreshOverview());
      }
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  // ── Affichage ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final page = _page;
    final envois = c.uploads.jobs
        .where((j) => j.folderId == widget.folderId && j.state != SafeboxUploadState.completed)
        .toList();
    final titre = page == null ? SafeboxController.rootLabel(widget.root, l10n) : SafeboxController.folderLabel(page.folder, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        actions: [
          if (c.uploads.jobs.isNotEmpty)
            IconButton(
              tooltip: l10n.safeboxTransfers,
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: () => showSafeboxTransfers(context),
            ),
        ],
      ),
      floatingActionButton: page == null
          ? null
          : FloatingActionButton(onPressed: _menuAjouter, tooltip: l10n.safeboxAddFiles, child: const Icon(Icons.add)),
      body: _erreur != null && page == null
          ? Center(
              child: Padding(
                padding: AppSpacing.card,
                child: TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)),
              ),
            )
          : page == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: CustomScrollView(
                    controller: _defilement,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (envois.isNotEmpty)
                        SliverList.list(children: [for (final j in envois) _LigneEnvoiDossier(job: j)]),
                      SliverList.list(children: [
                        for (final d in page.folders)
                          ListTile(
                            leading: Icon(Icons.folder_outlined, color: context.colors.primary),
                            title: Text(d.name ?? ''),
                            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _menuDossier(d)),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SafeboxFolderScreen(folderId: d.id, root: widget.root)),
                              );
                              if (mounted) await _charger();
                            },
                          ),
                      ]),
                      if (page.folders.isEmpty && _fichiers.isEmpty && envois.isEmpty)
                        SliverFillRemaining(hasScrollBody: false, child: _Vide(l10n: l10n))
                      else if (_grille)
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          sliver: SliverGrid.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: AppSpacing.xs,
                              crossAxisSpacing: AppSpacing.xs,
                            ),
                            itemCount: _fichiers.length,
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _ouvrirFichier(_fichiers[i]),
                              onLongPress: () => _menuFichier(_fichiers[i]),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  SafeboxFileThumb(file: _fichiers[i], fill: true),
                                  if (_fichiers[i].note != null)
                                    const Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.chat_bubble, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: _fichiers.length,
                          itemBuilder: (_, i) {
                            final f = _fichiers[i];
                            return ListTile(
                              leading: SafeboxFileThumb(file: f),
                              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${formatBytes(f.plainBytes, l10n)} · ${safeboxDate(context, f.createdAt)}'),
                                  if (f.lost) const SafeboxLostBadge(),
                                  if (f.note != null) SafeboxNoteLine(note: f.note!),
                                  if (f.sent != null) SafeboxSentBadge(sent: f.sent!),
                                ],
                              ),
                              trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _menuFichier(f)),
                              onTap: () => _ouvrirFichier(f),
                            );
                          },
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: context.colors.outlineVariant),
            AppSpacing.vGapMd,
            Text(l10n.safeboxFolderEmpty, style: context.text.titleMedium),
            AppSpacing.vGapXs,
            Text(l10n.safeboxFolderEmptyHint,
                textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      );
}

class _LigneEnvoiDossier extends StatelessWidget {
  const _LigneEnvoiDossier({required this.job});
  final SafeboxUploadJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enCours = job.state == SafeboxUploadState.running;
    final texte = switch (job.state) {
      SafeboxUploadState.running => l10n.safeboxUploadRunning((job.progress * 100).floor()),
      SafeboxUploadState.waitingNetwork => l10n.safeboxUploadWaitingNetwork,
      SafeboxUploadState.failed => safeboxUploadErrorText(context, job.errorCode),
      _ => l10n.safeboxUploadQueued,
    };
    return ListTile(
      leading: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(value: enCours ? job.progress : null, strokeWidth: 3),
      ),
      title: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(texte,
          style: TextStyle(color: job.state == SafeboxUploadState.failed ? context.colors.error : null)),
      onTap: () => showSafeboxTransfers(context),
    );
  }
}

class _DialogueTelechargement extends StatefulWidget {
  const _DialogueTelechargement({required this.file, required this.futur});
  final SafeboxFile file;
  final Future<File> futur;

  @override
  State<_DialogueTelechargement> createState() => _DialogueTelechargementState();
}

class _DialogueTelechargementState extends State<_DialogueTelechargement> {
  @override
  void initState() {
    super.initState();
    // Une seule fois : le dialogue se ferme quand le téléchargement se termine,
    // réussi ou non (l'erreur est affichée par l'écran du dossier).
    widget.futur.whenComplete(() {
      if (mounted) Navigator.of(context).pop();
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final progres = context.watch<SafeboxController>().downloads.progressOf(widget.file.id);
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          AppSpacing.vGapMd,
          LinearProgressIndicator(value: progres),
          AppSpacing.vGapSm,
          Text(context.l10n.safeboxDownloading(((progres ?? 0) * 100).floor())),
        ],
      ),
    );
  }
}
