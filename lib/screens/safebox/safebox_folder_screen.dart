//  Un dossier du coffre-fort : sous-dossiers, fichiers, envois en cours.
//
//  Lot 8 (maquettes du 24/10/2026) : photos et vidéos par jour, albums de
//  tous types avec un filtre par type, sélection multiple (appui long) et sa
//  barre Télécharger · Envoyer · Album · Déplacer · Supprimer, feuille
//  « Télécharger » (galerie ou ZIP).

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
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_chat_picker.dart';
import 'safebox_download_sheet.dart';
import 'safebox_grid.dart';
import 'safebox_note_widgets.dart';
import 'safebox_photo_screen.dart';
import 'safebox_compression_sheet.dart';
import 'safebox_move_picker.dart';
import 'safebox_transfers_screen.dart';
import 'safebox_widgets.dart';

class SafeboxFolderScreen extends StatefulWidget {
  const SafeboxFolderScreen({super.key, required this.folderId, required this.root, this.openPickerOnStart = false});
  final int folderId;
  final SafeboxRoot root;

  /// Ouvre tout de suite le choix des fichiers (bouton « + » de l'accueil).
  final bool openPickerOnStart;

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

  /// Fichiers sélectionnés (appui long) : la barre d'actions remplace le bouton « + ».
  final Set<int> _choisis = {};

  /// Filtre par type, dans Albums et Partager ; null : tout.
  SafeboxFamily? _filtre;
  bool _choixOuvert = false;

  SafeboxController get _c => context.read<SafeboxController>();
  bool get _grille =>
      widget.root == SafeboxRoot.photos || widget.root == SafeboxRoot.videos || widget.root == SafeboxRoot.albums;

  /// Photos et vidéos se parcourent par jour.
  bool get _parJour => widget.root == SafeboxRoot.photos || widget.root == SafeboxRoot.videos;

