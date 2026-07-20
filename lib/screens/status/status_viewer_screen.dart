import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'status_views_screen.dart';
import 'status_audio_view.dart';

class StatusViewerScreen extends StatefulWidget {
  final List<List<Statut>> contactGroups;
  final int startContactIndex;
  final int startItemIndex;
  final bool isMine;

  const StatusViewerScreen({
    super.key,
    required this.contactGroups,
    required this.startContactIndex,
    this.startItemIndex = 0,
    required this.isMine,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _textImageDuration = Duration(seconds: 5);
  static const int _maxMediaBytes = 50 * 1024 * 1024;

  late int _contactIndex;
  late int _itemIndex;
  late PageController _pageCtrl;
  late AnimationController _progress;
  bool _paused = false;
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  AudioPlayer? _audioPlayer;
  String? _audioPath;
  bool _audioPreparing = false;
  StreamSubscription<PlayerState>? _audioStateSub;
  VoidCallback? _videoTickListener;
  int _loadSeq = 0;
  final MediaCacheService _mediaCache = MediaCacheService();

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  bool _sendingReply = false;
  bool _hasReplyText = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _advancing = false;

  List<Statut> get _currentGroup => widget.contactGroups[_contactIndex];
  Statut get _current => _currentGroup[_itemIndex];

  @override
  void initState() {
    super.initState();
    final maxContact = widget.contactGroups.length - 1;
    _contactIndex = widget.startContactIndex
        .clamp(0, maxContact < 0 ? 0 : maxContact);
    final maxItem = _currentGroup.length - 1;
    _itemIndex =
        widget.startItemIndex.clamp(0, maxItem < 0 ? 0 : maxItem);
    _pageCtrl = PageController(initialPage: _contactIndex);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
    _replyController.addListener(_onReplyTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  void _onReplyTextChanged() {
    final has = _replyController.text.trim().isNotEmpty;
    if (has != _hasReplyText) setState(() => _hasReplyText = has);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _pageCtrl.dispose();
    _progress.dispose();
    _disposeMedia();
    _replyController.removeListener(_onReplyTextChanged);
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _disposeMedia() {
    _chewieCtrl?.dispose();
    if (_videoTickListener != null) {
      _videoCtrl?.removeListener(_videoTickListener!);
    }
    _videoCtrl?.dispose();
    _audioStateSub?.cancel();
    _audioPlayer?.dispose();
    _videoCtrl = null;
    _chewieCtrl = null;
    _audioPlayer = null;
    _audioPath = null;
    _audioPreparing = false;
    _videoTickListener = null;
    _audioStateSub = null;
  }

  /// Télécharge le média via HTTP (cert pinning) puis lit depuis le disque.
  /// video_player / just_audio utilisent les stacks natives qui ignorent
  /// HttpOverrides — un URL réseau direct échoue avec le cert auto-signé.
  Future<String?> _resolveMediaPath(String url) async {
    try {
      return await _mediaCache.ensureCached(url);
    } catch (e, st) {
      AppLog.w('StatusViewer', 'Cache média statut échoué', e, st);
      return null;
    }
  }

  Future<void> _loadCurrent() async {
    final seq = ++_loadSeq;
    _disposeMedia();
    _progress.stop();
    _progress.value = 0;
    final s = _current;
    if (!widget.isMine) {
      // ignore: unawaited_futures
      context.read<StatusProvider>().markViewed(s.id);
    }
    Duration totalDuration = _textImageDuration;
    var syncProgressFromMedia = false;

    if (s.type == 2 && s.mediaUrl != null) {
      final path = await _resolveMediaPath(s.mediaUrl!);
      if (!mounted || seq != _loadSeq) return;
      if (path != null) {
        final v = VideoPlayerController.file(File(path));
        try {
          await v.initialize();
          if (!mounted || seq != _loadSeq) {
            await v.dispose();
            return;
          }
          _videoCtrl = v;
          _chewieCtrl = ChewieController(
            videoPlayerController: v,
            autoPlay: true,
            looping: false,
            showControls: false,
          );
          final dur = v.value.duration;
          if (dur.inMilliseconds > 0) {
            totalDuration = dur;
            syncProgressFromMedia = true;
            _videoTickListener = _onVideoTick;
            v.addListener(_videoTickListener!);
          }
        } catch (e, st) {
          AppLog.w('StatusViewer', 'Lecture vidéo statut échouée', e, st);
          await v.dispose();
        }
      }
    } else if (s.type == 3 && s.mediaUrl != null) {
      if (mounted) setState(() => _audioPreparing = true);
      final path = await _resolveMediaPath(s.mediaUrl!);
      if (!mounted || seq != _loadSeq) return;
      if (path != null) {
        final p = AudioPlayer();
        try {
          await p.setFilePath(path);
          if (!mounted || seq != _loadSeq) {
            await p.dispose();
            return;
          }
          totalDuration = p.duration ??
              Duration(
                  milliseconds: s.mediaDurationMs ??
                      _textImageDuration.inMilliseconds);
          if (totalDuration.inMilliseconds > 0) {
            syncProgressFromMedia = true;
          }
          _audioStateSub = p.playerStateStream.listen((st) {
            if (st.processingState == ProcessingState.completed) _next();
          });
          _audioPlayer = p;
          _audioPath = path;
          _audioPreparing = false;
          if (!mounted || seq != _loadSeq) return;
          setState(() {});
          await p.play();
        } catch (e, st) {
          AppLog.w('StatusViewer', 'Lecture audio statut échouée', e, st);
          _audioPreparing = false;
          await p.dispose();
        }
      } else {
        _audioPreparing = false;
      }
    }

    if (!mounted || seq != _loadSeq) return;
    setState(() {});
    _progress.duration = totalDuration;
    // Texte / image : timer fixe. Vidéo / audio : barre pilotée par le lecteur.
    if (!syncProgressFromMedia && !_paused) {
      _progress.forward();
    }
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
    if (_advancing) return;

    if (_itemIndex < _currentGroup.length - 1) {
      setState(() => _itemIndex++);
      _loadCurrent();
      return;
    }

    if (_contactIndex < widget.contactGroups.length - 1) {
      _advancing = true;
      final nextContact = _contactIndex + 1;
      setState(() {
        _contactIndex = nextContact;
        _itemIndex = 0;
      });
      _loadCurrent();
      _pageCtrl
          .animateToPage(
            nextContact,
            duration: AppDurations.normal,
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted) _advancing = false;
          });
      return;
    }

    if (!mounted) return;
    _advancing = true;
    Navigator.pop(context);
  }

  void _prev() {
    if (_advancing) return;

    if (_itemIndex > 0) {
      setState(() => _itemIndex--);
      _loadCurrent();
      return;
    }

    if (_contactIndex > 0) {
      _advancing = true;
      final prevContact = _contactIndex - 1;
      final lastItem = widget.contactGroups[prevContact].length - 1;
      setState(() {
        _contactIndex = prevContact;
        _itemIndex = lastItem < 0 ? 0 : lastItem;
      });
      _loadCurrent();
      _pageCtrl
          .animateToPage(
            prevContact,
            duration: AppDurations.normal,
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (mounted) _advancing = false;
          });
    }
  }

  void _onPageChanged(int newIdx) {
    if (newIdx == _contactIndex) return;
    final forward = newIdx > _contactIndex;
    final lastItem = widget.contactGroups[newIdx].length - 1;
    setState(() {
      _contactIndex = newIdx;
      _itemIndex = forward ? 0 : (lastItem < 0 ? 0 : lastItem);
    });
    _loadCurrent();
  }

  void _setPaused(bool paused) {
    setState(() => _paused = paused);
    final s = _current;
    final mediaDriven = s.type == 2 || s.type == 3;
    if (paused) {
      _progress.stop();
      _videoCtrl?.pause();
      _audioPlayer?.pause();
    } else {
      if (!mediaDriven) _progress.forward();
      _videoCtrl?.play();
      _audioPlayer?.play();
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final provider = context.read<StatusProvider>();
    final id = _current.id;
    _setPaused(true);
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

  String _statusPreview() {
    final s = _current;
    if (s.text != null && s.text!.trim().isNotEmpty) return s.text!.trim();
    switch (s.type) {
      case 1:
        return context.l10n.photo;
      case 2:
        return context.l10n.video;
      case 3:
        return context.l10n.audio;
      default:
        return context.l10n.statusNoun;
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sendingReply) return;
    final author = _current.alanyaID;
    if (author == 0) return;

    setState(() => _sendingReply = true);
    try {
      final api = context.read<TalkyApiClient>();
      final chat = context.read<ChatProvider>();
      final result = await api.createConversation(participantID: author);
      final convId = result['conversID'] as int?;
      if (convId == null) throw Exception('conversID manquant');

      await chat.repository.sendText(
        conversationID: convId,
        content: text,
        replyToContent: _statusPreview(),
        isStatusReply: 1,
      );

      if (!mounted) return;
      _replyController.clear();
      _replyFocus.unfocus();
      _setPaused(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.replySent),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.sendFailedWithError('$e'))));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _startRecordingReply() async {
    if (_sendingReply || _isRecording) return;
    if (!await _recorder.hasPermission()) return;
    _setPaused(true);
    _replyFocus.unfocus();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/status_reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecordingReply({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (mounted) setState(() => _isRecording = false);

    if (send && path != null && seconds >= 1) {
      await _sendVoiceReply(File(path), seconds);
    } else if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {
        /* fichier temporaire déjà absent — ignoré */
      }
    }
    if (mounted) _setPaused(false);
  }

  Future<void> _sendVoiceReply(File file, int seconds) async {
    if (_sendingReply) return;
    final author = _current.alanyaID;
    if (author == 0) return;

    final size = file.existsSync() ? file.lengthSync() : 0;
    if (size > _maxMediaBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.fileTooLarge(mb)),
          backgroundColor: context.colors.error,
        ));
      }
      return;
    }

    setState(() => _sendingReply = true);
    try {
      final api = context.read<TalkyApiClient>();
      final chat = context.read<ChatProvider>();
      final result = await api.createConversation(participantID: author);
      final convId = result['conversID'] as int?;
      if (convId == null) throw Exception('conversID manquant');

      await chat.repository.sendMediaFile(
        conversationID: convId,
        type: 3,
        file: file,
        mediaName: context.l10n.voiceMessage,
        mediaDuration: seconds,
        replyToContent: _statusPreview(),
        isStatusReply: 1,
      );

      if (!mounted) return;
      _setPaused(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.replySent),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.sendFailedWithError('$e'))));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  String _fmtRec(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteThisStatus),
        content: Text(ctx.l10n.thisActionCannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonDelete),
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
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageCtrl,
          onPageChanged: _onPageChanged,
          itemCount: widget.contactGroups.length,
          itemBuilder: (context, pageIdx) {
            if (pageIdx != _contactIndex) {
              return const ColoredBox(color: AppColors.black);
            }
            return _buildCurrentPage(s);
          },
        ),
      ),
    );
  }

  Widget _buildCurrentPage(Statut s) {
    return Stack(
      children: [
        Positioned.fill(child: _buildContent(s)),
        // Statut audio : zones latérales seulement, pour ne pas bloquer
        // play/pause et la waveform au centre.
        Positioned.fill(
          child: s.type == 3
              ? Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _prev,
                        onLongPressStart: (_) => _setPaused(true),
                        onLongPressEnd: (_) => _setPaused(false),
                      ),
                    ),
                    const Expanded(child: SizedBox.expand()),
                    SizedBox(
                      width: 72,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _next,
                        onLongPressStart: (_) => _setPaused(true),
                        onLongPressEnd: (_) => _setPaused(false),
                      ),
                    ),
                  ],
                )
              : Row(
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
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              _ProgressBars(
                count: _currentGroup.length,
                currentIndex: _itemIndex,
                progress: _progress,
              ),
              _Header(
                statut: s,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        if ((s.type == 1 || s.type == 2) &&
            (s.text != null && s.text!.trim().isNotEmpty))
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: widget.isMine ? 96 : 80,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: AppRadius.brSm,
              ),
              child: Text(
                s.text!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isMine)
                _buildReplyBar()
              else
                _Footer(
                  statut: s,
                  onDelete: _confirmDelete,
                  onShowViews: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatusViewsScreen(statusId: s.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyBar() {
    final colors = context.colors;
    return Consumer<ConnectivityProvider>(
      builder: (context, conn, _) {
        final online = conn.isOnline;
        final canSend = online && !_sendingReply;
        final liked = _current.likedByMe;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
            top: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _isRecording
                    ? _buildRecordingReplyBar(colors)
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadius.brPill,
                          boxShadow: AppShadows.medium,
                        ),
                        child: TextField(
                          controller: _replyController,
                          focusNode: _replyFocus,
                          style: context.text.bodyLarge,
                          minLines: 1,
                          maxLines: 4,
                          onTap: () => _setPaused(true),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (canSend && _hasReplyText) _sendReply();
                          },
                          decoration: InputDecoration(
                            hintText: online
                                ? context.l10n.replyToStatus
                                : context.l10n.unavailableOffline,
                            hintStyle: context.text.bodyLarge
                                ?.copyWith(color: colors.onSurfaceVariant),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md),
                          ),
                        ),
                      ),
              ),
              IconButton(
                tooltip: liked ? context.l10n.unlike : context.l10n.likeAction,
                onPressed: _toggleLike,
                iconSize: AppIconSize.md,
                splashRadius: 22,
                color: Colors.white,
                icon: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey<bool>(liked),
                    color: liked ? Colors.redAccent : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Material(
                color: canSend
                    ? colors.primary
                    : colors.onSurfaceVariant.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: !canSend
                      ? null
                      : _isRecording
                          ? () => _stopRecordingReply(send: true)
                          : _hasReplyText
                              ? _sendReply
                              : _startRecordingReply,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: _sendingReply
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : Icon(
                            _isRecording
                                ? Icons.send
                                : _hasReplyText
                                    ? Icons.send
                                    : Icons.mic,
                            color: colors.onPrimary,
                            size: AppIconSize.sm + 2,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingReplyBar(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.brPill,
        boxShadow: AppShadows.medium,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.delete_outline,
                color: colors.error, size: AppIconSize.md),
            onPressed: () => _stopRecordingReply(send: false),
          ),
          const SizedBox(width: AppSpacing.sm),
          const _StatusRecordingDot(),
          const SizedBox(width: AppSpacing.sm + 2),
          Text(
            _fmtRec(_recordSeconds),
            style: context.text.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.l10n.recordingEllipsis,
              style: context.text.bodySmall?.copyWith(color: colors.error),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Statut s) {
    switch (s.type) {
      case 0:
        final bg = _parseColor(s.backgroundColor) ?? AppColors.brandPrimary;
        final fg = bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
        return Container(
          color: bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            s.text ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 1:
        return Center(
          child: CachedNetworkImage(
            imageUrl: s.mediaUrl ?? '',
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64),
          ),
        );
      case 2:
        if (_chewieCtrl != null) {
          return Center(
            child: AspectRatio(
              aspectRatio: _videoCtrl?.value.aspectRatio ?? 16 / 9,
              child: Chewie(controller: _chewieCtrl!),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      case 3:
        if (s.mediaUrl == null) {
          return const Center(
            child: Icon(Icons.audiotrack, color: Colors.white54, size: 64),
          );
        }
        return StatusAudioView(
          player: _audioPlayer,
          isPreparing: _audioPreparing,
          audioPath: _audioPath,
          fallbackKey: s.mediaUrl!,
          totalDuration: _audioPlayer?.duration ??
              Duration(milliseconds: s.mediaDurationMs ?? 5000),
          displayName: s.nom ?? s.pseudo ?? '',
          avatarUrl: s.avatarUrl,
          paused: _paused,
          onProgress: (v) => _progress.value = v,
        );
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
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
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
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

ImageProvider? _profileImage(Statut s) {
  return hasValidAvatarUrl(s.avatarUrl) ? NetworkImage(s.avatarUrl!) : null;
}

class _Header extends StatelessWidget {
  final Statut statut;
  final VoidCallback onClose;

  const _Header({required this.statut, required this.onClose});

  String _relative(BuildContext context, String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return context.l10n.justNow;
    if (diff.inMinutes < 60) return context.l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return context.l10n.timeAgoHours(diff.inHours);
    return context.l10n.timeAgoDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.immersiveSurface,
            backgroundImage: _profileImage(statut),
            child: _profileImage(statut) == null
                ? Text(
                    (statut.nom != null && statut.nom!.isNotEmpty)
                        ? statut.nom![0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statut.nom ?? context.l10n.meLabel,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  _relative(context, statut.createdAt),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
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
  final VoidCallback onDelete;
  final VoidCallback onShowViews;

  const _Footer({
    required this.statut,
    required this.onDelete,
    required this.onShowViews,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(180)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: onShowViews,
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: AppIconSize.sm),
                  AppSpacing.hGapSm,
                  Text(
                    context.l10n.viewsCountLabel(statut.viewedBy),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md + 2),
                  const Icon(Icons.favorite,
                      color: Colors.redAccent, size: AppIconSize.sm),
                  AppSpacing.hGapSm,
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
        ),
      ),
    );
  }
}

class _StatusRecordingDot extends StatefulWidget {
  const _StatusRecordingDot();

  @override
  State<_StatusRecordingDot> createState() => _StatusRecordingDotState();
}

class _StatusRecordingDotState extends State<_StatusRecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: context.colors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
