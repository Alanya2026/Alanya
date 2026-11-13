// « Libérer de l'espace » (lot D5) : les plus gros fichiers du coffre, à
// cocher puis mettre à la corbeille partout (un contenu rangé aussi dans un
// album ne libère sa place que si tous ses exemplaires partent), et la
// corbeille à vider. Comme le téléphone.

import 'dart:async';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../ui/common.dart';
import 'actions.dart';
import 'thumbnail.dart';

class FreeUpView extends StatefulWidget {
  const FreeUpView({super.key, required this.onOpenTrash});
  final VoidCallback onOpenTrash;

  @override
  State<FreeUpView> createState() => _FreeUpViewState();
}

class _FreeUpViewState extends State<FreeUpView> {
  List<SafeboxFile>? _fichiers;
  int _corbeille = 0;
  Object? _erreur;
  final Set<int> _choisis = {};
  bool _occupe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fichiers == null && _erreur == null) _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await context.vault.api.fetchSafeboxLargest(limit: 100);
      if (!mounted) return;
      setState(() {
        _fichiers = r.files;
        _corbeille = r.trashBytes;
        _erreur = null;
        _choisis.removeWhere((id) => !r.files.any((f) => f.id == id));
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

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

  Future<void> _viderCorbeille() async {
    final l = context.l;
    if (!await confirmDanger(context, message: l.emptyTrashConfirm, action: l.emptyTrash)) return;
    if (mounted) await _faire(context.vault.api.emptySafeboxTrash);
  }

  Future<void> _mettreALaCorbeille() {
    final vault = context.vault;
    final ids = _choisis.toList();
    return _faire(() async {
      for (final id in ids) {
        await vault.api.trashSafeboxFile(id, everywhere: true);
        await vault.downloads.evict(id);
      }
      _choisis.clear();
    }, ok: context.l.movedToTrash(ids.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final fichiers = _fichiers;
    if (fichiers == null) {
      return _erreur != null ? ErrorPanel(error: _erreur, onRetry: _charger) : const Center(child: CircularProgressIndicator());
    }
    final poids = fichiers.where((f) => _choisis.contains(f.id)).fold<int>(0, (s, f) => s + f.storedBytes);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(32, 24, 32, 24), children: [
          Row(children: [
            Expanded(child: Text(l.freeUp, style: t.headlineSmall)),
            IconButton(tooltip: l.refresh, onPressed: _occupe ? null : _charger, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 6),
          Text(l.freeUpIntro, style: t.bodySmall?.copyWith(height: 1.4)),
          const SizedBox(height: 16),
          if (_corbeille > 0)
            Card(
              color: Palette.warningContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(children: [
                  const Icon(Icons.delete_outline, color: Palette.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.freeUpTrash(formatBytes(context, _corbeille)), style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(l.freeUpHint, style: t.bodySmall),
                    ]),
                  ),
                  TextButton(onPressed: widget.onOpenTrash, child: Text(l.open)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Palette.danger),
                    onPressed: _occupe ? null : _viderCorbeille,
                    child: Text(l.emptyTrash),
                  ),
                ]),
              ),
            ),
          if (_occupe) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 12),
          if (fichiers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(child: Text(l.freeUpNothing, style: t.titleMedium)),
            ),
          for (final f in fichiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Card(
                color: _choisis.contains(f.id) ? Palette.brandContainer : null,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _occupe
                      ? null
                      : () => setState(() {
                            if (!_choisis.remove(f.id)) _choisis.add(f.id);
                          }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(children: [
                      Checkbox(
                        value: _choisis.contains(f.id),
                        onChanged: _occupe
                            ? null
                            : (v) => setState(() => v == true ? _choisis.add(f.id) : _choisis.remove(f.id)),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(width: 44, height: 44, child: Thumbnail(file: f)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (f.folderName != null || f.folderRoot != null)
                            Text(f.folderName ?? rootName(context, f.folderRoot!), style: t.bodySmall),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(formatBytes(context, f.storedBytes), style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
      if (_choisis.isNotEmpty)
        Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Palette.border))),
          padding: const EdgeInsets.fromLTRB(32, 10, 32, 10),
          child: Row(children: [
            Expanded(child: Text(l.freeUpSelected(_choisis.length, formatBytes(context, poids)), style: const TextStyle(fontWeight: FontWeight.w500))),
            TextButton(onPressed: _occupe ? null : () => setState(_choisis.clear), child: Text(l.clearSelection)),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Palette.danger),
              onPressed: _occupe ? null : _mettreALaCorbeille,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l.toTrash),
            ),
          ]),
        ),
    ]);
  }
}
