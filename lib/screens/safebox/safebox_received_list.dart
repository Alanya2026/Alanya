//  L'onglet « Reçus » du dossier Partager (lot 9, maquette « PartagerRecus »
//  du 24/10/2026) : les fichiers reçus par le coffre, toutes discussions
//  confondues, avec « Télécharger » et « Garder dans mon coffre ». « Plus
//  disponible » quand l'expéditeur a supprimé le fichier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/paywall_sheet.dart';
import 'safebox_share_widgets.dart';
import 'safebox_shared_screens.dart';
import 'safebox_widgets.dart';

class SafeboxReceivedList extends StatefulWidget {
  const SafeboxReceivedList({super.key, this.onCount});

  /// Nombre de partages reçus chargés, pour le titre de l'onglet.
  final ValueChanged<int>? onCount;

  @override
  State<SafeboxReceivedList> createState() => _SafeboxReceivedListState();
}

class _SafeboxReceivedListState extends State<SafeboxReceivedList> {
  final List<SafeboxShareInfo> _partages = [];
  final Set<int> _surLeTelephone = {};
  int? _suite;
  bool _charge = false;
  bool _chargeSuite = false;
  Object? _erreur;
  int? _occupe;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Un fichier seul vu comme son élément, avec l'aperçu et la clé de la ligne.
  static SafeboxShareItem? _element(SafeboxShareInfo s) =>
      s.isBatch ? null : (s.cover.isNotEmpty ? s.cover.first : s.asItem());

  Future<Set<int>> _locaux(List<SafeboxShareInfo> partages) async {
    final out = <int>{};
    for (final s in partages) {
      final e = _element(s);
      if (e != null && s.available && await _c.hasReceivedItem(e)) out.add(s.id);
    }
    return out;
  }

  Future<void> _charger() async {
    try {
      final page = await _c.receivedShares();
      final locaux = await _locaux(page.shares);
      if (!mounted) return;
      setState(() {
        _partages
          ..clear()
          ..addAll(page.shares);
        _surLeTelephone
          ..clear()
          ..addAll(locaux);
        _suite = page.nextCursor;
        _charge = true;
        _erreur = null;
      });
      widget.onCount?.call(_partages.length);
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _chargerSuite() async {
    if (_suite == null || _chargeSuite) return;
    _chargeSuite = true;
    try {
      final page = await _c.receivedShares(cursor: _suite);
      final locaux = await _locaux(page.shares);
      if (!mounted) return;
      setState(() {
        _partages.addAll(page.shares);
        _surLeTelephone.addAll(locaux);
        _suite = page.nextCursor;
      });
      widget.onCount?.call(_partages.length);
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      _chargeSuite = false;
    }
  }

  Future<void> _ouvrir(SafeboxShareInfo s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => s.isBatch
            ? SafeboxSharedAlbumScreen(shareId: s.id, title: s.name)
            : SafeboxSharedFileScreen(shareId: s.id, title: s.name),
      ),
    );
    if (mounted) await _charger();
  }

  Future<void> _telecharger(SafeboxShareInfo s) async {
    final e = _element(s);
    if (e == null) return;
    final l10n = context.l10n;
    setState(() => _occupe = s.id);
    try {
      final r = await _c.fetchReceivedItem(e);
      if (!mounted) return;
      setState(() => _surLeTelephone.add(s.id));
      if (r.published) safeboxSnack(context, l10n.safeboxSavedToDownloads);
      if (r.saveFailed) safeboxSnack(context, l10n.safeboxSaveToDownloadsFailed, error: true);
      final ouvert = await _c.received.open(r.location, e.mime);
      if (!ouvert && mounted) safeboxSnack(context, l10n.safeboxOpenFailed, error: true);
    } catch (err) {
      if (mounted) _erreur429(err);
    } finally {
      if (mounted) setState(() => _occupe = null);
    }
  }

  Future<void> _garder(SafeboxShareInfo s) async {
    setState(() => _occupe = s.id);
    try {
      if (s.isBatch) {
        final album = await _c.saveShareBatch(s.id);
        if (mounted) safeboxSnack(context, context.l10n.safeboxSharedAlbumKept(album.name ?? s.name));
      } else {
        await _c.saveShare(s.id);
        if (mounted) safeboxSnack(context, context.l10n.safeboxShareSavedToast);
      }
      if (mounted) await _charger();
    } catch (err) {
      if (mounted) _erreur429(err);
    } finally {
      if (mounted) setState(() => _occupe = null);
    }
  }

