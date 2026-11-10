// Écrans 3 et 4 : un dossier du coffre. Fil d'Ariane, sous-dossiers, puis
// les fichiers par jour d'ajout. Lecture seule (lot D2) ; la visionneuse et
// les actions arrivent avec les lots suivants.

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ui/common.dart';
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

class _FolderViewState extends State<FolderView> {
  SafeboxFolderPage? _page;
  final List<SafeboxFile> _fichiers = [];
  int? _suite;
  bool _charge = false;
  Object? _erreur;
  final _defilement = ScrollController();

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
    if (_page == null && !_charge) _charger();
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
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
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
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

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) {
      return _erreur != null ? ErrorPanel(error: _erreur, onRetry: _charger) : const Center(child: CircularProgressIndicator());
    }
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final jours = _parJour(_fichiers);
    return RefreshIndicator(
      onRefresh: _charger,
      child: CustomScrollView(controller: _defilement, slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 32, 0),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              if (widget.onBack != null)
                IconButton(tooltip: l.back, onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Ariane(page: page, onOpen: widget.onOpenFolder),
                  Text(folderName(context, page.folder), style: t.headlineSmall),
                ]),
              ),
              IconButton(tooltip: l.refresh, onPressed: _charge ? null : _charger, icon: const Icon(Icons.refresh)),
            ]),
          ),
        ),
        if (page.folders.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            sliver: SliverToBoxAdapter(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (final f in page.folders) _SousDossier(folder: f, onTap: () => widget.onOpenFolder(f.id)),
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
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  Widget _grille(List<SafeboxFile> fichiers) {
    final visuel = widget.root == SafeboxRoot.photos || widget.root == SafeboxRoot.videos || widget.root == SafeboxRoot.albums;
    if (visuel) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 6, crossAxisSpacing: 6),
        delegate: SliverChildBuilderDelegate(
          (context, i) => Tooltip(message: fichiers[i].name, waitDuration: const Duration(milliseconds: 600), child: Thumbnail(file: fichiers[i])),
          childCount: fichiers.length,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _Ligne(file: fichiers[i]),
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
  const _SousDossier({required this.folder, required this.onTap});
  final SafeboxFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = folder.fileCount;
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.file});
  final SafeboxFile file;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Card(
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
