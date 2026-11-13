// Écrans 3 et 4 : un dossier du coffre. Fil d'Ariane, sous-dossiers, puis
// les fichiers par jour d'ajout.
//  - D3 : visionneuse, téléchargement ;
//  - D4 : « Ajouter » ou dépôt de fichiers du PC ;
//  - D5 : ranger, à la souris et au clavier comme dans l'explorateur de
//    fichiers : clic pour sélectionner, double-clic pour ouvrir, Ctrl ou
//    Maj + clic, Ctrl+A, Suppr vers la corbeille, F2 pour renommer, Entrée
//    pour ouvrir, Échap pour désélectionner, clic droit pour le menu.

import 'dart:async';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/exporter.dart';
import '../ui/common.dart';
import '../viewer/viewer_screen.dart';
import 'actions.dart';
import 'import_flow.dart';
import 'thumbnail.dart';

class FolderView extends StatefulWidget {
  const FolderView({super.key, required this.root, required this.folderId, required this.onOpenFolder, this.onBack});

  final SafeboxRoot root;
  final int folderId;
  final void Function(int folderId) onOpenFolder;
  final VoidCallback? onBack;

  @override
  State<FolderView> createState() => _FolderViewState();
}

/// Un élément de la vue : un sous-dossier ou un fichier.
typedef _Cle = ({bool dossier, int id});

class _FolderViewState extends State<FolderView> {
  SafeboxFolderPage? _page;
  final List<SafeboxFile> _fichiers = [];
  int? _suite;
  bool _charge = false;
  Object? _erreur;
  final _defilement = ScrollController();
  final _focus = FocusNode(debugLabel: 'dossier');
  bool _survol = false;
  StreamSubscription<int>? _arrivees;
  Timer? _recharge;

  final Set<_Cle> _choix = {};
  _Cle? _ancre;

  /// Filtres, comme sur le téléphone : par type (Albums, Partager), par
  /// dossier d'origine (Photos, Vidéos), « Avec commentaire ».
  SafeboxFamily? _filtre;
  String? _filtreSource;
  bool _commentees = false;

  /// Les fichiers montrés, filtres appliqués.
  List<SafeboxFile> get _visibles => _fichiers
      .where((f) =>
          (_filtre == null || f.family == _filtre) &&
          (_filtreSource == null || f.meta?.source == _filtreSource) &&
          (!_commentees || f.note != null))
      .toList();

