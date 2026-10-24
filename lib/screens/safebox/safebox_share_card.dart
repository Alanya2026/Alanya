//  Carte d'un fichier du coffre-fort dans une discussion (message de type 11).
//
//  Ce que voit le destinataire avant de télécharger quoi que ce soit
//  (conception, section 07) : la mini-image floue du message tout de suite,
//  puis l'aperçu net, le nom, la taille, et deux boutons — télécharger, ou
//  enregistrer dans son coffre. Quand l'expéditeur supprime le fichier de son
//  coffre, la carte le dit.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/safebox_share_payload.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/paywall_sheet.dart';
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
  bool _ouvrable = false;
  bool _occupe = false;

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
      final local = info != null && await _c.hasReceived(info);
      if (!mounted) return;
      setState(() {
        _info = info;
        _introuvable = info == null;
        _ouvrable = local;
        _charge = true;
      });
    } catch (_) {
      if (mounted) setState(() => _charge = true);
    }
  }

  Future<void> _ouvrir() async {
    final info = _info;
    if (info == null) return;
    setState(() => _occupe = true);
    try {
      final r = await _c.fetchReceived(info);
      if (!mounted) return;
      setState(() => _ouvrable = true);
      if (r.published) safeboxSnack(context, context.l10n.safeboxSavedToDownloads);
      if (r.saveFailed) safeboxSnack(context, context.l10n.safeboxSaveToDownloadsFailed, error: true);
      final ouvert = await _c.received.open(r.location, info.mime);
      if (!ouvert && mounted) safeboxSnack(context, context.l10n.safeboxOpenFailed, error: true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      if (e.code == 'SAFEBOX_DOWNLOAD_LIMIT') {
        final limite = (e.details?['limit'] as num?)?.toInt() ?? 3;
        safeboxSnack(context, context.l10n.safeboxShareDownloadLimit(limite), error: true);
      } else if (e.code == 'SAFEBOX_SHARE_REVOKED') {
        await _charger(refresh: true);
      } else {
        safeboxShowError(context, e);
      }
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _enregistrer() async {
    setState(() => _occupe = true);
    try {
      await _c.saveShare(widget.payload.share);
      if (!mounted) return;
      await _charger();
      if (mounted) safeboxSnack(context, context.l10n.safeboxShareSavedToast);
    } on TalkyException catch (e) {
      if (!mounted) return;
      if (e.code == 'SAFEBOX_QUOTA_EXCEEDED') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.safeboxQuotaExceeded),
          action: SnackBarAction(label: context.l10n.safeboxGoPlus, onPressed: () => showPaywall(context, null)),
        ));
      } else if (e.code == 'SAFEBOX_SHARE_REVOKED') {
        await _charger(refresh: true);
      } else {
        safeboxShowError(context, e);
      }
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// Durée d'une vidéo ou d'un audio, sinon pages d'un PDF.
  String? _basDroite(SafeboxMeta? meta) {
    if (meta == null) return null;
    if (meta.durationLabel != null) return meta.durationLabel;
    if (meta.pages != null) return context.l10n.safeboxMetaPages(meta.pages!);
    return null;
  }

  /// La carte peut-elle montrer une image (mini-image floue ou aperçu net) ?
  bool _avecImage(SafeboxShareInfo? info) =>
      (widget.payload.blur != null && _decode(widget.payload.blur!) != null) ||
      (info?.previewUrl != null && info!.available);

  Widget _visuel(SafeboxShareInfo? info, SafeboxMeta? meta) {
    final p = widget.payload;
    final flou = p.blur == null ? null : _decode(p.blur!);
    final avecImage = _avecImage(info);
    if (!avecImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Icon(safeboxRootIcon(p.family.root), size: 36, color: widget.mutedColor),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.brSm,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (flou != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Image.memory(flou, fit: BoxFit.cover, gaplessPlayback: true),
              )
            else
              ColoredBox(color: context.semantic.brandContainer),
            if (info != null && info.available && info.previewUrl != null)
              SafeboxFileThumb(file: info.asFile(), fill: true),
            if (p.family == SafeboxFamily.videos)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            if (meta?.definitionLabel != null)
              Positioned(top: AppSpacing.xs, left: AppSpacing.xs, child: _Pastille(meta!.definitionLabel!)),
            if (_basDroite(meta) != null)
              Positioned(bottom: AppSpacing.xs, right: AppSpacing.xs, child: _Pastille(_basDroite(meta)!)),
          ],
        ),
      ),
    );
  }

  /// Mini-images décodées, pour ne pas refaire le travail à chaque image.
  static final Map<String, Uint8List?> _flous = {};
  Uint8List? _decode(String b64) {
    return _flous.putIfAbsent(b64, () {
      try {
        return base64Decode(b64);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.payload;
    final info = _info;
    final retire = info != null && !info.available;
    final progres = info == null ? null : context.watch<SafeboxController>().downloads.progressOf(info.localId);
    final dejaChezMoi = info?.savedFileId != null;
    final meta = p.meta ?? info?.meta;
    final morceau = [meta?.artist, meta?.title].whereType<String>().join(' — ');

    final sousTitre = <String>[
      formatBytes(p.size, l10n),
      // Sans image, la durée ou les pages passent dans la ligne de détails.
      if (!_avecImage(info) && _basDroite(meta) != null) _basDroite(meta)!,
      if (widget.isMe) l10n.safeboxShareFromVault,
      if (!widget.isMe && info?.downloadsLeft != null && !_ouvrable && !retire)
        l10n.safeboxShareDownloadsLeft(info!.downloadsLeft!),
    ].join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _visuel(info, meta),
          AppSpacing.vGapSm,
          Text(p.name.isEmpty ? l10n.safeboxShareFallback : p.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: context.text.bodyLarge?.copyWith(color: widget.textColor, fontWeight: FontWeight.w600)),
          if (morceau.isNotEmpty)
            Text(morceau, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: widget.textColor)),
          Text(sousTitre, style: context.text.bodySmall?.copyWith(color: widget.mutedColor)),
          AppSpacing.vGapSm,
          if (_introuvable)
            Text(l10n.safeboxShareUnavailableHere, style: context.text.bodySmall?.copyWith(color: widget.mutedColor))
          else if (info != null && info.available && info.lost)
            Row(
              children: [
                Icon(Icons.broken_image_outlined, size: 16, color: context.colors.error),
                AppSpacing.hGapXs,
                Flexible(
                  child: Text(l10n.safeboxShareLost,
                      style: context.text.bodySmall?.copyWith(color: context.colors.error)),
                ),
              ],
            )
          else if (retire)
            Row(
              children: [
                Icon(Icons.block, size: 16, color: widget.mutedColor),
                AppSpacing.hGapXs,
                Flexible(
                  child: Text(info.removedByModeration ? l10n.safeboxShareRemovedByModeration : l10n.safeboxShareRevoked,
                      style: context.text.bodySmall?.copyWith(color: widget.mutedColor, fontStyle: FontStyle.italic)),
                ),
              ],
            )
          else if (!_charge)
            const SizedBox(height: 4, child: LinearProgressIndicator())
          else ...[
            if (progres != null) ...[
              LinearProgressIndicator(value: progres),
              AppSpacing.vGapXs,
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _occupe ? null : _ouvrir,
                  icon: Icon(_ouvrable ? Icons.open_in_new : Icons.download, size: 18),
                  label: Text(_ouvrable ? l10n.safeboxOpen : l10n.safeboxShareDownload(formatBytes(p.size, l10n))),
                ),
                if (!widget.isMe)
                  dejaChezMoi
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, size: 16, color: context.semantic.success),
                            AppSpacing.hGapXs,
                            Text(l10n.safeboxShareSaved, style: context.text.bodySmall?.copyWith(color: widget.mutedColor)),
                          ]),
                        )
                      : TextButton.icon(
                          onPressed: _occupe ? null : _enregistrer,
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: Text(l10n.safeboxShareSave),
                        ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Petite étiquette sur l'image : « 1080p », « 12:47 », « 4 pages ».
class _Pastille extends StatelessWidget {
  const _Pastille(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black54, borderRadius: AppRadius.brSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2, vertical: 2),
          child: Text(texte, style: context.text.labelSmall?.copyWith(color: Colors.white)),
        ),
      );
}
