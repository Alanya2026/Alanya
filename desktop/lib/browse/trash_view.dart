// La corbeille (lot D5) : restaurer, supprimer définitivement, vider. Les
// éléments y restent un temps fixé par le serveur et comptent dans l'espace
// jusqu'à leur suppression.

import 'dart:async';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../ui/common.dart';
import 'actions.dart';
import 'thumbnail.dart';

class TrashView extends StatefulWidget {
  const TrashView({super.key});

  @override
  State<TrashView> createState() => _TrashViewState();
}

class _TrashViewState extends State<TrashView> {
  SafeboxTrash? _corbeille;
  Object? _erreur;
  bool _occupe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_corbeille == null && _erreur == null) _charger();
  }

  Future<void> _charger() async {
    try {
      final t = await context.vault.api.fetchSafeboxTrash();
      if (mounted) {
        setState(() {
          _corbeille = t;
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  /// Une action, puis la corbeille et l'espace se relisent.
  Future<void> _faire(Future<void> Function() action, {String? ok}) async {
    setState(() => _occupe = true);
    try {
      await action();
      if (mounted && ok != null) showSnack(context, ok);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      await _charger();
      if (mounted) {
        setState(() => _occupe = false);
        unawaited(context.vault.refresh());
      }
    }
  }

  Future<void> _vider() async {
    final l = context.l;
    final api = context.vault.api;
    if (!await confirmDanger(context, message: l.emptyTrashConfirm, action: l.emptyTrash)) return;
    await _faire(api.emptySafeboxTrash);
  }

  Future<void> _restaurerFichier(SafeboxFile f) {
    final vault = context.vault;
    return _faire(() async {
      final r = await vault.api.restoreSafeboxFile(f.id);
      vault.folderChanged(r.folderId);
    }, ok: context.l.restored);
  }

  Future<void> _restaurerDossier(SafeboxFolder d) {
    final vault = context.vault;
    return _faire(() async {
      final r = await vault.api.restoreSafeboxFolder(d.id);
      if (r.parentId != null) vault.folderChanged(r.parentId!);
    }, ok: context.l.restored);
  }

  Future<void> _supprimer(String nom, Future<void> Function() action) async {
    final l = context.l;
    if (!await confirmDanger(context, message: l.deleteForeverConfirm(nom), action: l.deleteForever)) return;
    await _faire(action);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final c = _corbeille;
    if (c == null) {
      return _erreur != null ? ErrorPanel(error: _erreur, onRetry: _charger) : const Center(child: CircularProgressIndicator());
    }
    final quota = context.vault.overview?.quota;
    return ListView(padding: const EdgeInsets.fromLTRB(32, 24, 32, 32), children: [
      Row(children: [
        Expanded(child: Text(l.navTrash, style: t.headlineSmall)),
        if (quota != null && quota.trashBytes > 0) ...[
          Text(l.freeUpTrash(formatBytes(context, quota.trashBytes)), style: t.bodySmall),
          const SizedBox(width: 12),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Palette.danger),
          onPressed: c.isEmpty || _occupe ? null : _vider,
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: Text(l.emptyTrash),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: l.refresh, onPressed: _occupe ? null : _charger, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 6),
      Text(l.trashHint(c.trashDays), style: t.bodySmall?.copyWith(height: 1.4)),
      if (_occupe) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      const SizedBox(height: 20),
      if (c.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(children: [
            const Icon(Icons.delete_outline, size: 48, color: Palette.muted),
            const SizedBox(height: 12),
            Text(l.trashEmptyState, style: t.titleMedium),
          ]),
        ),
      for (final d in c.folders)
        _Ligne(
          vignette: const Icon(Icons.folder_outlined, color: Palette.brand, size: 28),
          titre: folderName(context, d),
          detail: [rootName(context, d.root), if (d.storedBytes != null) formatBytes(context, d.storedBytes!), _purge(context, d.purgeAt)]
              .whereType<String>()
              .join(' · '),
          occupe: _occupe,
          onRestore: () => _restaurerDossier(d),
          onDelete: () => _supprimer(folderName(context, d), () => context.vault.api.deleteTrashedSafeboxFolder(d.id)),
        ),
      for (final f in c.files)
        _Ligne(
          vignette: SizedBox(width: 44, height: 44, child: Thumbnail(file: f)),
          titre: f.name,
          detail: [
            if (f.folderName != null || f.folderRoot != null)
              l.trashFrom(f.folderName ?? rootName(context, f.folderRoot!)),
            formatBytes(context, f.storedBytes),
            _purge(context, f.purgeAt),
          ].whereType<String>().join(' · '),
          occupe: _occupe,
          onRestore: () => _restaurerFichier(f),
          onDelete: () => _supprimer(f.name, () => context.vault.api.deleteTrashedSafeboxFile(f.id)),
        ),
    ]);
  }

  static String? _purge(BuildContext context, DateTime? quand) {
    if (quand == null) return null;
    final jours = quand.difference(DateTime.now()).inHours ~/ 24;
    return context.l.trashPurgeIn(jours < 0 ? 0 : jours);
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.vignette,
    required this.titre,
    required this.detail,
    required this.occupe,
    required this.onRestore,
    required this.onDelete,
  });
  final Widget vignette;
  final String titre;
  final String detail;
  final bool occupe;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            SizedBox(width: 44, height: 44, child: Center(child: vignette)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: occupe ? null : onRestore,
              icon: const Icon(Icons.restore, size: 18),
              label: Text(l.restore),
            ),
            IconButton(
              tooltip: l.deleteForever,
              onPressed: occupe ? null : onDelete,
              icon: const Icon(Icons.delete_forever_outlined, color: Palette.danger),
            ),
          ]),
        ),
      ),
    );
  }
}
