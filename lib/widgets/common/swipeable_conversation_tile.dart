import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';

/// Tuile de conversation avec actions swipe (archive, pin, delete, mark read).
///
/// Désactiver via [enabled] en mode sélection pour préserver long-press / tap.
class SwipeableConversationTile extends StatelessWidget {
  const SwipeableConversationTile({
    super.key,
    required this.conversation,
    required this.child,
    required this.onArchive,
    required this.onPin,
    required this.onDelete,
    required this.onMarkRead,
    this.enabled = true,
  });

  final LocalConversation conversation;
  final Widget child;
  final VoidCallback onArchive;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;
  final bool enabled;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConversation),
        content: Text(l10n.thisActionCannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: Text(l10n.deleteConversation2),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  void _hapticThen(VoidCallback action) {
    HapticFeedback.mediumImpact();
    action();
  }

  Widget _action({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return CustomSlidableAction(
      onPressed: (_) => _hapticThen(onPressed),
      backgroundColor: background,
      foregroundColor: foreground,
      padding: EdgeInsets.zero,
      child: Semantics(
        label: label,
        button: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: foreground, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final l10n = context.l10n;
    final semantic = context.semantic;
    final colors = context.colors;
    final archived = conversation.isArchived;
    final pinned = conversation.isPinned;
    final hasUnread = conversation.unreadCount > 0;

    final archiveLabel = archived ? l10n.unarchive : l10n.archiveAction;
    final pinLabel = pinned ? l10n.unpin2 : l10n.pin;

    return Slidable(
      key: ValueKey(conversation.conversID),
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          _action(
            label: archiveLabel,
            icon: archived ? Icons.unarchive : Icons.archive,
            background: semantic.info,
            foreground: semantic.onInfo,
            onPressed: onArchive,
          ),
          _action(
            label: pinLabel,
            icon: Icons.push_pin,
            background: semantic.success,
            foreground: semantic.onSuccess,
            onPressed: onPin,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          _action(
            label: l10n.deleteConversation2,
            icon: Icons.delete,
            background: colors.error,
            foreground: colors.onError,
            onPressed: () => _confirmDelete(context),
          ),
          if (hasUnread)
            _action(
              label: l10n.markAsRead,
              icon: Icons.done_all,
              background: semantic.warning,
              foreground: semantic.onWarning,
              onPressed: onMarkRead,
            ),
        ],
      ),
      child: child,
    );
  }
}
