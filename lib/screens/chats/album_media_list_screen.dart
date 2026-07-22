import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/message_share_service.dart';
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

const int _maxAlbumListSelectionCount = 50;

/// Liste verticale des médias d'un album (étape avant la visionneuse plein écran).
class AlbumMediaListScreen extends StatefulWidget {
  const AlbumMediaListScreen({
    super.key,
    required this.messages,
    this.initialIndex = 0,
    this.excludeConversationId,
    this.conversationId,
    this.initialSelectedIds,
    this.initialSelectionMode = false,
    this.onReply,
    this.onShowInfo,
  });

  final List<LocalMessage> messages;
  final int initialIndex;
  final int? excludeConversationId;
  final int? conversationId;
  final Set<int>? initialSelectedIds;
  final bool initialSelectionMode;
  final void Function(LocalMessage msg)? onReply;
  final void Function(LocalMessage msg)? onShowInfo;

  static const double itemHeight = 240;
  static const double itemSpacing = AppSpacing.sm;

  @override
  State<AlbumMediaListScreen> createState() => _AlbumMediaListScreenState();
}

class _AlbumMediaListScreenState extends State<AlbumMediaListScreen> {
  late final ScrollController _scrollController;
  late List<LocalMessage> _messages;
  StreamSubscription<List<LocalMessage>>? _messagesSub;
  bool _openingViewer = false;
  bool _selectionMode = false;
  bool _downloadingAll = false;
  final Set<int> _selectedMsgIDs = {};
  final Set<int> _mediaDownloadingIds = {};
  final Map<int, String> _localPathOverrides = {};

  bool _isSelectableMessage(LocalMessage msg) => msg.msgID > 0 && !msg.isDeleted;

  bool _hasLocal(LocalMessage msg) {
    final override = _localPathOverrides[msg.msgID];
    if (override != null && File(override).existsSync()) return true;
    return msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
  }

  String? _effectiveLocalPath(LocalMessage msg) {
    final override = _localPathOverrides[msg.msgID];
    if (override != null && File(override).existsSync()) return override;
    return msg.localMediaPath;
  }

  bool _needsMediaDownload(LocalMessage msg) {
    if (msg.isViewOnce) return false;
    final myId = context.read<ChatProvider>().repository.myId;
    if (msg.senderID == myId) return false;
    if (_hasLocal(msg)) return false;
    if (msg.type != 1 && msg.type != 2) return false;
    final url = msg.mediaUrl;
    return url != null && url.isNotEmpty;
  }

  int get _downloadableCount => _messages.where(_needsMediaDownload).length;

  List<LocalMessage> _resolveSelected() {
    return _messages
        .where((m) => _selectedMsgIDs.contains(m.msgID))
        .toList()
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _messages = List<LocalMessage>.from(widget.messages);
    if (widget.initialSelectionMode &&
        widget.initialSelectedIds != null &&
        widget.initialSelectedIds!.isNotEmpty) {
      _selectionMode = true;
      _selectedMsgIDs.addAll(widget.initialSelectedIds!);
    }
    final convId = widget.conversationId;
    if (convId != null) {
      final chat = context.read<ChatProvider>();
      _messagesSub = chat.watchMessages(convId).listen(_onMessagesUpdated);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
  }

  void _onMessagesUpdated(List<LocalMessage> all) {
    if (!mounted) return;
    final byId = {for (final m in all) m.msgID: m};
    var changed = false;
    final next = _messages.map((m) {
      final updated = byId[m.msgID];
      if (updated != null && updated != m) {
        changed = true;
        return updated;
      }
      return m;
    }).toList();
    if (changed) setState(() => _messages = next);
  }

  void _scrollToInitial() {
    if (!_scrollController.hasClients) return;
    final idx = widget.initialIndex.clamp(0, _messages.length - 1);
    final stride = AlbumMediaListScreen.itemHeight + AlbumMediaListScreen.itemSpacing;
    final offset = idx * stride;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, max));
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _downloadMedia(LocalMessage msg) async {
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty || msg.msgID == 0) return null;
    if (_mediaDownloadingIds.contains(msg.msgID)) return _effectiveLocalPath(msg);

