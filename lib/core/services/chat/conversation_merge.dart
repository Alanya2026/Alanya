import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../utils/media_album.dart';
import '../../../talky_models.dart';

/// Merge monotonic conversation list HTTP → cache local.
/// HTTP = catch-up ; jamais de downgrade d'aperçu / statut / unread optimiste.
class ConversationMerge {
  static const deletedPreview = 'Ce message a été supprimé';

  /// Garde le plus récent entre local et serveur ; protège pending optimistes.
  static LocalConversationsCompanion mergeConversation({
    required Conversation server,
    required LocalConversationsCompanion fromServer,
    required LocalConversation? local,
    required int myId,
    required bool hasLocalPendingNewer,
  }) {
    var companion = fromServer;

    if (local == null) return companion;

    // Ne jamais écraser un aperçu local plus récent (envoi optimiste en cours).
    // Préserve aussi unreadCount local (sinon le sync « ressuscite » un badge).
    if (hasLocalPendingNewer) {
      companion = companion.copyWith(
        lastMessage: Value(local.lastMessage),
        lastMessageAt: Value(local.lastMessageAt),
        lastMessageSenderID: Value(local.lastMessageSenderID),
        lastMessageType: Value(local.lastMessageType),
        lastMessageStatus: Value(local.lastMessageStatus),
        unreadCount: Value(local.unreadCount),
      );
      return _applyUnreadRules(
        companion: companion,
        local: local,
        server: server,
        myId: myId,
      );
    }

    final localAt = local.lastMessageAt;
    final serverAt = companion.lastMessageAt.present
        ? companion.lastMessageAt.value
        : null;

    if (localAt != null && serverAt != null && localAt.isAfter(serverAt)) {
      companion = companion.copyWith(
        lastMessage: Value(local.lastMessage),
        lastMessageAt: Value(local.lastMessageAt),
        lastMessageSenderID: Value(local.lastMessageSenderID),
        lastMessageType: Value(local.lastMessageType),
        lastMessageStatus: Value(local.lastMessageStatus),
      );
    } else if (myId != 0 &&
        server.lastMessageSenderID == myId &&
        local.lastMessageSenderID == myId) {
      final serverStatus = server.lastMessageStatus ?? 0;
      final localStatus = local.lastMessageStatus ?? 0;
      final merged = serverStatus > localStatus ? serverStatus : localStatus;
      if (merged != serverStatus) {
        companion = companion.copyWith(lastMessageStatus: Value(merged));
      }
    }

    final localLast = local.lastMessage;
    if (localLast == deletedPreview &&
        companion.lastMessage.present &&
        companion.lastMessage.value != deletedPreview) {
      companion = companion.copyWith(lastMessage: const Value(deletedPreview));
    }

    return _applyUnreadRules(
      companion: companion,
      local: local,
      server: server,
      myId: myId,
    );
  }

  /// Règles unread local-first :
  /// - dernier message = moi → unread = 0
  /// - local 0 et serveur > 0 sans message serveur plus récent → garder 0
  /// - sinon max(local, server)
  static LocalConversationsCompanion _applyUnreadRules({
    required LocalConversationsCompanion companion,
    required LocalConversation local,
    required Conversation server,
    required int myId,
  }) {
    final resolvedSender = companion.lastMessageSenderID.present
        ? companion.lastMessageSenderID.value
        : server.lastMessageSenderID;
    // Comparer les horodatages d'origine (pas ceux déjà fusionnés dans companion).
    final localAt = local.lastMessageAt;
    final serverAt = server.lastMessageAt != null
        ? DateTime.tryParse(server.lastMessageAt!)
        : null;

    final localUnread = local.unreadCount;
    final serverUnread = server.unreadCount;

    int unread;
    if (myId != 0 && resolvedSender == myId) {
      unread = 0;
    } else if (localUnread == 0 && serverUnread > 0) {
      final serverClearlyNewer = localAt != null &&
          serverAt != null &&
          serverAt.isAfter(localAt) &&
          server.lastMessageSenderID != myId;
      unread = serverClearlyNewer ? serverUnread : 0;
    } else {
      unread = localUnread > serverUnread ? localUnread : serverUnread;
    }

    return companion.copyWith(unreadCount: Value(unread));
  }

  static String previewForMedia(
    int type,
    String? content,
    String? mediaName, {
    bool isViewOnce = false,
  }) {
    if (!isViewOnce) {
      final marker = parseAlbumMarker(content);
      if (marker != null) return previewLabelForAlbumMarker(marker);
      if (content != null && content.trim().isNotEmpty) return content;
    }
    switch (type) {
      case 1:
        return isViewOnce ? '📷 Photo · Vue unique' : '📷 Photo';
      case 2:
        return isViewOnce ? '🎥 Vidéo · Vue unique' : '🎥 Vidéo';
      case 3:
        return isViewOnce ? '🎵 Audio · Vue unique' : '🎵 Audio';
      case 4:
        return mediaName?.isNotEmpty == true ? '📎 $mediaName' : '📎 Fichier';
      default:
        return mediaName ?? 'Média';
    }
  }
}
