import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Visionneuse plein écran pour image ou vidéo.
/// Privilégie le fichier local (offline) puis l'URL réseau.
class MediaViewerScreen extends StatefulWidget {
  final bool isVideo;
  final String? localPath;
  final String? networkUrl;
  final String? title;

  const MediaViewerScreen({
    super.key,
    required this.isVideo,
    this.localPath,
    this.networkUrl,
    this.title,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final hasLocal = widget.localPath != null && File(widget.localPath!).existsSync();
    _video = hasLocal
        ? VideoPlayerController.file(File(widget.localPath!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl ?? ''));
    await _video!.initialize();
    if (!mounted) return;
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: _video!,
        autoPlay: true,
        looping: false,
        aspectRatio: _video!.value.aspectRatio,
      );
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(child: widget.isVideo ? _buildVideo() : _buildImage()),
    );
  }

  Widget _buildVideo() {
    if (_chewie == null) return const CircularProgressIndicator(color: Colors.white);
    return Chewie(controller: _chewie!);
  }

  Widget _buildImage() {
    final hasLocal = widget.localPath != null && File(widget.localPath!).existsSync();
    if (hasLocal) {
      return InteractiveViewer(child: Image.file(File(widget.localPath!)));
    }
    return InteractiveViewer(
      child: CachedNetworkImage(
        imageUrl: widget.networkUrl ?? '',
        placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }
}
