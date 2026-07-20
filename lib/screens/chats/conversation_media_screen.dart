import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/db/app_database.dart';
import '../../core/utils/document_file_style.dart';
import '../../core/utils/rich_text_parser.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/common.dart';
import '../../widgets/video_message_preview.dart';
import 'media_viewer_screen.dart';

class _DateGroup {
  final String label;
  final List<LocalMessage> items;
  const _DateGroup({required this.label, required this.items});
}

class ConversationMediaScreen extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const ConversationMediaScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<ConversationMediaScreen> createState() =>
      _ConversationMediaScreenState();
}

class _ConversationMediaScreenState extends State<ConversationMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<List<LocalMessage>>? _messagesSub;
  List<LocalMessage> _images = [];
  List<LocalMessage> _videos = [];
  List<LocalMessage> _documents = [];
  List<LocalMessage> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _init() {
    final chat = context.read<ChatProvider>();
    // Local-first : Drift immédiat, sync réseau en fond (comme chat_detail).
    _messagesSub =
        chat.watchMessages(widget.conversationId).listen(_onMessages);
    unawaited(chat.repository.syncMessages(widget.conversationId));
  }

  void _onMessages(List<LocalMessage> messages) {
    final images = <LocalMessage>[];
    final videos = <LocalMessage>[];
    final documents = <LocalMessage>[];
    final links = <LocalMessage>[];
    for (final m in messages) {
      if (m.type == 1 && m.mediaUrl != null && m.mediaUrl!.isNotEmpty) {
        images.add(m);
      } else if (m.type == 2 &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty) {
        videos.add(m);
      } else if (m.type == 4 &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty) {
        documents.add(m);
      }
      final c = m.content;
      if (c != null && c.isNotEmpty && _hasUrl(c)) {
        links.add(m);
      }
    }
    if (!mounted) return;
    setState(() {
      _images = images.reversed.toList();
      _videos = videos.reversed.toList();
      _documents = documents.reversed.toList();
      _links = links.reversed.toList();
      _isLoading = false;
    });
  }

  bool _hasUrl(String text) =>
      text.contains('http://') || text.contains('https://');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(
          context.l10n.mediaTitleNamed(widget.conversationName),
          style: context.text.titleMedium,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? context.colors.surfaceContainerHigh
                : context.colors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(icon: Icon(Icons.image, size: 22), text: context.l10n.images),
                Tab(icon: Icon(Icons.videocam, size: 22), text: context.l10n.videos),
                Tab(icon: Icon(Icons.description, size: 22), text: context.l10n.documents),
                Tab(icon: Icon(Icons.link, size: 22), text: context.l10n.links),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const LoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildImageGrid(),
                _buildVideoGrid(),
                _buildDocumentList(),
                _buildLinksList(),
              ],
            ),
    );
  }

  // ── Images ──────────────────────────────────────────────────────────

  Widget _buildImageGrid() {
    if (_images.isEmpty) return _emptyState(CupertinoIcons.photo, context.l10n.noImages);
    return _buildDateSections(_images, isGrid: true, isVideo: false);
  }

  Widget _buildVideoGrid() {
    if (_videos.isEmpty) return _emptyState(CupertinoIcons.videocam, context.l10n.noVideos);
    return _buildDateSections(_videos, isGrid: true, isVideo: true);
  }

  Widget _buildDocumentList() {
    if (_documents.isEmpty) return _emptyState(Icons.insert_drive_file, context.l10n.noDocuments);
    return _buildDateSections(_documents, isGrid: false);
  }

  Widget _buildLinksList() {
    if (_links.isEmpty) return _emptyState(CupertinoIcons.link, context.l10n.noLinks);
    return _buildDateSections(_links, isGrid: false);
  }

  // ── Date grouping ───────────────────────────────────────────────────

  List<_DateGroup> _groupByDate(List<LocalMessage> messages) {
    if (messages.isEmpty) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_DateGroup>[];
    List<LocalMessage>? current;
    String? currentLabel;

    for (final m in messages) {
      final date = DateTime(m.sendAt.year, m.sendAt.month, m.sendAt.day);
      String label;
      if (date == today) {
        label = context.l10n.today;
      } else if (date == yesterday) {
        label = context.l10n.yesterday;
      } else {
        label =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }

      if (current == null || currentLabel != label) {
        if (current != null) {
          groups.add(_DateGroup(label: currentLabel!, items: current));
        }
        current = [];
        currentLabel = label;
      }
      current.add(m);
    }
    if (current != null) {
      groups.add(_DateGroup(label: currentLabel!, items: current));
    }
    return groups;
  }

  Widget _buildDateSections(List<LocalMessage> messages,
      {required bool isGrid, bool isVideo = false}) {
    final groups = _groupByDate(messages);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Text(
                group.label,
                style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w700),
              ),
            ),
            if (isGrid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: group.items.length,
                  itemBuilder: (context, i) =>
                      _gridItem(group.items[i], isVideo: isVideo),
                ),
              )
            else
              ...group.items.map((msg) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: msg.type == 4
                        ? _buildDocTile(msg)
                        : _buildLinkTile(msg),
                  )),
            AppSpacing.vGapSm,
          ],
        );
      },
    );
  }

  Widget _buildDocTile(LocalMessage msg) {
    final name = msg.mediaName ?? context.l10n.document;
    final style = DocumentFileStyle.fromMessage(
      mediaName: msg.mediaName,
      mediaUrl: msg.mediaUrl,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brSm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: style.color,
            borderRadius: AppRadius.brSm,
          ),
          child: Center(
            child: Text(style.extension,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        title: Text(name,
            style: context.text.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${msg.sendAt.day}/${msg.sendAt.month}/${msg.sendAt.year}',
          style: context.text.labelSmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right,
            color: context.colors.outlineVariant),
        onTap: () => _openDoc(msg),
      ),
    );
  }

  Widget _buildLinkTile(LocalMessage msg) {
    // Le contenu du message peut contenir du texte autour de l'URL
    // (« regarde ça : https://exemple.com ») : on n'ouvre que l'URL elle-même.
    final url = extractFirstUrl(msg.content ?? '');
    final info = context.semantic.info;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brSm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.semantic.infoContainer,
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(CupertinoIcons.link, color: info, size: 22),
        ),
        title: Text(msg.content ?? context.l10n.linkNoun,
            style: context.text.titleSmall?.copyWith(
              color: url != null ? info : null,
              decoration: url != null ? TextDecoration.underline : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${msg.sendAt.day}/${msg.sendAt.month}/${msg.sendAt.year}',
          style: context.text.labelSmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right,
            color: context.colors.outlineVariant),
        onTap: url != null ? () => openUrl(url) : null,
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String text) {
    return EmptyState(icon: icon, title: text);
  }

  Widget _gridItem(LocalMessage msg, {required bool isVideo}) {
    final placeholder = context.colors.surfaceContainerHighest;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            isVideo: isVideo,
            localPath: msg.localMediaPath,
            networkUrl: msg.mediaUrl,
            title: msg.mediaName,
          ),
        ),
      ),
      child: isVideo
          ? VideoMessagePreview(
              pendingPath: msg.pendingUploadPath,
              localPath: msg.localMediaPath,
              thumbBase64: msg.mediaThumb,
              durationSeconds: msg.mediaDuration,
              borderRadius: BorderRadius.circular(6),
              expandToFill: true,
              playIconSize: 26,
              fallbackColor: placeholder,
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: placeholder,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumbnail(msg, msg.localMediaPath ?? msg.mediaUrl),
                ),
              ],
            ),
    );
  }

  Widget _buildThumbnail(LocalMessage msg, String? url) {
    final placeholder = context.colors.surfaceContainerHighest;
    if (msg.type == 2) {
      return VideoMessagePreview(
        pendingPath: msg.pendingUploadPath,
        localPath: msg.localMediaPath,
        thumbBase64: msg.mediaThumb,
        durationSeconds: msg.mediaDuration,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        playIconSize: 26,
        fallbackColor: placeholder,
      );
    }
    final hasLocal =
        msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
    if (hasLocal) {
      return Image.file(File(msg.localMediaPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: placeholder));
    }
    // Reçu sans fichier local : preview réseau OK, badge download via l'ouverture.
    final myId = context.read<ChatProvider>().repository.myId;
    final isReceivedPending = !msg.isViewOnce &&
        msg.senderID != myId &&
        !hasLocal &&
        url != null &&
        url.isNotEmpty;
    if (url != null && url.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => const LoadingState(),
            errorWidget: (context, url, error) =>
                Container(color: placeholder),
          ),
          if (isReceivedPending)
            const Align(
              alignment: Alignment.center,
              child: Icon(Icons.download_rounded, color: AppColors.white, size: 28),
            ),
        ],
      );
    }
    return Container(color: placeholder);
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null &&
            File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      path = await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl!,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } else if (!msg.isViewOnce && msg.msgID != 0) {
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl ?? '',
        type: msg.type,
        isMine: isMine,
        isViewOnce: false,
        mediaName: msg.mediaName,
        existingLocalPath: path,
      );
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToDownloadTheFile),
              backgroundColor: context.colors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cannotOpenFileApp(res.message)),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: ctx.colors.primary)),
    );
  }
}
