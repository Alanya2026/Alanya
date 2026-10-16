//  Les envois vers le coffre-fort : progression, attente du réseau, échecs.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/app_bottom_sheet.dart';

Future<void> showSafeboxTransfers(BuildContext context) => showAppBottomSheet<void>(
      context: context,
      builder: (_) => const SafeboxTransfersSheet(),
    );

/// Texte d'un échec d'envoi, à partir de son code.
String safeboxUploadErrorText(BuildContext context, String? code) {
  final l10n = context.l10n;
  if (code == 'SAFEBOX_QUOTA_EXCEEDED') return l10n.safeboxQuotaExceeded;
  if (code == 'SAFEBOX_SOURCE_CHANGED' || code == 'SAFEBOX_SOURCE_MISSING') return l10n.safeboxSourceChanged;
  return presenterErreur(l10n, TalkyException('', 0, code: code), domaine: ErrorDomain.media, journaliser: false);
}

class SafeboxTransfersSheet extends StatelessWidget {
  const SafeboxTransfersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final jobs = c.uploads.jobs.reversed.toList();
    final finis = jobs.any((j) => j.state == SafeboxUploadState.completed || j.state == SafeboxUploadState.failed);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.safeboxTransfers, style: context.text.titleMedium)),
                  if (finis) TextButton(onPressed: c.uploads.clearFinished, child: Text(l10n.safeboxClearFinished)),
                ],
              ),
            ),
            if (jobs.isEmpty)
              Padding(padding: AppSpacing.card, child: Text(l10n.safeboxNoTransfers))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _LigneEnvoi(job: jobs[i]),
                ),
              ),
            AppSpacing.vGapMd,
          ],
        ),
      ),
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
    final pct = (job.progress * 100).floor();
    final (String etat, Color? couleur) = switch (job.state) {
      SafeboxUploadState.queued => (l10n.safeboxUploadQueued, null),
      SafeboxUploadState.running => (l10n.safeboxUploadRunning(pct), null),
      SafeboxUploadState.waitingNetwork => (l10n.safeboxUploadWaitingNetwork, context.semantic.warning),
      SafeboxUploadState.failed => (safeboxUploadErrorText(context, job.errorCode), context.colors.error),
      SafeboxUploadState.completed => (l10n.safeboxUploadDone, context.semantic.success),
    };
    return ListTile(
      title: Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatBytes(job.storedSize, l10n)} · $etat', style: TextStyle(color: couleur)),
          if (job.state == SafeboxUploadState.running || job.state == SafeboxUploadState.queued) ...[
            AppSpacing.vGapXs,
            LinearProgressIndicator(value: job.state == SafeboxUploadState.running ? job.progress : null),
          ],
        ],
      ),
      trailing: switch (job.state) {
        SafeboxUploadState.completed => Icon(Icons.check_circle, color: context.semantic.success),
        SafeboxUploadState.failed => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (job.errorCode != 'SAFEBOX_SOURCE_CHANGED' && job.errorCode != 'SAFEBOX_SOURCE_MISSING')
                IconButton(tooltip: l10n.safeboxRetry, icon: const Icon(Icons.refresh), onPressed: () => c.uploads.retry(job.id)),
              IconButton(tooltip: l10n.safeboxCancelUpload, icon: const Icon(Icons.close), onPressed: () => c.uploads.cancel(job.id)),
            ],
          ),
        _ => IconButton(tooltip: l10n.safeboxCancelUpload, icon: const Icon(Icons.close), onPressed: () => c.uploads.cancel(job.id)),
      },
    );
  }
}
