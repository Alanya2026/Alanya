// Écran « Sauvegarde du PC » (lot D6) : les dossiers choisis et ce qui en
// part, l'état des passages, « Sauvegarder maintenant ».

import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../browse/actions.dart';
import '../core/pc_backup.dart';
import '../ui/common.dart';

const _types = [SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.audios, SafeboxFamily.documents];

String familyName(BuildContext context, SafeboxFamily f) => rootName(context, f.root);

class PcBackupView extends StatelessWidget {
  const PcBackupView({super.key});

  Future<void> _ajouter(BuildContext context, PcBackup b) async {
    final l = context.l;
    final chemin = await getDirectoryPath(confirmButtonText: l.pcBackupStart);
    if (chemin == null || !context.mounted) return;
    if (b.settings.folders.any((f) => f.path == chemin)) {
      showSnack(context, l.pcBackupAlreadyAdded);
      return;
    }
    final nom = Directory(chemin).uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? chemin;
    final dossier = await showDialog<PcBackupFolder>(
      context: context,
      builder: (_) => _Estimation(backup: b, folder: PcBackupFolder(path: chemin, name: nom, families: _types.toSet())),
    );
    if (dossier == null) return;
    await b.update(b.settings.copyWith(enabled: true, folders: [...b.settings.folders, dossier]));
  }

  Future<void> _retirer(BuildContext context, PcBackup b, PcBackupFolder d) async {
    final l = context.l;
    if (!await confirmDanger(context, message: l.pcBackupRemoveConfirm(d.name), action: l.pcBackupRemoveFolder)) return;
    await b.update(b.settings.copyWith(folders: [for (final f in b.settings.folders) if (f.path != d.path) f]));
  }

