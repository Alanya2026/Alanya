//  Le suivi d'un partage, chez l'expéditeur (lot 9, maquette « PartageSuivi »
//  du 24/10/2026) : combien de membres l'ont reçu, chacun d'eux (téléchargé,
//  gardé dans son coffre, pas encore), « Envoyer ailleurs » et « Retirer le
//  partage ». Rien ne s'efface tout seul : le fichier reste dans Partager.
//
//  En tête (07/11/2026), ce qui a été envoyé : les photos et vidéos s'ouvrent
//  dans la visionneuse, comme chez les destinataires.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../widgets/common/app_avatar.dart';
import 'safebox_chat_picker.dart';
import 'safebox_share_widgets.dart';
import 'safebox_viewer_screen.dart';
import 'safebox_widgets.dart';

class SafeboxShareTrackingScreen extends StatefulWidget {
  const SafeboxShareTrackingScreen({super.key, required this.shareId, this.title});
  final int shareId;
  final String? title;

  @override
  State<SafeboxShareTrackingScreen> createState() => _SafeboxShareTrackingScreenState();
}

class _SafeboxShareTrackingScreenState extends State<SafeboxShareTrackingScreen> {
  SafeboxShareInfo? _info;
  SafeboxShareRecipients? _suivi;
  Object? _erreur;
  bool _occupe = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _info = _c.shareInfoCached(widget.shareId);
    _charger();
  }

  Future<void> _charger() async {
    try {
      final info = await _c.shareInfo(widget.shareId, refresh: true);
      final suivi = info == null ? null : await _c.shareRecipients(widget.shareId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _suivi = suivi;
        _erreur = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _envoyerAilleurs(SafeboxShareInfo info) async {
    await sendSafeboxToConversations(
      context,
      file: info.asFile(),
      others: info.isBatch ? info.count - 1 : 0,
      send: (_, ids) => _c.sendShareElsewhere(info, ids),
    );
  }

  /// Les photos et vidéos envoyées, dans la visionneuse, à partir de [depart].
  Future<void> _voir(SafeboxShareInfo info, SafeboxShareItem depart) async {
    try {
      final elements = info.isBatch ? await _c.shareItems(widget.shareId) : [info.asItem()];
      if (!mounted) return;
      final medias = [for (final e in elements) if (e.available && safeboxViewable(e.asFile())) e];
      final parId = {for (final e in medias) e.localId: e};
      final i = medias.indexWhere((e) => e.localId == depart.localId);
      await showSafeboxViewer(
        context,
        files: [for (final e in medias) e.asFile()],
        initialIndex: i < 0 ? 0 : i,
        showNotes: false,
        download: (f) => _c.downloads.fetchShareItem(parId[f.id]!),
      );
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _retirer() async {
    final l10n = context.l10n;
    final ok = await safeboxConfirm(context, message: l10n.safeboxTrackingRevokeConfirm, action: l10n.safeboxTrackingRevoke);
    if (!ok || !mounted) return;
    setState(() => _occupe = true);
    try {
      await _c.revokeShare(widget.shareId);
      if (!mounted) return;
      safeboxSnack(context, l10n.safeboxTrackingRevoked);
      await _charger();
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = _info;
    final suivi = _suivi;
    final resume = suivi?.tracking ?? info?.tracking;
    final detail = info == null
        ? null
        : info.isBatch
            ? '${l10n.safeboxShareItems(info.count)} · ${formatBytes(info.plainBytes, l10n)}'
            : safeboxSizeAndQuality(l10n, formatBytes(info.plainBytes, l10n), info.quality);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info?.name ?? widget.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (detail != null)
              SafeboxConversationName(
                conversationId: info?.conversationId,
                builder: (context, nom, _) => Text(
                  [detail, ?nom].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: info == null || !info.available
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _occupe || info.fileIds.isEmpty ? null : () => _envoyerAilleurs(info),
                        child: Text(l10n.safeboxTrackingSendElsewhere),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: context.colors.error,
                          side: BorderSide(color: context.colors.error.withValues(alpha: 0.5)),
                        ),
                        onPressed: _occupe ? null : _retirer,
                        child: Text(l10n.safeboxTrackingRevoke),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _erreur != null && info == null
          ? Center(child: TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)))
          : info == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      if (!info.available)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            info.removedByModeration ? l10n.safeboxShareRemovedByModeration : l10n.safeboxShareRevoked,
                            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ),
                      if (info.available) _Envoye(info: info, onOpen: (e) => _voir(info, e)),
                      if (resume != null) _Resume(tracking: resume, sentAt: info.createdAt),
                      AppSpacing.vGapLg,
                      Text(l10n.safeboxTrackingMembers.toUpperCase(),
                          style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.8)),
                      AppSpacing.vGapSm,
                      if (suivi == null)
                        const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))
                      else
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final m in suivi.members) _Membre(member: m),
                            ],
                          ),
                        ),
                      AppSpacing.vGapMd,
                      Text(l10n.safeboxTrackingNote,
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                    ],
                  ),
                ),
    );
  }
}