  /// Le clic précédent : un second clic rapide sur le même élément l'ouvre.
  ({_Cle cle, DateTime quand})? _dernierClic;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(() {
      if (_defilement.position.extentAfter < 600) _plus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arrivees ??= context.vault.folderChanges.listen((id) {
      if (id != widget.folderId) return;
      // Une rafale d'envois terminés : un seul rechargement.
      _recharge?.cancel();
      _recharge = Timer(const Duration(milliseconds: 800), () {
        if (mounted && !_charge) _charger(silencieux: true);
      });
    });
    if (_page == null && !_charge) _charger();
  }

  @override
  void dispose() {
    _recharge?.cancel();
    _arrivees?.cancel();
    _defilement.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    setState(() {
      _charge = true;
      if (!silencieux) _erreur = null;
    });
    try {
      final p = await context.vault.folder(widget.folderId);
      if (!mounted) return;
      setState(() {
        _page = p;
        _fichiers
          ..clear()
          ..addAll(p.files);
        _suite = p.nextCursor;
        // Ce qui a disparu (déplacé, à la corbeille) quitte la sélection.
        _choix.removeWhere((c) => c.dossier ? !p.folders.any((d) => d.id == c.id) : !_fichiers.any((f) => f.id == c.id));
      });
      // « Avec commentaire » porte sur tout le dossier, pas sur la première page.
      if (_commentees) await _toutCharger();
    } catch (e) {
      if (mounted && !silencieux) setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  Future<void> _plus() async {
    final c = _suite;
    if (c == null || _charge) return;
    _charge = true;
    try {
      final p = await context.vault.folder(widget.folderId, cursor: c);
      if (!mounted) return;
      setState(() {
        _fichiers.addAll(p.files);
        _suite = p.nextCursor;
      });
    } catch (_) {
      // Le prochain défilement réessaie.
    } finally {
      _charge = false;
    }
  }

  // ── Sélection ────────────────────────────────────────────────────────────

  /// Dans l'ordre de l'écran : les sous-dossiers, puis les fichiers.
  List<_Cle> get _ordre => [
        for (final d in _page?.folders ?? const <SafeboxFolder>[]) (dossier: true, id: d.id),
        for (final f in _visibles) (dossier: false, id: f.id),
      ];

  List<SafeboxFile> get _fichiersChoisis => _fichiers.where((f) => _choix.contains((dossier: false, id: f.id))).toList();
  List<SafeboxFolder> get _dossiersChoisis =>
      (_page?.folders ?? const <SafeboxFolder>[]).where((d) => _choix.contains((dossier: true, id: d.id))).toList();

  void _clic(_Cle cle) {
    _focus.requestFocus();
    final clavier = HardwareKeyboard.instance;
    final ctrl = clavier.isControlPressed || clavier.isMetaPressed;
    final maintenant = DateTime.now();
    final avant = _dernierClic;
    _dernierClic = (cle: cle, quand: maintenant);
    if (!ctrl && !clavier.isShiftPressed && avant != null && avant.cle == cle &&
        maintenant.difference(avant.quand) < const Duration(milliseconds: 450)) {
      _dernierClic = null;
      _ouvrir(cle);
      return;
    }
    setState(() {
      if (clavier.isShiftPressed && _ancre != null) {
        final ordre = _ordre;
        final a = ordre.indexOf(_ancre!);
        final b = ordre.indexOf(cle);
        if (a >= 0 && b >= 0) {
          if (!ctrl) _choix.clear();
          _choix.addAll(ordre.sublist(a < b ? a : b, (a < b ? b : a) + 1));
          return;
        }
      }
      if (ctrl) {
        if (!_choix.remove(cle)) _choix.add(cle);
      } else {
        _choix
          ..clear()
          ..add(cle);
      }
      _ancre = cle;
    });
  }

  void _toutChoisir() => setState(() => _choix
    ..clear()
    ..addAll(_ordre));

  void _rienChoisir() => setState(() {
        _choix.clear();
        _ancre = null;
      });

  // ── Actions ──────────────────────────────────────────────────────────────

  void _ouvrir(_Cle cle) {
    if (cle.dossier) {
      widget.onOpenFolder(cle.id);
      return;
    }
    final visibles = _visibles;
    final i = visibles.indexWhere((x) => x.id == cle.id);
    if (i >= 0) openViewer(context, visibles, i);
  }

  String get _ici => _page == null ? rootName(context, widget.root) : folderName(context, _page!.folder);

  Future<void> _apres(bool change) async {
    if (change && mounted) await _charger(silencieux: true);
  }

  Future<void> _renommer() async {
    final dossiers = _dossiersChoisis;
    final fichiers = _fichiersChoisis;
    if (dossiers.length + fichiers.length != 1) return;
    final change = dossiers.isNotEmpty ? renameFolder(context, dossiers.single) : renameFile(context, fichiers.single);
    await _apres(await change);
  }

  Future<void> _deplacer() async {
    final dossiers = _dossiersChoisis;
    final fichiers = _fichiersChoisis;
    if (dossiers.isEmpty && fichiers.isEmpty) return;
    await _apres(await moveItems(context, root: widget.root, currentFolderId: widget.folderId, files: fichiers, folders: dossiers));
  }

  Future<void> _album() => addToAlbum(context, _fichiersChoisis, currentFolderId: widget.folderId);

  Future<void> _corbeille() async {
    final dossiers = _dossiersChoisis;
    final fichiers = _fichiersChoisis;
    if (dossiers.isEmpty && fichiers.isEmpty) return;
    await _apres(await trashItems(context, files: fichiers, folders: dossiers, here: _ici));
  }

  Future<void> _nouveauDossier() async {
    final page = _page;
    if (page != null) await _apres(await createFolder(context, page.folder));
  }

  Future<void> _telechargerChoix() async {
    final exporter = context.vault.exporter;
    for (final d in _dossiersChoisis) {
      unawaited(exporter.saveFolder(d.id, folderName(context, d)));
    }
    for (final f in _fichiersChoisis) {
      unawaited(exporter.saveFile(f));
    }
  }

  Future<void> _telechargerDossier(SafeboxFolder dossier) async {
    final l = context.l;
    final messager = ScaffoldMessenger.of(context);
    final exporter = context.vault.exporter;
    await exporter.saveFolder(dossier.id, folderName(context, dossier));
    final t = exporter.task;
    if (!mounted || t == null) return;
    if (t.state == ExportState.failed) messager.showSnackBar(SnackBar(content: Text(l.downloadFailed)));
  }

  // ── Filtres ──────────────────────────────────────────────────────────────

  /// Tous les fichiers du dossier (toutes les pages) : un filtre ne doit
  /// manquer aucune photo.
  Future<bool> _toutCharger() async {
    try {
      while (_suite != null) {
        final p = await context.vault.folder(widget.folderId, cursor: _suite);
        if (!mounted) return false;
        setState(() {
          _fichiers.addAll(p.files);
          _suite = p.nextCursor;
        });
      }
      return true;
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      return false;
    }
  }

  void _filtrer(void Function() changement) => setState(() {
        changement();
        // Ce qui n'est plus montré quitte la sélection.
        final montres = {for (final f in _visibles) f.id};
        _choix.removeWhere((c) => !c.dossier && !montres.contains(c.id));
      });

  static String _nomSource(BuildContext context, String nom) {
    final l = context.l;
    return switch (nom.toLowerCase()) {
      'camera' || 'dcim' => l.folderCamera,
      'screenshots' => l.folderScreenshots,
      'download' || 'downloads' => l.folderDownloads,
      _ => nom,
    };
  }

  /// La barre des filtres, quand le dossier en a besoin (mêmes règles que le
  /// téléphone) ; null sinon.
  Widget? _filtres(BuildContext context) {
    final l = context.l;
    final parJour = widget.root == SafeboxRoot.photos || widget.root == SafeboxRoot.videos;
    final puces = <Widget>[];
    // « Avec commentaire » : Photos, Vidéos, Albums, dès qu'une photo en a un.
    if ((parJour || widget.root == SafeboxRoot.albums) && (_commentees || _fichiers.any((f) => f.note != null))) {
      puces.add(FilterChip(
        avatar: const Icon(Icons.chat_bubble_outline, size: 16),
        label: Text(l.filterWithNote),
        selected: _commentees,
        onSelected: (oui) async {
          if (oui && !await _toutCharger()) return;
          if (mounted) _filtrer(() => _commentees = oui);
        },
      ));
    }
    Widget choix(bool choisi, String texte, VoidCallback onTap) =>
        ChoiceChip(label: Text(texte), selected: choisi, onSelected: (_) => onTap());
    if (parJour) {
      // Par dossier d'origine, quand il y en a plusieurs.
      final parSource = <String, int>{};
      for (final f in _fichiers) {
        final src = f.meta?.source;
        if (src != null) parSource[src] = (parSource[src] ?? 0) + 1;
      }
      if (parSource.isNotEmpty && !(parSource.length < 2 && parSource.values.first == _fichiers.length)) {
        final sources = parSource.keys.toList()..sort((a, b) => parSource[b]!.compareTo(parSource[a]!));
        puces.add(choix(_filtreSource == null, l.filterAll, () => _filtrer(() => _filtreSource = null)));
        for (final src in sources) {
          puces.add(choix(_filtreSource == src, '${_nomSource(context, src)} · ${parSource[src]}',
              () => _filtrer(() => _filtreSource = src)));
        }
      }
    } else if (widget.root == SafeboxRoot.albums || widget.root == SafeboxRoot.partager) {
      // Par type, quand le dossier en mélange plusieurs.
      final familles = _fichiers.map((f) => f.family).toSet();
      if (familles.length >= 2 || _filtre != null) {
        puces.add(choix(_filtre == null, l.filterAll, () => _filtrer(() => _filtre = null)));
        for (final f in SafeboxFamily.values) {
          if (familles.contains(f)) {
            puces.add(choix(_filtre == f, rootName(context, f.root), () => _filtrer(() => _filtre = f)));
          }
        }
      }
    }
    if (puces.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 4),
      child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 6, children: puces)),
    );
  }

