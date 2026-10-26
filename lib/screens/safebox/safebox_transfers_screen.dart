//  Transferts du coffre-fort (lot 8, maquette « Transferts ») : les envois vers
//  le coffre (progression, pause, reprise, échecs) et les téléchargements vers
//  le téléphone (galerie ou ZIP). Onglet de l'accueil, et écran à part depuis
//  un dossier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_export.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../talky_api_client.dart';
import 'safebox_widgets.dart';

/// Ouvre les transferts en plein écran (depuis un dossier).
Future<void> showSafeboxTransfers(BuildContext context, {bool downloads = false}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SafeboxTransfersView(initialTab: downloads ? 1 : 0)),
    );

/// Texte d'un échec d'envoi, à partir de son code.
String safeboxUploadErrorText(BuildContext context, String? code) {
  final l10n = context.l10n;
  if (code == 'SAFEBOX_QUOTA_EXCEEDED') return l10n.safeboxQuotaExceeded;
  if (code == 'SAFEBOX_SOURCE_CHANGED' || code == 'SAFEBOX_SOURCE_MISSING') return l10n.safeboxSourceChanged;
  return presenterErreur(l10n, TalkyException('', 0, code: code), domaine: ErrorDomain.media, journaliser: false);
}

/// Les envois qui ne sont pas finis : ceux que l'accueil et l'onglet comptent.
bool safeboxUploadActive(SafeboxUploadJob j) => j.state != SafeboxUploadState.completed;

class SafeboxTransfersView extends StatelessWidget {
  const SafeboxTransfersView({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final envois = c.uploads.jobs;
    final telechargements = c.exports.tasks;
    final finis = envois.any((j) => j.state == SafeboxUploadState.completed || j.state == SafeboxUploadState.failed) ||
        telechargements.any((t) => t.finished);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.safeboxTabTransfers),
          actions: [
            if (finis)
              TextButton(
                onPressed: () {
                  c.uploads.clearFinished();
                  c.exports.clearFinished();
                },
                child: Text(l10n.safeboxClearFinished),
              ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: '${l10n.safeboxUploadsTab} · ${envois.where(safeboxUploadActive).length}'),
            Tab(text: '${l10n.safeboxDownloadsTab} · ${telechargements.where((t) => !t.finished).length}'),
          ]),
        ),
        body: TabBarView(children: [
          _Envois(jobs: envois),
          _Telechargements(tasks: telechargements),
        ]),
      ),
    );
  }
}

class _Envois extends StatelessWidget {
  const _Envois({required this.jobs});
  final List<SafeboxUploadJob> jobs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.read<SafeboxController>();
    if (jobs.isEmpty) return Center(child: Text(l10n.safeboxNoTransfers));
    final enCours = jobs.reversed.where(safeboxUploadActive).toList();
    final termines = jobs.reversed.where((j) => !safeboxUploadActive(j)).toList();
    final total = enCours.fold<int>(0, (s, j) => s + j.storedSize);
    final envoye = enCours.fold<int>(0, (s, j) => s + j.sentBytes);
    final enPause = enCours.any((j) => j.state == SafeboxUploadState.paused);
    final enMarche = enCours.any((j) => j.state != SafeboxUploadState.paused && j.state != SafeboxUploadState.failed);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        if (enCours.isNotEmpty)
          _Carte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.safeboxBytesOf(formatBytes(envoye, l10n), formatBytes(total, l10n)),
                    style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                AppSpacing.vGapSm,
                ClipRRect(
                  borderRadius: AppRadius.brPill,
                  child: LinearProgressIndicator(value: total <= 0 ? 0 : envoye / total, minHeight: 6),
                ),
                AppSpacing.vGapXs,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (enPause)
                      TextButton.icon(
                        onPressed: c.uploads.resumePaused,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.safeboxResumeAll),
                      ),
                    if (enMarche)
                      TextButton.icon(
                        onPressed: c.uploads.pauseAll,
                        icon: const Icon(Icons.pause),
                        label: Text(l10n.safeboxPauseAll),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (enCours.isNotEmpty) ...[
          _Titre(l10n.safeboxInProgress),
          _Carte(padding: EdgeInsets.zero, child: Column(children: [for (final j in enCours) _LigneEnvoi(job: j)])),
        ],
        if (termines.isNotEmpty) ...[
          _Titre(l10n.safeboxFinished),
          _Carte(padding: EdgeInsets.zero, child: Column(children: [for (final j in termines) _LigneEnvoi(job: j)])),
        ],
      ],
    );
  }
}

