//  Carte d'un partage du coffre-fort dans une discussion (message de type 11).
//
//  Maquettes « Envoi dans les discussions » (24/10/2026, lot 9) : pas de lien,
//  un bouton qui ouvre un écran dans Alanya. Chez le destinataire, un fichier
//  montre sa vignette, sa durée, son nom, sa taille et son format, avec
//  « Ouvrir » ; un lot (album, sélection) montre une mosaïque de quatre
//  vignettes, son titre, son contenu, avec « Voir l'album ». Chez
//  l'expéditeur : « Depuis votre coffre-fort », « Téléchargé par 2 sur 7 » et
//  « Voir le suivi ». La mini-image floue du message s'affiche tout de suite,
//  même hors connexion, avant l'aperçu net. Quand le fichier est retiré, la
//  carte le dit.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/safebox_share_payload.dart';
import 'safebox_share_tracking_screen.dart';
import 'safebox_share_widgets.dart';
import 'safebox_shared_screens.dart';
import 'safebox_widgets.dart';

class SafeboxShareCard extends StatefulWidget {
  const SafeboxShareCard({
    super.key,
    required this.payload,
    required this.isMe,
    required this.textColor,
    required this.mutedColor,
  });

  final SafeboxSharePayload payload;
  final bool isMe;
  final Color textColor;
  final Color mutedColor;

  @override
  State<SafeboxShareCard> createState() => _SafeboxShareCardState();
}

