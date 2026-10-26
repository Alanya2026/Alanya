//  Les écrans ouverts depuis la carte d'un partage (lot 9, maquettes
//  « PartageFichier » et « PartageAlbum » du 24/10/2026) : un fichier seul ou
//  un élément d'un lot (aperçu, qui l'a envoyé, « Télécharger et lire »,
//  « Garder dans mon coffre »), et un lot (la grille avec un filtre par type,
//  « Garder dans mon coffre », « Tout télécharger »). Les deux rappellent
//  que le contenu reste disponible tant que l'expéditeur le garde, et la
//  limite de téléchargements.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/common/app_avatar.dart';
import 'safebox_download_sheet.dart';
import 'safebox_grid.dart';
import 'safebox_share_widgets.dart';
import 'safebox_widgets.dart';

/// Au-delà, « Wi-Fi conseillé ».
const int _gros = 50 << 20;

/// Les erreurs d'un téléchargement ou d'un « Garder » reçus.
void _erreurPartage(BuildContext context, Object e) {
  final l10n = context.l10n;
  if (e is TalkyException && e.code == 'SAFEBOX_DOWNLOAD_LIMIT') {
    final limite = (e.details?['limit'] as num?)?.toInt() ?? 3;
    safeboxSnack(context, l10n.safeboxShareDownloadLimit(limite), error: true);
  } else if (e is TalkyException && e.code == 'SAFEBOX_QUOTA_EXCEEDED') {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.safeboxQuotaExceeded),
      action: SnackBarAction(label: l10n.safeboxGoPlus, onPressed: () => showPaywall(context, null)),
    ));
  } else {
    safeboxShowError(context, e);
  }
}

/// « Chiffré. Disponible tant que Clarisse le garde dans son coffre-fort. »
class _Rappel extends StatelessWidget {
  const _Rappel({required this.sender});
  final String sender;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        color: context.semantic.brandContainer,
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: context.colors.primary),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(context.l10n.safeboxSharedAvailableWhile(sender), style: context.text.bodySmall),
            ),
          ],
        ),
      );
}

String _expediteur(AppLocalizations l10n, SafeboxShareInfo? info) =>
    info?.sender?.name ?? l10n.safeboxSharedSender;

// ── Un fichier ───────────────────────────────────────────────────────────────

/// Un fichier reçu : celui d'un partage simple, ou un élément d'un lot ([item]).
class SafeboxSharedFileScreen extends StatefulWidget {
  const SafeboxSharedFileScreen({super.key, required this.shareId, this.title, this.blur, this.item});

  final int shareId;
  final String? title;

  /// Mini-image floue du message, affichée avant l'aperçu net.
  final String? blur;

  /// Un élément d'un lot ; null pour le fichier d'un partage simple.
  final SafeboxShareItem? item;

  @override
  State<SafeboxSharedFileScreen> createState() => _SafeboxSharedFileScreenState();
}

class _SafeboxSharedFileScreenState extends State<SafeboxSharedFileScreen> {
  SafeboxShareInfo? _info;
  bool _charge = false;
  bool _surLeTelephone = false;
  bool _occupe = false;

  /// Gardé pendant cet écran : l'élément d'un lot ne se relit pas tout seul.
  bool _garde = false;

  SafeboxController get _c => context.read<SafeboxController>();
  SafeboxShareItem? get _element => widget.item ?? _info?.asItem();

  @override
  void initState() {
    super.initState();
    _info = _c.shareInfoCached(widget.shareId);
    _charger();
  }

  Future<void> _charger({bool refresh = false}) async {
    try {
      final info = await _c.shareInfo(widget.shareId, refresh: refresh);
      final element = widget.item ?? info?.asItem();
      final local = element != null && element.available && await _c.hasReceivedItem(element);
      if (!mounted) return;
      setState(() {
        _info = info;
        _surLeTelephone = local;
        _charge = true;
      });
    } catch (e) {
      if (mounted) setState(() => _charge = true);
    }
  }