  // ── Menus ────────────────────────────────────────────────────────────────

  Future<void> _menu(Offset position, List<(IconData, String, VoidCallback?, bool)> entrees) async {
    final ecran = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choisi = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & ecran.size),
      items: [
        for (final (i, (icone, texte, action, danger)) in entrees.indexed)
          PopupMenuItem<int>(
            value: i,
            enabled: action != null,
            height: 40,
            child: Row(children: [
              Icon(icone, size: 20, color: danger ? Palette.danger : null),
              const SizedBox(width: 12),
              Text(texte, style: TextStyle(color: danger ? Palette.danger : null)),
            ]),
          ),
      ],
    );
    if (choisi != null) entrees[choisi].$3?.call();
  }

  /// Clic droit sur un élément : il rejoint la sélection s'il n'y est pas.
  void _menuElement(_Cle cle, Offset position) {
    if (!_choix.contains(cle)) {
      setState(() {
        _choix
          ..clear()
          ..add(cle);
        _ancre = cle;
      });
    }
    final l = context.l;
    final un = _choix.length == 1;
    final fichiers = _fichiersChoisis;
    _menu(position, [
      if (un) (Icons.open_in_new, l.open, () => _ouvrir(cle), false),
      (Icons.download_outlined, l.download, _telechargerChoix, false),
      if (un) (Icons.edit_outlined, l.rename, _renommer, false),
      (Icons.drive_file_move_outlined, l.move, _deplacer, false),
      if (fichiers.isNotEmpty && _dossiersChoisis.isEmpty) (Icons.photo_album_outlined, l.addToAlbum, _album, false),
      (Icons.delete_outline, l.toTrash, _corbeille, true),
    ]);
  }

  /// Clic droit dans le vide.
  void _menuFond(Offset position) {
    final page = _page;
    if (page == null) return;
    final l = context.l;
    final album = page.folder.root == SafeboxRoot.albums && page.folder.parentId == null;
    _rienChoisir();
    _menu(position, [
      (Icons.create_new_folder_outlined, album ? l.newAlbum : l.newFolder, _nouveauDossier, false),
      (Icons.insert_drive_file_outlined, l.addFiles, () => pickFilesAndImport(context, page.folder), false),
      (Icons.folder_outlined, l.addFolder, () => pickFolderAndImport(context, page.folder), false),
      (Icons.select_all, l.selectAll, _ordre.isEmpty ? null : _toutChoisir, false),
      (Icons.refresh, l.refresh, _charger, false),
    ]);
  }

  // ── Écran ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) {
      return _erreur != null ? ErrorPanel(error: _erreur, onRetry: _charger) : const Center(child: CircularProgressIndicator());
    }
    return DropTarget(
      onDragEntered: (_) => setState(() => _survol = true),
      onDragExited: (_) => setState(() => _survol = false),
      onDragDone: (d) {
        setState(() => _survol = false);
        final chemins = [for (final f in d.files) f.path].where((p) => p.isNotEmpty).toList();
        if (chemins.isNotEmpty) importPaths(context, chemins, page.folder);
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): _toutChoisir,
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): _toutChoisir,
          const SingleActivator(LogicalKeyboardKey.delete): _corbeille,
          const SingleActivator(LogicalKeyboardKey.f2): _renommer,
          const SingleActivator(LogicalKeyboardKey.escape): _rienChoisir,
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (_choix.length == 1) _ouvrir(_choix.single);
          },
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: Stack(children: [
            Column(children: [
              _Entete(
                page: page,
                onBack: widget.onBack,
                onOpenFolder: widget.onOpenFolder,
                busy: _charge,
                onRefresh: _charger,
                onNewFolder: _nouveauDossier,
                onDownloadFolder: _fichiers.isNotEmpty || page.folders.isNotEmpty ? () => _telechargerDossier(page.folder) : null,
              ),
              ?_filtres(context),
              if (_choix.isNotEmpty)
                _BarreSelection(
                  count: _choix.length,
                  onDownload: _telechargerChoix,
                  onRename: _choix.length == 1 ? _renommer : null,
                  onMove: _deplacer,
                  onAlbum: _fichiersChoisis.isNotEmpty && _dossiersChoisis.isEmpty ? _album : null,
                  onTrash: _corbeille,
                  onClear: _rienChoisir,
                ),
              Expanded(child: _contenu(context, page)),
            ]),
            if (_survol) Positioned.fill(child: _Depot(nom: folderName(context, page.folder))),
          ]),
        ),
      ),
    );
  }

  Widget _contenu(BuildContext context, SafeboxFolderPage page) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final jours = _parJour(_visibles);
    return GestureDetector(
      // Clic dans le vide : on désélectionne ; clic droit : menu du dossier.
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _focus.requestFocus();
        if (_choix.isNotEmpty) _rienChoisir();
      },
      onSecondaryTapUp: (d) => _menuFond(d.globalPosition),
      child: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(controller: _defilement, slivers: [
          if (page.folders.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final f in page.folders)
                    _Element(
                      cle: (dossier: true, id: f.id),
                      selected: _choix.contains((dossier: true, id: f.id)),
                      onTap: _clic,
                      onMenu: _menuElement,
                      child: _SousDossier(folder: f, selected: _choix.contains((dossier: true, id: f.id))),
                    ),
                ]),
              ),
            ),
          if (_fichiers.isEmpty && page.folders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(rootIcon(widget.root), size: 48, color: Palette.muted),
                  const SizedBox(height: 12),
                  Text(l.folderEmpty, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(l.folderEmptyHint, style: t.bodySmall),
                ]),
              ),
            ),
          for (final (jour, fichiers) in jours) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 10),
              sliver: SliverToBoxAdapter(child: Text(_titreJour(context, jour), style: t.titleMedium)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: _grille(fichiers),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Text(l.folderKeysHint, style: t.bodySmall?.copyWith(color: Palette.muted)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _grille(List<SafeboxFile> fichiers) {
    final visuel = widget.root == SafeboxRoot.photos || widget.root == SafeboxRoot.videos || widget.root == SafeboxRoot.albums;
    Widget element(SafeboxFile f, Widget enfant) {
      final cle = (dossier: false, id: f.id);
      return _Element(
        cle: cle,
        selected: _choix.contains(cle),
        onTap: _clic,
        onMenu: _menuElement,
        child: enfant,
      );
    }

    if (visuel) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 6, crossAxisSpacing: 6),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final f = fichiers[i];
            final choisi = _choix.contains((dossier: false, id: f.id));
            return element(
              f,
              Tooltip(
                message: f.name,
                waitDuration: const Duration(milliseconds: 600),
                child: Stack(fit: StackFit.expand, children: [
                  Thumbnail(file: f),
                  if (choisi)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.brand.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Palette.brand, width: 3),
                      ),
                    ),
                  if (choisi)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Palette.brand,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                ]),
              ),
            );
          },
          childCount: fichiers.length,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => element(fichiers[i], _Ligne(file: fichiers[i], selected: _choix.contains((dossier: false, id: fichiers[i].id)))),
        childCount: fichiers.length,
      ),
    );
  }

  /// Les fichiers groupés par jour d'ajout, dans l'ordre rendu par le serveur.
  static List<(DateTime?, List<SafeboxFile>)> _parJour(List<SafeboxFile> fichiers) {
    final out = <(DateTime?, List<SafeboxFile>)>[];
    for (final f in fichiers) {
      final d = f.createdAt;
      final jour = d == null ? null : DateTime(d.year, d.month, d.day);
      if (out.isNotEmpty && out.last.$1 == jour) {
        out.last.$2.add(f);
      } else {
        out.add((jour, [f]));
      }
    }
    return out;
  }

  String _titreJour(BuildContext context, DateTime? jour) {
    final l = context.l;
    if (jour == null) return l.dateUnknown;
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final diff = aujourdhui.difference(jour).inDays;
    if (diff == 0) return l.dateToday;
    if (diff == 1) return l.dateYesterday;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat(jour.year == now.year ? 'EEEE d MMMM' : 'd MMMM y', locale).format(jour);
  }
}

