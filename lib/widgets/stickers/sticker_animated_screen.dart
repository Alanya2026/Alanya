import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart' show TalkyException;
import '../../core/services/stickers/sticker_repository.dart';
import 'non_looping_animated_sticker.dart';
import 'sticker_creation_flows.dart';

/// Écran « Sticker animé » (V1c, contrat §4c) : forme, aperçu **animé** découpé
/// dans la forme, « Ajouter ».
///
/// L'aperçu n'est qu'un aperçu : le fichier choisi part **tel quel** au
/// serveur (`POST /assets/animated`, champ `shape`), qui recadre en 512×512,
/// applique la forme à chaque image, tronque à 3 s / 45 images et ré-encode
/// (jusqu'à ~15 s). Pendant ce temps : indicateur et bouton « Annuler ».
///
/// Ferme avec le [StickerAnimatedResult] en cas de succès, `null` sinon
/// (retour, animés fermés côté serveur).
class StickerAnimatedScreen extends StatefulWidget {
  const StickerAnimatedScreen({
    super.key,
    required this.packId,
    required this.bytes,
    required this.filename,
  });

  /// `null` : pack perso par défaut côté serveur (bouton « Créer » du plateau).
  final int? packId;
  final Uint8List bytes;
  final String filename;

  @override
  State<StickerAnimatedScreen> createState() => _StickerAnimatedScreenState();
}

/// Côté de l'aperçu, en dp.
const double _kPreviewSide = 240;

/// Rayon du « carré arrondi » en fraction du côté (aperçu seulement).
const double _kRoundedRatio = 0.22;

class _StickerAnimatedScreenState extends State<StickerAnimatedScreen> {
  late final StickerCreationRepository _repo = context
      .read<StickerCreationRepository>();
  StickerAnimatedShape _shape = StickerAnimatedShape.carreArrondi;
  bool _sending = false;
  bool _cancelled = false;
  Completer<void>? _cancel;

  @override
  void dispose() {
    // Écran fermé en cours d'envoi : la requête est interrompue.
    final c = _cancel;
    if (c != null && !c.isCompleted) c.complete();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final l10n = context.l10n;
    final cancel = Completer<void>();
    setState(() {
      _sending = true;
      _cancelled = false;
      _cancel = cancel;
    });
    try {
      final r = await _repo.addAnimatedSticker(
        widget.packId,
        widget.bytes,
        filename: widget.filename,
        shape: _shape,
        cancel: cancel.future,
      );
      if (!mounted) return;
      nav.pop(r);
    } catch (e) {
      if (!mounted) return;
      if (_cancelled) {
        // Le serveur a peut-être fini avant l'annulation : on relit mes packs.
        unawaited(_repo.syncCreated());
        return;
      }
      final closed = e is TalkyException && StickerRepository.isModuleClosed(e);
      if (closed) {
        // Animés fermés : l'option a disparu (drapeau), on quitte l'écran.
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.stickerAnimatedClosed)),
        );
        nav.pop();
        return;
      }
      showAnimatedCreationError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _cancel = null;
        });
      }
    }
  }

  void _cancelSend() {
    final c = _cancel;
    if (!_sending || c == null || c.isCompleted) return;
    _cancelled = true;
    c.complete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return PopScope(
      // Retour pendant la conversion : annule l'envoi, on reste sur l'écran.
      canPop: !_sending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sending) _cancelSend();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.stickerAnimatedTitle)),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Semantics(
                    label: l10n.stickerAnimatedPreviewLabel,
                    image: true,
                    excludeSemantics: true,
                    child: _ShapePreview(
                      key: const ValueKey('sticker-animated-preview'),
                      bytes: widget.bytes,
                      shape: _shape,
                    ),
                  ),
                ),
                AppSpacing.vGapLg,
                Text(l10n.stickerAnimatedShape, style: context.text.titleSmall),
                AppSpacing.vGapSm,
                SegmentedButton<StickerAnimatedShape>(
                  key: const ValueKey('sticker-animated-shapes'),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(
                      AppSizes.minTapTarget,
                      AppSizes.buttonHeight,
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: StickerAnimatedShape.cercle,
                      icon: const Icon(Icons.circle_outlined),
                      label: Text(l10n.stickerShapeCircle),
                    ),
                    ButtonSegment(
                      value: StickerAnimatedShape.carreArrondi,
                      icon: const Icon(Icons.rounded_corner),
                      label: Text(l10n.stickerShapeRounded),
                    ),
                    ButtonSegment(
                      value: StickerAnimatedShape.carre,
                      icon: const Icon(Icons.crop_square),
                      label: Text(l10n.stickerShapeSquare),
                    ),
                  ],
                  selected: {_shape},
                  onSelectionChanged: _sending
                      ? null
                      : (s) => setState(() => _shape = s.first),
                ),
                AppSpacing.vGapMd,
                Text(
                  l10n.stickerAnimatedHint,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapXl,
                FilledButton(
                  key: const ValueKey('sticker-animated-add'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                  onPressed: _sending ? null : _send,
                  child: Text(l10n.stickerPreviewAdd),
                ),
              ],
            ),
            if (_sending)
              Positioned.fill(
                child: StickerConvertingOverlay(onCancel: _cancelSend),
              ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu animé du fichier choisi, **découpé dans la forme** côté client
/// (simple aperçu : le vrai masque est posé par le serveur, image par image).
class _ShapePreview extends StatelessWidget {
  const _ShapePreview({super.key, required this.bytes, required this.shape});

  final Uint8List bytes;
  final StickerAnimatedShape shape;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final radius = switch (shape) {
      StickerAnimatedShape.cercle => _kPreviewSide / 2,
      StickerAnimatedShape.carreArrondi => _kPreviewSide * _kRoundedRatio,
      StickerAnimatedShape.carre => 0.0,
    };
    // « Réduire les animations » : première image seulement, jamais de boucle.
    final Widget content = reduce
        ? NonLoopingAnimatedSticker(
            url: 'memory://preview',
            emoji: '',
            size: _kPreviewSide,
            animate: false,
            interactive: false,
            fit: BoxFit.cover,
            loadBytes: (_) async => bytes,
          )
        : Image.memory(
            bytes,
            width: _kPreviewSide,
            height: _kPreviewSide,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: (_kPreviewSide * dpr).round(),
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: context.colors.onSurfaceVariant,
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        key: const ValueKey('sticker-animated-clip'),
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: _kPreviewSide,
          height: _kPreviewSide,
          child: content,
        ),
      ),
    );
  }
}

/// Voile de conversion : indicateur et « Annuler » (la conversion serveur peut
/// durer jusqu'à ~15 s ; plus pour une vidéo, d'où [title] et [hint]).
class StickerConvertingOverlay extends StatelessWidget {
  const StickerConvertingOverlay({
    super.key,
    required this.onCancel,
    this.title,
    this.hint,
  });
  final VoidCallback onCancel;
  final String? title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: colors.scrim.withValues(alpha: 0.45),
        ),
        Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: title ?? l10n.stickerAnimatedConverting,
            child: Card(
              margin: const EdgeInsets.all(AppSpacing.xxl),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      key: ValueKey('sticker-animated-progress'),
                    ),
                    AppSpacing.vGapLg,
                    Text(
                      title ?? l10n.stickerAnimatedConverting,
                      style: context.text.titleSmall,
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      hint ?? l10n.stickerAnimatedConvertingHint,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    OutlinedButton(
                      key: const ValueKey('sticker-animated-cancel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          AppSizes.minTapTarget,
                          AppSizes.buttonHeight,
                        ),
                      ),
                      onPressed: onCancel,
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
