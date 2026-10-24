import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Résultat retourné par [CameraScreen].
class CameraResult {
  final XFile file;
  final bool isVideo;
  final int? durationSeconds;

  const CameraResult({
    required this.file,
    required this.isVideo,
    this.durationSeconds,
  });
}

/// Écran caméra intégré : un seul déclencheur. En mode photo, toucher prend
/// une photo et maintenir filme (relâcher arrête) ; en mode vidéo, toucher
/// démarre puis arrête l'enregistrement.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.onPickFromGallery});

  /// Bouton galerie : la caméra se ferme, puis ce sélecteur s'ouvre. `null` :
  /// pas de bouton.
  final VoidCallback? onPickFromGallery;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  FlashMode _flashMode = FlashMode.auto;
  bool _isRecording = false;
  bool _isInitialized = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isTakingPicture = false;
  bool _videoMode = false;

  /// Le doigt s'est levé avant que l'enregistrement n'ait démarré.
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _initController(_cameras[_currentCameraIndex]);
  }

  Future<void> _initController(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
    } on CameraException catch (e) {
      debugPrint('[CameraScreen] init error: $e');
      if (mounted) Navigator.pop(context);
      return;
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ── Flash ──────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.off => FlashMode.auto,
      _ => FlashMode.auto,
    };
    setState(() => _flashMode = next);
    await _controller?.setFlashMode(next);
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.auto => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    FlashMode.off => Icons.flash_off,
    _ => Icons.flash_auto,
  };

  // ── Switch caméra ──────────────────────────────────────────────────────

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_currentCameraIndex + 1) % _cameras.length;
    setState(() {
      _currentCameraIndex = next;
      _isInitialized = false;
    });
    await _initController(_cameras[next]);
  }

  // ── Capture photo ──────────────────────────────────────────────────────

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPicture || _isRecording) return;
    setState(() => _isTakingPicture = true);
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, CameraResult(file: file, isVideo: false));
    } on CameraException catch (e) {
      debugPrint('[CameraScreen] takePicture error: $e');
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  // ── Enregistrement vidéo (hold) ────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording || _isTakingPicture) return;
    _stopRequested = false;
    try {
      await _controller!.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
      if (_stopRequested) await _stopRecording();
    } on CameraException catch (e) {
      debugPrint('[CameraScreen] startVideo error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null) return;
    if (!_isRecording) {
      // Relâché pendant le démarrage : on arrêtera dès qu'il aura démarré.
      _stopRequested = true;
      return;
    }
    _recordingTimer?.cancel();
    try {
      final file = await _controller!.stopVideoRecording();
      if (!mounted) return;
      Navigator.pop(
        context,
        CameraResult(
          file: file,
          isVideo: true,
          durationSeconds: _recordingSeconds,
        ),
      );
    } on CameraException catch (e) {
      debugPrint('[CameraScreen] stopVideo error: $e');
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: _isInitialized && _controller != null
          ? Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Prévisualisation (sans distorsion)
                        FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _controller!.value.previewSize!.height,
                            height: _controller!.value.previewSize!.width,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 8,
                          left: 0,
                          right: 0,
                          child: _buildTopBar(),
                        ),
                        if (!_isRecording)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: AppSpacing.md,
                            child: Text(
                              _videoMode
                                  ? context.l10n.cameraStartRecording
                                  : context.l10n.cameraShutterHint,
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall?.copyWith(
                                color: AppColors.white,
                                shadows: [
                                  Shadow(
                                    color: AppColors.black.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: bottom + AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeSwitch(),
                      AppSpacing.vGapMd,
                      _buildShutterRow(),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _circleButton(
            icon: Icons.close,
            label: context.l10n.commonClose,
            onTap: _isRecording ? null : () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatDuration(_recordingSeconds),
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const Spacer(),
          _circleButton(
            icon: _flashIcon,
            label: context.l10n.cameraFlash,
            onTap: _toggleFlash,
          ),
        ],
      ),
    );
  }

  /// VIDÉO · PHOTO : le mode du déclencheur.
  Widget _buildModeSwitch() {
    Widget mode(bool video, String label) {
      final selected = _videoMode == video;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: _isRecording ? null : () => setState(() => _videoMode = video),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTapTarget,
              minWidth: AppSizes.minTapTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.white.withValues(alpha: 0.14) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: selected
                      ? AppColors.drawYellow
                      : AppColors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        mode(true, context.l10n.video2),
        mode(false, context.l10n.photo2),
      ],
    );
  }

  Widget _buildShutterRow() {
    final l10n = context.l10n;
    final gallery = widget.onPickFromGallery;
    final String shutterLabel;
    if (_isRecording) {
      shutterLabel = l10n.cameraStopRecording;
    } else if (_videoMode) {
      shutterLabel = l10n.cameraStartRecording;
    } else {
      shutterLabel = l10n.cameraTakePhoto;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 52,
            child: gallery == null || _isRecording
                ? null
                : _circleButton(
                    icon: Icons.photo_library_outlined,
                    label: l10n.cameraOpenGallery,
                    size: 52,
                    onTap: () {
                      Navigator.pop(context);
                      gallery();
                    },
                  ),
          ),
          Semantics(
            button: true,
            label: shutterLabel,
            child: GestureDetector(
              key: const ValueKey('camera-shutter'),
              onTap: () {
                if (_isRecording) {
                  _stopRecording();
                } else if (_videoMode) {
                  _startRecording();
                } else {
                  _takePicture();
                }
              },
              // Mode photo : maintenir filme, relâcher arrête.
              onLongPressStart: _videoMode ? null : (_) => _startRecording(),
              onLongPressEnd: _videoMode ? null : (_) => _stopRecording(),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 4),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isRecording ? 30 : 60,
                    height: _isRecording ? 30 : 60,
                    decoration: BoxDecoration(
                      color: _isRecording || _videoMode
                          ? AppColors.error
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(
                        _isRecording ? 8 : 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: _cameras.length > 1 && !_isRecording
                ? _circleButton(
                    icon: Icons.cameraswitch_outlined,
                    label: l10n.switchCamera,
                    size: 52,
                    onTap: _switchCamera,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    double size = AppSizes.minTapTarget,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.black.withAlpha(100),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
