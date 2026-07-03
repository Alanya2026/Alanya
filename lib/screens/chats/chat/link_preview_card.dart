import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/link_preview_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';

/// Carte d'aperçu affichée sous un message contenant un lien : vignette,
/// titre, description et domaine. Se dessine uniquement si le site expose des
/// métadonnées Open Graph exploitables ; sinon elle ne rend rien.
class LinkPreviewCard extends StatefulWidget {
  final String url;
  final bool isMe;

  const LinkPreviewCard({super.key, required this.url, required this.isMe});

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  late final Future<LinkPreviewData?> _future = LinkPreviewService.fetch(widget.url);

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* ignoré */}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreviewData?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        // Rien tant que ça charge, ou si le site n'a pas d'aperçu.
        if (data == null || !data.hasContent) return const SizedBox.shrink();

        final colors = context.colors;
        final onBubble = widget.isMe ? colors.onPrimary : colors.onSurface;
        final bg = widget.isMe
            ? colors.onPrimary.withAlpha(30)
            : colors.surfaceContainerHighest.withAlpha(120);

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: _open,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.brMd,
                border: Border(
                  left: BorderSide(
                    color: widget.isMe ? colors.onPrimary : colors.primary,
                    width: 3,
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: data.imageUrl!,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.domain,
                          style: context.text.labelSmall?.copyWith(
                            color: onBubble.withAlpha(160),
                          ),
                        ),
                        if (data.title != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: onBubble,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (data.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: onBubble.withAlpha(190),
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
        );
      },
    );
  }
}
