import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import 'status_views_screen.dart';

class StatusViewerScreen extends StatefulWidget {
  final List<Statut> statuses;
  final int startIndex;
  final bool isMine;

  const StatusViewerScreen({
    super.key,
    required this.statuses,
    required this.startIndex,
    required this.isMine,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _textImageDuration = Duration(seconds: 5);

  late int _index;
  late AnimationController _progress;
  bool _paused = false;
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  AudioPlayer? _audioPlayer;

  Statut get _current => widget.statuses[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.statuses.length - 1);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  @override
  void dispose() {
    _progress.dispose();
    _disposeMedia();
    super.dispose();
  }

  void _disposeMedia() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _audioPlayer?.dispose();
    _videoCtrl = null;
    _chewieCtrl = null;
    _audioPlayer = null;
  }

  Future<void> _loadCurrent() async {
    _disposeMedia();
    _progress.stop();
    _progress.value = 0;
    final s = _current;
    if (!widget.isMine) {
      // ignore: unawaited_futures
      context.read<StatusProvider>().markViewed(s.id);
    }
    Duration totalDuration = _textImageDuration;
    if (s.type == 2 && s.mediaUrl != null) {
      // Vidéo
      final v = VideoPlayerController.networkUrl(Uri.parse(s.mediaUrl!));
      try {
        await v.initialize();
        _videoCtrl = v;
        _chewieCtrl = ChewieController(
          videoPlayerController: v,
          autoPlay: true,
          looping: false,
          showControls: false,
        );
        totalDuration = v.value.duration;
        v.addListener(_onVideoTick);
      } catch (_) {
        totalDuration = _textImageDuration;
      }
    } else if (s.type == 3 && s.mediaUrl != null) {
      // Audio
      final p = AudioPlayer();
      try {
        await p.setUrl(s.mediaUrl!);
        await p.play();
        _audioPlayer = p;
        totalDuration = p.duration ??
            Duration(milliseconds: s.mediaDurationMs ?? _textImageDuration.inMilliseconds);
        p.playerStateStream.listen((st) {
          if (st.processingState == ProcessingState.completed) _next();
        });
      } catch (_) {
        totalDuration = _textImageDuration;
      }
    }
    if (!mounted) return;
    setState(() {});
    _progress.duration = totalDuration;
    if (!_paused) _progress.forward();
  }

  void _onVideoTick() {
    final v = _videoCtrl;
    if (v == null || !v.value.isInitialized) return;
    final total = v.value.duration.inMilliseconds;
    if (total <= 0) return;
    final value = v.value.position.inMilliseconds / total;
    _progress.value = value.clamp(0.0, 1.0);
    if (value >= 0.999) _next();
  }

  void _next() {
    if (_index < widget.statuses.length - 1) {
      setState(() => _index++);
      _loadCurrent();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _loadCurrent();
    }
  }

  void _setPaused(bool paused) {
    setState(() => _paused = paused);
    if (paused) {
      _progress.stop();
      _videoCtrl?.pause();
      _audioPlayer?.pause();
    } else {
      _progress.forward();
      _videoCtrl?.play();
      _audioPlayer?.play();
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final provider = context.read<StatusProvider>();
    final id = _current.id;
    _setPaused(true);
    // toggleLike applique l'optimistic update avant le await réseau,
    // donc lancer le rebuild immédiatement reflète le nouvel état.
    final future = provider.toggleLike(id);
    setState(() {});
    try {
      await future;
    } finally {
      if (mounted) {
        setState(() {});
        _setPaused(false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce statut ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<StatusProvider>().delete(_current.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = _current;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu
            Positioned.fill(child: _buildContent(s)),
            // Gestes (tap zones + long press)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _prev,
                      onLongPressStart: (_) => _setPaused(true),
                      onLongPressEnd: (_) => _setPaused(false),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _next,
                      onLongPressStart: (_) => _setPaused(true),
                      onLongPressEnd: (_) => _setPaused(false),
                    ),
                  ),
                ],
              ),
            ),
            // Barres de progression + header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _ProgressBars(
                    count: widget.statuses.length,
                    currentIndex: _index,
                    progress: _progress,
                  ),
                  _Header(
                    statut: s,
                    onClose: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Caption (image/vidéo avec texte)
            if ((s.type == 1 || s.type == 2) &&
                (s.text != null && s.text!.trim().isNotEmpty))
              Positioned(
                left: 16,
                right: 16,
                bottom: widget.isMine ? 96 : 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.text!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            // Footer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _Footer(
                statut: s,
                isMine: widget.isMine,
                onLike: _toggleLike,
                onDelete: _confirmDelete,
                onShowViews: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatusViewsScreen(statusId: s.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Statut s) {
    switch (s.type) {
      case 0: // Texte
        final bg = _parseColor(s.backgroundColor) ?? Colors.indigo;
        return Container(
          color: bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            s.text ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 1: // Image
        return Center(
          child: CachedNetworkImage(
            imageUrl: s.mediaUrl ?? '',
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        );
      case 2: // Vidéo
        if (_chewieCtrl != null) {
          return Center(
            child: AspectRatio(
              aspectRatio: _videoCtrl?.value.aspectRatio ?? 16 / 9,
              child: Chewie(controller: _chewieCtrl!),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      case 3: // Audio
        return _AudioContent(statut: s);
      default:
        return const SizedBox.shrink();
    }
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = hex.replaceAll('#', '');
    final n = int.tryParse(v.length == 6 ? 'FF$v' : v, radix: 16);
    return n == null ? null : Color(n);
  }
}

// ── Sous-widgets ─────────────────────────────────────────────────────────────

class _ProgressBars extends StatelessWidget {
  final int count;
  final int currentIndex;
  final AnimationController progress;

  const _ProgressBars({
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: List.generate(count, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: progress,
                builder: (_, __) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: i < currentIndex
                          ? 1.0
                          : i == currentIndex
                              ? progress.value
                              : 0.0,
                      minHeight: 3,
                      backgroundColor: Colors.white.withAlpha(70),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Statut statut;
  final VoidCallback onClose;

  const _Header({required this.statut, required this.onClose});

  String _relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade700,
            backgroundImage:
                statut.avatarUrl != null && statut.avatarUrl!.isNotEmpty
                    ? NetworkImage(statut.avatarUrl!)
                    : null,
            child: statut.avatarUrl == null || statut.avatarUrl!.isEmpty
                ? Text(
                    (statut.nom != null && statut.nom!.isNotEmpty)
                        ? statut.nom![0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statut.nom ?? 'Moi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _relative(statut.createdAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final Statut statut;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onShowViews;

  const _Footer({
    required this.statut,
    required this.isMine,
    required this.onLike,
    required this.onDelete,
    required this.onShowViews,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Absorbe les taps dans la zone du footer pour éviter qu'ils
      // déclenchent prev/next du viewer en dessous.
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(180)],
          ),
        ),
        child: isMine ? _mineFooter(context) : _otherFooter(context),
      ),
    );
  }

  Widget _mineFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: onShowViews,
          child: Row(
            children: [
              const Icon(Icons.visibility, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                '${statut.viewedBy} vue${statut.viewedBy > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
              const SizedBox(width: 6),
              Text(
                '${statut.likedBy}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: onDelete,
        ),
      ],
    );
  }

  Widget _otherFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onLike,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statut.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: statut.likedByMe ? Colors.redAccent : Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  statut.likedByMe ? 'Aimé' : 'J\'aime',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioContent extends StatelessWidget {
  final Statut statut;

  const _AudioContent({required this.statut});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade900,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white24,
            backgroundImage:
                statut.avatarUrl != null && statut.avatarUrl!.isNotEmpty
                    ? NetworkImage(statut.avatarUrl!)
                    : null,
            child: statut.avatarUrl == null || statut.avatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 60, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 24),
          const Icon(Icons.audiotrack, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          Text(
            statut.nom ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Message vocal en cours...',
            style: TextStyle(color: Colors.white.withAlpha(180)),
          ),
        ],
      ),
    );
  }
}
