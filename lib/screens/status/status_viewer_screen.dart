import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/services/billing/entitlement_service.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/utils/status_reply_payload.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'status_views_screen.dart';
import 'status_audio_view.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';

/// Ce qui peut retenir la lecture d'un statut.
///
/// Un booléen unique ne suffisait pas : six gestes le levaient et le
/// baissaient sans savoir qui l'avait levé. Relâcher un appui long pendant
/// qu'un like était en vol relançait la lecture que le like tenait en pause,
/// et le `finally` du like la relançait à son tour sous un doigt encore posé.
enum _PauseReason {
  /// Doigt maintenu sur le statut.
  hold,

  /// Aller-retour réseau du like.
  like,

  /// Champ de réponse actif.
  reply,

  /// Enregistrement d'une réponse vocale.
  recording,
}

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
  static int get _maxMediaBytes => EntitlementService.maxUploadBytes;

  late int _contactIndex;
  late int _itemIndex;
  late PageController _pageCtrl;
  late AnimationController _progress;

  /// Les raisons en cours de retenir la lecture. La lecture ne reprend que
  /// lorsqu'il n'en reste aucune.
  final Set<_PauseReason> _pauseReasons = {};
  bool get _paused => _pauseReasons.isNotEmpty;

  /// True quand la barre avance au rythme du lecteur, et non du minuteur fixe.
  ///
  /// Le type du statut ne suffit pas à le dire : une vidéo dont le
  /// téléchargement ou l'initialisation a échoué retombe sur le minuteur.
  /// L'ancienne reprise jugeait du seul type et n'armait donc rien pour elle —
  /// un statut vidéo cassé restait à l'écran indéfiniment.
  bool _mediaDrivenProgress = false;

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
    // Toucher le champ met la lecture en pause ; seuls l'envoi d'une réponse
    // et la fin d'un enregistrement la relançaient. Fermer le clavier sans
    // rien envoyer laissait donc le statut en pause indéfiniment.
    _replyFocus.addListener(_onReplyFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  void _onReplyFocusChanged() {
    if (_replyFocus.hasFocus) {
      _pause(_PauseReason.reply);
    } else {
      _resume(_PauseReason.reply);
    }
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
    _replyFocus.removeListener(_onReplyFocusChanged);
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
    // Texte / image : minuteur fixe. Vidéo / audio prêt : barre pilotée par le
    // lecteur. Le démarrage lui-même n'est plus décidé ici : cette méthode
    // refusait de lancer la progression dès que `_paused` était vrai, sans
    // jamais rien remettre à false — un statut chargé pendant qu'un like était
    // en vol n'avait plus personne pour l'armer.
    _mediaDrivenProgress = syncProgressFromMedia;
    _applyPlayback();
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

  void _pause(_PauseReason raison) {
    final etaitEnPause = _paused;
    if (!_pauseReasons.add(raison) || etaitEnPause) return;
    if (mounted) setState(() {});
    _applyPlayback();
  }

  void _resume(_PauseReason raison) {
    if (!_pauseReasons.remove(raison)) return;
    // Une autre raison tient encore : ce n'est pas à celle-ci de relancer.
    if (_paused) return;
    if (mounted) setState(() {});
    _applyPlayback();
  }

  /// Seul endroit qui démarre ou arrête la lecture, et il le décide depuis
  /// l'état réel — pas depuis le souvenir de l'événement qui l'a appelé.
  ///
  /// Appelé aussi à la fin de [_loadCurrent] : un lecteur qui vient d'être
  /// prêt doit respecter une pause posée pendant son chargement, et un statut
  /// chargé alors que la pause vient d'être levée doit démarrer.
  void _applyPlayback() {
    if (!mounted) return;

    if (_paused) {
      _progress.stop();
      _videoCtrl?.pause();
      _audioPlayer?.pause();
      return;
    }

    _videoCtrl?.play();
    _audioPlayer?.play();
    // Barre pilotée par le lecteur : c'est lui qui fait avancer le fil.
    if (_mediaDrivenProgress) return;

    // Déjà au bout : ce statut a fini son temps pendant la pause. Un
    // `forward()` depuis 1.0 ne fait rien ET ne réémet pas `completed` — le
    // fil resterait figé pour de bon, faute d'un dernier avancement.
    if (_progress.value >= 1.0) {
      _next();
      return;
    }
    _progress.forward();
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final provider = context.read<StatusProvider>();
    final id = _current.id;
    _pause(_PauseReason.like);
    final future = provider.toggleLike(id);
    setState(() {});
    try {
      await future;
    } finally {
      if (mounted) {
        setState(() {});
        _resume(_PauseReason.like);
      }
    }
  }

  String _statusPreviewLabel() {
    final s = _current;
    final lang = context.read<LocaleController>().resolvedLocale.languageCode;
    final localized = s.localizedText(lang);
    if (localized != null && localized.trim().isNotEmpty) return localized.trim();
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

  /// Citation persistée : libellé + métadonnées média pour la vignette en chat.
  String _statusReplyContent() {
    final s = _current;
    return encodeStatusReplyContent(
      type: s.type,
      preview: _statusPreviewLabel(),
      mediaUrl: s.mediaUrl,
      backgroundColor: s.backgroundColor,
      statusId: s.id,
      authorId: s.alanyaID,
    );
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
        replyToContent: _statusReplyContent(),
        isStatusReply: 1,
      );

      if (!mounted) return;
      _replyController.clear();
      _replyFocus.unfocus();
      _resume(_PauseReason.reply);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.replySent),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(presenterErreur(context.l10n, e, domaine: ErrorDomain.statut))));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _startRecordingReply() async {
    if (_sendingReply || _isRecording) return;
    if (!await _recorder.hasPermission()) return;
    _pause(_PauseReason.recording);
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
    if (mounted) _resume(_PauseReason.recording);
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
          content: Text(context.l10n.fileTooLarge(mb, '${EntitlementService.maxUploadMb}')),
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
        replyToContent: _statusReplyContent(),
        isStatusReply: 1,
      );

      if (!mounted) return;
      _resume(_PauseReason.recording);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.replySent),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(presenterErreur(context.l10n, e, domaine: ErrorDomain.statut))));
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
    final lang = context.read<LocaleController>().resolvedLocale.languageCode;
    final caption = s.localizedText(lang);
    final hasCaption = caption != null && caption.trim().isNotEmpty;

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
                        onLongPressStart: (_) => _pause(_PauseReason.hold),
                        onLongPressEnd: (_) => _resume(_PauseReason.hold),
                      ),
                    ),
                    const Expanded(child: SizedBox.expand()),
                    SizedBox(
                      width: 72,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _next,
                        onLongPressStart: (_) => _pause(_PauseReason.hold),
                        onLongPressEnd: (_) => _resume(_PauseReason.hold),
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
                        onLongPressStart: (_) => _pause(_PauseReason.hold),
                        onLongPressEnd: (_) => _resume(_PauseReason.hold),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _next,
                        onLongPressStart: (_) => _pause(_PauseReason.hold),
                        onLongPressEnd: (_) => _resume(_PauseReason.hold),
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
        if ((s.type == 1 || s.type == 2) && hasCaption)
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
                caption!,
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
                          onTap: () => _pause(_PauseReason.reply),
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
        final lang = context.read<LocaleController>().resolvedLocale.languageCode;
        return Container(
          color: bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            s.localizedText(lang) ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 1:
        return Center(child: _StatusImage(url: s.mediaUrl ?? ''));
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

/// Image d'un statut, retentée après un échec.
///
/// Un échec de chargement laissait l'icône « image cassée » jusqu'à ce qu'on
/// quitte le statut (groupe 3GI 2029, bug A5) : une relance automatique au bout
/// de 2 s, puis un bouton « Réessayer ».
class _StatusImage extends StatefulWidget {
  const _StatusImage({required this.url});

  final String url;

  @override
  State<_StatusImage> createState() => _StatusImageState();
}

class _StatusImageState extends State<_StatusImage> {
  static const _autoRetryDelay = Duration(seconds: 2);

  int _attempt = 0;
  bool _autoRetried = false;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant _StatusImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _attempt = 0;
      _autoRetried = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    _retryTimer?.cancel();
    // L'échec n'est pas mis en cache, mais l'entrée partielle peut l'être.
    await CachedNetworkImage.evictFromCache(widget.url);
    if (!mounted) return;
    setState(() => _attempt++);
  }

  void _onError() {
    if (_autoRetried) return;
    _autoRetried = true;
    _retryTimer = Timer(_autoRetryDelay, () => unawaited(_retry()));
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, __, ___) {
        _onError();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => unawaited(_retry()),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                context.l10n.commonRetry,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