/// Ce qui a été envoyé : jusqu'à quatre aperçus ; une photo ou une vidéo
/// s'ouvre dans la visionneuse. Rien pour un envoi sans photo ni vidéo.
class _Envoye extends StatelessWidget {
  const _Envoye({required this.info, required this.onOpen});
  final SafeboxShareInfo info;
  final ValueChanged<SafeboxShareItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final elements = (info.isBatch ? info.cover : [info.asItem()])
        .where((e) => e.available && safeboxViewable(e.asFile()))
        .take(4)
        .toList();
    if (elements.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i += 1) ...[
                if (i > 0) AppSpacing.hGapXs,
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: i < elements.length
                        ? InkWell(
                            borderRadius: AppRadius.brSm,
                            onTap: () => onOpen(elements[i]),
                            child: SafeboxFileThumb(file: elements[i].asFile(), fill: true),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => onOpen(elements.first),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(l10n.safeboxSharedView),
            ),
          ),
        ],
      ),
    );
  }
}

/// « 3 sur 7 membres l'ont téléchargé ou gardé », la barre, « 1 l'a gardé ».
class _Resume extends StatelessWidget {
  const _Resume({required this.tracking, required this.sentAt});
  final SafeboxShareTracking tracking;
  final DateTime? sentAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final part = tracking.members <= 0 ? 0.0 : (tracking.received / tracking.members).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                Text(l10n.safeboxTrackingOutOf(tracking.received, tracking.members),
                    style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(l10n.safeboxTrackingReceivedLabel, style: context.text.bodyMedium),
                ),
              ],
            ),
            AppSpacing.vGapSm,
            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(value: part, minHeight: 6),
            ),
            AppSpacing.vGapSm,
            Text(
              [
                l10n.safeboxTrackingSaved(tracking.saved),
                if (sentAt != null) l10n.safeboxTrackingSentAt(safeboxDate(context, sentAt)),
              ].join(' · '),
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Membre extends StatelessWidget {
  const _Membre({required this.member});
  final SafeboxShareMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fait = member.state != SafeboxRecipientState.pending;
    final etat = switch (member.state) {
      SafeboxRecipientState.saved => l10n.safeboxTrackingSavedState,
      SafeboxRecipientState.downloaded => l10n.safeboxTrackingDownloadedAt(safeboxDate(context, member.at)),
      SafeboxRecipientState.pending => l10n.safeboxTrackingPending,
    };
    final nom = member.name ?? '#${member.alanyaId}';
    return ListTile(
      leading: AppAvatar(imageUrl: member.avatarUrl, name: nom, size: 40),
      title: Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(etat,
          style: context.text.bodySmall?.copyWith(color: fait ? context.semantic.success : context.colors.onSurfaceVariant)),
      trailing: fait ? Icon(Icons.check_circle, color: context.semantic.success) : null,
    );
  }
}
