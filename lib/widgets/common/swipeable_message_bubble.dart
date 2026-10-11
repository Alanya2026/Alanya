import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';

/// Bulle de message : glisser vers la droite pour répondre.
///
/// Copier et supprimer sont dans le menu d'appui long ([onLongPress]).
///
/// Désactiver via [enabled] en mode sélection ; [onLongPress] reste disponible.
class SwipeableMessageBubble extends StatelessWidget {
  const SwipeableMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.child,
    required this.onReply,
    this.onLongPress,
    this.enabled = true,
  });

  final LocalMessage message;
  final bool isMe;
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;
  final bool enabled;

  void _hapticThen(VoidCallback action) {
    HapticFeedback.mediumImpact();
    action();
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
            backgroundColor: Colors.transparent,
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
      // Pas de volet à droite (copier, supprimer) : un défilement un peu
      // oblique l'ouvrait, et la bulle restait décalée sur le côté pendant
      // qu'on remontait l'historique (groupe 3GI 2029, bug A16). Ces actions
      // restent dans le menu d'appui long.
      // Slidable s'étire en pleine largeur pour le geste ; sans Align
      // interne, toutes les bulles se collent à gauche.
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}
