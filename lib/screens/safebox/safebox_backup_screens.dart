//  La sauvegarde automatique (lot 10, maquettes « Activation 1 » et
//  « Activation 2 » du 24/10/2026) : l'autorisation d'Android, puis
//  « Que sauvegarder ? » (types, dossiers de photos et vidéos, dossiers de
//  documents, depuis quand) et « Qualité » (estimation face à l'espace libre,
//  un format par type, Wi-Fi, charge). Une fois activée, les mêmes écrans
//  servent de réglages.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_backup.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/billing/paywall_sheet.dart';
import 'safebox_widgets.dart';

/// Ouvre l'activation, ou les réglages si la sauvegarde est déjà activée.
Future<void> showSafeboxBackupSetup(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SafeboxBackupSetupScreen()),
    );

/// Nom d'un dossier du téléphone tel que l'inscrit le connaît.
String safeboxPhoneFolderLabel(AppLocalizations l10n, String name) => switch (name.toLowerCase()) {
      'camera' || 'dcim' => l10n.safeboxFolderCamera,
      'screenshots' => l10n.safeboxFolderScreenshots,
      'download' || 'downloads' => l10n.safeboxFolderDownloads,
      _ => name,
    };

class SafeboxBackupSetupScreen extends StatefulWidget {
  const SafeboxBackupSetupScreen({super.key});

  @override
  State<SafeboxBackupSetupScreen> createState() => _SafeboxBackupSetupScreenState();
}

