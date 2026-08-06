import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/backend_url.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../chats/media_viewer_screen.dart';

/// Grille paginée des médias envoyés par l'utilisateur.
class MyMediaScreen extends StatefulWidget {
  const MyMediaScreen({super.key});

  @override
  State<MyMediaScreen> createState() => _MyMediaScreenState();
}

class _MyMediaScreenState extends State<MyMediaScreen> {
  final _items = <MyMediaItem>[];
  final _scrollController = ScrollController();
  int? _nextCursor;
  bool _loading = false;
  bool _initial = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _nextCursor == null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && _nextCursor == null && !_initial) return;

    setState(() {
      _loading = true;
      if (refresh) _error = null;
    });

    try {
      final page = await context.read<TalkyApiClient>().getMyMedia(
            cursor: refresh ? null : _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _nextCursor = page.nextCursor;
        _initial = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initial = false;
        _error = '$e';
      });
    }
  }

  void _openViewer(int index) {
    final viewerItems = _items
        .map(
          (m) => MediaViewerItem(
            isVideo: m.isVideo,
            networkUrl: normalizeBackendUrl(m.mediaUrl),
            title: m.mediaName,
            msgID: m.msgID,
          ),
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          items: viewerItems,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.myMediaTitle)),
      body: _initial && _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: AppSpacing.screenH,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.myMediaLoadFailed),
                        AppSpacing.vGapMd,
                        TextButton(
                          onPressed: () => _load(refresh: true),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.myMediaEmpty,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(refresh: true),
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _items.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final item = _items[index];
                          final url = normalizeBackendUrl(item.mediaUrl) ?? '';
                          return GestureDetector(
                            onTap: () => _openViewer(index),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (url.isNotEmpty && !item.isVideo)
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: context.semantic.surfaceMuted,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: context.semantic.brandContainer,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    color: context.semantic.brandContainer,
                                    child: Icon(
                                      item.isVideo
                                          ? Icons.videocam_outlined
                                          : Icons.image_outlined,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                if (item.isVideo)
                                  const Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
