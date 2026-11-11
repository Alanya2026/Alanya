// Ajouter au coffre (lot D4) : analyse de ce qui a été choisi ou déposé,
// résumé avant d'envoyer (envois, doublons, place libre), puis envois.

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/importer.dart';
import '../ui/common.dart';

/// « Ajouter » → « Des fichiers… ».
Future<void> pickFilesAndImport(BuildContext context, SafeboxFolder target) async {
  final choisis = await openFiles();
  if (choisis.isEmpty || !context.mounted) return;
  await importPaths(context, [for (final f in choisis) f.path], target);
}

/// « Ajouter » → « Un dossier… ».
Future<void> pickFolderAndImport(BuildContext context, SafeboxFolder target) async {
  final chemin = await getDirectoryPath();
  if (chemin == null || !context.mounted) return;
  await importPaths(context, [chemin], target);
}

/// Analyse [paths], montre le résumé, puis lance les envois.
Future<void> importPaths(BuildContext context, List<String> paths, SafeboxFolder target) async {
  final l = context.l;
  final vault = context.vault;
  final messager = ScaffoldMessenger.of(context);
  final importer = vault.importer;
  if (importer.busy) {
    messager.showSnackBar(SnackBar(content: Text(l.importBusy)));
    return;
  }
  if (vault.overview == null) await vault.refresh();
  final overview = vault.overview;
  if (overview == null) {
    messager.showSnackBar(SnackBar(content: Text(l.errorNetwork)));
    return;
  }
  final ImportPlan plan;
  try {
    plan = await importer.plan(paths, target, overview);
  } catch (e) {
    debugPrint('[Coffre] analyse impossible : $e');
    messager.showSnackBar(SnackBar(content: Text(l.importFailed)));
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _Resume(plan: plan, limits: overview.limits),
  );
  if (ok != true || !context.mounted) return;
  await importer.run(plan, overview.limits);
  // Ajouts sans copie et sous-dossiers recréés : la cible se recharge (les
  // fichiers envoyés la rechargent à leur arrivée).
  vault.folderChanged(target.id);
}

class _Resume extends StatelessWidget {
  const _Resume({required this.plan, required this.limits});
  final ImportPlan plan;
  final SafeboxLimits limits;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final manque = plan.sendBytes - plan.freeBytes;
    Widget ligne(IconData icone, String texte, {Color? couleur}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icone, size: 20, color: couleur ?? Palette.brand),
            const SizedBox(width: 12),
            Expanded(child: Text(texte, style: TextStyle(color: couleur, height: 1.4))),
          ]),
        );
    return AlertDialog(
      title: Text(l.importTitle(folderName(context, plan.target))),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, minWidth: 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (plan.isEmpty) ligne(Icons.check_circle_outline, l.importNothing),
            if (plan.send.isNotEmpty)
              ligne(Icons.upload_outlined, l.importSend(plan.send.length, formatBytes(context, plan.sendBytes))),
            if (plan.link.isNotEmpty) ligne(Icons.link, l.importLink(plan.link.length)),
            if (plan.already > 0) ligne(Icons.done_all, l.importAlready(plan.already)),
            for (final MapEntry(key: racine, value: n) in plan.diverted.entries)
              ligne(rootIcon(racine), l.importDiverted(n, rootName(context, racine))),
            if (plan.tooLarge.isNotEmpty)
              ligne(Icons.block_outlined, l.importTooLarge(plan.tooLarge.length, formatBytes(context, limits.maxFileBytes)),
                  couleur: Palette.danger),
            if (plan.ignored > 0) ligne(Icons.visibility_off_outlined, l.importIgnored(plan.ignored), couleur: Palette.muted),
            if (plan.send.isNotEmpty) ...[
              const Divider(height: 24),
              Text(l.importFree(formatBytes(context, plan.freeBytes)), style: t.bodyMedium),
              if (manque > 0) ...[
                const SizedBox(height: 6),
                Text(l.importNoRoom(formatBytes(context, manque)), style: const TextStyle(color: Palette.danger)),
              ],
              const SizedBox(height: 12),
              Text(l.importOriginal, style: t.bodySmall?.copyWith(height: 1.4)),
            ],
          ]),
        ),
      ),
      actions: plan.isEmpty
          ? [FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.close))]
          : [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              FilledButton(
                onPressed: plan.send.isNotEmpty && !plan.fits ? null : () => Navigator.pop(context, true),
                child: Text(plan.send.isEmpty ? l.add : l.importStart),
              ),
            ],
    );
  }
}