  /// Le nom affiché dans le coffre (dossier d'origine des prochains
  /// fichiers) ; le chemin sur l'ordinateur ne change pas.
  Future<void> _renommer(BuildContext context, PcBackup b, PcBackupFolder d) async {
    final l = context.l;
    final nom = await askName(
      context,
      title: l.pcBackupRename,
      label: l.pcBackupNameLabel,
      action: l.pcBackupRename,
      initial: d.name,
      maxLength: 80,
      hint: l.pcBackupRenameHint,
    );
    if (nom == null || nom == d.name || !context.mounted) return;
    try {
      await b.renameFolder(d, nom);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  /// « Retirer de l'ordinateur après la sauvegarde » : une confirmation à
  /// l'activation, puis les retraits se font tout seuls.
  Future<void> _retraitOrdinateur(BuildContext context, PcBackup b, bool oui) async {
    final l = context.l;
    if (oui) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.pcRemoveConfirmTitle),
          content: SizedBox(width: 460, child: Text(l.pcRemoveConfirm, style: const TextStyle(height: 1.45))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.pcRemoveConfirmAction)),
          ],
        ),
      );
      if (ok != true) return;
    }
    await b.update(b.settings.copyWith(removeFromPc: oui));
    if (oui) await b.removeSaved();
  }

  Future<void> _basculerType(BuildContext context, PcBackup b, PcBackupFolder d, SafeboxFamily f, bool oui) async {
    final types = {...d.families};
    oui ? types.add(f) : types.remove(f);
    if (types.isEmpty) {
      showSnack(context, context.l.pcBackupNoType);
      return;
    }
    await b.update(b.settings.copyWith(folders: [for (final x in b.settings.folders) x.path == d.path ? d.withFamilies(types) : x]));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final b = context.vault.pcBackup;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        final s = b.settings;
        return ListView(padding: const EdgeInsets.fromLTRB(32, 24, 32, 32), children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.navPcBackup, style: t.headlineSmall),
                const SizedBox(height: 6),
                Text(l.pcBackupIntro, style: t.bodySmall?.copyWith(height: 1.45)),
                const SizedBox(height: 20),
                Card(
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      title: Text(l.pcBackupSwitch, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(l.pcBackupOpenOnly),
                      value: s.enabled,
                      onChanged: s.folders.isEmpty ? null : (v) => b.update(s.copyWith(enabled: v)),
                    ),
                    if (s.enabled && s.folders.isNotEmpty) ...[
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _Etat(backup: b),
                    ],
                  ]),
                ),
                if (s.folders.any((d) => d.families.contains(SafeboxFamily.photos) || d.families.contains(SafeboxFamily.videos))) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        title: Text(l.pcRemoveTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(l.pcRemoveHint),
                        value: s.removeFromPc,
                        onChanged: (v) => _retraitOrdinateur(context, b, v),
                      ),
                      if (s.removeFromPc)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.pcRemoveWhen, style: t.bodyMedium),
                            const SizedBox(height: 8),
                            SegmentedButton<int>(
                              segments: [
                                ButtonSegment(value: 30, label: Text(l.pcRemoveAfter(30))),
                                ButtonSegment(value: 7, label: Text(l.pcRemoveAfter(7))),
                                ButtonSegment(value: 0, label: Text(l.pcRemoveNow)),
                              ],
                              selected: {s.removeAfterDays},
                              showSelectedIcon: false,
                              onSelectionChanged: (v) async {
                                await b.update(s.copyWith(removeAfterDays: v.first));
                                await b.removeSaved();
                              },
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: Text(l.pcBackupFolders.toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: Palette.muted)),
                  ),
                  FilledButton.icon(
                    onPressed: () => _ajouter(context, b),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l.pcBackupAddFolder),
                  ),
                ]),
                const SizedBox(height: 10),
                if (s.folders.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(children: [
                        const Icon(Icons.folder_open_outlined, color: Palette.muted),
                        const SizedBox(width: 14),
                        Expanded(child: Text(l.pcBackupNoFolder)),
                      ]),
                    ),
                  ),
                for (final d in s.folders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.folder_outlined, color: Palette.brand),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                                Text(
                                  Directory(d.path).existsSync() ? d.path : '${d.path} · ${l.pcBackupFolderMissing}',
                                  style: t.bodySmall?.copyWith(color: Directory(d.path).existsSync() ? null : Palette.danger),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                            ),
                            IconButton(
                              tooltip: l.pcBackupRename,
                              onPressed: () => _renommer(context, b, d),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: l.pcBackupRemoveFolder,
                              onPressed: () => _retirer(context, b, d),
                              icon: const Icon(Icons.close),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            for (final f in _types)
                              FilterChip(
                                avatar: Icon(familyIcon(f), size: 18),
                                label: Text(familyName(context, f)),
                                selected: d.families.contains(f),
                                onSelected: (v) => _basculerType(context, b, d, f, v),
                              ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

/// L'état de la sauvegarde : passage en cours, ce qui reste, dernier passage.
class _Etat extends StatelessWidget {
  const _Etat({required this.backup});
  final PcBackup backup;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final b = backup;
    return ValueListenableBuilder<SafeboxBackupProgress?>(
      valueListenable: b.engine.progress,
      builder: (context, p, _) {
        final enCours = b.running;
        final String titre;
        double? barre;
        if (enCours && (p?.listing ?? true)) {
          titre = l.pcBackupListing;
        } else if (enCours && p != null && p.analysing) {
          titre = l.pcBackupChecking(p.checked, p.toCheck);
          barre = p.toCheck > 0 ? p.checked / p.toCheck : null;
        } else {
          titre = l.pcBackupRemaining(p?.remaining ?? 0);
        }
        final r = b.lastReport;
        final quand = b.lastRunAt;
        final details = <String>[
          if (r != null) l.pcBackupQueued(r.queued),
          if (r != null && r.alreadySaved > 0) l.pcBackupAlready(r.alreadySaved),
          if (r != null && r.skipped > 0) l.pcBackupSkipped(r.skipped),
          if (r != null && r.noRoom > 0) l.pcBackupNoRoom(r.noRoom),
          if (p != null && p.unreadable > 0) l.pcBackupUnreadable(p.unreadable),
          if (b.lastRemoval case final rt?) l.pcRemoved(rt.count, formatBytes(context, rt.bytes)),
        ];
        final max = context.vault.overview?.limits.maxFileBytes ?? 0;
        final locale = Localizations.localeOf(context).toLanguageTag();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                enCours ? Icons.sync : ((p?.remaining ?? 0) == 0 ? Icons.check_circle_outline : Icons.schedule),
                color: (r?.noRoom ?? 0) > 0 ? Palette.warning : Palette.brand,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titre, style: const TextStyle(fontWeight: FontWeight.w500))),
              OutlinedButton.icon(
                onPressed: enCours ? null : b.runNow,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: Text(l.pcBackupRunNow),
              ),
            ]),
            if (enCours) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: barre, minHeight: 6, backgroundColor: Palette.border),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              quand == null ? l.pcBackupNever : l.pcBackupLast(DateFormat.Hm(locale).format(quand)),
              style: t.bodySmall,
            ),
            if (details.isNotEmpty) Text(details.join(' · '), style: t.bodySmall),
            if (b.tooLarge > 0 && max > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.pcBackupTooLarge(b.tooLarge, formatBytes(context, max)),
                    style: t.bodySmall?.copyWith(color: Palette.warning)),
              ),
            if (b.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.pcBackupFailed(errorText(context, b.lastError)), style: t.bodySmall?.copyWith(color: Palette.danger)),
              ),
          ]),
        );
      },
    );
  }
}

