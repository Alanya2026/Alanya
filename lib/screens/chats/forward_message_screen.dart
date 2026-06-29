import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/forward_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'new_chat_screen.dart';

class ForwardMessageScreen extends StatefulWidget {
  const ForwardMessageScreen({
    super.key,
    required this.message,
    this.excludeConversationId,
  });

  final LocalMessage message;
  final int? excludeConversationId;

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
    final result = await chat.forwardMessage(
      source: widget.message,
      targetConversationIDs: _selectedIds.toList(),
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
                ? 'Message transféré'
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
        const SnackBar(
          content: Text('Impossible de transférer le message'),
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
              if (widget.message.type != 0)
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
    final preview = previewTextForForward(widget.message);
    final isMedia = widget.message.type != 0;

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
              _previewIcon(widget.message.type),
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
}
