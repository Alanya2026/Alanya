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

import '../../core/services/video_thumbnail_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../providers/status_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/common.dart';

enum _StatusType { text, photo, video, audio }

/// Un média sélectionné en attente de publication.
///
/// Chaque brouillon devient un statut à part entière : le serveur ne stocke
/// qu'un média par statut, la publication multiple boucle donc sur la liste.
class _StatusMediaDraft {
  _StatusMediaDraft({required this.file, this.name, this.durationMs});

  final File file;
  final String? name;
  final int? durationMs;
  final TextEditingController captionCtrl = TextEditingController();

  void dispose() => captionCtrl.dispose();
}

class StatusCreateScreen extends StatefulWidget {
  const StatusCreateScreen({super.key});

  @override
  State<StatusCreateScreen> createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends State<StatusCreateScreen>
    with TickerProviderStateMixin {
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

  /// Plafond par publication — au-delà, l'enchaînement des uploads devient
  /// interminable et la story illisible.
  static const int _maxMedias = 30;

  _StatusType _type = _StatusType.text;
  final _textCtrl = TextEditingController();
  final List<_StatusMediaDraft> _drafts = [];
  int _index = 0;
  Color _bgColor = const Color(0xFFE53935);
  bool _publishing = false;

  /// Nombre de brouillons déjà publiés dans la passe en cours.
  int _published = 0;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  late final TabController _tabController;
  late final PageController _pageCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
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
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
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
        return _drafts.isNotEmpty;
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
      _clearDrafts();
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  // ── Actions médias ───────────────────────────────────────────────

  /// Libère un brouillon retiré **après** le frame : son `TextField` est encore
  /// monté au moment du retrait, et disposer son contrôleur trop tôt le casse.
  void _disposeDraftLater(_StatusMediaDraft draft) {
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  /// À appeler dans un `setState` : vide la sélection et libère les contrôleurs.
  void _clearDrafts() {
    for (final draft in _drafts) {
      _disposeDraftLater(draft);
    }
    _drafts.clear();
    _index = 0;
  }

  void _warnMaxReached() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.maxMedias(_maxMedias))),
    );
  }

  /// Ajoute les médias sélectionnés et cadre sur le premier d'entre eux.
  ///
  /// Matérialisé d'emblée : une `Iterable` paresseuse construirait deux fois
  /// les brouillons — donc deux `TextEditingController` dont un jamais libéré.
  void _addDrafts(Iterable<_StatusMediaDraft> added) {
    final list = added.toList();
    if (list.isEmpty) return;
    setState(() {
      _index = _drafts.length;
      _drafts.addAll(list);
    });
    _jumpTo(_index);
  }

  /// Recadre la PageView après le rebuild — `itemCount` n'a pas encore changé
  /// au moment où la sélection est modifiée.
  void _jumpTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      if (index < 0 || index >= _drafts.length) return;
      _pageCtrl.jumpToPage(index);
    });
  }

  void _removeDraftAt(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _disposeDraftLater(_drafts.removeAt(index));
      if (_index >= _drafts.length) _index = _drafts.length - 1;
      if (_index < 0) _index = 0;
    });
    if (_drafts.isNotEmpty) _jumpTo(_index);
  }

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    final remaining = _maxMedias - _drafts.length;
    if (remaining <= 0) {
      _warnMaxReached();
      return;
    }

    final picker = ImagePicker();
    final List<XFile> files;
    // La caméra ne produit qu'un média ; `pickMulti*` exige une limite ≥ 2.
    if (source == ImageSource.camera || remaining == 1) {
      final one = video
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1920,
            );
      files = one == null ? const [] : [one];
    } else {
      files = video
          ? await picker.pickMultiVideo(limit: remaining)
          : await picker.pickMultiImage(
              imageQuality: 80,
              maxWidth: 1920,
              limit: remaining,
            );
    }
    if (files.isEmpty || !mounted) return;

    if (files.length > remaining) _warnMaxReached();
    _addDrafts(
      files.take(remaining).map((f) => _StatusMediaDraft(file: File(f.path))),
    );
  }

  // ── Audio ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.microphonePermissionDenied2)),
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
      setState(() => _isRecording = false);
      if (_drafts.length >= _maxMedias) {
        _warnMaxReached();
        _deleteTempFile(path);
        return;
      }
      _addDrafts([
        _StatusMediaDraft(
          file: File(path),
          durationMs: seconds * 1000,
          name: context.l10n.voiceMessage,
        ),
      ]);
    } else {
      _deleteTempFile(path);
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }
  }

  void _deleteTempFile(String? path) {
    if (path == null) return;
    try {
      File(path).deleteSync();
    } catch (_) {
      /* fichier temporaire déjà absent — ignoré */
    }
  }

  Future<void> _pickAudioFile() async {
    final remaining = _maxMedias - _drafts.length;
    if (remaining <= 0) {
      _warnMaxReached();
      return;
    }

    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    final picked = res?.files ?? const <PlatformFile>[];
    if (picked.isEmpty || !mounted) return;

    if (picked.length > remaining) _warnMaxReached();
    _addDrafts(
      picked
          .take(remaining)
          .where((f) => f.path != null)
          .map((f) => _StatusMediaDraft(file: File(f.path!), name: f.name)),
    );
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
            Text(context.l10n.backgroundColor, style: ctx.text.titleMedium),
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

  /// Type serveur du média courant (1 = image, 2 = vidéo, 3 = audio).
  int get _mediaType => switch (_type) {
        _StatusType.video => 2,
        _StatusType.audio => 3,
        _ => 1,
      };

  Future<void> _publish() async {
    if (!_canPublish) return;
    HapticFeedback.lightImpact();
    setState(() {
      _publishing = true;
      _published = 0;
    });
    final provider = context.read<StatusProvider>();
    try {
      if (_type == _StatusType.text) {
        await provider.createText(
          text: _textCtrl.text.trim(),
          backgroundColor:
              _bgColor.toARGB32().toRadixString(16).padLeft(8, '0'),
        );
      } else {
        final type = _mediaType;
        // Un statut par média : le serveur n'en accepte qu'un par publication.
        for (final draft in List<_StatusMediaDraft>.of(_drafts)) {
          final caption = draft.captionCtrl.text.trim();
          await provider.createMedia(
            file: draft.file,
            type: type,
            caption: type == 3 ? null : caption,
            mediaDurationMs: draft.durationMs,
          );
          if (!mounted) return;
          setState(() => _published++);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      AppLog.e('StatusCreate', 'Publication du statut échouée', e, st);
      if (mounted) {
        setState(() {
          // Les médias déjà publiés sortent de la liste : le bouton ne
          // republiera que ceux qui restent.
          for (var i = 0; i < _published && _drafts.isNotEmpty; i++) {
            _disposeDraftLater(_drafts.removeAt(0));
          }
          _index = 0;
          _published = 0;
          _publishing = false;
        });
        if (_drafts.isNotEmpty) _jumpTo(0);
        final detail = e is TalkyException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail.isNotEmpty
                  ? context.l10n.unableToPostStatusWithError(detail)
                  : context.l10n.unableToPostTheStatusTry,
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
        title: Text(context.l10n.newStatus, style: context.text.titleLarge),
        actions: [
          if (isText)
            IconButton(
              icon: const Icon(Icons.palette_rounded),
              tooltip: context.l10n.backgroundColor,
              onPressed: _openColorPicker,
            ),
          if (_drafts.isNotEmpty &&
              (_type == _StatusType.photo || _type == _StatusType.video))
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: context.l10n.addMore,
              onPressed: _publishing
                  ? null
                  : () => _pickMedia(
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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.primary,
                          ),
                        ),
                        if (_drafts.length > 1) ...[
                          AppSpacing.hGapSm,
                          Text(
                            '${(_published + 1).clamp(1, _drafts.length)}'
                            '/${_drafts.length}',
                          ),
                        ],
                      ],
                    )
                  : Text(context.l10n.publishAction),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: context.l10n.text2),
            Tab(text: context.l10n.photo2),
            Tab(text: context.l10n.video2),
            Tab(text: context.l10n.audio2),
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
    final fg = _onBackground(_bgColor);
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
            cursorColor: fg,
            style: TextStyle(
              color: fg,
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
              hintText: context.l10n.typeYourStatus,
              hintStyle: TextStyle(
                color: fg.withValues(alpha: 0.55),
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

    if (_drafts.isNotEmpty) {
      final multi = _drafts.length > 1;
      return ColoredBox(
        color: context.semantic.surfaceMuted,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _drafts.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  child: Center(
                    child: _buildDraftPreview(i, isVideo: isVideo),
                  ),
                ),
              ),
            ),
            if (multi) _buildFilmstrip(isVideo: isVideo),
            SizedBox(height: bottom + (multi ? AppSpacing.md : AppSpacing.lg)),
          ],
        ),
      );
    }

    return ColoredBox(
      color: context.semantic.surfaceMuted,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: EmptyState(
          icon: isVideo ? CupertinoIcons.videocam : CupertinoIcons.photo,
          title: isVideo ? context.l10n.addAVideo : context.l10n.addAPhoto,
          message: context.l10n.fromGalleryOrCamera,
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => _pickMedia(ImageSource.gallery, video: isVideo),
                icon: const Icon(Icons.photo_library_outlined, size: AppIconSize.sm),
                label: Text(context.l10n.gallery),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickMedia(ImageSource.camera, video: isVideo),
                icon: Icon(
                  isVideo ? Icons.videocam_outlined : Icons.camera_alt_outlined,
                  size: AppIconSize.sm,
                ),
                label: Text(context.l10n.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aperçu plein cadre d'un brouillon, avec sa légende et son bouton retirer.
  Widget _buildDraftPreview(int index, {required bool isVideo}) {
    final draft = _drafts[index];
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: AppRadius.brMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              _LocalVideoPreview(
                key: ValueKey(draft.file.path),
                file: draft.file,
              )
            else
              Image.file(draft.file, fit: BoxFit.cover),
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
                    controller: draft.captionCtrl,
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
                      hintText: context.l10n.addADescription,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: _OverlayIconButton(
                icon: Icons.close_rounded,
                tooltip: context.l10n.removeMedia,
                onPressed: _publishing ? null : () => _removeDraftAt(index),
              ),
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Row(
                children: [
                  if (_drafts.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: StatusChip(
                        label: '${index + 1}/${_drafts.length}',
                        tone: StatusChipTone.neutral,
                      ),
                    ),
                  if (isVideo)
                    StatusChip(
                      label: context.l10n.video2,
                      tone: StatusChipTone.brand,
                      icon: Icons.movie_outlined,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pellicule des médias sélectionnés — navigation rapide entre les brouillons.
  Widget _buildFilmstrip({required bool isVideo}) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _drafts.length,
        separatorBuilder: (_, __) => AppSpacing.hGapSm,
        itemBuilder: (_, i) {
          final selected = i == _index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
              _jumpTo(i);
            },
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: AppRadius.brSm,
                border: Border.all(
                  color: selected
                      ? context.colors.primary
                      : context.colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.brSm,
                child: isVideo
                    ? _VideoThumb(file: _drafts[i].file)
                    : Image.file(_drafts[i].file, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioCanvas() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasFiles = _drafts.isNotEmpty;
    final colors = context.colors;
    final sem = context.semantic;

    final Color circleColor = _isRecording
        ? colors.error
        : (hasFiles ? colors.primary : sem.brandContainer);
    final Color iconColor = (_isRecording || hasFiles)
        ? colors.onPrimary
        : sem.onBrandContainer;
    final IconData circleIcon = _isRecording
        ? Icons.graphic_eq_rounded
        : (hasFiles ? Icons.audiotrack_rounded : Icons.mic_rounded);

    // Centré verticalement comme Texte / EmptyState photo-vidéo.
    // Sans ça, la Column min reste collée en haut → écran « demi vide ».
    return ColoredBox(
      color: context.semantic.surfaceMuted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl + bottom,
          );
          return SingleChildScrollView(
            padding: pad,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - pad.vertical)
                    .clamp(0.0, double.infinity),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _isRecording
                        ? _pulseScale
                        : const AlwaysStoppedAnimation(1),
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
                        ? '${context.l10n.recordingEllipsis} ${_formatDuration(_recordSeconds)}'
                        : context.l10n.recordOrImportAudio,
                    style: context.text.titleMedium,
                    textAlign: TextAlign.center,
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
                          icon: const Icon(
                            Icons.delete_outline,
                            size: AppIconSize.sm,
                          ),
                          label: Text(context.l10n.commonCancel),
                        ),
                        FilledButton.icon(
                          onPressed: () => _stopRecording(keep: true),
                          icon: const Icon(
                            Icons.check_rounded,
                            size: AppIconSize.sm,
                          ),
                          label: Text(context.l10n.finishAction),
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
                          onPressed: _publishing ? null : _startRecording,
                          icon: const Icon(
                            Icons.mic_rounded,
                            size: AppIconSize.sm,
                          ),
                          label: Text(context.l10n.recordAction),
                        ),
                        OutlinedButton.icon(
                          onPressed: _publishing ? null : _pickAudioFile,
                          icon: const Icon(
                            Icons.upload_file_rounded,
                            size: AppIconSize.sm,
                          ),
                          label: Text(context.l10n.importAction),
                        ),
                      ],
                    ),
                  if (hasFiles && !_isRecording) ...[
                    AppSpacing.vGapXl,
                    for (var i = 0; i < _drafts.length; i++)
                      _buildAudioDraftTile(i),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Ligne d'un audio sélectionné : nom, durée si connue, retrait.
  Widget _buildAudioDraftTile(int index) {
    final draft = _drafts[index];
    final duration = draft.durationMs;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.semantic.brandContainer,
          child: Icon(
            Icons.audiotrack_rounded,
            color: context.semantic.onBrandContainer,
          ),
        ),
        title: Text(
          draft.name ?? context.l10n.voiceMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: duration == null
            ? null
            : Text(_formatDuration((duration / 1000).round())),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.l10n.removeMedia,
          onPressed: _publishing ? null : () => _removeDraftAt(index),
        ),
      ),
    );
  }
}

/// Bouton rond translucide posé sur un média (retirer, etc.).
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }
}

/// Vignette d'une vidéo locale pour la pellicule de sélection.
class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnailService.forFile(file.path),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return ColoredBox(
            color: context.semantic.surfaceMuted,
            child: Icon(
              Icons.movie_outlined,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
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
