import '../../l10n/app_localizations.dart';
import '../db/app_database.dart';
import '../db/chat_dao.dart';
import '../services/chat/conversation_merge.dart';
import '../theme/locale_controller.dart';
import 'media_album.dart';
import 'self_chat.dart';

export 'self_chat.dart' show kSelfChatMarker;

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

/// Le participant « moi » d'une conversation avec soi-même, ou null.
Map<String, dynamic>? selfParticipant(LocalConversation conv, int myId) {
  if (myId == 0) return null;
  for (final p in decodeParticipants(conv.participantsJson)) {
    if (conversationParticipantId(p['alanyaID']) == myId) return p;
  }
  return null;
}

/// Conversation « message à soi-même ».
///
/// S'appuie sur le marqueur serveur, jamais sur « 1-1 sans autre participant » :
/// une conv 1-1 dont le pair a supprimé son côté — ou dont le compte a été
/// supprimé — a exactement la même forme sans en être une. Le contrôle sur
/// [myId] protège d'une ligne héritée d'un autre compte.
bool isSelfConversation(LocalConversation conv, int myId) {
  if (conv.isGroup || myId == 0) return false;
  if (conv.groupName != kSelfChatMarker) return false;
  final parts = decodeParticipants(conv.participantsJson);
  if (parts.isEmpty) return true; // payload serveur tronqué
  return parts.any((p) => conversationParticipantId(p['alanyaID']) == myId);
}

String conversationDisplayName(LocalConversation conv, int myId) {
  final l10n = resolveL10n();
  if (conv.isGroup) return conv.groupName ?? l10n.groupFallback;
  if (isSelfConversation(conv, myId)) {
    final name = (selfParticipant(conv, myId)?['nom'] as String?)?.trim();
    return l10n.selfChatTitle(
      name != null && name.isNotEmpty ? name : l10n.meLabel,
    );
  }
  final other = otherParticipant(conv, myId);
  return (other?['nom'] as String?) ?? l10n.unknownSender;
}

String? conversationDisplayAvatar(LocalConversation conv, int myId) {
  if (conv.isGroup) {
    return conv.groupPhoto?.isNotEmpty == true ? conv.groupPhoto : null;
  }
  final source = isSelfConversation(conv, myId)
      ? selfParticipant(conv, myId)
      : otherParticipant(conv, myId);
  final avatar = source?['avatar_url']?.toString();
  return avatar != null && avatar.isNotEmpty ? avatar : null;
}

/// L'AUTRE personne d'une conversation 1-1 — donc null pour un self-chat.
///
/// Plusieurs écrans s'appuient sur ce null pour désactiver présence, anneau de
/// statut et profil du pair. Pour « avec qui cette conversation est-elle ? »,
/// utiliser [conversationCounterpartId].
int? conversationOtherUserId(LocalConversation conv, int myId) {
  final other = otherParticipant(conv, myId);
  if (other == null) return null;
  final id = conversationParticipantId(other['alanyaID']);
  return id == 0 ? null : id;
}

/// Interlocuteur d'une conversation 1-1 : moi-même pour un self-chat.
int? conversationCounterpartId(LocalConversation conv, int myId) {
  if (conv.isGroup) return null;
  if (isSelfConversation(conv, myId)) return myId == 0 ? null : myId;
  return conversationOtherUserId(conv, myId);
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
    if (conversationCounterpartId(c, myId) != peerUserId) continue;
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
