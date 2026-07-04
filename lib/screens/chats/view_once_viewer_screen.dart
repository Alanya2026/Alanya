import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rich_text_parser.dart';

/// Visionneuse plein écran pour un média à VUE UNIQUE (image, vidéo, audio).
///
/// Le média n'est jamais mis en cache persistant : il est téléchargé vers un
/// fichier temporaire (via le client HTTP de l'app, qui gère le cert pinning —
/// les lecteurs natifs échoueraient sur une URL réseau directe), lu depuis ce
/// fichier, puis le fichier est supprimé à la fermeture de l'écran.
///
/// La légende éventuelle n'est affichée qu'ici, jamais dans la bulle de chat.
class ViewOnceViewerScreen extends StatefulWidget {
  final int type; // 1=image, 2=vidéo, 3=audio
  final String mediaUrl;
  final String? caption;

  const ViewOnceViewerScreen({
    super.key,
    required this.type,
    required this.mediaUrl,
    this.caption,
  });

  @override
  State<ViewOnceViewerScreen> createState() => _ViewOnceViewerScreenState();
}

class _ViewOnceViewerScreenState extends State<ViewOnceViewerScreen> {
  final MediaCacheService _cache = MediaCacheService();

  String? _tempPath;
  bool _loading = true;
  bool _error = false;

  VideoPlayerController? _video;
  ChewieController? _chewie;
  AudioPlayer? _audio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await _cache.downloadToTemp(widget.mediaUrl);
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    _tempPath = path;

    try {
      if (widget.type == 2) {
        _video = VideoPlayerController.file(File(path));
        await _video!.initialize();
        if (!mounted) return;
        _chewie = ChewieController(
          videoPlayerController: _video!,
          autoPlay: true,
          looping: false,
          aspectRatio: _video!.value.aspectRatio,
        );
      } else if (widget.type == 3) {
        _audio = AudioPlayer();
        await _audio!.setFilePath(path);
        if (!mounted) return;
        await _audio!.play();
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    _audio?.dispose();
    // Suppression du fichier temporaire : le média vue unique ne laisse
    // aucune trace sur l'appareil.
    if (_tempPath != null) {
      try {
        final f = File(_tempPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {/* déjà supprimé — ignoré */}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: const Text('Vue unique',
            style: TextStyle(color: AppColors.white, fontSize: 16)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: _buildBody()),
          if (hasCaption && !_loading && !_error)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xxl,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: parseRichSpans(
                          caption,
                          (context.text.bodyLarge ?? const TextStyle()).copyWith(
                            color: AppColors.white,
                            height: 1.35,
                          ),
                          linkColor: context.colors.primary,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const CircularProgressIndicator(color: AppColors.white);
    }
    if (_error || _tempPath == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white54, size: 64),
          SizedBox(height: 12),
          Text('Média indisponible', style: TextStyle(color: Colors.white54)),
        ],
      );
    }

    switch (widget.type) {
      case 2:
        return _chewie == null
            ? const CircularProgressIndicator(color: AppColors.white)
            : Chewie(controller: _chewie!);
      case 3:
        return _AudioView(player: _audio!);
      default: // 1 = image
        return InteractiveViewer(child: Image.file(File(_tempPath!)));
    }
  }
}

/// Lecteur audio minimal : play/pause + barre de progression.
class _AudioView extends StatelessWidget {
  final AudioPlayer player;
  const _AudioView({required this.player});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, color: AppColors.white, size: 72),
          const SizedBox(height: 24),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              final completed = snap.data?.processingState == ProcessingState.completed;
              return IconButton(
                iconSize: 56,
                color: AppColors.white,
                icon: Icon(completed
                    ? Icons.replay_circle_filled
                    : playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled),
                onPressed: () async {
                  if (completed) {
                    await player.seek(Duration.zero);
                    await player.play();
                  } else if (playing) {
                    await player.pause();
                  } else {
                    await player.play();
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = player.duration ?? Duration.zero;
              final max = total.inMilliseconds == 0 ? 1.0 : total.inMilliseconds.toDouble();
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.white,
                    ),
                    child: Slider(
                      value: pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                      max: max,
                      onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pos), style: const TextStyle(color: Colors.white70)),
                      Text(_fmt(total), style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
