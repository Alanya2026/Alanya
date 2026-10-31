//  Corbeille du coffre-fort : ce qui a été supprimé, et quand cela partira.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../talky_api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_widgets.dart';

class SafeboxTrashScreen extends StatefulWidget {
  const SafeboxTrashScreen({super.key});

  @override
  State<SafeboxTrashScreen> createState() => _SafeboxTrashScreenState();
}

class _SafeboxTrashScreenState extends State<SafeboxTrashScreen> {
  SafeboxTrash? _corbeille;
  Object? _erreur;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final t = await _c.api.fetchSafeboxTrash();
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

  Future<void> _agir(Future<void> Function() action, {String? message}) async {
    try {
      await action();
      if (mounted && message != null) safeboxSnack(context, message);
      await _charger();
      unawaited(_c.refreshOverview());
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _vider() async {
    final l10n = context.l10n;
    if (!await safeboxConfirm(context, message: l10n.safeboxEmptyTrashConfirm, action: l10n.safeboxEmptyTrash)) return;
    final partis = [for (final f in _corbeille?.files ?? const <SafeboxFile>[]) f.id];
    await _agir(() async {
      await _c.api.emptySafeboxTrash();
      // Ceux des dossiers supprimés partiront au tri des aperçus.
      unawaited(_c.previews.forget(partis));
    });
  }

  Future<void> _menu({SafeboxFolder? dossier, SafeboxFile? fichier}) async {
    final l10n = context.l10n;
    final nom = dossier?.name ?? fichier?.name ?? '';
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.text.titleSmall)),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.restore), title: Text(l10n.safeboxRestore), onTap: () => Navigator.pop(ctx, 'restaurer')),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: ctx.colors.error),
              title: Text(l10n.safeboxDeleteForever, style: TextStyle(color: ctx.colors.error)),
              onTap: () => Navigator.pop(ctx, 'supprimer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'restaurer') {
      await _agir(
        () => dossier != null ? _c.api.restoreSafeboxFolder(dossier.id) : _c.api.restoreSafeboxFile(fichier!.id),
        message: l10n.safeboxRestored,
      );
    } else if (await safeboxConfirm(context, message: l10n.safeboxDeleteForeverConfirm(nom), action: l10n.safeboxDeleteForever)) {
      await _agir(() async {
        if (dossier != null) return _c.api.deleteTrashedSafeboxFolder(dossier.id);
        await _c.api.deleteTrashedSafeboxFile(fichier!.id);
        unawaited(_c.previews.forget([fichier.id]));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = _corbeille;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.safeboxTrash),
        actions: [
          if (t != null && !t.isEmpty)
            IconButton(tooltip: l10n.safeboxEmptyTrash, icon: const Icon(Icons.delete_sweep_outlined), onPressed: _vider),
        ],
      ),
      body: t == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: AppSpacing.card,
                    child: Text(l10n.safeboxTrashExplain(t.trashDays),
                        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                  ),
                  if (t.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Center(child: Text(l10n.safeboxTrashEmpty, style: context.text.titleMedium)),
                    ),
                  for (final d in t.folders)
                    ListTile(
                      leading: Icon(Icons.folder_outlined, color: context.colors.onSurfaceVariant),
                      title: Text(d.name ?? ''),
                      subtitle: Text([
                        l10n.safeboxRootSummary(d.fileCount ?? 0, formatBytes(d.storedBytes ?? 0, l10n)),
                        l10n.safeboxTrashPurgeOn(safeboxDate(context, d.purgeAt)),
                      ].join(' · ')),
                      onTap: () => _menu(dossier: d),
                    ),
                  for (final f in t.files)
                    ListTile(
                      leading: SafeboxFileThumb(file: f, size: 40),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${formatBytes(f.plainBytes, l10n)} · ${l10n.safeboxTrashPurgeOn(safeboxDate(context, f.purgeAt))}'),
                      onTap: () => _menu(fichier: f),
                    ),
                ],
              ),
            ),
    );
  }
}
