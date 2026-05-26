import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
    final hasLocal = widget.localPath != null &&
        File(widget.localPath!).existsSync();

    if (hasLocal) {
      return Image.file(File(widget.localPath!));
    }

    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: Colors.white),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
            color: Colors.white54, size: 64),
        fit: BoxFit.contain,
      );
    }

    return const Icon(Icons.image_not_supported,
        color: Colors.white54, size: 64);
  }
}
