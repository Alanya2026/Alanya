import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../../talky_models.dart';
import '../../utils/audio_message_kind.dart';
import '../../utils/contact_payload.dart';
import '../../utils/location_payload.dart';
import '../../utils/media_album.dart';
import '../../utils/system_event_payload.dart';
import '../../utils/welcome_cta_payload.dart';
import '../../theme/locale_controller.dart';

/// Merge monotonic conversation list HTTP → cache local.
///
/// HTTP = catch-up d'identité / meta (pin, archive, participants, aperçu
/// serveur initial). L'unread et l'aperçu définitifs sont dérivés ensuite par
/// [ConversationSummaryReducer] à partir des messages locaux.
class ConversationMerge {
  /// Sentinelle **interne** stockée en Drift (`lastMessage` / comparaisons).
  /// Ne jamais localiser à l'écriture : les lignes existantes et les merges
  /// comparent cette chaîne. Localiser uniquement à l'affichage via
  /// [displayConversationPreview] / `l10n.thisMessageWasDeleted`.
  static const deletedPreview = 'Ce message a été supprimé';

  /// Variante EN éventuellement déjà écrite (affichage / merge défensif).
  static const deletedPreviewEn = 'This message was deleted';

  /// True si [text] est une sentinelle « message supprimé » connue.
  static bool isDeletedPreview(String? text) =>
      text == deletedPreview || text == deletedPreviewEn;

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
    // Préserver l'aperçu « supprimé » local face à un catch-up HTTP qui
    // renverrait encore le contenu d'avant suppression.
    if (isDeletedPreview(localLast) &&
        companion.lastMessage.present &&
        !isDeletedPreview(companion.lastMessage.value)) {
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

  /// True si l'aperçu / unread / statut serveur diffère du cache local
  /// (nouvelle conv, ou catch-up HTTP qui a quelque chose à dire).
  static bool previewOrUnreadDiffers({
    required LocalConversation? local,
    required Conversation server,
    required DateTime? Function(dynamic) parseDate,
  }) {
    if (local == null) return true;
    if (local.unreadCount != server.unreadCount) return true;
    if (local.lastMessage != server.lastMessage) return true;
    if (local.lastMessageSenderID != server.lastMessageSenderID) return true;
    if (local.lastMessageType != server.lastMessageType) return true;
    if (local.lastMessageStatus != server.lastMessageStatus) return true;
    final serverAt = parseDate(server.lastMessageAt);
    final localAt = local.lastMessageAt;
    if (localAt == null && serverAt == null) return false;
    if (localAt == null || serverAt == null) return true;
    return localAt.toUtc().millisecondsSinceEpoch !=
        serverAt.toUtc().millisecondsSinceEpoch;
  }

  /// Serveur a un aperçu strictement plus récent que le local (pas de pending).
  /// Dans ce cas le recompute pré-delta écraserait l'aperçu serveur avec un
  /// message local plus vieux — on attend le delta messages.
  static bool serverPreviewAhead({
    required LocalConversation? local,
    required DateTime? serverAt,
    required bool hasLocalPendingNewer,
  }) {
    if (hasLocalPendingNewer || local == null) return false;
    final localAt = local.lastMessageAt;
    if (localAt == null || serverAt == null) return false;
    return serverAt.isAfter(localAt);
  }

  static String previewForMedia(
    int type,
    String? content,
    String? mediaName, {
    bool isViewOnce = false,
  }) {
    // type=5 : JSON lat/lng — ne jamais exposer le content brut.
    if (type == 5) return locationPreviewLabel(content);
    // type=6 : JSON événement de groupe — ne jamais exposer le content brut.
    if (type == kSystemMessageType) {
      final payload = SystemEventPayload.tryParse(content);
      if (payload != null) {
        return payload.previewLabel(resolveL10n());
      }
      return resolveL10n().sysGroupEventFallback;
    }
    // type=7 : JSON contact — ne jamais exposer le content brut.
    if (type == 7) return contactPreviewLabel(content);
    if (type == kWelcomeCtaMessageType) {
      final cta = WelcomeCtaPayload.tryParse(content);
      if (cta != null && cta.buttons.isNotEmpty) {
        return cta.buttons.map((b) => b.label).join(' · ');
      }
      return '';
    }

    if (!isViewOnce) {
      final marker = parseAlbumMarker(content);
      if (marker != null) return previewLabelForAlbumMarker(marker);
      if (content != null && content.trim().isNotEmpty) return content;
    }
    switch (type) {
      case 1:
        return isViewOnce ? LocaleController.instance.l10n.photoViewOnce : LocaleController.instance.l10n.photo;
      case 2:
        return isViewOnce ? LocaleController.instance.l10n.videoViewOnce : LocaleController.instance.l10n.video;
      case 3:
        if (isViewOnce) return LocaleController.instance.l10n.audioViewOnce;
        // Vocal et musique partagent le type 3 : cf. audio_message_kind.dart.
        if (audioKindFromName(mediaName) == AudioMessageKind.music) {
          return LocaleController.instance.l10n.musicPreview(
            musicTitleFromName(mediaName,
                fallback: LocaleController.instance.l10n.music),
          );
        }
        return LocaleController.instance.l10n.audio;
      case 4:
        return mediaName?.isNotEmpty == true ? LocaleController.instance.l10n.fileWithName(mediaName!) : LocaleController.instance.l10n.file;
      default:
        return mediaName ?? LocaleController.instance.l10n.mediaFallback;
    }
  }
}