/// Un élément cliquable : clic (sélection), double-clic (ouvrir), clic droit (menu).
class _Element extends StatelessWidget {
  const _Element({
    required this.cle,
    required this.selected,
    required this.onTap,
    required this.onMenu,
    required this.child,
  });
  final _Cle cle;
  final bool selected;

  /// Clic ; un second clic rapide ouvre (voir _clic).
  final void Function(_Cle) onTap;
  final void Function(_Cle, Offset) onMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(cle),
          onSecondaryTapUp: (d) => onMenu(cle, d.globalPosition),
          child: child,
        ),
      );
}

class _Entete extends StatelessWidget {
  const _Entete({
    required this.page,
    required this.onBack,
    required this.onOpenFolder,
    required this.busy,
    required this.onRefresh,
    required this.onNewFolder,
    required this.onDownloadFolder,
  });
  final SafeboxFolderPage page;
  final VoidCallback? onBack;
  final void Function(int) onOpenFolder;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onNewFolder;
  final VoidCallback? onDownloadFolder;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final album = page.folder.root == SafeboxRoot.albums && page.folder.parentId == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 32, 8),
      child: Row(children: [
        if (onBack != null) IconButton(tooltip: l.back, onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Ariane(page: page, onOpen: onOpenFolder),
            Text(folderName(context, page.folder), style: t.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        _Ajouter(folder: page.folder),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onNewFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: Text(album ? l.newAlbum : l.newFolder),
        ),
        const SizedBox(width: 8),
        if (onDownloadFolder != null)
          OutlinedButton.icon(
            onPressed: onDownloadFolder,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(l.downloadFolder),
          ),
        const SizedBox(width: 8),
        IconButton(tooltip: l.refresh, onPressed: busy ? null : onRefresh, icon: const Icon(Icons.refresh)),
      ]),
    );
  }
}

