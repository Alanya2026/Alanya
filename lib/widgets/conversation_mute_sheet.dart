import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';

enum ConversationMuteChoice {
  eightHours,
  oneWeek,
  forever,
  unmute,
}

/// Bottom sheet pour mute / unmute une conversation.
Future<void> showConversationMuteSheet(
  BuildContext context, {
  required int conversationId,
  required String conversationName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ConversationMuteSheet(
      conversationId: conversationId,
      conversationName: conversationName,
    ),
  );
}

class _ConversationMuteSheet extends StatelessWidget {
  const _ConversationMuteSheet({
    required this.conversationId,
    required this.conversationName,
  });

  final int conversationId;
  final String conversationName;

  Future<void> _apply(BuildContext context, ConversationMuteChoice choice) async {
    final api = context.read<TalkyApiClient>();
    final l10n = context.l10n;
    Navigator.pop(context);
    try {
      switch (choice) {
        case ConversationMuteChoice.eightHours:
          await api.updateConversationMute(
            conversationId,
            mutedUntil: DateTime.now().add(const Duration(hours: 8)),
          );
          break;
        case ConversationMuteChoice.oneWeek:
          await api.updateConversationMute(
            conversationId,
            mutedUntil: DateTime.now().add(const Duration(days: 7)),
          );
          break;
        case ConversationMuteChoice.forever:
          await api.updateConversationMute(
            conversationId,
            muteForever: true,
          );
          break;
        case ConversationMuteChoice.unmute:
          await api.updateConversationMute(conversationId, unmute: true);
          break;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              choice == ConversationMuteChoice.unmute
                  ? l10n.convUnmuteDone(conversationName)
                  : l10n.convMuteDone(conversationName),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.convMuteFailed),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.convMuteTitle(conversationName),
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapMd,
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.convMute8h),
              onTap: () => _apply(context, ConversationMuteChoice.eightHours),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.convMute1w),
              onTap: () => _apply(context, ConversationMuteChoice.oneWeek),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.convMuteForever),
              onTap: () => _apply(context, ConversationMuteChoice.forever),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.convUnmute),
              onTap: () => _apply(context, ConversationMuteChoice.unmute),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile réutilisable dans fiche contact / groupe.
class ConversationMuteListTile extends StatelessWidget {
  const ConversationMuteListTile({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  final int conversationId;
  final String conversationName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.semantic.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.notifications_off_outlined,
          color: context.colors.onSurfaceVariant,
          size: AppIconSize.md,
        ),
      ),
      title: Text(
        context.l10n.convMuteAction,
        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        context.l10n.convMuteSubtitle,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: context.colors.outlineVariant,
      ),
      onTap: () => showConversationMuteSheet(
        context,
        conversationId: conversationId,
        conversationName: conversationName,
      ),
    );
  }
}
