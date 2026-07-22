import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/incoming_share_payload.dart';
import '../../core/utils/media_album.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'new_chat_screen.dart';

/// Limite alignée sur multer (50 Mo) côté backend.
const int _maxMediaBytes = 50 * 1024 * 1024;

/// Choisit une ou plusieurs conversations pour envoyer un contenu partagé
/// depuis une autre app (Galerie, Fichiers, navigateur…).
class ShareToConversationScreen extends StatefulWidget {
  const ShareToConversationScreen({super.key, required this.payload});

  final IncomingSharePayload payload;

  @override
  State<ShareToConversationScreen> createState() =>
      _ShareToConversationScreenState();
}

class _ShareToConversationScreenState extends State<ShareToConversationScreen> {
  final _searchController = TextEditingController();
  final _captionController = TextEditingController();
  final Set<int> _selectedIds = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.payload.text?.trim();
    if (preset != null &&
        preset.isNotEmpty &&
        widget.payload.hasMedia &&
        widget.payload.canSendAsAlbum) {
      // Le texte partagé avec des médias devient légende par défaut.
      _captionController.text = preset;
    }
  }

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
    final result = await _sendToConversations(
      chat,
      widget.payload,
      _selectedIds.toList(),
      caption: caption.isEmpty ? null : caption,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.hasSuccess && result.failed == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded == 1
                ? context.l10n.sharedContentSent
                : context.l10n.sharedContentSentTo(result.succeeded),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (result.hasSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.forwardedToRatio(
              result.succeeded,
              result.succeeded + result.failed,
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.unableToShareTheContent),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<ForwardResult> _sendToConversations(
    ChatProvider chat,
    IncomingSharePayload payload,
    List<int> conversationIDs, {
    String? caption,
  }) async {
    var succeeded = 0;
    var failed = 0;
    final errors = <String>[];

    for (final convId in conversationIDs) {
      try {
        await _sendPayload(chat, payload, convId, caption: caption);
        succeeded++;
      } catch (e) {
        failed++;
        errors.add(e.toString());
        debugPrint('[ShareToConv] envoi vers $convId échoué: $e');
      }
    }

    return ForwardResult(succeeded: succeeded, failed: failed, errors: errors);
  }

  Future<void> _sendPayload(
    ChatProvider chat,
    IncomingSharePayload payload,
    int conversationID, {
    String? caption,
  }) async {
    if (payload.isTextOnly) {
      await chat.repository.sendText(
        conversationID: conversationID,
        content: payload.text!.trim(),
      );
      return;
    }

    final media = payload.mediaItems;
    if (media.isEmpty) {
      throw StateError('empty payload');
    }

    _assertMediaSizes(media);

    final effectiveCaption = caption ??
        (media.length == 1 && payload.text?.trim().isNotEmpty == true
            ? payload.text!.trim()
            : null);

    if (payload.canSendAsAlbum) {
      final items = media
          .map(
            (m) => AlbumSendItem(
              file: m.file,
              type: m.type,
              mediaName: m.name,
              duration: m.duration,
            ),
          )
          .toList();
      await chat.repository.sendMediaAlbum(
        conversationID: conversationID,
        items: items,
        content: effectiveCaption,
      );
      return;
    }

    for (var i = 0; i < media.length; i++) {
      final m = media[i];
      final content = i == 0 ? effectiveCaption : null;
      await chat.repository.sendMediaFile(
        conversationID: conversationID,
        type: m.type,
        file: m.file,
        mediaName: m.name,
        mediaDuration: m.duration,
        content: content,
      );
    }

    if (payload.text?.trim().isNotEmpty == true &&
        media.length > 1 &&
        effectiveCaption == null) {
      await chat.repository.sendText(
        conversationID: conversationID,
        content: payload.text!.trim(),
      );
    }
  }

  void _assertMediaSizes(List<IncomingShareMediaItem> media) {
    for (final m in media) {
      if (!m.file.existsSync()) {
        throw StateError('missing file');
      }
      final size = m.file.lengthSync();
      if (size > _maxMediaBytes) {
        throw StateError('file too large');
      }
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
          SnackBar(content: Text(context.l10n.unableToCreateTheConversation)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.select<AuthProvider, int>(
      (a) => a.currentUser?.alanyaID ?? 0,
    );
    final chat = context.watch<ChatProvider>();
    final query = _searchController.text;
    final showCaption = widget.payload.hasMedia;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.shareToConversation),
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
                      border: const OutlineInputBorder(),
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
                        .where(
                          (c) => conversationMatchesSearch(c, myId, query),
                        )
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
                        final avatar = conversationDisplayAvatar(conv, myId);

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
    final payload = widget.payload;
    final primary = context.colors.primary;

    if (payload.isTextOnly) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.text_snippet_outlined, color: primary),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                payload.previewLabel(),
                style: context.text.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (payload.canSendAsAlbum && payload.mediaItems.isNotEmpty) {
      final first = payload.mediaItems.first;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            _mediaThumb(first, size: 56),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                payload.previewLabel(),
                style: context.text.titleSmall,
              ),
            ),
          ],
        ),
      );
    }

    if (payload.mediaItems.length == 1) {
      final m = payload.mediaItems.first;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            _mediaThumb(m, size: 72),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name ?? mediaLabelForType(m.type),
                    style: context.text.titleSmall,
                  ),
                  if (payload.text?.trim().isNotEmpty == true)
                    Text(
                      payload.text!.trim(),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.folder_copy_outlined, color: primary, size: 40),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              payload.previewLabel(),
              style: context.text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaThumb(IncomingShareMediaItem item, {required double size}) {
    if (item.type == 1 && item.file.existsSync()) {
      return ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Image.file(
          item.file,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    if (item.type == 2) {
      return _VideoThumb(file: item.file, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.brSm,
      ),
      child: Icon(
        item.type == 3 ? Icons.mic_outlined : Icons.insert_drive_file,
        color: context.colors.primary,
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.file, required this.size});

  final File file;
  final double size;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    return ClipRRect(
      borderRadius: AppRadius.brSm,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ctrl != null && ctrl.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: ctrl.value.size.width,
                  height: ctrl.value.size.height,
                  child: VideoPlayer(ctrl),
                ),
              )
            : ColoredBox(
                color: context.colors.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.videocam_outlined),
                ),
              ),
      ),
    );
  }
}