class _LigneEnvoi extends StatelessWidget {
  const _LigneEnvoi({required this.job});
  final SafeboxUploadJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.read<SafeboxController>();
    final (String etat, Color? couleur) = switch (job.state) {
      SafeboxUploadState.queued => (l10n.safeboxUploadQueued, null),
      SafeboxUploadState.running => (
          '${l10n.safeboxBytesOf(formatBytes(job.sentBytes, l10n), formatBytes(job.storedSize, l10n))} · '
              '${(job.progress * 100).floor()} %',
          context.colors.primary
        ),
      SafeboxUploadState.waitingNetwork => (l10n.safeboxUploadWaitingNetwork, context.semantic.warning),
      SafeboxUploadState.waitingWifi => (l10n.safeboxUploadWaitingWifi, context.semantic.warning),
      SafeboxUploadState.paused => (l10n.safeboxUploadPaused, null),
      SafeboxUploadState.failed => (safeboxUploadErrorText(context, job.errorCode), context.colors.error),
      SafeboxUploadState.completed => (
          [
            if (job.quality != null && job.quality != SafeboxQuality.original.name)
              SafeboxQuality.fromName(job.quality) == SafeboxQuality.hd ? l10n.safeboxQualityHd : l10n.safeboxQualityCompressed,
            if (job.originalSize != null)
              '${formatBytes(job.originalSize!, l10n)} → ${formatBytes(job.plainSize, l10n)}'
            else
              formatBytes(job.plainSize, l10n),
          ].join(' · '),
          null
        ),
    };
    final famille = c.familyOf(job.name);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
        child: Icon(safeboxRootIcon(famille.root), color: context.colors.primary, size: AppIconSize.sm),
      ),
      title: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etat, style: context.text.bodySmall?.copyWith(color: couleur ?? context.colors.onSurfaceVariant)),
          if (job.state == SafeboxUploadState.running || job.state == SafeboxUploadState.paused) ...[
            AppSpacing.vGapXs,
            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(value: job.progress, minHeight: 4),
            ),
          ],
        ],
      ),
      trailing: switch (job.state) {
        SafeboxUploadState.running ||
        SafeboxUploadState.queued ||
        SafeboxUploadState.waitingNetwork ||
        SafeboxUploadState.waitingWifi =>
          IconButton(
            tooltip: l10n.safeboxPause,
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () => c.uploads.pause(job.id),
          ),
        SafeboxUploadState.paused => IconButton(
            tooltip: l10n.safeboxResume,
            icon: Icon(Icons.play_circle_outline, color: context.colors.primary),
            onPressed: () => c.uploads.resume(job.id),
          ),
        SafeboxUploadState.failed => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: l10n.safeboxRetry, icon: const Icon(Icons.refresh), onPressed: () => c.uploads.retry(job.id)),
              IconButton(tooltip: MaterialLocalizations.of(context).cancelButtonLabel, icon: const Icon(Icons.close), onPressed: () => c.uploads.cancel(job.id)),
            ],
          ),
        SafeboxUploadState.completed => Icon(Icons.check_circle, color: context.semantic.success),
      },
    );
  }
}

class _Telechargements extends StatelessWidget {
  const _Telechargements({required this.tasks});
  final List<SafeboxExportTask> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (tasks.isEmpty) return Center(child: Text(l10n.safeboxNoDownloads));
    final enCours = tasks.reversed.where((t) => !t.finished).toList();
    final termines = tasks.reversed.where((t) => t.finished).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        _Carte(
          child: Text(l10n.safeboxDownloadDecryptHint,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        if (enCours.isNotEmpty) ...[
          _Titre(l10n.safeboxInProgress),
          _Carte(padding: EdgeInsets.zero, child: Column(children: [for (final t in enCours) _LigneTelechargement(task: t)])),
        ],
        if (termines.isNotEmpty) ...[
          _Titre(l10n.safeboxFinished),
          _Carte(padding: EdgeInsets.zero, child: Column(children: [for (final t in termines) _LigneTelechargement(task: t)])),
        ],
      ],
    );
  }
}

class _LigneTelechargement extends StatelessWidget {
  const _LigneTelechargement({required this.task});
  final SafeboxExportTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.read<SafeboxController>();
    final destination = task.target == SafeboxExportTarget.zip ? l10n.safeboxExportDoneZip : l10n.safeboxExportDoneGallery;
    final (String etat, Color? couleur) = switch (task.state) {
      SafeboxExportState.queued => (l10n.safeboxUploadQueued, null),
      SafeboxExportState.running => (
          '${l10n.safeboxExportProgress(task.done, task.files.length)} · ${(task.progress * 100).floor()} %',
          context.colors.primary
        ),
      SafeboxExportState.done => (
          [destination, if (task.skipped > 0) l10n.safeboxExportSkipped(task.skipped)].join(' · '),
          task.skipped > 0 ? context.semantic.warning : null
        ),
      SafeboxExportState.failed => (l10n.safeboxExportFailed, context.colors.error),
      SafeboxExportState.cancelled => (l10n.safeboxExportCancelled, null),
    };
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
        child: Icon(
          task.target == SafeboxExportTarget.zip ? Icons.folder_zip_outlined : Icons.photo_library_outlined,
          color: context.colors.primary,
          size: AppIconSize.sm,
        ),
      ),
      title: Text('${task.title} · ${formatBytes(task.totalBytes, l10n)}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etat, style: context.text.bodySmall?.copyWith(color: couleur ?? context.colors.onSurfaceVariant)),
          if (task.state == SafeboxExportState.running) ...[
            AppSpacing.vGapXs,
            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(value: task.progress, minHeight: 4),
            ),
          ],
        ],
      ),
      trailing: task.finished
          ? (task.state == SafeboxExportState.done ? Icon(Icons.check_circle, color: context.semantic.success) : null)
          : IconButton(
              tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
              icon: const Icon(Icons.close),
              onPressed: () => c.exports.cancel(task),
            ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
        child: Text(
          texte.toUpperCase(),
          style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.4),
        ),
      );
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child, this.padding = AppSpacing.card});
  final Widget child;
  final EdgeInsetsGeometry padding;

  // Le fond est un Material, et non une décoration : les ListTile y peignent
  // leur effet d'appui.
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        decoration: BoxDecoration(borderRadius: AppRadius.brMd, boxShadow: AppShadows.subtle),
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadius.brMd,
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      );
}
