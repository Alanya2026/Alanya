//  La feuille « Télécharger » (lot 8, maquette du 24/10/2026) : quoi (la
//  sélection ou tout le dossier), où (la galerie du téléphone ou un fichier
//  ZIP). Les fichiers sont déchiffrés sur le téléphone.

import 'package:flutter/material.dart';

import '../../core/services/safebox/safebox_export.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../widgets/common/app_bottom_sheet.dart';

/// Ce que l'inscrit a choisi : la sélection (`wholeFolder` faux) ou tout le
/// dossier, et la destination.
typedef SafeboxDownloadChoice = ({bool wholeFolder, SafeboxExportTarget target});

Future<SafeboxDownloadChoice?> showSafeboxDownloadSheet(
  BuildContext context, {
  required List<SafeboxFile> selection,
  required String folderName,
}) =>
    showAppBottomSheet<SafeboxDownloadChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleTelecharger(selection: selection, folderName: folderName),
    );

class _FeuilleTelecharger extends StatefulWidget {
  const _FeuilleTelecharger({required this.selection, required this.folderName});
  final List<SafeboxFile> selection;
  final String folderName;

  @override
  State<_FeuilleTelecharger> createState() => _FeuilleTelechargerState();
}

class _FeuilleTelechargerState extends State<_FeuilleTelecharger> {
  late bool _dossier = widget.selection.isEmpty;
  var _cible = SafeboxExportTarget.gallery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taille = widget.selection.fold<int>(0, (s, f) => s + f.plainBytes);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.download_outlined, color: context.colors.primary),
                AppSpacing.hGapSm,
                Text(l10n.safeboxDownload, style: context.text.titleMedium),
              ],
            ),
            AppSpacing.vGapMd,
            Text(l10n.safeboxDownloadWhat.toUpperCase(),
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            RadioGroup<bool>(
              groupValue: _dossier,
              onChanged: (v) => setState(() => _dossier = v ?? true),
              child: Column(
                children: [
                  if (widget.selection.isNotEmpty)
                    RadioListTile<bool>(
                      value: false,
                      title: Text(l10n.safeboxDownloadSelection(widget.selection.length, formatBytes(taille, l10n))),
                      contentPadding: EdgeInsets.zero,
                    ),
                  RadioListTile<bool>(
                    value: true,
                    title: Text(l10n.safeboxDownloadFolder(widget.folderName)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            AppSpacing.vGapSm,
            Text(l10n.safeboxDownloadWhere.toUpperCase(),
                style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            AppSpacing.vGapSm,
            SegmentedButton<SafeboxExportTarget>(
              segments: [
                ButtonSegment(
                  value: SafeboxExportTarget.gallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.safeboxDownloadGallery),
                ),
                ButtonSegment(
                  value: SafeboxExportTarget.zip,
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: Text(l10n.safeboxDownloadZip),
                ),
              ],
              selected: {_cible},
              onSelectionChanged: (s) => setState(() => _cible = s.first),
            ),
            AppSpacing.vGapSm,
            Text(
              _cible == SafeboxExportTarget.zip ? l10n.safeboxDownloadZipHint : l10n.safeboxDownloadGalleryHint,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            AppSpacing.vGapMd,
            Container(
              padding: AppSpacing.card,
              decoration: BoxDecoration(color: context.semantic.infoContainer, borderRadius: AppRadius.brSm),
              child: Text(l10n.safeboxDownloadDecryptHint, style: context.text.bodySmall),
            ),
            AppSpacing.vGapMd,
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, (wholeFolder: _dossier, target: _cible)),
              icon: const Icon(Icons.download),
              label: Text(_dossier ? l10n.safeboxDownload : l10n.safeboxDownloadAction(formatBytes(taille, l10n))),
            ),
          ],
        ),
      ),
    );
  }
}
