//  « Libérer de l'espace » : les plus gros fichiers du coffre d'abord, les
//  fichiers déjà envoyés à d'autres (ceux que tout le monde a reçus en tête),
//  et la corbeille, qui compte dans l'espace tant qu'elle n'est pas vidée.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../talky_api_client.dart';
import 'safebox_widgets.dart';

class SafeboxFreeUpScreen extends StatefulWidget {
  const SafeboxFreeUpScreen({super.key});

  @override
  State<SafeboxFreeUpScreen> createState() => _SafeboxFreeUpScreenState();
}

class _SafeboxFreeUpScreenState extends State<SafeboxFreeUpScreen> {
  List<SafeboxFile>? _fichiers;
  int _corbeille = 0;
  Object? _erreur;
  final Set<int> _choisis = {};
  bool _occupe = false;

  /// Seulement les fichiers déjà envoyés dans une discussion.
  bool _envoyesSeulement = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await _c.api.fetchSafeboxLargest(limit: 100);
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

  Future<void> _apres() async {
    await _charger();
    unawaited(_c.refreshOverview());
  }

  Future<void> _viderCorbeille() async {
    final l10n = context.l10n;
    if (!await safeboxConfirm(context, message: l10n.safeboxEmptyTrashConfirm, action: l10n.safeboxEmptyTrash)) return;
    setState(() => _occupe = true);
    try {
      await _c.api.emptySafeboxTrash();
      await _apres();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _mettreALaCorbeille() async {
    final ids = _choisis.toList();
    setState(() => _occupe = true);
    try {
      // Partout : un contenu aussi rangé dans un album ne libère sa place
      // que si tous ses exemplaires partent (décision du 24/10/2026).
      for (final id in ids) {
        await _c.api.trashSafeboxFile(id, everywhere: true);
        await _c.downloads.evict(id);
      }
      _choisis.clear();
      if (mounted) safeboxSnack(context, context.l10n.safeboxMovedToTrash);
      await _apres();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
      await _charger();
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tous = _fichiers;
    // Filtre « Déjà envoyés » : ceux que tout le monde a reçus d'abord, ce
    // sont eux qu'on supprime sans priver personne ; puis par poids.
    final fichiers = tous == null || !_envoyesSeulement
        ? tous
        : (tous.where((f) => f.sent != null).toList()
          ..sort((a, b) {
            final ta = a.sent!.receivedByAll ? 0 : 1;
            final tb = b.sent!.receivedByAll ? 0 : 1;
            return ta != tb ? ta - tb : b.storedBytes - a.storedBytes;
          }));
    final avecEnvois = tous?.any((f) => f.sent != null) ?? false;
    final vue = context.watch<SafeboxController>().overview;
    // Sur tous les fichiers : une sélection cachée par le filtre part aussi.
    final poidsChoisi = (tous ?? const <SafeboxFile>[])
        .where((f) => _choisis.contains(f.id))
        .fold<int>(0, (s, f) => s + f.storedBytes);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxFreeUpTitle)),
      bottomNavigationBar: _choisis.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: AppSpacing.card,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: context.colors.error),
                  onPressed: _occupe ? null : _mettreALaCorbeille,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('${l10n.safeboxFreeUpDelete} · ${l10n.safeboxFreeUpSelected(_choisis.length, formatBytes(poidsChoisi, l10n))}'),
                ),
              ),
            ),
      body: fichiers == null
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
                  if (vue != null)
                    Padding(padding: AppSpacing.card, child: SafeboxQuotaBar(quota: vue.quota)),
                  if (_corbeille > 0)
                    Padding(
                      padding: AppSpacing.screenH,
                      child: OutlinedButton.icon(
                        onPressed: _occupe ? null : _viderCorbeille,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(l10n.safeboxFreeUpTrash(formatBytes(_corbeille, l10n))),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
                    child: Text(l10n.safeboxFreeUpLargest, style: context.text.titleSmall),
                  ),
                  Padding(
                    padding: AppSpacing.screenH,
                    child: Text(l10n.safeboxFreeUpHint,
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  ),
                  if (avecEnvois || _envoyesSeulement)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          avatar: const Icon(Icons.send_outlined, size: 16),
                          label: Text(l10n.safeboxFreeUpSent),
                          selected: _envoyesSeulement,
                          onSelected: (v) => setState(() => _envoyesSeulement = v),
                        ),
                      ),
                    ),
                  if (fichiers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Center(child: Text(l10n.safeboxFreeUpNothing)),
                    ),
                  for (final f in fichiers)
                    CheckboxListTile(
                      value: _choisis.contains(f.id),
                      onChanged: _occupe
                          ? null
                          : (v) => setState(() => v == true ? _choisis.add(f.id) : _choisis.remove(f.id)),
                      secondary: SafeboxFileThumb(file: f, size: 44),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text([
                            formatBytes(f.storedBytes, l10n),
                            l10n.safeboxInFolder(f.folderName ?? SafeboxController.rootLabel(f.folderRoot ?? f.family.root, l10n)),
                          ].join(' · ')),
                          if (f.lost) const SafeboxLostBadge(),
                          if (f.sent != null) SafeboxSentBadge(sent: f.sent!),
                        ],
                      ),
                    ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
    );
  }
}