/// La barre des actions sur la sélection.
class _BarreSelection extends StatelessWidget {
  const _BarreSelection({
    required this.count,
    required this.onDownload,
    required this.onRename,
    required this.onMove,
    required this.onAlbum,
    required this.onTrash,
    required this.onClear,
  });
  final int count;
  final VoidCallback onDownload;
  final VoidCallback? onRename;
  final VoidCallback onMove;
  final VoidCallback? onAlbum;
  final VoidCallback onTrash;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 32, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Palette.brandContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        IconButton(tooltip: l.clearSelection, onPressed: onClear, icon: const Icon(Icons.close)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(l.selectedCount(count),
              style: const TextStyle(fontWeight: FontWeight.w500, color: Palette.brandDark), overflow: TextOverflow.ellipsis),
        ),
        TextButton.icon(onPressed: onDownload, icon: const Icon(Icons.download_outlined, size: 18), label: Text(l.download)),
        if (onRename != null)
          TextButton.icon(onPressed: onRename, icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l.rename)),
        TextButton.icon(onPressed: onMove, icon: const Icon(Icons.drive_file_move_outlined, size: 18), label: Text(l.move)),
        if (onAlbum != null)
          TextButton.icon(onPressed: onAlbum, icon: const Icon(Icons.photo_album_outlined, size: 18), label: Text(l.addToAlbum)),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Palette.danger),
          onPressed: onTrash,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l.toTrash),
        ),
      ]),
    );
  }
}

