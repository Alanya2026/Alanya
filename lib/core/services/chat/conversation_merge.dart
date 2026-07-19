import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../../talky_models.dart';
import '../../utils/contact_payload.dart';
import '../../utils/location_payload.dart';
import '../../utils/media_album.dart';

/// Merge monotonic conversation list HTTP → cache local.
///
/// HTTP = catch-up d'identité / meta (pin, archive, participants, aperçu
/// serveur initial). L'unread et l'aperçu définitifs sont dérivés ensuite par
/// [ConversationSummaryReducer] à partir des messages locaux.
class ConversationMerge {
  static const deletedPreview = 'Ce message a été supprimé';

  /// Garde le plus récent entre local et serveur ; protège pending optimistes.
  /// Ne touche plus aux règles unread ad-hoc (source unique = reducer).
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
    if (hasLocalPendingNewer) {
      return companion.copyWith(
        lastMessage: Value(local.lastMessage),
        lastMessageAt: Value(local.lastMessageAt),
        lastMessageSenderID: Value(local.lastMessageSenderID),
        lastMessageType: Value(local.lastMessageType),
        lastMessageStatus: Value(local.lastMessageStatus),
        // Unread : conserver local jusqu'au recompute (messages = vérité).
        unreadCount: Value(local.unreadCount),
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
        unreadCount: Value(local.unreadCount),
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

    // Si on a déjà des messages locaux, le unread serveur n'est qu'un hint :
    // le reducer le recalculera. On préserve le local pour éviter un flash.
    final hasLocalPreview = local.lastMessageAt != null;
    if (hasLocalPreview) {
      companion = companion.copyWith(unreadCount: Value(local.unreadCount));
    }

    return companion;
  }

  static String previewForMedia(
    int type,
    String? content,
    String? mediaName, {
    bool isViewOnce = false,
  }) {
    // type=5 : JSON lat/lng — ne jamais exposer le content brut.
    if (type == 5) return locationPreviewLabel(content);
    // type=7 : JSON contact — ne jamais exposer le content brut.
    if (type == 7) return contactPreviewLabel(content);

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
