import 'package:flutter/material.dart';

import '../core/exporter.dart';
import '../ui/common.dart';
import '../ui/system.dart';

/// En bas de la fenêtre : l'enregistrement en cours sur l'ordinateur, ou le
/// dernier terminé (« Afficher dans le dossier »).
class ExportBar extends StatelessWidget {
  const ExportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final exporter = context.vault.exporter;
    return ListenableBuilder(
      listenable: exporter,
      builder: (context, _) {
        final t = exporter.task;
        if (t == null) return const SizedBox.shrink();
        final l = context.l;
        final enCours = t.state == ExportState.running;
        final titre = switch (t.state) {
          ExportState.running => t.filesTotal > 1
              ? l.exportRunningMany(t.label, t.filesDone, t.filesTotal)
              : l.exportRunning(t.label),
          ExportState.done => l.exportDone(t.label),
          ExportState.failed => l.exportFailed(t.label),
          ExportState.cancelled => l.exportCancelled(t.label),
        };
        return Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Palette.border))),
          padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
          child: Row(children: [
            Icon(
              switch (t.state) {
                ExportState.running => Icons.download_outlined,
                ExportState.done => Icons.check_circle_outline,
                ExportState.failed => Icons.error_outline,
                ExportState.cancelled => Icons.block_outlined,
              },
              color: t.state == ExportState.failed ? Palette.danger : Palette.brand,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                if (enCours)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: t.bytesTotal > 0 ? t.progress : null, minHeight: 6, backgroundColor: Palette.border),
                  )
                else
                  Text(t.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 12),
            if (enCours) ...[
              if (t.bytesTotal > 0)
                Text(
                  '${formatBytes(context, t.bytesDone)} / ${formatBytes(context, t.bytesTotal)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(width: 8),
              if (t.filesTotal > 1) TextButton(onPressed: exporter.cancel, child: Text(l.cancel)),
            ] else ...[
              if (t.state != ExportState.failed)
                TextButton(onPressed: () => showInFolder(t.destination), child: Text(l.showInFolder)),
              IconButton(tooltip: l.close, onPressed: exporter.dismiss, icon: const Icon(Icons.close)),
            ],
          ]),
        );
      },
    );
  }
}
