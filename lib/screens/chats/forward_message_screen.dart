import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/media_album.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'new_chat_screen.dart';

class ForwardMessageScreen extends StatefulWidget {
  const ForwardMessageScreen({
    super.key,
    this.message,
    this.albumItems,
    this.excludeConversationId,
  }) : assert(message != null || (albumItems != null && albumItems.length >= 2));

  final LocalMessage? message;
  final List<LocalMessage>? albumItems;
  final int? excludeConversationId;

  bool get isAlbum => albumItems != null && albumItems!.length >= 2;

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

    if (widget.isAlbum) {
      result = await chat.forwardAlbum(
        sourceItems: widget.albumItems!,
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded == 1
                ? (widget.isAlbum ? 'Album transféré' : 'Message transféré')
                : widget.isAlbum
                    ? 'Album transféré vers ${result.succeeded} discussions'
                    : 'Message transféré vers ${result.succeeded} discussions',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (result.hasSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Transféré vers ${result.succeeded}/${result.succeeded + result.failed} discussions',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isAlbum
                ? 'Impossible de transférer l\'album'
                : 'Impossible de transférer le message',
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

      await chat.refreshConversations();
      if (!mounted) return;
      setState(() => _selectedIds.add(convId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer la discussion')),
        );
      }
    }
  }

  IconData _previewIcon(int type) {
    switch (type) {
      case 1:
        return Icons.image_outlined;
      case 2:
        return Icons.videocam_outlined;
      case 3:
        return Icons.mic_outlined;
      case 4:
        return Icons.insert_drive_file_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.select<AuthProvider, int>(
      (a) => a.currentUser?.alanyaID ?? 0,
    );
    final chat = context.watch<ChatProvider>();
    final query = _searchController.text;
    final showCaption = !widget.isAlbum && (widget.message?.type ?? 0) != 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transférer'),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty || _sending
                ? null
                : () => _send(chat),
            child: Text(
              _selectedIds.isEmpty
                  ? 'Envoyer'
                  : 'Envoyer (${_selectedIds.length})',
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
                    decoration: const InputDecoration(
                      hintText: 'Ajouter une légende (optionnel)',
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
                  label: const Text('Nouveau contact'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Rechercher une discussion…',
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
                            ? 'Aucune discussion'
                            : 'Aucun résultat',
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
                                  'Groupe',
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
              color: Colors.black26,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (widget.isAlbum) {
      return _buildAlbumPreview(context, widget.albumItems!);
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
              _previewIcon(msg.type),
              color: context.colors.primary,
              size: AppIconSize.md,
            ),
            AppSpacing.hGapMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message à transférer',
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
            'Album à transférer',
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
    return ClipRRect(
      borderRadius: AppRadius.brSm,
      child: AspectRatio(
        aspectRatio: 1,
        child: hasLocal
            ? Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: msg.mediaUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceMuted,
                  child: Icon(
                    msg.type == 2 ? Icons.videocam : Icons.image,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
      ),
    );
  }
}
