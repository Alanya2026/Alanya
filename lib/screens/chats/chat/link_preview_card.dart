import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/link_preview_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';

/// Carte d'aperçu affichée sous un message contenant un lien : vignette,
/// titre, description et domaine.
///
/// Affiche d'abord une carte domaine (fallback), puis enrichit avec les
/// métadonnées Open Graph si le fetch aboutit.
///
/// Style carte plate (type WhatsApp) : fond léger, contour discret, sans
/// bande d'accent latérale.
class LinkPreviewCard extends StatefulWidget {
  final String url;
  final bool isMe;

  const LinkPreviewCard({super.key, required this.url, required this.isMe});

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  late Future<LinkPreviewData> _future = LinkPreviewService.fetch(widget.url);

  @override
  void didUpdateWidget(covariant LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = LinkPreviewService.fetch(widget.url);
    }
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* ignoré */}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreviewData>(
      future: _future,
      builder: (context, snap) {
        // Pendant le chargement : carte domaine immédiate (toujours visible).
        final data = snap.data ?? LinkPreviewService.fallback(widget.url);
        return _card(context, data);
      },
    );
  }

  Widget _card(BuildContext context, LinkPreviewData data) {
    final colors = context.colors;
    final onBubble = widget.isMe ? colors.onPrimary : colors.onSurface;
    final bg = widget.isMe
        ? colors.onPrimary.withAlpha(32)
        : colors.surfaceContainerHighest.withAlpha(140);
    final borderColor = widget.isMe
        ? colors.onPrimary.withAlpha(40)
        : colors.outlineVariant.withAlpha(160);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        onTap: _open,
        child: SizedBox(
          // Largeur explicite : évite un layout à largeur nulle dans une
          // Column (width: infinity sans borne max effective).
          width: 260,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: borderColor, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: data.imageUrl!,
                    width: 260,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.domain.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: onBubble.withAlpha(150),
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (data.title != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          data.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: onBubble,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (data.description != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          data.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: onBubble.withAlpha(180),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
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
