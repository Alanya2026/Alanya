// En bas de la fenêtre : l'ajout en préparation (analyse, empreintes) puis
// les envois vers le coffre, avec pause, reprise et détails (lot D4).

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../core/importer.dart';
import '../ui/common.dart';

class TransferBar extends StatelessWidget {
  const TransferBar({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.vault;
    return ListenableBuilder(
      listenable: Listenable.merge([vault.importer, vault.uploads]),
      builder: (context, _) {
        final p = vault.importer.progress;
        if (p != null) return _Preparation(progress: p);
        final jobs = vault.uploads.jobs;
        if (jobs.isEmpty) return const SizedBox.shrink();
        return _Envois(jobs: jobs, uploads: vault.uploads);
      },
    );
  }
}

class _Cadre extends StatelessWidget {
  const _Cadre({required this.icon, required this.title, this.bar, this.subtitle, this.actions = const [], this.iconColor});
  final IconData icon;
  final Color? iconColor;
  final String title;
  final double? bar;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Palette.border))),
        padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
        child: Row(children: [
          Icon(icon, color: iconColor ?? Palette.brand),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              if (bar != null || subtitle == null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: bar, minHeight: 6, backgroundColor: Palette.border),
                )
              else
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          const SizedBox(width: 12),
          ...actions,
        ]),
      );
}

class _Preparation extends StatelessWidget {
  const _Preparation({required this.progress});
  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = progress;
    return _Cadre(
      icon: Icons.manage_search,
      title: switch (p.step) {
        ImportStep.scanning => l.importScanning(p.done),
        ImportStep.checking => l.importChecking(p.done, p.total),
        ImportStep.preparing => l.importPreparing(p.done, p.total),
      },
      bar: p.total > 0 ? (p.done / p.total).clamp(0.0, 1.0) : null,
    );
  }
}

bool _actif(SafeboxUploadJob j) =>
    j.state == SafeboxUploadState.running ||
    j.state == SafeboxUploadState.queued ||
    j.state == SafeboxUploadState.waitingNetwork ||
    j.state == SafeboxUploadState.waitingWifi;

class _Envois extends StatelessWidget {
  const _Envois({required this.jobs, required this.uploads});
  final List<SafeboxUploadJob> jobs;
  final SafeboxUploadManager uploads;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final actifs = jobs.where(_actif).toList();
    final enPause = jobs.where((j) => j.state == SafeboxUploadState.paused).length;
    final echecs = jobs.where((j) => j.state == SafeboxUploadState.failed).length;
    final finis = jobs.where((j) => j.state == SafeboxUploadState.completed).length;
    final details = TextButton(onPressed: () => showUploadsDialog(context), child: Text(l.details));

    if (actifs.isNotEmpty) {
      final total = actifs.fold<int>(0, (s, j) => s + j.storedSize);
      final envoye = actifs.fold<int>(0, (s, j) => s + j.sentBytes);
      final debit = actifs.fold<double>(0, (s, j) => s + (j.bytesPerSecond ?? 0));
      final reseau = actifs.every((j) => j.state == SafeboxUploadState.waitingNetwork);
      return _Cadre(
        icon: reseau ? Icons.cloud_off_outlined : Icons.upload_outlined,
        title: reseau ? l.uploadsWaitingNetwork : l.uploadsRunning(actifs.length),
        bar: total > 0 ? (envoye / total).clamp(0.0, 1.0) : null,
        actions: [
          Text(
            [
              '${formatBytes(context, envoye)} / ${formatBytes(context, total)}',
              if (debit > 0) l.speed(formatBytes(context, debit.round())),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: uploads.pauseAll, child: Text(l.pauseAll)),
          details,
        ],
      );
    }
    if (enPause > 0) {
      return _Cadre(
        icon: Icons.pause_circle_outline,
        title: l.uploadsPaused(enPause),
        subtitle: echecs > 0 ? l.uploadsFailed(echecs) : null,
        actions: [TextButton(onPressed: uploads.resumePaused, child: Text(l.resumeAll)), details],
      );
    }
    return _Cadre(
      icon: echecs > 0 ? Icons.error_outline : Icons.check_circle_outline,
      iconColor: echecs > 0 ? Palette.danger : null,
      title: echecs > 0 ? l.uploadsFailed(echecs) : l.uploadsDone(finis),
      subtitle: echecs > 0 && finis > 0 ? l.uploadsDone(finis) : '',
      actions: [
        details,
        IconButton(tooltip: l.close, onPressed: uploads.clearFinished, icon: const Icon(Icons.close)),
      ],
    );
  }
}

