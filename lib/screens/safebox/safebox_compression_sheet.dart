//  La feuille « Qualité d'envoi » (décision du 24/10/2026, conception
//  section 05) : Original, HD ou Compressé, avec le poids de chacun et le gain.
//  Original est présélectionné (décision du 15/10/2026) s'il passe sous la
//  limite d'un fichier ; un format qui la dépasserait est grisé, avec le nom
//  du fichier en cause, et un format qui ne gagnerait presque rien aussi.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_quality.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_widgets.dart';

/// Le format d'un lot de fichiers déposés dans [folder] (ou envoyés dans
/// [conversationId]) : la feuille, ou le choix retenu s'il passe. Rend null si
/// l'inscrit renonce, si rien ne passe sous la limite, ou si l'espace manque
/// (un message le dit).
Future<SafeboxQuality?> askSafeboxQuality(
  BuildContext context, {
  required List<SafeboxPick> picks,
  required SafeboxFolder folder,
  int? conversationId,
  bool send = false,
}) async {
  final c = context.read<SafeboxController>();
  final l10n = context.l10n;
  final est = await c.estimateQualities(picks, folder: folder, conversationId: conversationId);
  if (!context.mounted) return null;
  final max = c.overview?.limits.maxFileBytes ?? 0;
  SafeboxQuality? qualite;
  if (!est.compressible) {
    qualite = est.fits(SafeboxQuality.original) ? SafeboxQuality.original : null;
  } else {
    final retenu = await c.rememberedQuality();
    if (retenu != null) {
      qualite = safeboxFittingQuality(retenu, est.fits);
      if (qualite != null && qualite != retenu && context.mounted) {
        safeboxSnack(context, l10n.safeboxQualityDowngraded(safeboxQualityLabel(qualite, l10n)));
      }
    }
    if (qualite == null && retenu == null) {
      if (!context.mounted) return null;
      final r = await showSafeboxQualitySheet(
        context,
        estimate: est,
        maxFileBytes: max,
        freeBytes: c.overview?.quota.freeBytes,
        destination: SafeboxController.folderLabel(folder, l10n),
        fileCount: picks.length,
        send: send,
      );
      if (r == null) return null;
      if (r.remember) await c.rememberQuality(r.quality);
      qualite = r.quality;
    }
  }
  if (!context.mounted) return null;
  if (qualite == null) {
    safeboxSnack(context, l10n.safeboxQualityNoneFits(formatBytes(max, l10n)), error: true);
    return null;
  }
  // Espace : on prévient tout de suite plutôt qu'à la réservation.
  final libre = c.overview?.quota.freeBytes;
  if (libre != null && (est.totals[qualite] ?? 0) > libre) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.safeboxQuotaExceeded),
      action: SnackBarAction(label: l10n.safeboxGoPlus, onPressed: () => showPaywall(context, null)),
    ));
    return null;
  }
  return qualite;
}

/// La feuille seule : rend le format choisi et « Retenir mon choix », ou null.
Future<({SafeboxQuality quality, bool remember})?> showSafeboxQualitySheet(
  BuildContext context, {
  required SafeboxQualityEstimate estimate,
  required int maxFileBytes,
  required int? freeBytes,
  required String destination,
  required int fileCount,
  bool send = false,
}) =>
    showAppBottomSheet<({SafeboxQuality quality, bool remember})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleQualite(
        estimate: estimate,
        maxFileBytes: maxFileBytes,
        freeBytes: freeBytes,
        destination: destination,
        fileCount: fileCount,
        send: send,
      ),
    );

String safeboxQualityLabel(SafeboxQuality q, AppLocalizations l10n) => switch (q) {
      SafeboxQuality.original => l10n.safeboxQualityOriginal,
      SafeboxQuality.hd => l10n.safeboxQualityHd,
      SafeboxQuality.compressed => l10n.safeboxQualityCompressed,
    };

class _FeuilleQualite extends StatefulWidget {
  const _FeuilleQualite({
    required this.estimate,
    required this.maxFileBytes,
    required this.freeBytes,
    required this.destination,
    required this.fileCount,
    required this.send,
  });

  final SafeboxQualityEstimate estimate;
  final int maxFileBytes;
  final int? freeBytes;
  final String destination;
  final int fileCount;
  final bool send;

  @override
  State<_FeuilleQualite> createState() => _FeuilleQualiteState();
}

class _FeuilleQualiteState extends State<_FeuilleQualite> {
  late SafeboxQuality? _choix;
  bool _retenir = false;

  SafeboxQualityEstimate get _est => widget.estimate;

  bool _possible(SafeboxQuality q) => _est.fits(q) && !_est.nothingToGain(q);

  @override
  void initState() {
    super.initState();
    // Original d'abord ; s'il dépasse la limite, le premier format qui passe.
    _choix = safeboxFittingQuality(SafeboxQuality.original, _possible);
  }

  /// « Vidéo 720p · photo 2 560 px · musique 128 kbit/s », selon ce que
  /// contient le lot.
  String _description(SafeboxQuality q, AppLocalizations l10n) {
    if (q == SafeboxQuality.original) return l10n.safeboxQualityOriginalHint;
    final parts = <String>[
      if ((_est.counts[SafeboxFamily.videos] ?? 0) > 0)
        l10n.safeboxQualityVideoPart('${safeboxVideoProfile(q, hevc: _est.hevc)!.shortSide}p'),
      if ((_est.counts[SafeboxFamily.photos] ?? 0) > 0)
        l10n.safeboxQualityPhotoPart('${safeboxPhotoProfile(q)!.longSide}'),
      if ((_est.counts[SafeboxFamily.audios] ?? 0) > 0)
        l10n.safeboxQualityMusicPart('${safeboxAudioBitrate(q)! ~/ 1000}'),
    ];
    return parts.join(' · ');
  }