  bool get _selection => _choisis.isNotEmpty;
  List<SafeboxFile> get _visibles => _filtre == null ? _fichiers : _fichiers.where((f) => f.family == _filtre).toList();
  List<SafeboxFile> get _selectionnes => _fichiers.where((f) => _choisis.contains(f.id)).toList();

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
        _choisis.removeWhere((id) => !_fichiers.any((f) => f.id == id));
      });
      if (widget.openPickerOnStart && !_choixOuvert) {
        _choixOuvert = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ajouterFichiers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  /// Tout le dossier (ses fichiers, pas ses sous-dossiers), pages comprises.
  Future<List<SafeboxFile>> _toutLeDossier() async {
    final tous = [..._fichiers];
    var suite = _suite;
    while (suite != null) {
      final p = await _c.api.fetchSafeboxFolder(widget.folderId, cursor: suite);
      tous.addAll(p.files);
      suite = p.nextCursor;
    }
    return tous;
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
    // Albums et Partager acceptent tous les types.
    final type = switch (widget.root) {
      SafeboxRoot.photos => FileType.image,
      SafeboxRoot.videos => FileType.video,
      SafeboxRoot.audios => FileType.audio,
      SafeboxRoot.documents || SafeboxRoot.albums || SafeboxRoot.partager => FileType.any,
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
          l10n.safeboxWrongFamily(SafeboxController.rootLabel((r.expectedFamily ?? SafeboxFamily.documents).root, l10n)),
        SafeboxRejectReason.tooLarge =>
          l10n.safeboxFileTooLarge(formatBytes(_c.overview?.limits.maxFileBytes ?? 0, l10n)),
        SafeboxRejectReason.empty || SafeboxRejectReason.unreadable => l10n.safeboxEmptyFile,
      };
      safeboxSnack(context, '${r.pick.name} : $message', error: true);
    }
    if (tri.ok.isEmpty) return;

    // Original, HD ou Compressé (décision du 24/10/2026), espace compris.
    final qualite = await askSafeboxQuality(context, picks: tri.ok, folder: page.folder);
    if (qualite == null || !mounted) return;
    safeboxSnack(context, l10n.safeboxPreparing);
    await _c.addFiles(tri.ok, page.folder, quality: qualite);
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
    if (f.family != SafeboxFamily.photos) return _ouvrir(f);
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
    if (!await confirmSafeboxHevcSend(context, f, ids) || !mounted) return;
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

  /// Vers un dossier de sa racine, d'Albums ou de Partager.
  Future<void> _deplacerFichier(SafeboxFile f) async {
    final cible = await pickSafeboxFileDestination(context, family: f.family, currentParentId: widget.folderId);
    if (cible == null || !mounted) return;
    try {
      await _c.api.updateSafeboxFile(f.id, folderId: cible);
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  /// Dans un album, sans copie (décision du 24/10/2026) : l'espace ne change pas.
  Future<void> _ajouterAUnAlbum(SafeboxFile f) async {
    final l10n = context.l10n;
    final albums = _c.overview?.rootIds[SafeboxRoot.albums];
    if (albums == null) return;
    final cible = await pickSafeboxDestination(
      context,
      startFolderId: albums,
      currentParentId: -1,
      actionLabel: l10n.safeboxAddToAlbumHere,
    );
    if (cible == null || !mounted) return;
    try {
      await _c.addToAlbum([f], cible);
      if (!mounted) return;
      safeboxSnack(context, l10n.safeboxAddedToAlbum);
      await _charger(); // « Aussi dans … » apparaît
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  /// Le même contenu est ailleurs dans le coffre : retirer d'ici seulement
  /// (rien n'est libéré) ou supprimer partout. Null si l'inscrit renonce.
  Future<bool?> _icOuPartout(SafeboxFile f) {
    final l10n = context.l10n;
    final page = _page;
    final ici = page == null ? SafeboxController.rootLabel(widget.root, l10n) : SafeboxController.folderLabel(page.folder, l10n);
    final ailleurs = f.alsoIn.map((p) => SafeboxController.placeLabel(p, l10n)).toSet().join(', ');
    return showAppBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.text.titleSmall),
              subtitle: Text(l10n.safeboxDeleteWhich),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(l10n.safeboxDeleteHereOnly(ici)),
              subtitle: Text(l10n.safeboxDeleteHereOnlyHint(ailleurs)),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.colors.error),
              title: Text(l10n.safeboxDeleteEverywhere, style: TextStyle(color: ctx.colors.error)),
              subtitle: Text(l10n.safeboxDeleteEverywhereHint),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimerFichier(SafeboxFile f) async {
    var partout = false;
    if (f.alsoIn.isNotEmpty) {
      final choix = await _icOuPartout(f);
      if (choix == null || !mounted) return;
      partout = choix;
    }
    try {
      await _c.trashFile(f, everywhere: partout);
      if (mounted) safeboxSnack(context, context.l10n.safeboxMovedToTrash);
      await _charger();
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
            if (f.family == SafeboxFamily.photos)
              ListTile(
                leading: const Icon(Icons.add_comment_outlined),
                title: Text(f.note == null ? l10n.safeboxNoteAdd : l10n.safeboxNoteEdit),
                onTap: () => Navigator.pop(ctx, 'commentaire'),
              ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(l10n.safeboxAddToAlbum),
              onTap: () => Navigator.pop(ctx, 'album'),
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
      case 'album':
        await _ajouterAUnAlbum(f);
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

  // ── Sélection ────────────────────────────────────────────────────────────

  void _basculer(SafeboxFile f) => setState(() {
        if (!_choisis.remove(f.id)) _choisis.add(f.id);
      });

  void _quitterSelection() => setState(_choisis.clear);

  String _titreDossier(AppLocalizations l10n) {
    final page = _page;
    return page == null ? SafeboxController.rootLabel(widget.root, l10n) : SafeboxController.folderLabel(page.folder, l10n);
  }

  /// La feuille « Télécharger » : la sélection, ou tout le dossier.
  Future<void> _versLeTelephone({List<SafeboxFile> selection = const []}) async {
    final l10n = context.l10n;
    final choix = await showSafeboxDownloadSheet(context, selection: selection, folderName: _titreDossier(l10n));
    if (choix == null || !mounted) return;
    try {
      final fichiers = choix.wholeFolder ? await _toutLeDossier() : selection;
      if (fichiers.isEmpty || !mounted) return;
      // Nom du téléchargement (et du ZIP) : « Kribi 2026 », ou « Kribi 2026 · 5 sélectionnés ».
      final titre = choix.wholeFolder
          ? _titreDossier(l10n)
          : '${_titreDossier(l10n)} · ${l10n.safeboxSelectedCount(fichiers.length)}';
      _c.exports.start(fichiers, target: choix.target, title: titre);
      _quitterSelection();
      safeboxSnack(context, l10n.safeboxDownloadStarted);
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _envoyerSelection() async {
    final l10n = context.l10n;
    final fichiers = _selectionnes;
    if (fichiers.isEmpty) return;
    final ids = await pickSafeboxConversations(context, file: fichiers.first, others: fichiers.length - 1);
    if (ids == null || ids.isEmpty || !mounted) return;
    var envoyes = 0;
    try {
      for (final f in fichiers) {
        if (!mounted) return;
        if (!await confirmSafeboxHevcSend(context, f, ids)) continue;
        envoyes += await _c.sendToConversations(f, ids) > 0 ? 1 : 0;
      }
      if (!mounted) return;
      if (envoyes > 0) safeboxSnack(context, l10n.safeboxSendDone(ids.length));
      _quitterSelection();
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _ajouterSelectionAUnAlbum() async {
    final l10n = context.l10n;
    final albums = _c.overview?.rootIds[SafeboxRoot.albums];
    if (albums == null) return;
    final cible = await pickSafeboxDestination(
      context,
      startFolderId: albums,
      currentParentId: -1,
      actionLabel: l10n.safeboxAddToAlbumHere,
    );
    if (cible == null || !mounted) return;
    try {
      await _c.addToAlbum(_selectionnes, cible);
      if (!mounted) return;
      safeboxSnack(context, l10n.safeboxAddedToAlbum);
      _quitterSelection();
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _deplacerSelection() async {
    final fichiers = _selectionnes;
    final familles = fichiers.map((f) => f.family).toSet();
    final cible = await pickSafeboxFileDestination(
      context,
      family: familles.length == 1 ? familles.first : null,
      currentParentId: widget.folderId,
    );
    if (cible == null || !mounted) return;
    try {
      for (final f in fichiers) {
        await _c.api.updateSafeboxFile(f.id, folderId: cible);
      }
      _quitterSelection();
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
      await _charger();
    }
  }

  Future<void> _supprimerSelection() async {
    final fichiers = _selectionnes;
    if (fichiers.isEmpty) return;
    var partout = false;
    final ailleurs = fichiers.where((f) => f.alsoIn.isNotEmpty).toList();
    if (ailleurs.isNotEmpty) {
      final choix = await _icOuPartout(ailleurs.first);
      if (choix == null || !mounted) return;
      partout = choix;
    }
    try {
      for (final f in fichiers) {
        await _c.trashFile(f, everywhere: partout);
      }
      if (mounted) safeboxSnack(context, context.l10n.safeboxMovedToTrash);
      _quitterSelection();
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
      await _charger();
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

  void _toucherFichier(SafeboxFile f) => _selection ? _basculer(f) : _ouvrirFichier(f);

  Widget _tuile(SafeboxFile f) => SafeboxGridTile(
        file: f,
        selecting: _selection,
        selected: _choisis.contains(f.id),
        onTap: () => _toucherFichier(f),
        onLongPress: () => _basculer(f),
      );

  SliverGridDelegate get _grilleDelegue => const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
      );

  /// Les fichiers : par jour (photos, vidéos), en grille (albums), ou en liste.
  List<Widget> _fichiersEnSlivers(AppLocalizations l10n) {
    final fichiers = _visibles;
    if (_grille && _parJour) {
      return [
        for (final g in safeboxGroupByDay(fichiers)) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Text(safeboxDayLabel(context, g.day), style: context.text.titleSmall),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            sliver: SliverGrid.builder(
              gridDelegate: _grilleDelegue,
              itemCount: g.files.length,
              itemBuilder: (_, i) => _tuile(g.files[i]),
            ),
          ),
        ],
      ];
    }
    if (_grille) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          sliver: SliverGrid.builder(
            gridDelegate: _grilleDelegue,
            itemCount: fichiers.length,
            itemBuilder: (_, i) => _tuile(fichiers[i]),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: fichiers.length,
        itemBuilder: (_, i) {
          final f = fichiers[i];
          return ListTile(
            selected: _choisis.contains(f.id),
            leading: _selection
                ? Checkbox(value: _choisis.contains(f.id), onChanged: (_) => _basculer(f))
                : SafeboxFileThumb(file: f),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text([
                  formatBytes(f.plainBytes, l10n),
                  if (f.quality == SafeboxQuality.hd) l10n.safeboxQualityHd,
                  if (f.quality == SafeboxQuality.compressed) l10n.safeboxQualityCompressed,
                  safeboxDate(context, f.createdAt),
                ].join(' · ')),
                if (f.lost) const SafeboxLostBadge(),
                if (f.note != null) SafeboxNoteLine(note: f.note!),
                if (f.alsoIn.isNotEmpty)
                  Text(
                    l10n.safeboxAlsoIn(SafeboxController.placeLabel(f.alsoIn.first, l10n)),
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                if (f.sent != null) SafeboxSentBadge(sent: f.sent!),
              ],
            ),
            trailing: _selection
                ? null
                : IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _menuFichier(f)),
            onTap: () => _toucherFichier(f),
            onLongPress: () => _basculer(f),
          );
        },
      ),
    ];
  }

  /// Filtre par type, quand le dossier en mélange plusieurs (Albums, Partager).
  Widget? _filtres(AppLocalizations l10n) {
    if (widget.root != SafeboxRoot.albums && widget.root != SafeboxRoot.partager) return null;
    final familles = _fichiers.map((f) => f.family).toSet();
    if (familles.length < 2) return null;
    Widget puce(SafeboxFamily? f, String label) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            label: Text(label),
            selected: _filtre == f,
            onSelected: (_) => setState(() => _filtre = f),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        children: [
          puce(null, l10n.safeboxFilterAll),
          for (final f in SafeboxFamily.values)
            if (familles.contains(f)) puce(f, SafeboxController.rootLabel(f.root, l10n)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final page = _page;
    final envois = c.uploads.jobs
        .where((j) => j.folderId == widget.folderId && j.state != SafeboxUploadState.completed)
        .toList();
    final filtres = page == null ? null : _filtres(l10n);

    return PopScope(
      canPop: !_selection,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _selection) _quitterSelection();
      },
      child: Scaffold(
        appBar: _selection
            ? AppBar(
                leading: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: _quitterSelection,
                ),
                title: Text(l10n.safeboxSelectedCount(_choisis.length)),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _choisis.addAll(_visibles.map((f) => f.id))),
                    child: Text(l10n.safeboxSelectAll),
                  ),
                ],
              )
            : AppBar(
                title: Text(_titreDossier(l10n)),
                actions: [
                  if (c.uploads.jobs.isNotEmpty)
                    IconButton(
                      tooltip: l10n.safeboxTabTransfers,
                      icon: const Icon(Icons.swap_vert),
                      onPressed: () => showSafeboxTransfers(context),
                    ),
                  if (page != null && _fichiers.isNotEmpty)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'telecharger') _versLeTelephone();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'telecharger',
                          child: ListTile(
                            leading: const Icon(Icons.download_outlined),
                            title: Text(l10n.safeboxDownloadFolderAction),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
        floatingActionButton: page == null || _selection
            ? null
            : FloatingActionButton(
                heroTag: 'coffre_dossier_${widget.folderId}',
                onPressed: _menuAjouter,
                tooltip: l10n.safeboxAddFiles,
                child: const Icon(Icons.add),
              ),
        bottomNavigationBar: _selection ? _barreSelection(l10n) : null,
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
                        if (filtres != null) SliverToBoxAdapter(child: filtres),
                        if (envois.isNotEmpty)
                          SliverList.list(children: [for (final j in envois) _LigneEnvoiDossier(job: j)]),
                        if (!_selection)
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
                        else
                          ..._fichiersEnSlivers(l10n),
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  ),
      ),
    );
  }

  /// Télécharger · Envoyer · Album · Déplacer · Supprimer (et « Plus » pour un
  /// seul fichier : renommer, commenter, ouvrir avec…).
  Widget _barreSelection(AppLocalizations l10n) {
    final selection = _selectionnes;
    final taille = selection.fold<int>(0, (s, f) => s + f.plainBytes);
    Widget action(IconData icone, String label, VoidCallback? onTap, {Color? couleur}) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, color: couleur ?? context.colors.primary),
                  AppSpacing.vGapXs,
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: couleur ?? context.colors.onSurface)),
                ],
              ),
            ),
          ),
        );
    return SafeArea(
      child: Material(
        color: context.colors.surface,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l10n.safeboxSelectedCount(selection.length)} · ${formatBytes(taille, l10n)}',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              Row(
                children: [
                  action(Icons.download_outlined, l10n.safeboxDownload, () => _versLeTelephone(selection: selection)),
                  action(Icons.send_outlined, l10n.safeboxSendToChat, _envoyerSelection),
                  action(Icons.collections_bookmark_outlined, l10n.safeboxAddToAlbum, _ajouterSelectionAUnAlbum),
                  action(Icons.drive_file_move_outlined, l10n.safeboxMove, _deplacerSelection),
                  action(Icons.delete_outline, l10n.safeboxDelete, _supprimerSelection, couleur: context.colors.error),
                  if (selection.length == 1)
                    action(Icons.more_horiz, MaterialLocalizations.of(context).moreButtonTooltip, () {
                      final f = selection.single;
                      _quitterSelection();
                      _menuFichier(f);
                    }),
                ],
              ),
            ],
          ),
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