class _SafeboxShareCardState extends State<SafeboxShareCard> {
  SafeboxShareInfo? _info;
  bool _charge = false;
  bool _introuvable = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    _info = _c.shareInfoCached(widget.payload.share);
    _charger();
  }

  Future<void> _charger({bool refresh = false}) async {
    try {
      final info = await _c.shareInfo(widget.payload.share, refresh: refresh);
      if (!mounted) return;
      setState(() {
        _info = info;
        _introuvable = info == null;
        _charge = true;
      });
    } catch (_) {
      if (mounted) setState(() => _charge = true);
    }
  }

  /// Le bouton de la carte : l'écran du fichier ou de l'album, ou le suivi
  /// chez l'expéditeur. La carte se relit au retour (téléchargé, gardé…).
  Future<void> _ouvrir() async {
    final p = widget.payload;
    final Widget ecran = widget.isMe
        ? SafeboxShareTrackingScreen(shareId: p.share, title: p.name)
        : p.isBatch
            ? SafeboxSharedAlbumScreen(shareId: p.share, title: p.name)
            : SafeboxSharedFileScreen(shareId: p.share, title: p.name, blur: p.blur);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
    if (mounted) await _charger(refresh: true);
  }

  /// Durée d'une vidéo ou d'un audio, sinon pages d'un PDF.
  String? _basDroite(SafeboxMeta? meta) {
    if (meta == null) return null;
    if (meta.durationLabel != null) return meta.durationLabel;
    if (meta.pages != null) return context.l10n.safeboxMetaPages(meta.pages!);
    return null;
  }

  /// La carte d'un fichier peut-elle montrer une image (mini-image floue ou aperçu net) ?
  bool _avecImage(SafeboxShareInfo? info) =>
      safeboxDecodeBlur(widget.payload.blur) != null || (info?.previewUrl != null && info!.available);

  Widget _image(SafeboxShareInfo? info, SafeboxMeta? meta) {
    final p = widget.payload;
    final flou = safeboxDecodeBlur(p.blur);
    final basDroite = _basDroite(meta);
    return ClipRRect(
      borderRadius: AppRadius.brMd,
      child: SizedBox(
        height: 152,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (flou != null) SafeboxBlur(bytes: flou) else ColoredBox(color: context.semantic.brandContainer),
            if (info != null && info.available && info.previewUrl != null)
              SafeboxFileThumb(file: info.asFile(), fill: true),
            if (p.family == SafeboxFamily.videos)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm + 2),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            if (!widget.isMe) const Positioned(left: AppSpacing.sm, top: AppSpacing.sm, child: SafeboxVaultBadge()),
            if (meta?.definitionLabel != null)
              Positioned(top: AppSpacing.sm, right: AppSpacing.sm, child: SafeboxImageLabel(meta!.definitionLabel!)),
            if (basDroite != null)
              Positioned(bottom: AppSpacing.sm, right: AppSpacing.sm, child: SafeboxImageLabel(basDroite)),
          ],
        ),
      ),
    );
  }

  /// Un fichier sans image : son type dans une case, son nom et sa taille.
  Widget _ligneFichier(SafeboxShareInfo? info, String detail) {
    final p = widget.payload;
    final ext = safeboxExtensionOf(p.name).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withValues(alpha: 0.12) : context.semantic.brandContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white : context.semantic.brandContainer,
              borderRadius: AppRadius.brSm,
            ),
            child: ext.isEmpty || ext.length > 4
                ? Icon(safeboxRootIcon(p.family.root), color: context.colors.primary)
                : Text(ext,
                    style: context.text.labelSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w700)),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name.isEmpty ? context.l10n.safeboxShareFallback : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(color: widget.textColor, fontWeight: FontWeight.w500)),
                Text(detail, style: context.text.bodySmall?.copyWith(color: widget.mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etat(IconData icone, String texte, {Color? couleur}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icone, size: 16, color: couleur ?? widget.mutedColor),
            AppSpacing.hGapXs,
            Flexible(
              child: Text(texte,
                  style: context.text.bodySmall?.copyWith(
                    color: couleur ?? widget.mutedColor,
                    fontStyle: couleur == null ? FontStyle.italic : null,
                  )),
            ),
          ],
        ),
      );

  Widget _bouton(IconData icone, String label) {
    final style = widget.isMe
        ? FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: context.colors.primary)
        : null;
    return FilledButton.icon(
      style: (style ?? const ButtonStyle()).merge(
        FilledButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm)),
      ),
      onPressed: _ouvrir,
      icon: Icon(icone, size: 18),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.payload;
    final info = _info;
    final retire = info != null && !info.available;
    final meta = p.meta ?? info?.meta;
    final morceau = [meta?.artist, meta?.title].whereType<String>().join(' — ');
    final taille = formatBytes(p.size, l10n);
    final detail = p.isBatch
        ? '${l10n.safeboxShareItems(p.count)} · $taille'
        : safeboxSizeAndQuality(l10n, taille, info?.quality ?? SafeboxQuality.original);
    final titreStyle = context.text.titleSmall?.copyWith(color: widget.textColor, fontWeight: FontWeight.w500);
    final detailStyle = context.text.bodySmall?.copyWith(color: widget.mutedColor);
    final avecImage = !p.isBatch && _avecImage(info);

    final etat = <Widget>[
      if (_introuvable)
        _etat(Icons.info_outline, l10n.safeboxShareUnavailableHere)
      else if (info != null && info.available && info.lost)
        _etat(Icons.broken_image_outlined, l10n.safeboxShareLost, couleur: context.colors.error)
      else if (retire)
        _etat(Icons.block, info.removedByModeration ? l10n.safeboxShareRemovedByModeration : l10n.safeboxShareRevoked)
      else if (!_charge)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: SizedBox(height: 4, child: LinearProgressIndicator()),
        )
      else ...[
        if (widget.isMe && info?.tracking != null)
          _etat(
            Icons.download_rounded,
            l10n.safeboxShareDownloadedBy(info!.tracking!.received, info.tracking!.members),
            couleur: widget.textColor,
          ),
        if (widget.isMe)
          _bouton(Icons.people_outline, l10n.safeboxShareSeeTracking)
        else if (p.isBatch)
          _bouton(Icons.grid_view_rounded, l10n.safeboxShareSeeAlbum)
        else
          _bouton(Icons.play_arrow_rounded, l10n.safeboxOpen),
      ],
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 272),
      child: InkWell(
        onTap: _introuvable || retire ? null : _ouvrir,
        borderRadius: AppRadius.brMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isMe)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: widget.mutedColor),
                    const SizedBox(width: 5),
                    Text(l10n.safeboxShareFromVault, style: detailStyle),
                  ],
                ),
              ),
            if (p.isBatch)
              SafeboxShareMosaic(
                count: p.count,
                blurs: p.mosaic,
                items: retire ? const [] : info?.cover ?? const [],
                height: widget.isMe ? 100 : 112,
              )
            else if (avecImage)
              _image(info, meta)
            else
              _ligneFichier(info, detail),
            if (p.isBatch || avecImage) ...[
              AppSpacing.vGapSm,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name.isEmpty ? l10n.safeboxShareFallback : p.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: titreStyle),
                    if (morceau.isNotEmpty)
                      Text(morceau, maxLines: 1, overflow: TextOverflow.ellipsis, style: detailStyle),
                    Text(detail, style: detailStyle),
                    if (p.isBatch && p.families.isNotEmpty)
                      Text(safeboxFamiliesLabel(l10n, p.families), style: detailStyle),
                  ],
                ),
              ),
            ],
            for (final w in etat) ...[AppSpacing.vGapSm, w],
          ],
        ),
      ),
    );
  }
}