String uploadErrorText(BuildContext context, String? code) {
  final l = context.l;
  return switch (code) {
    'SAFEBOX_QUOTA_EXCEEDED' => l.uploadErrorQuota,
    'SAFEBOX_SOURCE_CHANGED' => l.uploadErrorChanged,
    'SAFEBOX_SOURCE_MISSING' => l.uploadErrorMissing,
    'NETWORK' => l.uploadsWaitingNetwork,
    _ => l.uploadErrorGeneric,
  };
}

/// La liste des envois, un par un, avec pause, reprise, nouvel essai, retrait.
Future<void> showUploadsDialog(BuildContext context) {
  final uploads = context.vault.uploads;
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l = context.l;
      return AlertDialog(
        title: Text(l.uploadsTitle),
        content: SizedBox(
          width: 620,
          height: 420,
          child: ListenableBuilder(
            listenable: uploads,
            builder: (context, _) {
              final jobs = uploads.jobs.reversed.toList();
              return ListView.separated(
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _LigneEnvoi(job: jobs[i], uploads: uploads),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: uploads.clearFinished, child: Text(l.clearFinished)),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
        ],
      );
    },
  );
}

class _LigneEnvoi extends StatelessWidget {
  const _LigneEnvoi({required this.job, required this.uploads});
  final SafeboxUploadJob job;
  final SafeboxUploadManager uploads;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final j = job;
    final etat = switch (j.state) {
      SafeboxUploadState.running => '${formatBytes(context, j.sentBytes)} / ${formatBytes(context, j.storedSize)}'
          '${j.bytesPerSecond != null && j.bytesPerSecond! > 0 ? ' · ${l.speed(formatBytes(context, j.bytesPerSecond!.round()))}' : ''}',
      SafeboxUploadState.queued => l.uploadQueued,
      SafeboxUploadState.waitingNetwork || SafeboxUploadState.waitingWifi => l.uploadsWaitingNetwork,
      SafeboxUploadState.paused => l.uploadPaused,
      SafeboxUploadState.failed => uploadErrorText(context, j.errorCode),
      SafeboxUploadState.completed => l.uploadDone,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(
          switch (j.state) {
            SafeboxUploadState.completed => Icons.check_circle_outline,
            SafeboxUploadState.failed => Icons.error_outline,
            SafeboxUploadState.paused => Icons.pause_circle_outline,
            _ => Icons.upload_outlined,
          },
          color: j.state == SafeboxUploadState.failed ? Palette.danger : Palette.brand,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(j.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            if (j.state == SafeboxUploadState.running) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: j.progress, minHeight: 4, backgroundColor: Palette.border),
              ),
              const SizedBox(height: 4),
            ],
            Text(etat, style: t.bodySmall?.copyWith(color: j.state == SafeboxUploadState.failed ? Palette.danger : null)),
          ]),
        ),
        const SizedBox(width: 8),
        if (_actif(j)) IconButton(tooltip: l.pause, onPressed: () => uploads.pause(j.id), icon: const Icon(Icons.pause)),
        if (j.state == SafeboxUploadState.paused)
          IconButton(tooltip: l.resume, onPressed: () => uploads.resume(j.id), icon: const Icon(Icons.play_arrow)),
        if (j.state == SafeboxUploadState.failed)
          IconButton(tooltip: l.retry, onPressed: () => uploads.retry(j.id), icon: const Icon(Icons.refresh)),
        if (j.state != SafeboxUploadState.completed)
          IconButton(tooltip: l.cancel, onPressed: () => uploads.cancel(j.id), icon: const Icon(Icons.close)),
      ]),
    );
  }
}
