import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_album.dart';

/// Résultat de l'écran de composition média (légende optionnelle).
class MediaSendResult {
  const MediaSendResult({this.caption});

  final String? caption;
}

/// Aperçu plein écran avant envoi d'une photo / vidéo (ou d'un album),
/// avec champ de légende optionnel.
class MediaSendScreen extends StatefulWidget {
  const MediaSendScreen({
    super.key,
    required this.items,
    this.isViewOnce = false,
  });

  final List<AlbumSendItem> items;
  final bool isViewOnce;

  @override
  State<MediaSendScreen> createState() => _MediaSendScreenState();
}

class _MediaSendScreenState extends State<MediaSendScreen> {
  final _captionCtrl = TextEditingController();
  final _pageCtrl = PageController();
  int _page = 0;
  bool _isSending = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_isSending) return;
    _isSending = true;
    final caption = _captionCtrl.text.trim();
    Navigator.pop(
      context,
      MediaSendResult(caption: caption.isEmpty ? null : caption),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final multi = items.length > 1;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.immersiveBackground,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.white),
                    tooltip: context.l10n.commonCancel,
                  ),
                  Expanded(
                    child: Text(
                      multi
                          ? '${_page + 1}/${items.length}'
                          : (items.first.type == 2 ? context.l10n.video2 : context.l10n.photo2),
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isViewOnce)
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(Icons.timer, color: AppColors.white, size: 20),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item.type == 2) {
                    return _LocalVideoPreview(file: item.file);
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.file(item.file, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captionCtrl,
                        style: const TextStyle(color: AppColors.white, fontSize: 15),
                        cursorColor: AppColors.white,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.white.withValues(alpha: 0.12),
                          hintText: context.l10n.addACaption,
                          hintStyle: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.55),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: context.colors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSending ? null : _send,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.send,
                            color: _isSending
                                ? AppColors.white.withValues(alpha: 0.5)
                                : AppColors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu d'une vidéo locale avant envoi.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.file});

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
      return Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.white.withValues(alpha: 0.7),
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
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: playing ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.white.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppColors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
