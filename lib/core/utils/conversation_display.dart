import '../../l10n/app_localizations.dart';
import '../db/app_database.dart';
import '../db/chat_dao.dart';
import '../services/chat/conversation_merge.dart';
import '../theme/locale_controller.dart';
import 'media_album.dart';

int conversationParticipantId(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

Map<String, dynamic>? otherParticipant(LocalConversation conv, int myId) {
  final parts = decodeParticipants(conv.participantsJson);
  for (final p in parts) {
    final id = conversationParticipantId(p['alanyaID']);
    if (myId != 0 && id != 0 && id != myId) return p;
  }
  return null;
}

String conversationDisplayName(LocalConversation conv, int myId) {
  if (conv.isGroup) return conv.groupName ?? LocaleController.instance.l10n.groupFallback;
  final other = otherParticipant(conv, myId);
  return (other?['nom'] as String?) ?? LocaleController.instance.l10n.unknownSender;
}

String? conversationDisplayAvatar(LocalConversation conv, int myId) {
  if (conv.isGroup) {
    return conv.groupPhoto?.isNotEmpty == true ? conv.groupPhoto : null;
  }
  final other = otherParticipant(conv, myId);
  final avatar = other?['avatar_url']?.toString();
  return avatar != null && avatar.isNotEmpty ? avatar : null;
}

int? conversationOtherUserId(LocalConversation conv, int myId) {
  final other = otherParticipant(conv, myId);
  if (other == null) return null;
  final id = conversationParticipantId(other['alanyaID']);
  return id == 0 ? null : id;
}

/// Retrouve l'ID d'une conversation 1-1 locale avec [peerUserId], ou null.
/// En cas de doublons (legacy backend), prend la plus récente.
int? findLocalDirectConversationId(
  Iterable<LocalConversation> convs,
  int myId,
  int peerUserId,
) {
  LocalConversation? best;
  for (final c in convs) {
    if (c.isGroup) continue;
    if (conversationOtherUserId(c, myId) != peerUserId) continue;
    if (best == null) {
      best = c;
      continue;
    }
    final bestAt = best.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final curAt = c.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (curAt.isAfter(bestAt) || (curAt == bestAt && c.conversID > best.conversID)) {
      best = c;
    }
  }
  return best?.conversID;
}

/// Toutes les conversations 1-1 locales avec [peerUserId] (doublons legacy).
List<int> findAllDirectConversationIds(
  Iterable<LocalConversation> convs,
  int myId,
  int peerUserId,
) {
  final ids = <int>[];
  for (final c in convs) {
    if (c.isGroup) continue;
    if (conversationOtherUserId(c, myId) == peerUserId) {
      ids.add(c.conversID);
    }
  }
  return ids;
}

bool conversationMatchesSearch(LocalConversation conv, int myId, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return conversationDisplayName(conv, myId).toLowerCase().contains(q);
}

/// Aperçu prêt pour l'UI / notifications : album + sentinelle supprimé → l10n.
///
/// Ne pas écrire le résultat en Drift (garder [ConversationMerge.deletedPreview]).
String displayConversationPreview(String? text, AppLocalizations l10n) {
  final normalized = normalizeConversationPreview(text);
  if (ConversationMerge.isDeletedPreview(normalized)) {
    return l10n.thisMessageWasDeleted;
  }
  return normalized;
}