/// Avant d'ajouter un dossier : ce qui part, combien, et la place libre.
class _Estimation extends StatefulWidget {
  const _Estimation({required this.backup, required this.folder});
  final PcBackup backup;
  final PcBackupFolder folder;

  @override
  State<_Estimation> createState() => _EstimationState();
}

class _EstimationState extends State<_Estimation> {
  late Set<SafeboxFamily> _choisis = {...widget.folder.families};
  PcBackupEstimate? _tout;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    // Une seule lecture, tous types : les cases recalculent sans relire.
    widget.backup.estimate(widget.folder.withFamilies(_types.toSet())).then((e) {
      if (mounted) setState(() => _tout = e);
    }, onError: (Object e) {
      if (mounted) setState(() => _erreur = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final e = _tout;
    final n = e == null ? 0 : _choisis.fold<int>(0, (s, f) => s + (e.counts[f] ?? 0));
    final poids = e == null ? 0 : _choisis.fold<int>(0, (s, f) => s + (e.bytes[f] ?? 0));
    final quota = context.vault.overview?.quota;
    return AlertDialog(
      title: Text(l.pcBackupEstimateTitle(widget.folder.name)),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.folder.path, style: t.bodySmall),
          const SizedBox(height: 16),
          Text(l.pcBackupTypes, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final f in _types)
              FilterChip(
                avatar: Icon(familyIcon(f), size: 18),
                label: Text(e == null ? familyName(context, f) : '${familyName(context, f)} · ${e.counts[f] ?? 0}'),
                selected: _choisis.contains(f),
                onSelected: (v) => setState(() {
                  _choisis = {..._choisis};
                  v ? _choisis.add(f) : _choisis.remove(f);
                }),
              ),
          ]),
          const SizedBox(height: 16),
          if (_erreur != null)
            Text(errorText(context, _erreur), style: const TextStyle(color: Palette.danger))
          else if (e == null)
            const LinearProgressIndicator()
          else ...[
            Text(l.pcBackupEstimate(n, formatBytes(context, poids)), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (quota != null) ...[
              const SizedBox(height: 4),
              Text(l.importFree(formatBytes(context, quota.freeBytes)),
                  style: t.bodyMedium?.copyWith(color: poids > quota.freeBytes ? Palette.warning : null)),
            ],
          ],
          const SizedBox(height: 12),
          Text(l.pcBackupEstimateHint, style: t.bodySmall?.copyWith(height: 1.45)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _choisis.isEmpty || _erreur != null ? null : () => Navigator.pop(context, widget.folder.withFamilies(_choisis)),
          child: Text(l.pcBackupStart),
        ),
      ],
    );
  }
}
