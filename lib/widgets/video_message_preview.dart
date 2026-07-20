import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/services/video_thumbnail_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// Aperçu vidéo type WhatsApp : vignette, voile léger, bouton play centré,
/// badge durée optionnel.
///
/// Priorité d'affichage :
///  1. vignette **locale** (fichier téléchargé / en envoi) — meilleure qualité ;
///  2. `mediaThumb` base64 — repli immédiat / hors ligne seulement ;
///  3. fond uni.
class VideoMessagePreview extends StatefulWidget {
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
    this.hidePlayIcon = false,
  });

  final String? pendingPath;
  final String? localPath;

  /// Vignette base64 reçue avec le message (aperçu destinataire), utilisée en
  /// repli quand aucun fichier vidéo local n'est disponible, ou en placeholder
  /// le temps que la vignette locale soit générée.
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
  final bool hidePlayIcon;

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
  State<VideoMessagePreview> createState() => _VideoMessagePreviewState();
}

class _VideoMessagePreviewState extends State<VideoMessagePreview> {
  Future<Uint8List?>? _localThumbFuture;
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _syncLocalFuture();
  }

  @override
  void didUpdateWidget(covariant VideoMessagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingPath != widget.pendingPath ||
        oldWidget.localPath != widget.localPath) {
      _syncLocalFuture();
    }
  }

  void _syncLocalFuture() {
    final path = VideoThumbnailService.resolveLocalPath(
      pendingPath: widget.pendingPath,
      localPath: widget.localPath,
    );
    if (path == _resolvedPath && _localThumbFuture != null) return;
    _resolvedPath = path;
    _localThumbFuture =
        path == null ? null : VideoThumbnailService.forFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadius.brSm;
    final fallback = widget.fallbackColor ?? AppColors.immersiveBackground;
    final hasLocal = _resolvedPath != null;
    final base64Bytes =
        VideoThumbnailService.decodeBase64(widget.thumbBase64);

    // Pas de fichier local : mediaThumb (ou fond) uniquement.
    if (!hasLocal || _localThumbFuture == null) {
      return _frame(
        radius: radius,
        fallback: fallback,
        bytes: base64Bytes,
        sourceKey: 'b64',
        generating: false,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _localThumbFuture,
      builder: (context, snap) {
        final localBytes = snap.data;
        final waiting = snap.connectionState == ConnectionState.waiting;
        // Locale prête → toujours la préférer (qualité 480/75).
        // Sinon mediaThumb en placeholder / repli si la génération échoue.
        final bytes = localBytes ?? base64Bytes;
        final fromLocal = localBytes != null;

        return _frame(
          radius: radius,
          fallback: fallback,
          bytes: bytes,
          sourceKey: fromLocal ? 'local' : 'b64',
          generating: waiting && bytes == null,
        );
      },
    );
  }

  Widget _frame({
    required BorderRadius radius,
    required Color fallback,
    required Uint8List? bytes,
    required String sourceKey,
    required bool generating,
  }) {
    Widget content = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (bytes != null)
          Image.memory(
            bytes,
            key: ValueKey<String>('thumb_$sourceKey'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        else
          ColoredBox(color: fallback),
        if (bytes != null) const ColoredBox(color: Color(0x42000000)),
        // Center : sous StackFit.expand le Container recevrait sinon des
        // contraintes serrées → cercle aussi grand que la vignette.
        if (!generating && !widget.hidePlayIcon)
          Center(
            child: Container(
              padding: EdgeInsets.all(widget.playPadding),
              decoration: BoxDecoration(
                color: AppColors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: AppColors.white,
                size: widget.playIconSize,
              ),
            ),
          ),
        if (widget.showDuration &&
            widget.durationSeconds != null &&
            widget.durationSeconds! > 0)
          Positioned(
            right: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                VideoMessagePreview.formatDuration(widget.durationSeconds!),
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

    if (widget.expandToFill) {
      content = SizedBox.expand(child: content);
    } else if (widget.width != null || widget.height != null) {
      content =
          SizedBox(width: widget.width, height: widget.height, child: content);
    } else {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
        ),
        child: content,
      );
    }

    return ClipRRect(borderRadius: radius, child: content);
  }
}
