import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../providers/status_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/common.dart';

enum _StatusType { text, photo, video, audio }

class StatusCreateScreen extends StatefulWidget {
  const StatusCreateScreen({super.key});

  @override
  State<StatusCreateScreen> createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends State<StatusCreateScreen>
    with TickerProviderStateMixin {
  static const Color _textStatusForeground = Colors.white;

  static const List<Color> _palette = [
    Color(0xFFE53935),
    Color(0xFF3949AB),
    Color(0xFF00897B),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
    Color(0xFFFFB300),
    Color(0xFF424242),
    Color(0xFF6D4C41),
  ];

  _StatusType _type = _StatusType.text;
  final _textCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  File? _mediaFile;
  Color _bgColor = const Color(0xFFE53935);
  bool _publishing = false;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  int? _audioDurationMs;
  String? _audioName;

  late final TabController _tabController;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _captionCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  bool get _canPublish {
    if (_publishing) return false;
    switch (_type) {
      case _StatusType.text:
        return _textCtrl.text.trim().isNotEmpty;
      case _StatusType.photo:
      case _StatusType.video:
      case _StatusType.audio:
        return _mediaFile != null;
    }
  }

  bool get _isTextMode => _type == _StatusType.text;

  Color _onBackground(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _applyType(_StatusType.values[_tabController.index]);
  }

  void _applyType(_StatusType next, {bool haptic = true}) {
    if (next == _type) return;
    if (haptic) HapticFeedback.selectionClick();
    if (_isRecording) {
      _recordTimer?.cancel();
      _recorder.stop();
      _pulseCtrl.stop();
    }
    setState(() {
      _type = next;
      _mediaFile = null;
      _captionCtrl.clear();
      _isRecording = false;
      _recordSeconds = 0;
      _audioDurationMs = null;
      _audioName = null;
    });
  }

  // ── Actions médias ───────────────────────────────────────────────

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(
            source: source,
            imageQuality: 80,
            maxWidth: 1920,
          );
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  // ── Audio ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission micro refusée')),
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/status_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    _pulseCtrl.repeat(reverse: true);
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _mediaFile = null;
      _audioDurationMs = null;
      _audioName = null;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool keep}) async {
    _recordTimer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (!mounted) return;
    HapticFeedback.lightImpact();
    if (keep && path != null && seconds >= 1) {
      setState(() {
        _isRecording = false;
        _mediaFile = File(path);
        _audioDurationMs = seconds * 1000;
        _audioName = 'Message vocal';
      });
    } else {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {
          /* fichier temporaire déjà absent — ignoré */
        }
      }
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = res?.files.single.path;
    if (path != null && mounted) {
      setState(() {
        _mediaFile = File(path);
        _audioDurationMs = null;
        _audioName = res!.files.single.name;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Color picker ─────────────────────────────────────────────────

  Future<void> _openColorPicker() async {
    final onSurface = context.colors.onSurface;
    final picked = await showAppBottomSheet<Color>(
      context: context,
      builder: (ctx) => AppBottomSheet(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Couleur de fond', style: ctx.text.titleMedium),
            AppSpacing.vGapLg,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final color in _palette)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, color),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _bgColor.toARGB32() == color.toARGB32()
                              ? onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: AppShadows.subtle,
                      ),
                      child: _bgColor.toARGB32() == color.toARGB32()
                          ? Icon(
                              Icons.check,
                              color: _onBackground(color),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _bgColor = picked);
  }

  // ── Publication ──────────────────────────────────────────────────

  Future<void> _publish() async {
    if (!_canPublish) return;
    HapticFeedback.lightImpact();
    setState(() => _publishing = true);
    final provider = context.read<StatusProvider>();
    try {
      switch (_type) {
        case _StatusType.text:
          await provider.createText(
            text: _textCtrl.text.trim(),
            backgroundColor:
                _bgColor.toARGB32().toRadixString(16).padLeft(8, '0'),
          );
        case _StatusType.photo:
          await provider.createMedia(
            file: _mediaFile!,
            type: 1,
            caption: _captionCtrl.text.trim(),
          );
        case _StatusType.video:
          await provider.createMedia(
            file: _mediaFile!,
            type: 2,
            caption: _captionCtrl.text.trim(),
          );
        case _StatusType.audio:
          await provider.createMedia(
            file: _mediaFile!,
            type: 3,
            mediaDurationMs: _audioDurationMs,
          );
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      AppLog.e('StatusCreate', 'Publication du statut échouée', e, st);
      if (mounted) {
        setState(() => _publishing = false);
        final detail = e is TalkyException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail.isNotEmpty
                  ? 'Impossible de publier le statut : $detail'
                  : 'Impossible de publier le statut, réessayez',
            ),
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isText = _isTextMode;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Text('Nouveau statut', style: context.text.titleLarge),
        actions: [
          if (isText)
            IconButton(
              icon: const Icon(Icons.palette_rounded),
              tooltip: 'Couleur de fond',
              onPressed: _openColorPicker,
            ),
          if (_mediaFile != null &&
              (_type == _StatusType.photo || _type == _StatusType.video))
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Changer le média',
              onPressed: () => _pickMedia(
                ImageSource.gallery,
                video: _type == _StatusType.video,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.tonal(
              onPressed: _canPublish && !_publishing ? _publish : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: _publishing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.primary,
                      ),
                    )
                  : const Text('Publier'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Texte'),
            Tab(text: 'Photo'),
            Tab(text: 'Vidéo'),
            Tab(text: 'Audio'),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.fast,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(_type),
          child: _buildCanvas(),
        ),
      ),
    );
  }

  // ── Canvas par mode ──────────────────────────────────────────────

  Widget _buildCanvas() {
    switch (_type) {
      case _StatusType.text:
        return _buildTextCanvas();
      case _StatusType.photo:
        return _buildMediaCanvas(isVideo: false);
      case _StatusType.video:
        return _buildMediaCanvas(isVideo: true);
      case _StatusType.audio:
        return _buildAudioCanvas();
    }
  }

  Widget _buildTextCanvas() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: _bgColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg + bottom,
        ),
        child: Center(
          child: TextField(
            controller: _textCtrl,
            onChanged: (_) => setState(() {}),
            maxLines: null,
            textAlign: TextAlign.center,
            cursorColor: _textStatusForeground,
            style: const TextStyle(
              color: _textStatusForeground,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            decoration: InputDecoration(
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Tapez votre statut…',
              hintStyle: TextStyle(
                color: _textStatusForeground.withValues(alpha: 0.55),
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCanvas({required bool isVideo}) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (_mediaFile != null) {
      return ColoredBox(
        color: context.semantic.surfaceMuted,
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + bottom,
            ),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: AppRadius.brMd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isVideo)
                      _LocalVideoPreview(
                        key: ValueKey(_mediaFile!.path),
                        file: _mediaFile!,
                      )
                    else
                      Image.file(_mediaFile!, fit: BoxFit.cover),
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
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xxl,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: TextField(
                            controller: _captionCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            cursorColor: Colors.white,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Ajouter une description…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isVideo)
                      const Positioned(
                        top: AppSpacing.md,
                        right: AppSpacing.md,
                        child: StatusChip(
                          label: 'Vidéo',
                          tone: StatusChipTone.brand,
                          icon: Icons.movie_outlined,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: context.semantic.surfaceMuted,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: EmptyState(
          icon: isVideo ? CupertinoIcons.videocam : CupertinoIcons.photo,
          title: isVideo ? 'Ajouter une vidéo' : 'Ajouter une photo',
          message: 'Depuis la galerie ou l\'appareil photo',
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => _pickMedia(ImageSource.gallery, video: isVideo),
                icon: const Icon(Icons.photo_library_outlined, size: AppIconSize.sm),
                label: const Text('Galerie'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickMedia(ImageSource.camera, video: isVideo),
                icon: Icon(
                  isVideo ? Icons.videocam_outlined : Icons.camera_alt_outlined,
                  size: AppIconSize.sm,
                ),
                label: Text(isVideo ? 'Caméra' : 'Appareil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCanvas() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasFile = _mediaFile != null;
    final colors = context.colors;
    final sem = context.semantic;

    final Color circleColor = _isRecording
        ? colors.error
        : (hasFile ? colors.primary : sem.brandContainer);
    final Color iconColor = (_isRecording || hasFile)
        ? colors.onPrimary
        : sem.onBrandContainer;
    final IconData circleIcon = _isRecording
        ? Icons.graphic_eq_rounded
        : (hasFile ? Icons.audiotrack_rounded : Icons.mic_rounded);

    return ColoredBox(
      color: context.semantic.surfaceMuted,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ScaleTransition(
                scale: _isRecording ? _pulseScale : const AlwaysStoppedAnimation(1),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    boxShadow: _isRecording ? AppShadows.medium : null,
                  ),
                  child: Icon(circleIcon, size: 44, color: iconColor),
                ),
              ),
              AppSpacing.vGapXl,
              Text(
                _isRecording
                    ? 'Enregistrement… ${_formatDuration(_recordSeconds)}'
                    : hasFile
                        ? (_audioName ?? 'Message vocal')
                        : 'Enregistrez un vocal ou importez un fichier audio',
                style: context.text.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (hasFile && !_isRecording && _audioDurationMs != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _formatDuration((_audioDurationMs! / 1000).round()),
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              AppSpacing.vGapXl,
              if (_isRecording)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _stopRecording(keep: false),
                      icon: const Icon(Icons.delete_outline, size: AppIconSize.sm),
                      label: const Text('Annuler'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _stopRecording(keep: true),
                      icon: const Icon(Icons.check_rounded, size: AppIconSize.sm),
                      label: const Text('Terminer'),
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic_rounded, size: AppIconSize.sm),
                      label: Text(hasFile ? 'Réenregistrer' : 'Enregistrer'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.upload_file_rounded, size: AppIconSize.sm),
                      label: const Text('Importer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aperçu d'une vidéo locale — `Image.file` ne peut pas décoder un fichier vidéo.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({super.key, required this.file});

  final File file;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_onVideoUpdate);
      await controller.setLooping(true);
      await controller.setVolume(1);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await controller.dispose();
      _controller = null;
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    HapticFeedback.lightImpact();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      );
    }

    final playing = controller.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlayback,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Icon(
                key: ValueKey(playing),
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 6,
                    color: Color(0x99000000),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
