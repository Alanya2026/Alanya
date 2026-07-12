import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/services/video_thumbnail_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// Aperçu vidéo type WhatsApp : vignette, voile léger, bouton play centré,
/// badge durée optionnel.
class VideoMessagePreview extends StatelessWidget {
  const VideoMessagePreview({
    super.key,
    this.pendingPath,
    this.localPath,
    this.thumbBase64,
    this.durationSeconds,
    this.width,
    this.height,
    this.maxWidth = 240,
    this.maxHeight = 220,
    this.playIconSize = 28,
    this.playPadding = 8,
    this.borderRadius,
    this.showDuration = true,
    this.fallbackColor,
    this.expandToFill = false,
  });

  final String? pendingPath;
  final String? localPath;

  /// Vignette base64 reçue avec le message (aperçu destinataire), utilisée en
  /// repli quand aucun fichier vidéo local n'est disponible.
  final String? thumbBase64;
  final int? durationSeconds;
  final double? width;
  final double? height;
  final double maxWidth;
  final double maxHeight;
  final double playIconSize;
  final double playPadding;
  final BorderRadius? borderRadius;
  final bool showDuration;
  final Color? fallbackColor;
  final bool expandToFill;

  static String formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString()}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.brSm;
    final fallback = fallbackColor ?? AppColors.immersiveBackground;
    final hasLocal = VideoThumbnailService.hasLocalSource(
      pendingPath: pendingPath,
      localPath: localPath,
    );
    // Vignette reçue (base64) : repli immédiat, disponible hors ligne.
    final base64Bytes = VideoThumbnailService.decodeBase64(thumbBase64);

    return FutureBuilder<Uint8List?>(
      future: VideoThumbnailService.forMessage(
        pendingPath: pendingPath,
        localPath: localPath,
      ),
      builder: (context, snap) {
        // Priorité : vignette locale générée > vignette base64 reçue > repli.
        final bytes = snap.data ?? base64Bytes;
        final generating = hasLocal &&
            snap.connectionState == ConnectionState.waiting &&
            bytes == null;

        Widget content = Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              )
            else
              ColoredBox(color: fallback),
            if (bytes != null)
              const ColoredBox(color: Color(0x42000000)),
            if (!generating)
              Container(
                padding: EdgeInsets.all(playPadding),
                decoration: BoxDecoration(
                  color: AppColors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.white,
                  size: playIconSize,
                ),
              ),
            if (showDuration &&
                durationSeconds != null &&
                durationSeconds! > 0)
              Positioned(
                right: 8,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatDuration(durationSeconds!),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (generating)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        );

        if (expandToFill) {
          content = SizedBox.expand(child: content);
        } else if (width != null || height != null) {
          content = SizedBox(width: width, height: height, child: content);
        } else {
          content = ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
            child: content,
          );
        }

        return ClipRRect(borderRadius: radius, child: content);
      },
    );
  }
}