    setState(() => _mediaDownloadingIds.add(msg.msgID));
    try {
      final chat = context.read<ChatProvider>();
      final myId = chat.repository.myId;
      final isMine = msg.senderID == myId;
      final path = await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: url,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (path == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.unableToDownloadTheMedia),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (path != null && mounted) {
        setState(() => _localPathOverrides[msg.msgID] = path);
      }
      return path;
    } finally {
      if (mounted) {
        setState(() => _mediaDownloadingIds.remove(msg.msgID));
      } else {
        _mediaDownloadingIds.remove(msg.msgID);
      }
    }
  }

  Future<void> _downloadAllMedia() async {
    final pending = _messages.where(_needsMediaDownload).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.albumMediaAlreadyDownloaded)),
      );
      return;
    }
    if (_downloadingAll) return;

    setState(() => _downloadingAll = true);
    try {
      for (final msg in pending) {
        final path = await _downloadMedia(msg);
        if (!mounted) return;
        if (path == null) return;
      }
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  void _enterSelectionMode(LocalMessage seed) {
    if (!_isSelectableMessage(seed)) return;
    setState(() {
      _selectionMode = true;
      _selectedMsgIDs
        ..clear()
        ..add(seed.msgID);
    });
  }

  void _enterSelectionModeAll() {
    final ids = _messages
        .where(_isSelectableMessage)
        .map((m) => m.msgID)
        .toSet();
    if (ids.isEmpty) return;
    setState(() {
      _selectionMode = true;
      _selectedMsgIDs
        ..clear()
        ..addAll(ids);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedMsgIDs.clear();
    });
  }

  void _toggleSelection(LocalMessage msg) {
    if (!_selectionMode || !_isSelectableMessage(msg)) return;
    final id = msg.msgID;

    if (_selectedMsgIDs.contains(id)) {
      setState(() {
        _selectedMsgIDs.remove(id);
        if (_selectedMsgIDs.isEmpty) _selectionMode = false;
      });
      return;
    }

    if (_selectedMsgIDs.length >= _maxAlbumListSelectionCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.maxMessages(_maxAlbumListSelectionCount)),
        ),
      );
      return;
    }

    setState(() => _selectedMsgIDs.add(id));
  }

  Future<void> _openViewer(int index) async {
    if (_openingViewer || _selectionMode) return;
    setState(() => _openingViewer = true);

    final chat = context.read<ChatProvider>();
    var loaderShown = false;

    try {
      final items = await buildMediaViewerItems(
        _messages,
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
    final chat = context.read<ChatProvider>();
    final myId = chat.repository.myId;
    final isMe = msg.senderID == myId;
    final primary = context.colors.primary;
    final error = context.colors.error;
    final muted = context.colors.onSurfaceVariant;
    final convId = widget.conversationId;

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSelectableMessage(msg))
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: primary),
                title: Text(context.l10n.select),
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(msg);
                },
              ),
            if (isMe && msg.status == 4)
              ListTile(
                leading: Icon(Icons.refresh, color: primary),
                title: Text(context.l10n.retrySending),
                onTap: () {
                  Navigator.pop(context);
                  chat.repository.retryMessage(msg.clientId);
                },
              ),
            if (widget.onReply != null)
              ListTile(
                leading: Icon(Icons.reply, color: primary),
                title: Text(context.l10n.reply),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context, _selectedMsgIDs);
                  widget.onReply!(msg);
                },
              ),
            if (canForwardMessage(msg))
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: Text(context.l10n.forward),
                onTap: () {
                  Navigator.pop(context);
                  _openForwardPicker(msg);
                },
              ),
            if (canForwardMessage(msg))
              ListTile(
                leading: Icon(Icons.share_outlined, color: primary),
                title: Text(context.l10n.share),
                onTap: () {
                  Navigator.pop(context);
                  _shareMessage(msg);
                },
              ),
            if (msg.msgID != 0 && !msg.isDeleted)
              ListTile(
                leading: Icon(
                  msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: primary,
                ),
                title: Text(msg.isPinned ? context.l10n.unpin2 : context.l10n.pin),
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(msg);
                },
              ),
            if (isMe && !msg.isDeleted)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(context.l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  chat.repository.deleteMessage(
                    msg.msgID,
                    forAll: true,
                    conversationID: convId,
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(context.l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                chat.repository.deleteMessage(
                  msg.msgID,
                  forAll: false,
                  conversationID: convId,
                );
              },
            ),
            if (msg.msgID != 0 && widget.onShowInfo != null)
              ListTile(
                leading: Icon(Icons.info_outline, color: primary),
                title: Text(context.l10n.infoAction),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context, _selectedMsgIDs);
                  widget.onShowInfo!(msg);
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  Future<void> _shareMessage(LocalMessage msg) async {
    final chat = context.read<ChatProvider>();
    if (!canForwardMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thisMessageCannotBeSharedRight),
        ),
      );
      return;
    }

    final ok = await MessageShareService.instance.shareMessage(
      message: msg,
      repository: chat.repository,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToShareTheMessage)),
      );
    }
  }

  Future<void> _shareSelected() async {
    final selected = _resolveSelected();
    if (selected.isEmpty) return;
    if (!selected.every(canForwardMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.oneOrMoreMessagesCannotBe),
        ),
      );
      return;
    }

    final chat = context.read<ChatProvider>();
    for (final msg in selected) {
      final ok = await MessageShareService.instance.shareMessage(
        message: msg,
        repository: chat.repository,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.unableToShareTheMessage)),
        );
        return;
      }
    }
    _exitSelectionMode();
  }

  Future<void> _togglePin(LocalMessage msg) async {
    if (msg.msgID == 0) return;
    final chat = context.read<ChatProvider>();
    try {
      await chat.repository.setMessagePinned(msg.msgID, !msg.isPinned);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.actionFailedPleaseTryAgain)),
      );
    }
  }

  Future<void> _togglePinSelected() async {
    final selected = _resolveSelected();
    if (selected.length != 1) return;
    await _togglePin(selected.first);
    if (mounted) _exitSelectionMode();
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

  Future<void> _forwardSelected() async {
    final selected = _resolveSelected();
    if (selected.isEmpty) return;
    if (!selected.every(canForwardMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.oneOrMoreMessagesCannotBe),
        ),
      );
      return;
    }

    final bool? ok;
    if (selected.length == 1) {
      ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardMessageScreen(
            message: selected.first,
            excludeConversationId: widget.excludeConversationId,
          ),
        ),
      );
    } else if (isCompleteAlbumSelection(selected) && canForwardAlbum(selected)) {
      ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardMessageScreen(
            albumItems: selected,
            excludeConversationId: widget.excludeConversationId,
          ),
        ),
      );
    } else {
      ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardMessageScreen(
            messages: selected,
            excludeConversationId: widget.excludeConversationId,
          ),
        ),
      );
    }

    if (ok == true && mounted) _exitSelectionMode();
  }

  Future<void> _deleteSelected({required bool forAll}) async {
    final ids = _selectedMsgIDs.toList();
    if (ids.isEmpty) return;
    final chat = context.read<ChatProvider>();
    await chat.repository.deleteMessages(
      ids,
      forAll: forAll,
      conversationID: widget.conversationId,
    );
    if (!mounted) return;
    _exitSelectionMode();
  }

  void _showDeleteSelectedMenu() {
    final selected = _resolveSelected();
    if (selected.isEmpty) return;
    final myId = context.read<ChatProvider>().repository.myId;
    final canDeleteForAll = selected.every((m) => m.senderID == myId);
    final muted = context.colors.onSurfaceVariant;
    final error = context.colors.error;

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(context.l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                _deleteSelected(forAll: false);
              },
            ),
            if (canDeleteForAll)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(context.l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSelected(forAll: true);
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  void _replyToSelected() {
    final selected = _resolveSelected();
    if (selected.length != 1 || widget.onReply == null) return;
    Navigator.pop(context, _selectedMsgIDs);
    widget.onReply!(selected.first);
  }

  void _showInfoSelected() {
    final selected = _resolveSelected();
    if (selected.length != 1 || widget.onShowInfo == null) return;
    Navigator.pop(context, _selectedMsgIDs);
    widget.onShowInfo!(selected.first);
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedMsgIDs.length;
    final selected = _resolveSelected();
    final single = selected.length == 1 ? selected.first : null;
    final canForward =
        selected.isNotEmpty && selected.every(canForwardMessage);
    final canShare = canForward;
    final canDelete = selected.isNotEmpty;
    final canReply = single != null && widget.onReply != null;
    final canPin = single != null && single.msgID != 0 && !single.isDeleted;
    final canInfo = single != null && single.msgID != 0 && widget.onShowInfo != null;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(context.l10n.selectedCount(count)),
      actions: [
        if (canReply)
          IconButton(
            icon: const Icon(Icons.reply),
            tooltip: context.l10n.reply,
            onPressed: _replyToSelected,
          ),
        if (canForward)
          IconButton(
            icon: const Icon(Icons.forward),
            tooltip: context.l10n.forward,
            onPressed: _forwardSelected,
          ),
        if (canShare)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: context.l10n.share,
            onPressed: _shareSelected,
          ),
        if (canPin)
          IconButton(
            icon: Icon(
              single.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            tooltip: single.isPinned ? context.l10n.unpin2 : context.l10n.pin,
            onPressed: _togglePinSelected,
          ),
        if (canInfo)
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.infoAction,
            onPressed: _showInfoSelected,
          ),
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.commonDelete,
            onPressed: _showDeleteSelectedMenu,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar(String title) {
    final selectableCount =
        _messages.where(_isSelectableMessage).length;
    final downloadableCount = _downloadableCount;
    return AppBar(
      title: Text(title),
      actions: [
        if (downloadableCount > 0)
          IconButton(
            icon: _downloadingAll
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.primary,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: context.l10n.downloadAlbumCount(downloadableCount),
            onPressed: _downloadingAll ? null : _downloadAllMedia,
          ),
        if (selectableCount >= 2)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: context.l10n.selectCount(selectableCount),
            onPressed: _enterSelectionModeAll,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = previewLabelForAlbumMessages(_messages);

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: _selectionMode
            ? _buildSelectionAppBar()
            : _buildNormalAppBar(title),
        body: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _messages.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AlbumMediaListScreen.itemSpacing),
          itemBuilder: (context, index) {
            final msg = _messages[index];
            final selected = _selectedMsgIDs.contains(msg.msgID);
            final needsDl = _needsMediaDownload(msg);
            final downloading = _mediaDownloadingIds.contains(msg.msgID);
            return _AlbumListTile(
              message: msg,
              index: index,
              selectionMode: _selectionMode,
              selected: selected,
              selectable: _isSelectableMessage(msg),
              localPath: _effectiveLocalPath(msg),
              needsDownload: needsDl,
              downloading: downloading,
              onTap: () async {
                if (_selectionMode) {
                  _toggleSelection(msg);
                  return;
                }
                if (needsDl) {
                  final path = await _downloadMedia(msg);
                  if (path == null) return;
                }
                if (!mounted) return;
                _openViewer(index);
              },
              onLongPress: () {
                if (_selectionMode) {
                  if (_isSelectableMessage(msg)) _toggleSelection(msg);
                  return;
                }
                _showItemMenu(msg);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlbumListTile extends StatelessWidget {
  const _AlbumListTile({
    required this.message,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.selectable,
    required this.localPath,
    required this.needsDownload,
    required this.downloading,
    required this.onTap,
    required this.onLongPress,
  });

  final LocalMessage message;
  final int index;
  final bool selectionMode;
  final bool selected;
  final bool selectable;
  final String? localPath;
  final bool needsDownload;
  final bool downloading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == 2;
    final uploading = message.status == 0;

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
                    localPath: localPath,
                    thumbBase64: message.mediaThumb,
                    durationSeconds: message.mediaDuration,
                    borderRadius: BorderRadius.zero,
                    expandToFill: true,
                    playIconSize: 36,
                    playPadding: 10,
                    hidePlayIcon: needsDownload,
                  )
                else
                  ImageMessagePreview(
                    localPath: localPath,
                    networkUrl: message.mediaUrl,
                    thumbBase64: message.mediaThumb,
                    useBlurredThumb: needsDownload,
                    borderRadius: BorderRadius.zero,
                    expandToFill: true,
                    fallbackColor: context.semantic.surfaceMuted,
                  ),
                if (needsDownload && !selectionMode)
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: downloading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(
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
                if (selectionMode && selected)
                  Container(
                    color: context.colors.primary.withValues(alpha: 0.28),
                  ),
                if (selectionMode && selectable)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? context.colors.primary
                            : AppColors.black.withValues(alpha: 0.45),
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: AppColors.white)
                          : null,
                    ),
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
