import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../talky_api_client.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../../core/db/app_database.dart';
import '../../core/db/chat_dao.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/chat/chat_repository.dart';
import '../../core/services/export/export_delivery.dart';
import '../../core/services/export/export_scan.dart';
import '../../core/services/export/export_zip_builder.dart';
import '../../core/services/export/media_export_job.dart';
import '../../core/services/stickers/sticker_cache.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/sticker_payload.dart';
import '../../l10n/app_localizations.dart';

/// Périmètre à exporter, tel que les filtres de l'écran l'ont défini.
class ExportRequest {
  final int myId;
  final bool? mineOnly;
  final int? conversationID;
  final String? conversationName;
  final DateTime? from;
  final DateTime? until;
  final List<int> types;

  const ExportRequest({
    required this.myId,
    this.mineOnly,
    this.conversationID,
    this.conversationName,
    this.from,
    this.until,
    this.types = kExportMediaTypes,
  });
}

/// Feuille « Exporter cette période ».
///
/// Elle annonce **avant tout engagement** ce que l'inscrit obtiendra : combien
/// d'éléments, quel poids, et ce qui manque — en distinguant ce que le serveur
/// peut encore rendre de ce qui est définitivement perdu. La récupération
/// réseau est proposée décochée : c'est la seule dépense de données de tout le
/// mécanisme, et elle doit rester un choix explicite.
class ExportPeriodSheet extends StatefulWidget {
  final ChatDao dao;

  /// Sert uniquement à la récupération réseau des manquants, quand l'inscrit
  /// la coche. Le travail d'export, lui, ne connaît que le [typedef]
  /// [MediaRecoverer] — il reste donc testable sans dépôt ni réseau.
  final ChatRepository repository;

  final ExportRequest request;

  const ExportPeriodSheet({
    super.key,
    required this.dao,
    required this.repository,
    required this.request,
  });

  @override
  State<ExportPeriodSheet> createState() => _ExportPeriodSheetState();
}

class _ExportPeriodSheetState extends State<ExportPeriodSheet> {
  ExportScanResult? _scan;
  String? _scanError;

  /// Décoché par défaut : rien ne part sur le réseau sans un geste.
  bool _recoverMissing = false;

  MediaExportJob? _job;
  ExportStatus? _status;
  String? _error;
  bool _finished = false;

