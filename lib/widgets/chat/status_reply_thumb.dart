import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/media_cache_service.dart';
import '../../core/services/video_thumbnail_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/status_reply_payload.dart';
import '../image_message_preview.dart';

/// Mini-vignette carrée d'un statut cité dans une bulle de réponse.
class StatusReplyThumb extends StatelessWidget {
  const StatusReplyThumb({
    super.key,
    required this.payload,
    this.size = 40,
  });

  final StatusReplyPayload payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).colorScheme.surfaceContainerHighest;
    final child = switch (payload.type) {
      1 => _image(payload.mediaUrl, fallback),
      2 => _StatusVideoThumb(
          mediaUrl: payload.mediaUrl,
          size: size,
          fallback: fallback,
        ),
      3 => ColoredBox(
          color: fallback,
          child: Icon(
            Icons.mic_rounded,
            size: size * 0.45,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      _ => ColoredBox(
          color: _parseBg(payload.backgroundColor) ??
              Theme.of(context).colorScheme.primary,
          child: Center(
            child: Icon(
              Icons.text_fields_rounded,
              size: size * 0.4,
              color: AppColors.white.withAlpha(220),
            ),
          ),
        ),
    };
    if (child == null) return const SizedBox.shrink();
    return SizedBox(width: size, height: size, child: child);
  }

  Widget? _image(String? url, Color fallback) {
    if (url == null || url.isEmpty) return null;
    return ImageMessagePreview(
      networkUrl: url,
      borderRadius: BorderRadius.zero,
      expandToFill: true,
      fallbackColor: fallback,
    );
  }

  static Color? _parseBg(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }
}

class _StatusVideoThumb extends StatelessWidget {
  const _StatusVideoThumb({
    required this.mediaUrl,
    required this.size,
    required this.fallback,
  });

  final String? mediaUrl;
  final double size;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl;
    if (url == null || url.isEmpty) return _placeholder(fallback);
    return FutureBuilder<Uint8List?>(
      future: _bytes(url),
      builder: (context, snap) {
        final bytes = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
              )
            else
              ColoredBox(color: fallback),
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 18,
                color: Color(0xE6FFFFFF),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<Uint8List?> _bytes(String url) async {
    final path = await MediaCacheService().cachedPathFor(url);
    if (path == null) return null;
    return VideoThumbnailService.forFile(path);
  }

  static Widget _placeholder(Color fallback) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: fallback),
        const Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 18,
            color: Color(0xE6FFFFFF),
          ),
        ),
      ],
    );
  }
}