  String _sousTitre(AppLocalizations l10n) {
    final n = _est.counts;
    final parts = <String>[
      if ((n[SafeboxFamily.videos] ?? 0) > 0) l10n.safeboxCountVideos(n[SafeboxFamily.videos]!),
      if ((n[SafeboxFamily.photos] ?? 0) > 0) l10n.safeboxCountPhotos(n[SafeboxFamily.photos]!),
      if ((n[SafeboxFamily.audios] ?? 0) > 0) l10n.safeboxCountAudios(n[SafeboxFamily.audios]!),
      if ((n[SafeboxFamily.documents] ?? 0) > 0) l10n.safeboxCountDocuments(n[SafeboxFamily.documents]!),
    ];
    return '${parts.join(' · ')} · ${l10n.safeboxQualityTo(widget.destination)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choix = _choix;
    final total = choix == null ? null : _est.totals[choix];
    final libre = widget.freeBytes;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.safeboxQualityTitle, style: context.text.titleMedium),
            AppSpacing.vGapXs,
            Text(_sousTitre(l10n), style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            AppSpacing.vGapMd,
            RadioGroup<SafeboxQuality>(
              groupValue: choix,
              onChanged: (v) => setState(() => _choix = v),
              child: Column(
                children: [
                  for (final q in SafeboxQuality.values) ...[
                    _Option(
                      quality: q,
                      label: safeboxQualityLabel(q, l10n),
                      size: _est.totals[q] ?? 0,
                      approx: q != SafeboxQuality.original,
                      gainPercent: _est.gainPercent(q),
                      description: _description(q, l10n),
                      enabled: _possible(q),
                      warning: !_est.fits(q)
                          ? l10n.safeboxQualityTooLarge(
                              _est.tooLarge[q]!.name,
                              formatBytes(_est.tooLarge[q]!.bytes, l10n),
                              formatBytes(widget.maxFileBytes, l10n),
                            )
                          : _est.nothingToGain(q)
                              ? l10n.safeboxCompressNothingToGain
                              : null,
                      selected: q == choix,
                      onTap: _possible(q) ? () => setState(() => _choix = q) : null,
                    ),
                    AppSpacing.vGapSm,
                  ],
                ],
              ),
            ),
            Text(l10n.safeboxQualityNote,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            CheckboxListTile(
              value: _retenir,
              onChanged: (v) => setState(() => _retenir = v ?? false),
              title: Text(l10n.safeboxCompressRemember),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (choix == null)
              Text(l10n.safeboxQualityNoneFits(formatBytes(widget.maxFileBytes, l10n)),
                  style: context.text.bodySmall?.copyWith(color: context.colors.error))
            else if (libre != null && total != null)
              Text(
                total > libre ? l10n.safeboxQuotaExceeded : l10n.safeboxQualityFreeAfter(formatBytes(libre - total, l10n)),
                style: context.text.bodySmall?.copyWith(
                  color: total > libre ? context.colors.error : context.colors.onSurfaceVariant,
                ),
              ),
            AppSpacing.vGapMd,
            FilledButton(
              onPressed: choix == null ? null : () => Navigator.pop(context, (quality: choix, remember: _retenir)),
              child: Text(
                widget.send
                    ? l10n.safeboxQualitySendCount(widget.fileCount, formatBytes(total ?? 0, l10n))
                    : l10n.safeboxQualityAddCount(widget.fileCount, formatBytes(total ?? 0, l10n)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.quality,
    required this.label,
    required this.size,
    required this.approx,
    required this.gainPercent,
    required this.description,
    required this.enabled,
    required this.warning,
    required this.selected,
    required this.onTap,
  });

  final SafeboxQuality quality;
  final String label;
  final int size;
  final bool approx;
  final int gainPercent;
  final String description;
  final bool enabled;
  final String? warning;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final couleurTexte = enabled ? context.colors.onSurface : context.colors.onSurfaceVariant;
    final taille = formatBytes(size, l10n);
    return Material(
      color: !enabled
          ? context.colors.surfaceContainerHighest.withValues(alpha: 0.5)
          : selected
              ? context.semantic.brandContainer
              : context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: selected ? context.colors.primary : context.colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<SafeboxQuality>(value: quality, enabled: enabled),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label, style: context.text.titleSmall?.copyWith(color: couleurTexte)),
                        if (approx && gainPercent >= 5) ...[
                          AppSpacing.hGapSm,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.semantic.successContainer,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Text('−$gainPercent %',
                                style: context.text.labelSmall?.copyWith(color: context.semantic.success)),
                          ),
                        ],
                        const Spacer(),
                        Text(approx ? '≈ $taille' : taille,
                            style: context.text.titleSmall?.copyWith(color: couleurTexte)),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      AppSpacing.vGapXs,
                      Text(description,
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                    ],
                    if (warning != null) ...[
                      AppSpacing.vGapXs,
                      Text(warning!, style: context.text.bodySmall?.copyWith(color: context.semantic.warning)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
