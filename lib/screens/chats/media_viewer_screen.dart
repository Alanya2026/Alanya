import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';

import '../../widgets/video/double_tap_seek_overlay.dart';
import '../../widgets/video/video_speed_memory.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/alanya_media_export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_save_feedback.dart';

/// Élément affichable dans la visionneuse multi-médias.
class MediaViewerItem {
  const MediaViewerItem({
    required this.isVideo,
    this.localPath,
    this.networkUrl,
    this.title,
    this.msgID = 0,
    this.canSave = true,
  });

  final bool isVideo;
  final String? localPath;
  final String? networkUrl;
  final String? title;

  /// Identifiant du message porteur, s'il y en a un : sert à savoir si ce
  /// média a déjà été exporté vers l'appareil.
  final int msgID;

  /// Faux là où l'enregistrement n'a pas de sens (photo de profil).
  final bool canSave;
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
    int msgID = 0,
    bool canSave = true,
    List<MediaViewerItem>? items,
    this.initialIndex = 0,
  }) : items = items ??
            [
              MediaViewerItem(
                isVideo: isVideo,
                localPath: localPath,
                networkUrl: networkUrl,
                title: title,
                msgID: msgID,
                canSave: canSave,
              ),
            ];

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

/// État du bouton d'enregistrement, par média.
///
/// [saved] n'est que la confirmation passagère du geste qui vient d'aboutir ;
/// [alreadySaved] est le fait durable.
enum _SaveState { idle, saving, saved, alreadySaved }

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videos = {};
  final Map<int, ChewieController?> _chewies = {};
  final Map<int, VideoSpeedMemory> _speeds = {};
  final Map<int, _SaveState> _saveStates = {};
  Timer? _savedResetTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _initVideoAt(_currentIndex);
    _refreshSaveStateAt(_currentIndex);
  }

  @override
  void dispose() {
    _savedResetTimer?.cancel();
    _pageController.dispose();
    for (final c in _chewies.values) {
      c?.dispose();
    }
    for (final m in _speeds.values) {
      m.dispose();
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
        _speeds[index] = VideoSpeedMemory.attach(video);
        _chewies[index] = ChewieController(
          videoPlayerController: video,
          autoPlay: index == _currentIndex,
          looping: false,
          aspectRatio: video.value.aspectRatio,
          playbackSpeeds: kVideoPlaybackSpeeds,
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
    _refreshSaveStateAt(index);
    final chewie = _chewies[index];
    if (chewie != null) chewie.play();
  }

  int _typeOf(MediaViewerItem item) => item.isVideo ? 2 : 1;

  bool _canSave(MediaViewerItem item) {
    if (!item.canSave) return false;
    final hasLocal =
        item.localPath != null && File(item.localPath!).existsSync();
    final hasUrl = item.networkUrl != null && item.networkUrl!.isNotEmpty;
    return hasLocal || hasUrl;
  }

  /// Relit le fait « ce média est déjà sur l'appareil ». Ne touche pas à un
  /// enregistrement en cours ni à la confirmation qui vient de s'afficher.
  Future<void> _refreshSaveStateAt(int index) async {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (!_canSave(item) || item.msgID == 0) return;
    final exported =
        await AlanyaMediaExportService.instance.isExported(item.msgID);
    if (!mounted || !exported) return;
    final current = _saveStates[index] ?? _SaveState.idle;
    if (current != _SaveState.idle) return;
    setState(() => _saveStates[index] = _SaveState.alreadySaved);
  }

  /// Fait passer les confirmations encore affichées à leur état durable.
  void _settlePendingSaved() {
    final pending = _saveStates.entries
        .where((e) => e.value == _SaveState.saved)
        .map((e) => e.key)
        .toList();
    if (pending.isEmpty) return;
    for (final i in pending) {
      _saveStates[i] = _SaveState.alreadySaved;
    }
  }

  Future<void> _save(int index) async {
    final item = widget.items[index];
    if (_saveStates[index] == _SaveState.saving) return;

    setState(() => _saveStates[index] = _SaveState.saving);
    final ok = await AlanyaMediaExportService.instance.saveNow(
      type: _typeOf(item),
      localPath: item.localPath,
      networkUrl: item.networkUrl,
      mediaName: item.title,
      msgID: item.msgID,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() => _saveStates[index] = _SaveState.idle);
      MediaSaveFeedback.showFailed(context);
      return;
    }

    // Un enregistrement plus récent annule le minuteur du précédent : on solde
    // les coches en attente avant d'en armer une nouvelle, sinon un média resté
    // en « saved » garderait sa coche verte indéfiniment.
    _settlePendingSaved();
    setState(() => _saveStates[index] = _SaveState.saved);
    MediaSaveFeedback.showSaved(context, _typeOf(item));
    // La coche n'est qu'un accusé de réception ; l'état durable est « déjà
    // enregistré », qui reste tapable pour une copie supplémentaire assumée.
    _savedResetTimer?.cancel();
    _savedResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_saveStates[index] != _SaveState.saved) return;
      setState(() => _saveStates[index] = _SaveState.alreadySaved);
    });
  }

  Widget _buildSaveAction() {
    final item = widget.items[_currentIndex];
    if (!_canSave(item)) return const SizedBox.shrink();

    final state = _saveStates[_currentIndex] ?? _SaveState.idle;
    if (state == _SaveState.saving) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }

    if (state == _SaveState.saved) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.check_rounded, color: AppColors.success),
      );
    }

    final already = state == _SaveState.alreadySaved;
    return IconButton(
      tooltip: MediaSaveFeedback.actionLabel(context, _typeOf(item)),
      icon: Icon(
        already ? Icons.download_done_rounded : Icons.download_rounded,
        color: already
            ? AppColors.white.withValues(alpha: 0.55)
            : AppColors.white,
      ),
      onPressed: already
          ? () => MediaSaveFeedback.showAlreadySaved(
                context,
                _typeOf(item),
                onSaveAgain: () => _save(_currentIndex),
              )
          : () => _save(_currentIndex),
    );
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
        actions: [_buildSaveAction()],
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
    final video = _videos[index];
    if (chewie == null || video == null) {
      return const CircularProgressIndicator(color: AppColors.white);
    }
    return DoubleTapSeekOverlay(
      controller: video,
      child: Chewie(controller: chewie),
    );
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
        errorWidget: (_, __, ___) => Icon(
          Icons.broken_image,
          color: AppColors.white.withValues(alpha: 0.54),
          size: 64,
        ),
      ),
    );
  }
}
