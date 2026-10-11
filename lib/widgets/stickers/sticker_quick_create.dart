import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/stickers/sticker_animated_check.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_image_adapter.dart';
import '../../core/services/stickers/sticker_image_check.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'sticker_animated_screen.dart';
import 'sticker_created_pack_screen.dart';
import 'sticker_creation_flows.dart';

/// Ouvre l'écran « Sticker animé » pour le bouton « Créer » : sans pack (le
/// serveur dépose le sticker dans le pack perso par défaut). Injectable.
typedef StickerQuickAnimatedFlow =
    Future<StickerAnimatedResult?> Function(
      BuildContext context,
      Uint8List bytes,
      String filename,
    );

Future<StickerAnimatedResult?> _openAnimated(
  BuildContext context,
  Uint8List bytes,
  String filename,
) => Navigator.of(context).push<StickerAnimatedResult>(
  MaterialPageRoute(
    builder: (_) =>
        StickerAnimatedScreen(packId: null, bytes: bytes, filename: filename),
  ),
);

/// Sélecteur de la galerie, **sans** `maxWidth` ni `imageQuality` (rien n'est
/// ré-encodé ici : l'adaptation ou le serveur s'en charge). La taille est
/// connue avant lecture : un fichier énorme n'est jamais chargé.
Future<({Uint8List bytes, String name})?> _pickFromGallery() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  final limit = math.max(
    StickerImageAdapter.maxInputBytes,
    StickerAnimatedCheck.maxBytes,
  );
  if (await x.length() > limit) {
    throw const StickerImageRejected(StickerImageIssue.inputTooBig);
  }
  return (bytes: await x.readAsBytes(), name: x.name);
}

/// Points d'injection du parcours de création (tests) ; chaque champ nul prend
/// son comportement de production.
class StickerCreateHooks {
  const StickerCreateHooks({
    this.pickImage,
    this.adaptImage,
    this.editImage,
    this.animatedFlow,
  });

  final StickerImagePicker? pickImage;
  final StickerImageAdaptation? adaptImage;
  final StickerImageEditor? editImage;
  final StickerQuickAnimatedFlow? animatedFlow;
}

/// Tuile « Créer » : première case de l'onglet Récents du plateau.
///
/// Au toucher : avis de confidentialité (une seule fois, mémorisé), puis
/// sélecteur de la galerie, puis le parcours de création — adaptation
/// 512×512, aperçu Annuler / Modifier / Ajouter (ou écran « Sticker animé » si
/// le fichier est animé et que `features.animated` est vrai). « Ajouter »
/// envoie `POST /assets` **sans** `packId` : le serveur range le sticker dans
/// le pack perso par défaut, créé à la première fois. Le sticker passe en tête
/// des Récents, et un message propose de voir le pack.
class StickerCreateTile extends StatefulWidget {
  const StickerCreateTile({
    super.key,
    required this.creation,
    required this.stickers,
    required this.onViewPack,
    this.hooks = const StickerCreateHooks(),
  });

  final StickerCreationRepository creation;
  final StickerRepository stickers;

  /// « Voir » du message de confirmation : ouvre l'onglet de ce pack.
  final void Function(int packId) onViewPack;
  final StickerCreateHooks hooks;

  @override
  State<StickerCreateTile> createState() => _StickerCreateTileState();
}

class _StickerCreateTileState extends State<StickerCreateTile> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    var animated = false;
    try {
      if (!await ensureStickerPrivacyAck(context) || !mounted) return;
      final picked = await (widget.hooks.pickImage ?? _pickFromGallery)();
      if (picked == null || !mounted) return;

      final StickerUploadResult? result;
      // Un GIF / WebP animé : parcours animé si le serveur ouvre les animés.
      if (widget.creation.features.animated.value &&
          StickerAnimatedCheck.isAnimated(picked.bytes)) {
        animated = true;
        StickerAnimatedCheck.validate(picked.bytes);
        final r = await (widget.hooks.animatedFlow ?? _openAnimated)(
          context,
          picked.bytes,
          picked.name,
        );
        result = r?.upload;
      } else {
        result = await _createStatic(picked);
      }
      if (result == null) return;

      // Tête des Récents tout de suite (local à l'appareil, Drift).
      if (result.stickerId > 0) {
        await widget.stickers.markUsed(result.stickerId);
      }
      final pack = result.packId > 0
          ? await widget.creation.packById(result.packId)
          : null;
      if (messenger == null) return;
      final name = (pack?.name.isNotEmpty ?? false)
          ? pack!.name
          : l10n.stickerDefaultPackName;
      final viewable = result.packId > 0;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.reused
                ? l10n.stickerAlreadyOwned
                : l10n.stickerCreatedInMyStickers(name),
          ),
          action: viewable
              ? SnackBarAction(
                  label: l10n.stickerView,
                  onPressed: () => widget.onViewPack(result!.packId),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (animated) {
        showAnimatedCreationError(context, e);
      } else {
        showStickerCreationError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Image fixe : adaptation 512×512, aperçu (Annuler / Modifier / Ajouter),
  /// envoi sans pack. `null` si l'utilisateur renonce.
  Future<StickerUploadResult?> _createStatic(
    ({Uint8List bytes, String name}) picked,
  ) async {
    var png = await (widget.hooks.adaptImage ?? StickerImageAdapter.adapt)(
      picked.bytes,
    );
    var editorSource = picked.bytes;
    while (true) {
      if (!mounted) return null;
      final choice = await confirmStickerPreview(context, png);
      if (!mounted || choice == StickerPreviewChoice.cancel) return null;
      if (choice == StickerPreviewChoice.add) break;
      final edited = await (widget.hooks.editImage ?? openStickerEditor)(
        context,
        editorSource,
      );
      if (edited != null) {
        png = edited;
        editorSource = edited;
      }
    }
    return widget.creation.addStickerFromImage(
      null,
      png,
      filename: picked.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.stickerCreateTile;
    return Semantics(
      button: true,
      enabled: !_busy,
      label: label,
      excludeSemantics: true,
      onTap: _busy ? null : _start,
      child: InkWell(
        key: const ValueKey('sticker-create-tile'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: _busy ? null : _start,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.minTapTarget,
            minHeight: AppSizes.minTapTarget,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      key: const ValueKey('sticker-create-busy'),
                      strokeWidth: 2,
                      color: colors.onSurface,
                    ),
                  )
                else
                  Icon(Icons.add, size: 28, color: colors.onSurface),
                AppSpacing.vGapXs,
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
