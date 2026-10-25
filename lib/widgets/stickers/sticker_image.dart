import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/services/stickers/sticker_cache.dart';
import '../../core/services/stickers/sticker_trust.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Image d'un sticker, lue dans le cache dédié ([StickerCache]).
///
/// Trois issues, toutes prévues — aucune n'est une « erreur » à l'écran :
/// l'image, le repli « Sticker retiré » (fichier 404/410 côté serveur : état
/// prévu du contrat §4 du plan) et, sur une panne réseau, l'emoji seul.
class StickerImage extends StatelessWidget {
  const StickerImage({
    super.key,
    required this.url,
    required this.emoji,
    this.thumbUrl,
    this.size = 150,
    this.semanticLabel,
    this.showRemovedLabel = true,
    this.staticFrame = false,
  });

  final String url;
  final String emoji;

  /// Vignette 96×96 affichée pendant le chargement du sticker complet.
  final String? thumbUrl;
  final double size;
  final String? semanticLabel;

  /// Faux pour les petites vignettes du plateau : l'emoji suffit.
  final bool showRemovedLabel;

  /// Image **fixe** : affiche la vignette 96×96 (première image) au lieu du
  /// fichier complet. Pour tout ce qui n'est pas la bulle ou la fiche d'un
  /// sticker animé (plateau, listes, couvertures, citations) : un WebP animé
  /// tournerait en boucle dans une liste et coûterait CPU et batterie.
  final bool staticFrame;

  @override
  Widget build(BuildContext context) {
    // Image fixe : la vignette prend la place du fichier complet.
    final staticThumb =
        staticFrame ? (thumbUrl ?? stickerThumbUrlOf(url)) : null;
    final shownUrl = staticThumb ?? url;
    final shownThumb = staticThumb == null ? thumbUrl : null;
    // URL non fiable (hôte étranger, chemin hors stickers — cf. StickerTrust) :
    // on ne télécharge RIEN, on affiche le repli. Protection contre une
    // `mediaUrl` malveillante stockée dans un ancien message de type 10.
    if (!StickerTrust.isTrustedStickerUrl(shownUrl) ||
        (shownThumb != null &&
            !StickerTrust.isTrustedStickerUrl(shownThumb))) {
      return StickerFallback(
        emoji: emoji,
        size: size,
        showLabel: showRemovedLabel,
        // Ce n'est pas un retrait serveur : pas de « Sticker retiré ».
      );
    }
    final cache = StickerCache.instance.manager;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticLabel ?? context.l10n.stickerSemantics(emoji),
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: shownUrl,
          cacheManager: cache,
          fit: BoxFit.contain,
          fadeInDuration: reduce ? Duration.zero : const Duration(milliseconds: 120),
          fadeOutDuration: reduce ? Duration.zero : const Duration(milliseconds: 80),
          placeholder: (_, _) => (shownThumb == null || shownThumb.isEmpty)
              ? Center(child: _EmojiOnly(emoji: emoji, size: size))
              : CachedNetworkImage(
                  imageUrl: shownThumb,
                  cacheManager: cache,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  errorWidget: (_, _, _) =>
                      Center(child: _EmojiOnly(emoji: emoji, size: size)),
                ),
          errorWidget: (_, _, error) => StickerFallback(
            emoji: emoji,
            size: size,
            removed: isStickerGone(error),
            showLabel: showRemovedLabel,
          ),
        ),
      ),
    );
  }
}

/// Vignette statique (`…_t.webp`, 96×96, première image) d'un fichier sticker
/// (contrat §8 : même clé + `_t.webp`, pour les officiels comme pour les
/// stickers perso). `null` si [url] n'est pas un `.webp` ; l'URL d'une
/// vignette se rend telle quelle.
String? stickerThumbUrlOf(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final path = uri.path;
  if (!path.toLowerCase().endsWith('.webp')) return null;
  if (path.toLowerCase().endsWith('_t.webp')) return url;
  final thumbPath = '${path.substring(0, path.length - '.webp'.length)}_t.webp';
  return uri.replace(path: thumbPath).toString();
}

/// Le serveur a répondu « n'existe plus » (404/410) : fichier retiré.
bool isStickerGone(Object? error) =>
    error is HttpExceptionWithStatus &&
    (error.statusCode == 404 || error.statusCode == 410);

class _EmojiOnly extends StatelessWidget {
  const _EmojiOnly({required this.emoji, required this.size});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: TextStyle(fontSize: size * 0.34));
}

/// Repli d'un sticker qui ne s'affiche pas : l'emoji du payload et, quand le
/// fichier a été retiré, le libellé « Sticker retiré » (jamais le JSON).
class StickerFallback extends StatelessWidget {
  const StickerFallback({
    super.key,
    required this.emoji,
    this.size = 150,
    this.removed = false,
    this.showLabel = true,
    this.label,
  });

  final String emoji;
  final double size;

  /// Fichier retiré par le serveur.
  final bool removed;
  final bool showLabel;

  /// Libellé forcé (« Sticker non pris en charge » pour une version future).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (removed ? context.l10n.stickerRemoved : context.l10n.stickerWord);
    return Semantics(
      label: emoji.isEmpty ? text : '$emoji $text',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.semantic.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty)
              Text(emoji,
                  style: TextStyle(fontSize: size * (showLabel ? 0.30 : 0.38))),
            if (showLabel) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