  bool get _running => _job != null && !_finished;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final r = widget.request;
    try {
      final scan = await MediaExportJob(widget.dao, stickerFile: _stickerFile)
          .preview(
        r.myId,
        mineOnly: r.mineOnly,
        conversationID: r.conversationID,
        from: r.from,
        until: r.until,
        types: r.types,
      );
      // Le client seul ne peut que déduire l'expiration d'une rétention qu'il
      // n'a pas toujours apprise — et croit alors TOUT récupérable. Une
      // requête de quelques kilo-octets remplace la devinette par un fait, et
      // évite des dizaines de téléchargements voués au 410.
      final refined = await _askServer(scan);
      if (!mounted) return;
      setState(() => _scan = refined);
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanError =
          presenterErreur(context.l10n, e, domaine: ErrorDomain.media));
    }
  }

  /// Affine le tri des manquants avec la réponse du serveur.
  ///
  /// En cas d'échec — réseau coupé, serveur indisponible — on rend le scan tel
  /// quel. L'écran parlera alors d'estimation (`verifiedByServer` reste faux)
  /// au lieu de promettre.
  Future<ExportScanResult> _askServer(ExportScanResult scan) async {
    // Les stickers sont laissés de côté : leur disponibilité ne se lit pas
    // dans la partition média (ils ne sont pas purgés), et l'appelant sait
    // déjà qu'un sticker absent du cache est simplement récupérable. Les
    // interroger risquerait de les classer « perdus » à tort.
    final ids = scan.recoverable
        .where((m) => !m.isSticker)
        .map((m) => m.msgID)
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty) return scan;
    try {
      final api = context.read<TalkyApiClient>();
      final json = await api.fetchMediaAvailability(ids);
      final available = ((json['available'] as List?) ?? const [])
          .map((v) => int.tryParse(v.toString()) ?? 0)
          .where((v) => v > 0)
          .toSet();
      final sizes = <int, int>{};
      (json['bytes'] as Map?)?.forEach((k, v) {
        final id = int.tryParse(k.toString());
        final size = int.tryParse(v.toString());
        if (id != null && size != null) sizes[id] = size;
      });
      return scan.withServerVerdict(available: available, sizes: sizes);
    } catch (_) {
      return scan;
    }
  }

  Future<void> _start(ExportDestination destination) async {
    final l10n = context.l10n;
    // Capturés avant tout `await` — et surtout avant le `pop` : une fois la
    // feuille retirée, son `context` ne peut plus servir à retrouver le
    // messager, et le message de fin serait perdu ou lèverait.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final r = widget.request;
    final job = MediaExportJob(widget.dao, stickerFile: _stickerFile);
    setState(() {
      _job = job;
      _error = null;
      _finished = false;
      _status = const ExportStatus(phase: ExportPhase.scanning);
    });

    try {
      final dir = await ExportDelivery.workingDirectory();
      final file = File(p.join(
        dir.path,
        ExportDelivery.archiveName(
          alanyaID: r.myId,
          from: r.from,
          to: r.until?.subtract(const Duration(days: 1)),
        ),
      ));

      // Mesuré juste avant l'assemblage : refuser après avoir écrit la moitié
      // d'une archive laisserait le disque plus plein qu'au départ, pour un
      // fichier inutilisable.
      final available = await ExportDelivery.freeSpaceBytes(dir.path);

      // Protège l'assemblage si l'inscrit bascule sur une autre application.
      await ExportDelivery.startForegroundTask();

      final result = await job.run(
        myId: r.myId,
        destination: file,
        availableBytes: available,
        mineOnly: r.mineOnly,
        conversationID: r.conversationID,
        conversationName: r.conversationName,
        from: r.from,
        until: r.until,
        types: r.types,
        recoverMissing: _recoverMissing ? _recover : null,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
          if (s.phase == ExportPhase.assembling && s.total > 0) {
            unawaited(ExportDelivery.updateForegroundTask(s.done, s.total));
          }
        },
      );

      await const ExportDelivery().deliver(
        archive: result.archive,
        destination: destination,
        subject: l10n.exportSheetTitle,
      );

      if (!mounted) return;
      setState(() => _finished = true);
      navigator.pop();
      // Dire ce qu'on a réellement obtenu, pas seulement « c'est prêt ». Sans
      // ça, l'inscrit qui avait 200 manquants ne sait pas combien sont revenus.
      final missing = result.manifest.missing.length;
      final size = formatBytes(result.manifest.totalBytes, l10n);
      messenger.showSnackBar(SnackBar(
        content: Text(destination == ExportDestination.downloads
            ? l10n.exportSavedToDownloads
            : (missing > 0
                ? l10n.exportDoneWithMissing(size, missing)
                : l10n.exportDone(size))),
      ));
    } on ExportCancelled {
      if (!mounted) return;
      setState(() {
        _finished = true;
        _error = l10n.exportCancelled;
      });
    } on ExportInsufficientSpace {
      if (!mounted) return;
      setState(() {
        _finished = true;
        _error = l10n.exportNoSpace;
      });
    } on ExportDeliveryUnsupported {
      if (!mounted) return;
      setState(() {
        _finished = true;
        _error = l10n.exportSaveUnsupported;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finished = true;
        _error = l10n.exportFailedGeneric;
      });
    } finally {
      // Dans un `finally` sans exception : un service de premier plan oublié
      // laisse une notification permanente que l'inscrit ne peut pas retirer.
      await ExportDelivery.stopForegroundTask();
    }
  }

  /// Fichier d'un sticker, lu dans le cache dédié ([StickerCache]) — **sans
  /// réseau**. Un export ne télécharge rien que l'inscrit n'ait explicitement
  /// accepté : un sticker absent du cache est simplement déclaré manquant.
  ///
  /// Un sticker ne renseigne pas `localMediaPath` : son image vit dans un cache
  /// séparé, indexé par URL. C'est pourquoi l'export a besoin de ce résolveur.
  Future<File?> _stickerFile(LocalMessage msg) async {
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty) return null;
    return StickerCache.instance.cachedFile(url);
  }

  /// Récupération réseau d'un manquant, par sa clé primaire.
  ///
  /// Retourne `null` à la moindre difficulté — message introuvable, média à
  /// vue unique, téléchargement échoué. L'élément reste alors simplement
  /// déclaré absent dans le manifeste : renoncer à toute l'archive parce
  /// qu'une photo n'est pas revenue serait absurde.
  Future<String?> _recover(String clientId) async {
    final msg = await widget.dao.messageByClientId(clientId);
    final url = msg?.mediaUrl;
    if (msg == null || url == null || url.isEmpty) return null;
    // Un média à vue unique n'a pas de copie persistante côté destinataire :
    // il n'a rien à faire dans une archive en clair.
    if (msg.isViewOnce) return null;
    // Un sticker se télécharge dans son cache dédié, jamais dans le cache média
    // général : c'est là que le scan va le chercher, et dans le dossier
    // « Alanya Stickers » pour l'archive.
    if (msg.type == kStickerMessageType) {
      return (await StickerCache.instance.fileFor(url))?.path;
    }
    return widget.repository.ensureReceivedMediaLocal(
      msgID: msg.msgID,
      mediaUrl: url,
      type: msg.type,
      isMine: msg.senderID == widget.request.myId,
      isViewOnce: false,
      mediaName: msg.mediaName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.vGapMd,
            Text(l10n.exportSheetTitle, style: context.text.titleMedium),
            AppSpacing.vGapSm,
            ..._content(l10n),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations l10n) {
    if (_scanError != null) {
      return [
        Text(l10n.exportFailedGeneric,
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.error)),
        AppSpacing.vGapMd,
        TextButton(onPressed: _loadPreview, child: Text(l10n.commonRetry)),
      ];
    }

    final scan = _scan;
    if (scan == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_running) return _progress(l10n);

    return [
      Text(
        scan.present.isEmpty
            ? l10n.exportSheetNothing
            : l10n.exportSheetSummary(
                scan.present.length,
                formatBytes(scan.bytes, l10n),
              ),
        style: context.text.bodyMedium,
      ),
      if (scan.recoverable.isNotEmpty) ...[
        AppSpacing.vGapSm,
        _recoverableTile(l10n, scan),
      ],
      if (scan.lost.isNotEmpty) ...[
        AppSpacing.vGapSm,
        _lostTile(l10n, scan),
      ],
      if (_error != null) ...[
        AppSpacing.vGapMd,
        Text(_error!,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.error)),
      ],
      AppSpacing.vGapLg,
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(
                l10n.exportDestinationDownloads,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: scan.present.isEmpty
                  ? null
                  : () => _start(ExportDestination.downloads),
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text(
                l10n.exportDestinationShare,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: scan.present.isEmpty
                  ? null
                  : () => _start(ExportDestination.share),
            ),
          ),
        ],
      ),
    ];
  }

  /// Le coût réseau est chiffré et la case décochée : l'inscrit décide en
  /// connaissant la dépense, ce qui est la seule façon acceptable de sortir de
  /// la règle « aucun octet ».
  Widget _recoverableTile(AppLocalizations l10n, ExportScanResult scan) {
    // Deux discours, selon ce qu'on sait réellement.
    //
    // Le serveur a répondu : on annonce un décompte et un poids EXACTS, et on
    // peut promettre. Il n'a pas répondu : le tri repose sur une rétention
    // déduite, et le client croit peut-être récupérable ce qui est perdu — on
    // dit « jusqu'à », et on prévient. Promettre ce qu'on ne peut pas tenir
    // est précisément le défaut qu'on corrige ici.
    final count = scan.recoverable.length;
    final verified = scan.verifiedByServer;
    final bytes = scan.recoverableBytes;

    return CheckboxListTile(
      value: _recoverMissing,
      onChanged: (v) =>
          setState(() => _recoverMissing = v ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        verified && bytes != null
            ? l10n.exportMissingRecoverable(count, formatBytes(bytes, l10n))
            : l10n.exportMissingRecoverableEstimate(count),
        style: context.text.bodySmall,
      ),
      subtitle: Text(
        verified
            ? l10n.exportMissingRecoverableHint
            : l10n.exportMissingEstimateHint,
        style: context.text.labelSmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }

  Widget _lostTile(AppLocalizations l10n, ExportScanResult scan) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.exportMissingLost(scan.lost.length),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.exportMissingLostHint,
            style: context.text.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _progress(AppLocalizations l10n) {
    final status = _status;
    final label = switch (status?.phase) {
      ExportPhase.recovering =>
        l10n.exportPhaseRecovering(status!.done, status.total),
      ExportPhase.assembling =>
        l10n.exportPhaseAssembling(status!.done, status.total),
      _ => l10n.exportPhaseScanning,
    };
    return [
      AppSpacing.vGapMd,
      LinearProgressIndicator(
        value: (status?.total ?? 0) == 0 ? null : status!.ratio,
      ),
      AppSpacing.vGapSm,
      Text(label, style: context.text.bodySmall),
      AppSpacing.vGapMd,
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => _job?.cancel(),
          child: Text(l10n.commonCancel),
        ),
      ),
    ];
  }
}