  Future<void> _telecharger() async {
    final element = _element;
    if (element == null) return;
    final l10n = context.l10n;
    setState(() => _occupe = true);
    try {
      final r = await _c.fetchReceivedItem(element);
      if (!mounted) return;
      setState(() => _surLeTelephone = true);
      if (r.published) safeboxSnack(context, l10n.safeboxSavedToDownloads);
      if (r.saveFailed) safeboxSnack(context, l10n.safeboxSaveToDownloadsFailed, error: true);
      final ouvert = await _c.received.open(r.location, element.mime);
      if (!ouvert && mounted) safeboxSnack(context, l10n.safeboxOpenFailed, error: true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      if (e.code == 'SAFEBOX_SHARE_REVOKED') {
        await _charger(refresh: true);
      } else {
        _erreurPartage(context, e);
      }
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _garder() async {
    final element = _element;
    if (element == null) return;
    setState(() => _occupe = true);
    try {
      await _c.saveShare(widget.shareId, itemId: element.id);
      if (!mounted) return;
      safeboxSnack(context, context.l10n.safeboxShareSavedToast);
      _garde = true;
      await _charger(refresh: true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      if (e.code == 'SAFEBOX_SHARE_REVOKED') {
        await _charger(refresh: true);
      } else {
        _erreurPartage(context, e);
      }
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
    final element = _element;
    final c = context.watch<SafeboxController>();
    final progres = element == null ? null : c.downloads.progressOf(element.localId);
    final disponible = element != null && element.available && (info?.available ?? true);
    final dejaGarde = _garde || element?.savedFileId != null;
    final meta = element?.meta;
    final duree = meta?.durationLabel;
    final nom = element?.name ?? widget.title ?? '';
    final flou = safeboxDecodeBlur(widget.blur);
    final expediteur = _expediteur(l10n, info);
    final detail = element == null
        ? null
        : [
            safeboxSizeAndQuality(l10n, formatBytes(element.plainBytes, l10n), element.quality),
            ?duree,
            if (meta?.pages != null) l10n.safeboxMetaPages(meta!.pages!),
          ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxSharedFileTitle)),
      body: !_charge && info == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (flou != null) SafeboxBlur(bytes: flou) else ColoredBox(color: context.semantic.brandContainer),
                      if (element != null && disponible && element.previewUrl != null)
                        SafeboxFileThumb(file: element.asFile(), fill: true)
                      else if (flou == null && element != null)
                        Center(child: Icon(safeboxRootIcon(element.family.root), size: 56, color: context.colors.primary)),
                      if (element?.family == SafeboxFamily.videos)
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                            child: const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      if (duree != null)
                        Positioned(right: AppSpacing.md, bottom: AppSpacing.md, child: SafeboxImageLabel(duree)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(nom, style: context.text.titleLarge),
                      if (detail != null) ...[
                        AppSpacing.vGapXs,
                        Text(detail, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                      ],
                      AppSpacing.vGapMd,
                      Row(
                        children: [
                          AppAvatar(imageUrl: info?.sender?.avatarUrl, name: expediteur, size: 40),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.safeboxSharedBy(expediteur), style: context.text.titleSmall),
                                if (info?.createdAt != null)
                                  Text(safeboxDate(context, info!.createdAt),
                                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Rappel(sender: expediteur),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!disponible)
                        Text(
                          info?.removedByModeration == true
                              ? l10n.safeboxShareRemovedByModeration
                              : info?.revokedBySender == true
                                  ? l10n.safeboxShareRevoked
                                  : l10n.safeboxSharedUnavailable,
                          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                        )
                      else if (element.lost)
                        Text(l10n.safeboxShareLost, style: context.text.bodyMedium?.copyWith(color: context.colors.error))
                      else ...[
                        if (progres != null) ...[
                          LinearProgressIndicator(value: progres),
                          AppSpacing.vGapSm,
                        ],
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: _occupe ? null : _telecharger,
                          icon: Icon(_surLeTelephone ? Icons.open_in_new : Icons.download_rounded),
                          label: Text(_surLeTelephone ? l10n.safeboxOpen : l10n.safeboxSharedDownloadPlay),
                        ),
                        AppSpacing.vGapSm,
                        if (dejaGarde)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 18, color: context.semantic.success),
                              AppSpacing.hGapXs,
                              Text(l10n.safeboxShareSaved, style: context.text.bodyMedium),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            onPressed: _occupe ? null : _garder,
                            icon: const Icon(Icons.lock_outline),
                            label: Text(l10n.safeboxShareSave),
                          ),
                        AppSpacing.vGapSm,
                        Text(
                          [
                            if (element.plainBytes >= _gros)
                              l10n.safeboxSharedWifiAdvised(formatBytes(element.plainBytes, l10n)),
                            if (info?.downloadsLeft != null && !_surLeTelephone)
                              l10n.safeboxShareDownloadsLeft(info!.downloadsLeft!),
                          ].join(' '),
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Un lot ───────────────────────────────────────────────────────────────────

/// Un album ou une sélection reçus en une seule carte.
class SafeboxSharedAlbumScreen extends StatefulWidget {
  const SafeboxSharedAlbumScreen({super.key, required this.shareId, this.title});
  final int shareId;
  final String? title;

  @override
  State<SafeboxSharedAlbumScreen> createState() => _SafeboxSharedAlbumScreenState();
}

class _SafeboxSharedAlbumScreenState extends State<SafeboxSharedAlbumScreen> {
  SafeboxShareInfo? _info;
  List<SafeboxShareItem>? _elements;
  Object? _erreur;
  SafeboxFamily? _filtre;
  bool _occupe = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _info = _c.shareInfoCached(widget.shareId);
    _charger();
  }

  Future<void> _charger({bool refresh = false}) async {
    try {
      final info = await _c.shareInfo(widget.shareId, refresh: refresh);
      final elements = info == null ? const <SafeboxShareItem>[] : await _c.shareItems(widget.shareId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _elements = elements;
        _erreur = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  List<SafeboxShareItem> get _disponibles => (_elements ?? const []).where((e) => e.available && !e.lost).toList();

  Future<void> _garder() async {
    setState(() => _occupe = true);
    try {
      final album = await _c.saveShareBatch(widget.shareId);
      if (!mounted) return;
      safeboxSnack(context, context.l10n.safeboxSharedAlbumKept(album.name ?? widget.title ?? ''));
      await _charger(refresh: true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      if (e.code == 'SAFEBOX_SHARE_REVOKED') {
        await _charger(refresh: true);
      } else {
        _erreurPartage(context, e);
      }
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _toutTelecharger(String titre) async {
    final l10n = context.l10n;
    final fichiers = [for (final e in _disponibles) e.asFile()];
    if (fichiers.isEmpty) return;
    final choix = await showSafeboxDownloadSheet(context, selection: const [], folderName: titre);
    if (choix == null || !mounted) return;
    _c.exports.start(fichiers, target: choix.target, title: titre);
    safeboxSnack(context, l10n.safeboxDownloadStarted);
  }

  void _ouvrirElement(SafeboxShareItem e) {
    if (!e.available) {
      safeboxSnack(context, context.l10n.safeboxSharedUnavailable);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SafeboxSharedFileScreen(shareId: widget.shareId, item: e)),
    );
  }

  Widget? _filtres(AppLocalizations l10n, List<SafeboxShareItem> elements) {
    final parType = <SafeboxFamily, int>{};
    for (final e in elements) {
      parType[e.family] = (parType[e.family] ?? 0) + 1;
    }
    if (parType.length < 2) return null;
    Widget puce(SafeboxFamily? f, String label) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(label: Text(label), selected: _filtre == f, onSelected: (_) => setState(() => _filtre = f)),
        );
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        children: [
          puce(null, '${l10n.safeboxFilterAll} · ${elements.length}'),
          for (final f in SafeboxFamily.values)
            if (parType.containsKey(f)) puce(f, '${SafeboxController.rootLabel(f.root, l10n)} · ${parType[f]}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = _info;
    final elements = _elements;
    final titre = info?.name ?? widget.title ?? '';
    final expediteur = _expediteur(l10n, info);
    final disponibles = _disponibles;
    final visibles = elements == null ? const <SafeboxShareItem>[] : elements.where((e) => _filtre == null || e.family == _filtre).toList();
    final toutGarde = info != null && info.availableCount != null && info.availableCount! > 0 &&
        (info.savedCount ?? 0) >= info.availableCount!;
    final tailleDispo = disponibles.fold<int>(0, (s, e) => s + e.plainBytes);
    final filtres = elements == null ? null : _filtres(l10n, elements);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (info != null)
              Text(
                [
                  l10n.safeboxSharedFrom(expediteur),
                  l10n.safeboxShareItems(info.count),
                  formatBytes(info.plainBytes, l10n),
                ].join(' · '),
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
      bottomNavigationBar: info == null || !info.available || disponibles.isEmpty
          ? null
          : SafeArea(
              child: Material(
                color: context.colors.surface,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: toutGarde
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 18, color: context.semantic.success),
                                      AppSpacing.hGapXs,
                                      Flexible(child: Text(l10n.safeboxSharedAllKept, style: context.text.bodyMedium)),
                                    ],
                                  )
                                : OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                                    onPressed: _occupe ? null : _garder,
                                    icon: const Icon(Icons.lock_outline, size: 18),
                                    label: Text(l10n.safeboxShareSave, textAlign: TextAlign.center),
                                  ),
                          ),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                              onPressed: () => _toutTelecharger(titre),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(l10n.safeboxSharedDownloadAll),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vGapSm,
                      Text(
                        [
                          if (!toutGarde) l10n.safeboxSharedKeepAlbumHint(formatBytes(tailleDispo, l10n)),
                          if (info.downloadsLeft != null) l10n.safeboxShareDownloadsLeft(info.downloadsLeft!),
                        ].join(' '),
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: _erreur != null && elements == null
          ? Center(child: TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)))
          : elements == null
              ? const Center(child: CircularProgressIndicator())
              : info == null
                  ? Center(child: Text(l10n.safeboxShareUnavailableHere))
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _Rappel(sender: expediteur)),
                        if (!info.available)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                info.removedByModeration ? l10n.safeboxShareRemovedByModeration : l10n.safeboxShareRevoked,
                                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                              ),
                            ),
                          ),
                        if (filtres != null) SliverToBoxAdapter(child: filtres),
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          sliver: SliverGrid.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: AppSpacing.xs,
                              crossAxisSpacing: AppSpacing.xs,
                            ),
                            itemCount: visibles.length,
                            itemBuilder: (_, i) {
                              final e = visibles[i];
                              final tuile = SafeboxGridTile(
                                file: e.asFile(),
                                selecting: false,
                                selected: false,
                                onTap: () => _ouvrirElement(e),
                                onLongPress: () => _ouvrirElement(e),
                              );
                              return e.available ? tuile : Opacity(opacity: 0.4, child: tuile);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
