import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/document_file_style.dart';
import '../../core/utils/audio_message_kind.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/media_album.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/image_message_preview.dart';
import '../../widgets/video_message_preview.dart';
import 'new_chat_screen.dart';

class ForwardMessageScreen extends StatefulWidget {
  const ForwardMessageScreen({
    super.key,
    this.message,
    this.messages,
    this.albumItems,
    this.excludeConversationId,
  }) : assert(
          message != null ||
              (messages != null && messages.length >= 2) ||
              (albumItems != null && albumItems.length >= 2),
        );

  final LocalMessage? message;
  final List<LocalMessage>? messages;
  final List<LocalMessage>? albumItems;
  final int? excludeConversationId;

  /// Transfert explicite depuis le menu « Transférer l'album ».
  bool get isExplicitAlbumForward =>
      albumItems != null && albumItems!.length >= 2;

  bool get isMultiMessage =>
      messages != null && messages!.length >= 2;

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final _searchController = TextEditingController();
  final _captionController = TextEditingController();
  final Set<int> _selectedIds = {};
  bool _sending = false;

  @override
  void dispose() {
    _searchController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _send(ChatProvider chat) async {
    if (_selectedIds.isEmpty || _sending) return;
    setState(() => _sending = true);

    final caption = _captionController.text.trim();
    final ForwardResult result;

    if (widget.isExplicitAlbumForward) {
      result = await chat.forwardAlbum(
        sourceItems: widget.albumItems!,
        targetConversationIDs: _selectedIds.toList(),
      );
    } else if (widget.isMultiMessage) {
      result = await chat.forwardMessages(
        sources: widget.messages!,
        targetConversationIDs: _selectedIds.toList(),
      );
    } else {
      result = await chat.forwardMessage(
        source: widget.message!,
        targetConversationIDs: _selectedIds.toList(),
        caption: caption.isEmpty ? null : caption,
      );
    }

    if (!mounted) return;
    setState(() => _sending = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.hasSuccess && result.failed == 0) {
      final label = widget.isExplicitAlbumForward
          ? context.l10n.albumNoun
          : widget.isMultiMessage
              ? context.l10n.messagesCountLabel(widget.messages!.length)
              : context.l10n.messageNoun;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded == 1
                ? context.l10n.labelForwarded(label)
                : context.l10n.labelForwardedTo(label, result.succeeded),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (result.hasSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.forwardedToRatio(result.succeeded, result.succeeded + result.failed),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isExplicitAlbumForward
                ? context.l10n.unableToForwardTheAlbum
                : widget.isMultiMessage
                    ? context.l10n.unableToForwardTheMessages
                    : context.l10n.unableToForwardTheMessage,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickNewContact() async {
    final user = await Navigator.push<User>(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (user == null || !mounted) return;

    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      final result =
          await api.createConversation(participantID: user.alanyaID);
      final convId = result['conversID'] as int?;
      if (convId == null) return;

      await chat.refreshConversations(force: true);
      if (!mounted) return;
      setState(() => _selectedIds.add(convId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.unableToCreateTheConversation)),
        );
      }
    }
  }

  IconData _previewIcon(LocalMessage msg) {
    switch (msg.type) {
      case 1:
        return Icons.image_outlined;
      case 2:
        return Icons.videocam_outlined;
      case 3:
        return audioKindFromName(msg.mediaName) == AudioMessageKind.music
            ? Icons.music_note
            : Icons.mic_outlined;
      case 4:
        return DocumentFileStyle.fromMessage(
          mediaName: msg.mediaName,
          mediaUrl: msg.mediaUrl,
        ).icon;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color _previewIconColor(LocalMessage msg, Color fallback) {
    if (msg.type == 4) {
      return DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      ).color;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.select<AuthProvider, int>(
      (a) => a.currentUser?.alanyaID ?? 0,
    );
    final chat = context.watch<ChatProvider>();
    final query = _searchController.text;
    final showCaption = !widget.isExplicitAlbumForward &&
        !widget.isMultiMessage &&
        (widget.message?.type ?? 0) != 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.forward),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty || _sending
                ? null
                : () => _send(chat),
            child: Text(
              _selectedIds.isEmpty
                  ? context.l10n.commonSend
                  : context.l10n.sendWithCount(_selectedIds.length),
              style: TextStyle(
                color: _selectedIds.isEmpty
                    ? context.colors.onSurfaceVariant
                    : context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreview(context),
              if (showCaption)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      hintText: context.l10n.addACaptionOptional,
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: OutlinedButton.icon(
                  onPressed: _pickNewContact,
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(context.l10n.newContact),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: context.l10n.searchChats,
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              AppSpacing.vGapSm,
              Expanded(
                child: StreamBuilder<List<LocalConversation>>(
                  stream: chat.watchConversations(),
                  builder: (context, snap) {
                    final all = snap.data ?? const [];
                    final convs = all
                        .where((c) =>
                            c.conversID != widget.excludeConversationId &&
                            conversationMatchesSearch(c, myId, query))
                        .toList();

                    if (convs.isEmpty) {
                      return EmptyState(
                        icon: Icons.forum_outlined,
                        title: query.trim().isEmpty
                            ? context.l10n.noChats
                            : context.l10n.noResults,
                      );
                    }

                    return ListView.builder(
                      itemCount: convs.length,
                      itemBuilder: (_, i) {
                        final conv = convs[i];
                        final selected = _selectedIds.contains(conv.conversID);
                        final name = conversationDisplayName(conv, myId);
                        final avatar =
                            conversationDisplayAvatar(conv, myId);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) {
                            setState(() {
                              if (selected) {
                                _selectedIds.remove(conv.conversID);
                              } else {
                                _selectedIds.add(conv.conversID);
                              }
                            });
                          },
                          secondary: AppAvatar(
                            imageUrl: avatar,
                            name: name,
                            isGroup: conv.isGroup,
                            size: AppSizes.avatarMd,
                          ),
                          title: Text(name, style: context.text.titleSmall),
                          subtitle: conv.isGroup
                              ? Text(
                                  context.l10n.groupFallback,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          controlAffinity: ListTileControlAffinity.trailing,
                          activeColor: context.colors.primary,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_sending)
            Container(
              color: AppColors.black.withValues(alpha: 0.26),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (widget.isExplicitAlbumForward) {
      return _buildAlbumPreview(context, widget.albumItems!);
    }
    if (widget.isMultiMessage) {
      return _buildMultiMessagePreview(context, widget.messages!);
    }

    final msg = widget.message!;
    final preview = previewTextForForward(msg);
    final isMedia = msg.type != 0;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMedia) ...[
            Icon(
              _previewIcon(msg),
              color: _previewIconColor(msg, context.colors.primary),
              size: AppIconSize.md,
            ),
            AppSpacing.hGapMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.messageToForward,
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.vGapXs,
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiMessagePreview(BuildContext context, List<LocalMessage> items) {
    final sorted = List<LocalMessage>.from(items)
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sorted.length == 1 ? context.l10n.messagesCountLabelOne(sorted.length) : context.l10n.messagesCountLabel(sorted.length),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapSm,
          for (final msg in sorted.take(4)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.type != 0) ...[
                  Icon(
                    _previewIcon(msg),
                    size: AppIconSize.sm,
                    color: _previewIconColor(msg, context.colors.onSurfaceVariant),
                  ),
                  AppSpacing.hGapSm,
                ],
                Expanded(
                  child: Text(
                    previewTextForForward(msg),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
            AppSpacing.vGapSm,
          ],
          if (sorted.length > 4)
            Text(
              context.l10n.andNOthers(sorted.length - 4),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumPreview(BuildContext context, List<LocalMessage> items) {
    final sorted = List<LocalMessage>.from(items)
      ..sort((a, b) {
        final ma = parseAlbumMarker(a.content);
        final mb = parseAlbumMarker(b.content);
        return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
      });
    final preview = previewTextForForwardAlbum(sorted);
    final thumbs = sorted.take(4).toList();

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.albumToForward,
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapSm,
          SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < thumbs.length; i++) ...[
                  if (i > 0) AppSpacing.hGapXs,
                  Expanded(child: _albumThumb(thumbs[i])),
                ],
              ],
            ),
          ),
          AppSpacing.vGapSm,
          Text(preview, style: context.text.bodyMedium),
        ],
      ),
    );
  }

  Widget _albumThumb(LocalMessage msg) {
    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    final myId = context.read<ChatProvider>().repository.myId;
    final needsDl = !msg.isViewOnce &&
        msg.senderID != myId &&
        !hasLocal &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: AppRadius.brSm,
      child: AspectRatio(
        aspectRatio: 1,
        child: msg.type == 2
            ? VideoMessagePreview(
                pendingPath: msg.pendingUploadPath,
                localPath: msg.localMediaPath,
                thumbBase64: msg.mediaThumb,
                borderRadius: BorderRadius.zero,
                expandToFill: true,
                showDuration: false,
                hidePlayIcon: true,
                playIconSize: 20,
                playPadding: 4,
                fallbackColor: AppColors.surfaceMuted,
              )
            : ImageMessagePreview(
                localPath: msg.localMediaPath,
                networkUrl: msg.mediaUrl,
                thumbBase64: msg.mediaThumb,
                useBlurredThumb: needsDl,
                borderRadius: BorderRadius.zero,
                expandToFill: true,
                fallbackColor: AppColors.surfaceMuted,
              ),
      ),
    );
  }
}