class _Ariane extends StatelessWidget {
  const _Ariane({required this.page, required this.onOpen});
  final SafeboxFolderPage page;
  final void Function(int) onOpen;

  @override
  Widget build(BuildContext context) {
    final avant = page.breadcrumbs.where((b) => b.id != page.folder.id).toList();
    if (avant.isEmpty) return const SizedBox.shrink();
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final b in avant) ...[
        InkWell(
          onTap: () => onOpen(b.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(folderName(context, b), style: const TextStyle(color: Palette.brand, fontSize: 13)),
          ),
        ),
        const Icon(Icons.chevron_right, size: 16, color: Palette.muted),
      ],
    ]);
  }
}

class _SousDossier extends StatelessWidget {
  const _SousDossier({required this.folder, required this.selected});
  final SafeboxFolder folder;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final n = folder.fileCount;
    return SizedBox(
      width: 220,
      child: Card(
        color: selected ? Palette.brandContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? Palette.brand : Palette.border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.folder_outlined, color: Palette.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folderName(context, folder), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (n != null) Text(context.l.fileCount(n), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.file, required this.selected});
  final SafeboxFile file;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Card(
          color: selected ? Palette.brandContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? Palette.brand : Palette.border, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              SizedBox(width: 44, height: 44, child: Thumbnail(file: file)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Text(formatBytes(context, file.plainBytes), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

/// « Ajouter » : des fichiers ou un dossier du PC.
class _Ajouter extends StatelessWidget {
  const _Ajouter({required this.folder});
  final SafeboxFolder folder;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.insert_drive_file_outlined, size: 20),
          onPressed: () => pickFilesAndImport(context, folder),
          child: Text(l.addFiles),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_outlined, size: 20),
          onPressed: () => pickFolderAndImport(context, folder),
          child: Text(l.addFolder),
        ),
      ],
      builder: (context, menu, _) => FilledButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.add, size: 18),
        label: Text(l.add),
      ),
    );
  }
}

/// Le voile pendant qu'on survole le dossier avec des fichiers.
class _Depot extends StatelessWidget {
  const _Depot({required this.nom});
  final String nom;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Palette.brandContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.brand, width: 2),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.file_upload_outlined, size: 48, color: Palette.brandDark),
              const SizedBox(height: 12),
              Text(context.l.dropHere(nom),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Palette.brandDark)),
            ]),
          ),
        ),
      );
}