  void _erreur429(Object e) {
    final l10n = context.l10n;
    if (e is TalkyException && e.code == 'SAFEBOX_DOWNLOAD_LIMIT') {
      safeboxSnack(context, l10n.safeboxShareDownloadLimit((e.details?['limit'] as num?)?.toInt() ?? 3), error: true);
    } else if (e is TalkyException && e.code == 'SAFEBOX_QUOTA_EXCEEDED') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.safeboxQuotaExceeded),
        action: SnackBarAction(label: l10n.safeboxGoPlus, onPressed: () => showPaywall(context, null)),
      ));
    } else if (e is TalkyException && e.code == 'SAFEBOX_SHARE_REVOKED') {
      _charger();
    } else {
      safeboxShowError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_erreur != null && !_charge) {
      return Center(child: TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)));
    }
    if (!_charge) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _charger,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) _chargerSuite();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
          children: [
            safeboxShareInfoLine(context, l10n.safeboxShareReceivedInfo),
            AppSpacing.vGapSm,
            if (_partages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(Icons.move_to_inbox_outlined, size: 56, color: context.colors.outlineVariant),
                    AppSpacing.vGapMd,
                    Text(l10n.safeboxReceivedEmpty, textAlign: TextAlign.center, style: context.text.titleMedium),
                  ],
                ),
              ),
            for (final s in _partages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CarteRecue(
                  share: s,
                  element: _element(s),
                  onPhone: _surLeTelephone.contains(s.id),
                  busy: _occupe == s.id,
                  onOpen: () => _ouvrir(s),
                  onDownload: () => _telecharger(s),
                  onKeep: () => _garder(s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne d'explication en tête d'onglet, avec l'icône « i ».
Widget safeboxShareInfoLine(BuildContext context, String texte) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 16, color: context.colors.onSurfaceVariant),
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(texte, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ],
    );

class _CarteRecue extends StatelessWidget {
  const _CarteRecue({
    required this.share,
    required this.element,
    required this.onPhone,
    required this.busy,
    required this.onOpen,
    required this.onDownload,
    required this.onKeep,
  });

  final SafeboxShareInfo share;
  final SafeboxShareItem? element;
  final bool onPhone;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = share;
    final muet = context.colors.onSurfaceVariant;
    final couverture = s.cover.isNotEmpty ? s.cover.first : null;
    final taille = formatBytes(s.plainBytes, l10n);
    final detail = s.isBatch
        ? '${l10n.safeboxShareItems(s.count)} · $taille'
        : [
            safeboxSizeAndQuality(l10n, taille, s.quality),
            ?s.meta?.durationLabel,
          ].join(' · ');
    final garde = s.savedFileId != null;
    final (String? etat, Color? couleurEtat) = !s.available
        ? (s.removedByModeration ? l10n.safeboxShareRemovedByModeration : l10n.safeboxSharedUnavailable, muet)
        : garde
            ? (l10n.safeboxReceivedKept, context.semantic.success)
            : onPhone
                ? (l10n.safeboxReceivedInDownloads, context.semantic.success)
                : (null, null);
    final actions = s.available && !garde && !(onPhone && !s.isBatch);

    return Material(
      color: s.available ? context.colors.surface : context.colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brLg,
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: s.available ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: couverture != null && s.available
                        ? SafeboxFileThumb(file: couverture.asFile(), fill: true)
                        : DecoratedBox(
                            decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
                            child: Icon(s.isBatch ? Icons.collections_outlined : safeboxRootIcon(s.family.root),
                                color: context.colors.primary),
                          ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(color: s.available ? null : muet)),
                        Text(detail, style: context.text.bodySmall?.copyWith(color: muet)),
                        SafeboxConversationName(
                          conversationId: s.conversationId,
                          builder: (context, discussion) => Text(
                            [
                              l10n.safeboxSharedFrom(s.sender?.name ?? l10n.safeboxSharedSender),
                              if (discussion != null && discussion != s.sender?.name) discussion,
                              if (s.createdAt != null) safeboxDate(context, s.createdAt),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(color: muet),
                          ),
                        ),
                        if (etat != null)
                          Text(etat,
                              style: context.text.bodySmall?.copyWith(color: couleurEtat, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (s.available && onPhone && !s.isBatch)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                      onPressed: busy ? null : onDownload,
                      child: Text(l10n.safeboxOpen),
                    ),
                ],
              ),
              if (actions) ...[
                AppSpacing.vGapMd,
                Row(
                  children: [
                    Expanded(
                      child: s.isBatch
                          ? FilledButton.icon(
                              onPressed: busy ? null : onOpen,
                              icon: const Icon(Icons.grid_view_rounded, size: 18),
                              label: Text(l10n.safeboxShareSeeAlbum),
                            )
                          : FilledButton.icon(
                              onPressed: busy ? null : onDownload,
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(l10n.safeboxDownload),
                            ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onKeep,
                        child: Text(l10n.safeboxShareSave, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
                if (s.downloadsLeft != null) ...[
                  AppSpacing.vGapXs,
                  Text(l10n.safeboxShareDownloadsLeft(s.downloadsLeft!),
                      style: context.text.bodySmall?.copyWith(color: muet)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
