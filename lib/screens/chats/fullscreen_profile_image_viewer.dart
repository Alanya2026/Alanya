import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Visionneuse plein écran pour les images de profil avec zoom.
/// Affiche uniquement l'image zoomable avec un bouton retour.
class FullscreenProfileImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;

  const FullscreenProfileImageViewer({
    super.key,
    this.imageUrl,
    this.localPath,
  });

  @override
  State<FullscreenProfileImageViewer> createState() =>
      _FullscreenProfileImageViewerState();
}

class _FullscreenProfileImageViewerState
    extends State<FullscreenProfileImageViewer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final hasLocal =
        widget.localPath != null && File(widget.localPath!).existsSync();

    if (hasLocal) {
      return Image.file(File(widget.localPath!));
    }

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: AppColors.white),
        errorWidget: (_, __, ___) =>
            Icon(Icons.broken_image, color: AppColors.white.withValues(alpha: 0.54), size: 64),
        fit: BoxFit.contain,
      );
    }

    return Icon(
      Icons.image_not_supported,
      color: AppColors.white.withValues(alpha: 0.54),
      size: 64,
    );
  }
}
