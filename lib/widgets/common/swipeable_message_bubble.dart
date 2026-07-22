import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'app_bottom_sheet.dart';

/// Bulle de message avec actions swipe (reply, copy, delete).
///
/// Désactiver via [enabled] en mode sélection ; [onLongPress] reste disponible.
class SwipeableMessageBubble extends StatelessWidget {
  const SwipeableMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.child,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    this.onLongPress,
    this.enabled = true,
  });

  final LocalMessage message;
  final bool isMe;
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final void Function({required bool forAll}) onDelete;
  final VoidCallback? onLongPress;
  final bool enabled;

  bool get _canCopy =>
      message.type == 0 &&
      message.content != null &&
      message.content!.isNotEmpty &&
      !message.isDeleted;

  void _hapticThen(VoidCallback action) {
    HapticFeedback.mediumImpact();
    action();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final muted = context.colors.onSurfaceVariant;
    final error = context.colors.error;

    await showAppBottomSheet<void>(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                onDelete(forAll: false);
              },
            ),
            if (isMe && !message.isDeleted)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  onDelete(forAll: true);
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
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
    final content = onLongPress == null
        ? child
        : GestureDetector(
            onLongPress: onLongPress,
            child: child,
          );

    if (!enabled) return content;

    final l10n = context.l10n;
    final colors = context.colors;

    return Slidable(
      key: ValueKey(
        message.msgID != 0 ? message.msgID : message.clientId,
      ),
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        // Swipe passé le seuil → répondre tout de suite (pas de second tap).
        dismissible: DismissiblePane(
          dismissThreshold: 0.4,
          closeOnCancel: true,
          confirmDismiss: () async {
            _hapticThen(onReply);
            return false;
          },
          onDismissed: () {},
        ),
        children: [
          CustomSlidableAction(
            onPressed: (_) => _hapticThen(onReply),
            backgroundColor: colors.surface,
            foregroundColor: colors.primary,
            padding: EdgeInsets.zero,
            child: Semantics(
              label: l10n.reply,
              button: true,
              child: Icon(Icons.reply, color: colors.primary, size: 28),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.25,
        children: [
          if (_canCopy)
            _action(
              label: l10n.copy,
              icon: Icons.copy,
              background: colors.onSurfaceVariant,
              foreground: colors.onPrimary,
              onPressed: onCopy,
            ),
          _action(
            label: l10n.deleteForMe,
            icon: Icons.delete,
            background: colors.error,
            foreground: colors.onError,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      // Slidable s'étire en pleine largeur pour le geste ; sans Align
      // interne, toutes les bulles se collent à gauche.
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}