class _SafeboxBackupSetupScreenState extends State<SafeboxBackupSetupScreen> {
  /// 0 : autorisation, 1 : que sauvegarder, 2 : qualité.
  int _etape = 1;
  late SafeboxBackupSettings _r;
  late final bool _reglages;
  SafeboxMediaAccess? _acces;
  List<SafeboxDeviceFolder>? _dossiers;
  final Map<String, int> _documentsParDossier = {};
  SafeboxBackupEstimate? _estimation;
  bool _calcul = false;
  bool _qualiteTouchee = false;
  Timer? _attente;
  int _generation = 0;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _r = _c.backupSettings;
    _reglages = _r.enabled;
    _qualiteTouchee = _reglages;
    _demarrer();
  }

  @override
  void dispose() {
    _attente?.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    final acces = await _c.device.access();
    if (!mounted) return;
    setState(() {
      _acces = acces;
      _etape = acces == SafeboxMediaAccess.denied && !_reglages ? 0 : 1;
    });
    if (acces != SafeboxMediaAccess.denied) await _chargerDossiers();
    _recalculer();
    for (final d in _r.documentFolders) {
      unawaited(_compterDocuments(d));
    }
  }

  Future<void> _autoriser() async {
    final acces = await _c.device.requestAccess();
    if (!mounted) return;
    setState(() => _acces = acces);
    if (acces == SafeboxMediaAccess.denied) return;
    setState(() => _etape = 1);
    await _chargerDossiers();
    _recalculer();
  }

  Future<void> _chargerDossiers() async {
    try {
      final dossiers = await _c.device.galleryFolders();
      if (!mounted) return;
      setState(() {
        _dossiers = dossiers;
        // Première activation : l'appareil photo et WhatsApp cochés.
        if (!_reglages && _r.galleryFolders.isEmpty) {
          _r = _r.copyWith(galleryFolders: {for (final d in dossiers) if (d.checkedByDefault) d.id});
        }
      });
    } catch (e) {
      if (mounted) setState(() => _dossiers = const []);
    }
  }

  Future<void> _compterDocuments(SafeboxDocumentFolder d) async {
    try {
      final n = (await _c.device.documentItems(d)).length;
      if (mounted) setState(() => _documentsParDossier[d.uri] = n);
    } catch (_) {}
  }

  /// Nombres et poids de la sélection, recalculés un instant après le dernier
  /// changement : mesurer la galerie prend quelques secondes.
  void _recalculer() {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () async {
      final g = ++_generation;
      setState(() => _calcul = true);
      try {
        // Tous les types : la description de chacun montre ce qu'il apporterait.
        final tout = _r.copyWith(families: SafeboxFamily.values.toSet());
        final items = await _c.backup.selection(tout, withSizes: true);
        if (!mounted || g != _generation) return;
        final e = SafeboxBackupEstimate.of(items);
        setState(() {
          _estimation = e;
          _calcul = false;
        });
      } catch (e) {
        if (mounted && g == _generation) setState(() => _calcul = false);
      }
    });
  }

  int get _libre {
    final q = _c.overview?.quota;
    if (q == null) return 0;
    return (q.quotaBytes - q.usedBytes).clamp(0, 1 << 62);
  }

  /// L'estimation des seuls types retenus.
  SafeboxBackupEstimate? get _retenue {
    final e = _estimation;
    if (e == null) return null;
    return SafeboxBackupEstimate(
      counts: {for (final f in _r.families) f: e.countOf(f)},
      bytes: {for (final f in _r.families) f: e.bytes[f] ?? const {}},
    );
  }

  void _versQualite() {
    final e = _retenue;
    if (!_qualiteTouchee && e != null) {
      // Présélection du 24/10/2026 : Original si tout tient, sinon HD.
      final q = safeboxBackupPreselect(e, _libre);
      _r = _r.copyWith(quality: {
        for (final f in const [SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.audios]) f: q,
      });
    }
    setState(() => _etape = 2);
  }

  Future<void> _ajouterDossier() async {
    try {
      final d = await _c.device.pickDocumentFolder();
      if (d == null || !mounted || _r.documentFolders.contains(d)) return;
      setState(() => _r = _r.copyWith(documentFolders: [..._r.documentFolders, d]));
      unawaited(_compterDocuments(d));
      _recalculer();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  void _retirerDossier(SafeboxDocumentFolder d) {
    setState(() => _r = _r.copyWith(documentFolders: [..._r.documentFolders]..remove(d)));
    _recalculer();
  }

  Future<void> _activer() async {
    final l10n = context.l10n;
    await _c.saveBackupSettings(_r.copyWith(enabled: true));
    if (!mounted) return;
    if (!_reglages) safeboxSnack(context, l10n.safeboxBackupEnabledToast);
    Navigator.pop(context);
  }

  Future<void> _desactiver() async {
    final l10n = context.l10n;
    final ok = await safeboxConfirm(context, message: l10n.safeboxBackupDisableConfirm, action: l10n.safeboxBackupDisable);
    if (!ok || !mounted) return;
    await _c.saveBackupSettings(_r.copyWith(enabled: false));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sousTitre = switch (_etape) {
      0 => null,
      1 => l10n.safeboxBackupStep1,
      _ => l10n.safeboxBackupStep2,
    };
    return PopScope(
      canPop: _etape != 2,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _etape == 2) setState(() => _etape = 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_reglages ? l10n.safeboxBackupSettings : l10n.safeboxBackupTitle),
              if (sousTitre != null)
                Text(sousTitre, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
          actions: [
            if (_reglages)
              PopupMenuButton<String>(
                onSelected: (_) => _desactiver(),
                itemBuilder: (_) => [PopupMenuItem(value: 'off', child: Text(l10n.safeboxBackupDisable))],
              ),
          ],
          bottom: _etape == 0
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(child: _Trait(actif: true)),
                        AppSpacing.hGapXs,
                        Expanded(child: _Trait(actif: _etape == 2)),
                      ],
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: _etape == 0
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _etape == 1
                        ? (_r.families.isEmpty ? null : _versQualite)
                        : _activer,
                    child: Text(_etape == 1
                        ? l10n.safeboxBackupContinue
                        : (_reglages ? l10n.safeboxBackupSave : l10n.safeboxBackupEnable)),
                  ),
                ),
              ),
        body: switch (_etape) {
          0 => _autorisation(l10n),
          1 => _quoi(l10n),
          _ => _qualite(l10n),
        },
      ),
    );
  }

  // ── Étape 0 : l'autorisation d'Android ─────────────────────────────────────

  Widget _autorisation(AppLocalizations l10n) {
    final refuse = _acces == SafeboxMediaAccess.denied;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppSpacing.vGapLg,
        Icon(Icons.photo_library_outlined, size: 64, color: context.colors.primary),
        AppSpacing.vGapLg,
        Text(l10n.safeboxBackupPermissionTitle, textAlign: TextAlign.center, style: context.text.titleLarge),
        AppSpacing.vGapMd,
        Text(l10n.safeboxBackupPermissionBody,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        AppSpacing.vGapXl,
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _autoriser,
          child: Text(l10n.safeboxBackupAllow),
        ),
        if (refuse) ...[
          AppSpacing.vGapLg,
          Text(l10n.safeboxBackupPermissionDenied,
              textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: context.semantic.warning)),
          AppSpacing.vGapSm,
          OutlinedButton(onPressed: PhotoManager.openSetting, child: Text(l10n.safeboxBackupOpenSettings)),
          AppSpacing.vGapSm,
          TextButton(onPressed: () => setState(() => _etape = 1), child: Text(l10n.safeboxBackupContinue)),
        ],
      ],
    );
  }

  // ── Étape 1 : que sauvegarder ? ─────────────────────────────────────────────

  Widget _quoi(AppLocalizations l10n) {
    final est = _estimation;
    final dossiers = _dossiers;
    String? desc(SafeboxFamily f) {
      if (est == null) return null;
      final n = est.countOf(f);
      final taille = formatBytes(est.bytesOf(f, SafeboxQuality.original), l10n);
      return switch (f) {
        SafeboxFamily.photos => l10n.safeboxBackupPhotosDesc(n, taille),
        SafeboxFamily.videos => l10n.safeboxBackupVideosDesc(n, taille),
        SafeboxFamily.audios => l10n.safeboxBackupAudiosDesc(n),
        SafeboxFamily.documents => l10n.safeboxBackupDocsDesc(taille),
      };
    }

    void basculer(SafeboxFamily f, bool oui) => setState(() {
          final familles = {..._r.families};
          oui ? familles.add(f) : familles.remove(f);
          _r = _r.copyWith(families: familles);
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        if (_acces == SafeboxMediaAccess.full || _acces == SafeboxMediaAccess.limited)
          _Bandeau(
            icone: _acces == SafeboxMediaAccess.full ? Icons.check : Icons.info_outline,
            couleur: _acces == SafeboxMediaAccess.full ? context.semantic.success : context.semantic.warning,
            fond: _acces == SafeboxMediaAccess.full ? context.semantic.successContainer : context.semantic.warningContainer,
            texte: _acces == SafeboxMediaAccess.full ? l10n.safeboxBackupGranted : l10n.safeboxBackupLimited,
            action: _acces == SafeboxMediaAccess.limited ? (l10n.safeboxBackupWiden, _autoriser) : null,
          ),
        if (_calcul) ...[
          AppSpacing.vGapSm,
          Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              AppSpacing.hGapSm,
              Expanded(child: Text(l10n.safeboxBackupScanning, style: context.text.bodySmall)),
            ],
          ),
        ],
        _Titre(l10n.safeboxBackupWhat),
        _Groupe(children: [
          for (final f in SafeboxFamily.values)
            SwitchListTile(
              value: _r.families.contains(f),
              onChanged: (f != SafeboxFamily.documents && _acces == SafeboxMediaAccess.denied) ? null : (v) => basculer(f, v),
              title: Text(SafeboxController.rootLabel(f.root, l10n)),
              subtitle: desc(f) == null ? null : Text(desc(f)!),
            ),
        ]),
        if (_acces != SafeboxMediaAccess.denied) ...[
          _Titre(l10n.safeboxBackupGalleryFolders),
          _Groupe(children: [
            if (dossiers == null)
              const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator())
            else
              for (final d in dossiers)
                CheckboxListTile(
                  value: _r.galleryFolders.contains(d.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    setState(() {
                      final ids = {..._r.galleryFolders};
                      v == true ? ids.add(d.id) : ids.remove(d.id);
                      _r = _r.copyWith(galleryFolders: ids);
                    });
                    _recalculer();
                  },
                  title: Text(safeboxPhoneFolderLabel(l10n, d.name)),
                  secondary: Text('${d.count}', style: context.text.bodySmall),
                ),
          ]),
        ],
        _Titre(l10n.safeboxBackupDocFolders),
        _Groupe(children: [
          for (final d in _r.documentFolders)
            ListTile(
              leading: Icon(Icons.folder_outlined, color: context.colors.primary),
              title: Text(d.name),
              subtitle: _documentsParDossier[d.uri] == null
                  ? null
                  : Text(l10n.safeboxFilesCount(_documentsParDossier[d.uri]!)),
              trailing: IconButton(
                tooltip: l10n.safeboxBackupRemoveFolder,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _retirerDossier(d),
              ),
            ),
          ListTile(
            leading: Icon(Icons.add, color: context.colors.primary),
            title: Text(l10n.safeboxBackupAddFolder,
                style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
            onTap: _ajouterDossier,
          ),
        ]),
        AppSpacing.vGapSm,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: context.semantic.warning),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(l10n.safeboxBackupDownloadsWarning,
                  style: context.text.bodySmall?.copyWith(color: context.semantic.warning)),
            ),
          ],
        ),
        _Titre(l10n.safeboxBackupSince),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.safeboxBackupAllHistory)),
            ButtonSegment(value: false, label: Text(l10n.safeboxBackupFromToday)),
          ],
          selected: {_r.since == null},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            final tout = v.first;
            final aujourdhui = DateTime.now();
            setState(() => _r = tout
                ? _r.copyWith(clearSince: true)
                : _r.copyWith(since: DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day)));
            _recalculer();
          },
        ),
      ],
    );
  }

  // ── Étape 2 : qualité ─────────────────────────────────────────────────────

  Widget _qualite(AppLocalizations l10n) {
    final est = _retenue;
    final libre = _libre;
    final total = est?.total(_r.qualityOf) ?? 0;
    final tient = total <= libre;
    final enOriginal = est?.total((_) => SafeboxQuality.original) ?? 0;
    final hdPreselectionne = !_reglages && est != null && enOriginal > libre;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        _Groupe(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.safeboxBackupSelection, style: context.text.bodyMedium)),
                Text(l10n.safeboxBackupFree(formatBytes(libre, l10n)), style: context.text.bodyMedium),
              ],
            ),
            AppSpacing.vGapSm,
            Text('≈ ${formatBytes(total, l10n)}', style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            AppSpacing.vGapSm,
            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(
                value: libre <= 0 ? 1 : (total / libre).clamp(0.0, 1.0),
                minHeight: 10,
                color: tient ? context.colors.primary : context.semantic.warning,
              ),
            ),
            AppSpacing.vGapSm,
            if (tient)
              Text(l10n.safeboxBackupFits(formatBytes(libre - total, l10n)),
                  style: context.text.bodySmall?.copyWith(color: context.semantic.success, fontWeight: FontWeight.w500))
            else ...[
              Text(l10n.safeboxBackupOverflows(formatBytes(total - libre, l10n)),
                  style: context.text.bodySmall?.copyWith(color: context.semantic.warning, fontWeight: FontWeight.w500)),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => showPaywall(context, null),
                child: Text(l10n.safeboxGoPlus),
              ),
            ],
          ],
        ),
        if (hdPreselectionne) ...[
          AppSpacing.vGapSm,
          Text(l10n.safeboxBackupHdPreselected(formatBytes(enOriginal, l10n)),
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
        for (final f in const [SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.audios])
          if (_r.families.contains(f)) ...[
            _Titre('${SafeboxController.rootLabel(f.root, l10n)} · ${est?.countOf(f) ?? 0}'),
            SegmentedButton<SafeboxQuality>(
              segments: [
                for (final q in SafeboxQuality.values)
                  ButtonSegment(
                    value: q,
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(safeboxQualityLabel(l10n, q)),
                        if (est != null)
                          Text(formatBytes(est.bytesOf(f, q), l10n), style: context.text.labelSmall),
                      ],
                    ),
                  ),
              ],
              selected: {_r.qualityOf(f)},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _qualiteTouchee = true;
                _r = _r.copyWith(quality: {..._r.quality, f: v.first});
              }),
            ),
          ],
        if (_r.families.contains(SafeboxFamily.documents)) ...[
          AppSpacing.vGapMd,
          Text(l10n.safeboxBackupDocsAlways(formatBytes(est?.bytesOf(SafeboxFamily.documents, SafeboxQuality.original) ?? 0, l10n)),
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
        AppSpacing.vGapMd,
        _Groupe(children: [
          SwitchListTile(
            value: _r.wifiOnly,
            onChanged: (v) => setState(() => _r = _r.copyWith(wifiOnly: v)),
            title: Text(l10n.safeboxBackupWifiOnly),
          ),
          SwitchListTile(
            value: _r.chargingOnly,
            onChanged: (v) => setState(() => _r = _r.copyWith(chargingOnly: v)),
            title: Text(l10n.safeboxBackupChargingOnly),
          ),
        ]),
        AppSpacing.vGapSm,
        Text(l10n.safeboxBackupRulesNote, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      ],
    );
  }
}

/// « Original », « HD », « Compressé ».
String safeboxQualityLabel(AppLocalizations l10n, SafeboxQuality q) => switch (q) {
      SafeboxQuality.original => l10n.safeboxQualityOriginal,
      SafeboxQuality.hd => l10n.safeboxQualityHd,
      SafeboxQuality.compressed => l10n.safeboxQualityCompressed,
    };

class _Trait extends StatelessWidget {
  const _Trait({required this.actif});
  final bool actif;

  @override
  Widget build(BuildContext context) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: actif ? context.colors.primary : context.colors.outlineVariant,
          borderRadius: AppRadius.brPill,
        ),
      );
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
        child: Text(texte.toUpperCase(),
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.6)),
      );
}

class _Groupe extends StatelessWidget {
  const _Groupe({required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg, side: BorderSide(color: context.colors.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.icone, required this.couleur, required this.fond, required this.texte, this.action});
  final IconData icone;
  final Color couleur;
  final Color fond;
  final String texte;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: fond, borderRadius: AppRadius.brMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 18, color: couleur),
            AppSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texte, style: context.text.bodySmall),
                  if (action != null)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      onPressed: action!.$2,
                      child: Text(action!.$1),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
