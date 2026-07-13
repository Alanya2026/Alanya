import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

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

/// Écran caméra intégré — tap = photo, hold = vidéo.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    } on CameraException catch (e) {
      debugPrint('[CameraScreen] startVideo error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;
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
    return Scaffold(
      backgroundColor: AppColors.black,
      body: _isInitialized && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Prévisualisation (sans distortion)
                Center(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),

                // En haut : fermer + flash + switch caméra
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(),
                ),

                // En bas : boutons photo/vidéo
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                  left: 0,
                  right: 0,
                  child: _buildShutter(),
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
          // Fermer
          _circleButton(
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          // Flash
          _circleButton(
            icon: _flashIcon,
            onTap: _toggleFlash,
          ),
          const SizedBox(width: AppSpacing.md),
          // Switch caméra
          if (_cameras.length > 1)
            _circleButton(
              icon: Icons.cameraswitch_outlined,
              onTap: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildShutter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bouton photo
          GestureDetector(
            onTap: _isRecording ? null : _takePicture,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                      ),
                      child: const Icon(Icons.camera, color: AppColors.black, size: 26),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Photo',
                  style: TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          // Bouton vidéo
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 4),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: _isRecording
                          ? const BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.all(Radius.circular(14)),
                            )
                          : const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error,
                            ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.videocam,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isRecording ? _formatDuration(_recordingSeconds) : 'Vidéo',
                  style: TextStyle(
                    color: _isRecording ? AppColors.error : AppColors.white,
                    fontSize: 12,
                    fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
                    fontFeatures: _isRecording ? [const FontFeature.tabularFigures()] : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.black.withAlpha(100),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.white, size: 22),
      ),
    );
  }
}
