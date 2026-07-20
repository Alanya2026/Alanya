import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/media_album.dart';
import '../../core/utils/media_viewer_items.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/common.dart';
import '../../widgets/image_message_preview.dart';
import '../../widgets/video_message_preview.dart';
import 'forward_message_screen.dart';
import 'media_viewer_screen.dart';

/// Liste verticale des médias d'un album (étape avant la visionneuse plein écran).
class AlbumMediaListScreen extends StatefulWidget {
  const AlbumMediaListScreen({
    super.key,
    required this.messages,
    this.initialIndex = 0,
    this.excludeConversationId,
  });

  final List<LocalMessage> messages;
  final int initialIndex;
  final int? excludeConversationId;

  static const double itemHeight = 240;
  static const double itemSpacing = AppSpacing.sm;

  @override
  State<AlbumMediaListScreen> createState() => _AlbumMediaListScreenState();
}

class _AlbumMediaListScreenState extends State<AlbumMediaListScreen> {
  late final ScrollController _scrollController;
  bool _openingViewer = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
  }

  void _scrollToInitial() {
    if (!_scrollController.hasClients) return;
    final idx = widget.initialIndex.clamp(0, widget.messages.length - 1);
    final stride = AlbumMediaListScreen.itemHeight + AlbumMediaListScreen.itemSpacing;
    final offset = idx * stride;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, max));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openViewer(int index) async {
    if (_openingViewer) return;
    setState(() => _openingViewer = true);

    final chat = context.read<ChatProvider>();
    var loaderShown = false;

    try {
      final items = await buildMediaViewerItems(
        widget.messages,
        chat.repository,
        myId: chat.repository.myId,
        loadingForIndex: index,
        onLoadingVideo: () {
          if (!mounted || loaderShown) return;
          loaderShown = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        },
        onLoadingDone: () {
          if (mounted && loaderShown) {
            Navigator.of(context, rootNavigator: true).pop();
            loaderShown = false;
          }
        },
      );
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            items: items,
            initialIndex: index.clamp(0, items.length - 1),
          ),
        ),
      );
    } finally {
      if (mounted && loaderShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _openingViewer = false);
    }
  }

  void _showItemMenu(LocalMessage msg) {
    final primary = context.colors.primary;
    final canForward = canForwardMessage(msg);
    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canForward)
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: Text(context.l10n.forward),
                onTap: () {
                  Navigator.pop(context);
                  _openForwardPicker(msg);
                },
              )
            else
              ListTile(
                leading: Icon(
                  Icons.forward,
                  color: context.colors.onSurfaceVariant,
                ),
                title: Text(context.l10n.forwardUnavailable),
                subtitle: Text(context.l10n.mediaIsNotReadyYet),
                enabled: false,
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  void _openForwardPicker(LocalMessage msg) {
    if (!canForwardMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thisMediaCannotBeForwardedRight),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(
          message: msg,
          excludeConversationId: widget.excludeConversationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = previewLabelForAlbumMessages(widget.messages);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: widget.messages.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AlbumMediaListScreen.itemSpacing),
        itemBuilder: (context, index) {
          final msg = widget.messages[index];
          return _AlbumListTile(
            message: msg,
            index: index,
            onTap: () => _openViewer(index),
            onLongPress: () => _showItemMenu(msg),
          );
        },
      ),
    );
  }
}

class _AlbumListTile extends StatelessWidget {
  const _AlbumListTile({
    required this.message,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  final LocalMessage message;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == 2;
    final uploading = message.status == 0;
    final hasLocal = message.localMediaPath != null &&
        File(message.localMediaPath!).existsSync();
    final myId = context.read<ChatProvider>().repository.myId;
    final needsDl = !message.isViewOnce &&
        message.senderID != myId &&
        !hasLocal &&
        message.mediaUrl != null &&
        message.mediaUrl!.isNotEmpty;

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.brMd,
        child: ClipRRect(
          borderRadius: AppRadius.brMd,
          child: SizedBox(
            height: AlbumMediaListScreen.itemHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  VideoMessagePreview(
                    pendingPath: message.pendingUploadPath,
                    localPath: message.localMediaPath,
                    thumbBase64: message.mediaThumb,
                    durationSeconds: message.mediaDuration,
                    borderRadius: BorderRadius.zero,
                    expandToFill: true,
                    playIconSize: 36,
                    playPadding: 10,
                    hidePlayIcon: needsDl,
                  )
                else
                  ImageMessagePreview(
                    localPath: message.localMediaPath,
                    networkUrl: message.mediaUrl,
                    thumbBase64: message.mediaThumb,
                    useBlurredThumb: needsDl,
                    borderRadius: BorderRadius.zero,
                    expandToFill: true,
                    fallbackColor: context.semantic.surfaceMuted,
                  ),
                if (needsDl)
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                  ),
                if (uploading)
                  Container(
                    color: AppColors.black.withValues(alpha: 0.26),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: AppColors.white),
                  ),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.54),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
