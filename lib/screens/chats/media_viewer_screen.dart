import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';

/// Élément affichable dans la visionneuse multi-médias.
class MediaViewerItem {
  const MediaViewerItem({
    required this.isVideo,
    this.localPath,
    this.networkUrl,
    this.title,
  });

  final bool isVideo;
  final String? localPath;
  final String? networkUrl;
  final String? title;
}

/// Visionneuse plein écran pour image(s) ou vidéo(s), avec navigation swipe.
class MediaViewerScreen extends StatefulWidget {
  final List<MediaViewerItem> items;
  final int initialIndex;

  /// Constructeur rétrocompatible pour un seul média.
  MediaViewerScreen({
    super.key,
    bool isVideo = false,
    String? localPath,
    String? networkUrl,
    String? title,
    List<MediaViewerItem>? items,
    this.initialIndex = 0,
  }) : items = items ??
            [
              MediaViewerItem(
                isVideo: isVideo,
                localPath: localPath,
                networkUrl: networkUrl,
                title: title,
              ),
            ];

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videos = {};
  final Map<int, ChewieController?> _chewies = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _initVideoAt(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _chewies.values) {
      c?.dispose();
    }
    for (final v in _videos.values) {
      v?.dispose();
    }
    super.dispose();
  }

  Future<void> _initVideoAt(int index) async {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (!item.isVideo || _videos[index] != null) return;

    final hasLocal =
        item.localPath != null && File(item.localPath!).existsSync();
    final video = hasLocal
        ? VideoPlayerController.file(File(item.localPath!))
        : VideoPlayerController.networkUrl(
            Uri.parse(item.networkUrl ?? ''),
          );
    _videos[index] = video;

    try {
      await video.initialize();
      if (!mounted) return;
      setState(() {
        _chewies[index] = ChewieController(
          videoPlayerController: video,
          autoPlay: index == _currentIndex,
          looping: false,
          aspectRatio: video.value.aspectRatio,
        );
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int index) {
    _chewies[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
    _initVideoAt(index);
    final chewie = _chewies[index];
    if (chewie != null) chewie.play();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final title = widget.items.length > 1
        ? '${_currentIndex + 1} / ${widget.items.length}'
        : (item.title ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.white, fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final media = widget.items[index];
          return Center(
            child: media.isVideo ? _buildVideo(index) : _buildImage(media),
          );
        },
      ),
    );
  }

  Widget _buildVideo(int index) {
    final chewie = _chewies[index];
    if (chewie == null) {
      return const CircularProgressIndicator(color: AppColors.white);
    }
    return Chewie(controller: chewie);
  }

  Widget _buildImage(MediaViewerItem item) {
    final hasLocal =
        item.localPath != null && File(item.localPath!).existsSync();
    if (hasLocal) {
      return InteractiveViewer(child: Image.file(File(item.localPath!)));
    }
    return InteractiveViewer(
      child: CachedNetworkImage(
        imageUrl: item.networkUrl ?? '',
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: AppColors.white),
        errorWidget: (_, __, ___) => const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        ),
      ),
    );
  }
}
