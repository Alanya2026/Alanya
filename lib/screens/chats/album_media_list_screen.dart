import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_album.dart';
import '../../core/utils/media_viewer_items.dart';
import '../../providers/chat_provider.dart';
import 'media_viewer_screen.dart';

/// Liste verticale des médias d'un album (étape avant la visionneuse plein écran).
class AlbumMediaListScreen extends StatefulWidget {
  const AlbumMediaListScreen({
    super.key,
    required this.messages,
    this.initialIndex = 0,
  });

  final List<LocalMessage> messages;
  final int initialIndex;

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
  });

  final LocalMessage message;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == 2;
    final uploading = message.status == 0;
    final hasLocal = message.localMediaPath != null &&
        File(message.localMediaPath!).existsSync();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: ClipRRect(
          borderRadius: AppRadius.brMd,
          child: SizedBox(
            height: AlbumMediaListScreen.itemHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasLocal)
                  Image.file(File(message.localMediaPath!), fit: BoxFit.cover)
                else if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isVideo
                          ? AppColors.immersiveBackground
                          : context.semantic.surfaceMuted,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: context.semantic.surfaceMuted,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Container(color: AppColors.immersiveBackground),
                if (isVideo)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.white.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: AppColors.white,
                        size: 40,
                      ),
                    ),
                  ),
                if (uploading)
                  Container(
                    color: Colors.black26,
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
                      color: Colors.black54,
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
