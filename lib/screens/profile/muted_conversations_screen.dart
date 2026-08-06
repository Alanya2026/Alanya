import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/common.dart';
import '../chats/chat_detail_screen.dart';

bool isConversationMuted(LocalConversation conv) {
  if (conv.muteForever) return true;
  final until = conv.mutedUntil;
  if (until == null) return false;
  return until.isAfter(DateTime.now());
}

/// Liste des conversations mises en silencieux.
class MutedConversationsScreen extends StatelessWidget {
  const MutedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final myId = context.watch<AuthProvider>().currentUser?.alanyaID ?? 0;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.mutedConversationsTitle)),
      body: StreamBuilder<List<LocalConversation>>(
        stream: context.read<ChatProvider>().watchConversations(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final muted = all.where(isConversationMuted).toList();

          if (snapshot.connectionState == ConnectionState.waiting &&
              muted.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (muted.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.screenH,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: context.colors.outline,
                    ),
                    AppSpacing.vGapMd,
                    Text(
                      l10n.mutedConversationsEmpty,
                      textAlign: TextAlign.center,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: muted.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: AppSpacing.xl + AppSizes.avatarMd + AppSpacing.md,
              color: context.colors.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final conv = muted[index];
              final name = conversationDisplayName(conv, myId);
              final avatar = conversationDisplayAvatar(conv, myId);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                leading: AppAvatar(
                  imageUrl: avatar,
                  name: name,
                  size: AppSizes.avatarMd,
                ),
                title: Text(name),
                subtitle: Text(
                  conv.muteForever
                      ? l10n.mutedForeverLabel
                      : l10n.mutedUntilLabel(
                          _formatUntil(context, conv.mutedUntil),
                        ),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.notifications_active_outlined),
                  tooltip: l10n.convUnmute,
                  onPressed: () => _unmute(context, conv.conversID, name),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      conversationId: conv.conversID,
                      userName: name,
                      avatarUrl: avatar,
                      isGroup: conv.isGroup,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatUntil(BuildContext context, DateTime? until) {
    if (until == null) return '—';
    final local = until.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _unmute(
    BuildContext context,
    int conversationId,
    String name,
  ) async {
    try {
      await context.read<TalkyApiClient>().updateConversationMute(
            conversationId,
            unmute: true,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.convUnmuteDone(name))),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.convMuteFailed)),
      );
    }
  }
}
