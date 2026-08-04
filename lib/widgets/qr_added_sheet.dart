import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/chat/message_sound_service.dart';
import '../core/utils/app_log.dart';
import '../core/utils/conversation_display.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../screens/chats/chat_detail_screen.dart';
import '../screens/chats/contact_detail_screen.dart';
import '../talky_models.dart';
import 'qr_scan_result_card.dart';

/// Confirmation d'un ajout de contact venu d'un lien `…/q/u/<jeton>`.
///
/// Le scanner affiche déjà [QrScanResultCard] par-dessus sa caméra ; on
/// présente ici la même carte en feuille modale. Scanner et lien doivent
/// aboutir au même écran, sinon l'ajout par lien passerait pour un chemin de
/// seconde zone — c'est exactement ce que réclame l'en-tête de `QrContactFlow`.
///
/// Un bandeau ne suffisait pas : l'utilisateur revient d'un navigateur, donc
/// d'un autre contexte, et il a besoin de voir QUI a été ajouté — le visage,
/// pas une ligne de texte qui s'efface en cinq secondes.
Future<void> showQrAddedSheet({
  required BuildContext context,
  required User user,
  required bool alreadyContact,
  required VoidCallback onUndo,
  Future<bool> Function(String note)? onNote,
}) {
  // Même accusé sonore et haptique qu'un scan réussi. Coupé automatiquement
  // en mode silencieux par le canal notification.
  if (!alreadyContact) {
    MessageSoundService.instance.playQrScanSuccess();
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // L'ajout est déjà fait : rien n'oblige l'utilisateur à répondre, il doit
    // pouvoir refermer d'un geste n'importe où.
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) {
      final nav = Navigator.of(sheetContext);

      void fermer() {
        if (nav.canPop()) nav.pop();
      }

      return SafeArea(
        child: QrScanResultCard(
          user: user,
          alreadyContact: alreadyContact,
          // Aucune disparition automatique : la carte est ici le seul contenu
          // à l'écran, s'évanouir toute seule passerait pour un bug.
          duree: null,
          onMessage: () {
            fermer();
            unawaited(_ouvrirConversation(context, user));
          },
          onDetails: () {
            fermer();
            _ouvrirFiche(context, user);
          },
          onNote: onNote,
        onUndo: () {
            fermer();
            onUndo();
          },
          onDismissed: fermer,
        ),
      );
    },
  );
}

Future<void> _ouvrirConversation(BuildContext context, User user) async {
  final convId = await conversationDirecteLocale(context, user.alanyaID);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatDetailScreen(
        userName: user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo,
        conversationId: convId,
        userId: user.alanyaID,
        avatarUrl: user.avatarUrl,
      ),
    ),
  );
}

void _ouvrirFiche(BuildContext context, User user) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ContactDetailScreen(
        userId: user.alanyaID,
        initialName:
            user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo,
        initialAvatar: user.avatarUrl,
      ),
    ),
  );
}

/// Conversation directe déjà connue localement avec [peerId], s'il y en a une.
///
/// Sans elle l'écran de conversation s'ouvrirait vide alors que l'historique
/// existe. Partagée entre le scanner et la feuille d'ajout par lien : les deux
/// mènent au même bouton « Message » et doivent atterrir au même endroit.
Future<int?> conversationDirecteLocale(BuildContext context, int peerId) async {
  try {
    final myId = context.read<AuthProvider>().currentUser?.alanyaID;
    if (myId == null) return null;
    final convs =
        await context.read<ChatProvider>().repository.dao.getAllConversations();
    return findLocalDirectConversationId(convs, myId, peerId);
  } catch (e, st) {
    AppLog.w('QrAdded', 'Résolution de la conversation échouée', e, st);
    return null;
  }
}
