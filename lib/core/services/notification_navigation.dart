import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../theme/app_theme.dart';
import '../utils/conversation_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/status_provider.dart';
import '../../screens/chats/chat_detail_screen.dart';
import '../../screens/status/status_viewer_screen.dart';

/// Action de navigation déclenchée par un tap (ou réception foreground) de notification.
class NotificationAction {
  final String type;
  final Map<String, String> data;
  final bool fromTap;

  const NotificationAction({
    required this.type,
    required this.data,
    this.fromTap = true,
  });

  factory NotificationAction.fromMap(
    Map<String, dynamic> raw, {
    bool fromTap = true,
  }) {
    return NotificationAction(
      type: raw['type']?.toString() ?? '',
      data: raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      fromTap: fromTap,
    );
  }
}

String encodeNotificationPayload(Map<String, dynamic> data) => jsonEncode(data);

NotificationAction? decodeNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    return NotificationAction.fromMap(map);
  } catch (_) {
    // Ancien format pipe pour les réunions : type|meetingId|title|organiser|time
    final parts = payload.split('|');
    if (parts.length >= 4) {
      return NotificationAction.fromMap({
        'type': parts[0],
        'meetingId': parts[1],
        'meetingTitle': parts[2],
        'organiserName': parts[3],
        if (parts.length > 4) 'meetingTime': parts[4],
      });
    }
    return null;
  }
}

/// Résout une conversation et ouvre [ChatDetailScreen].
class NotificationNavigation {
  NotificationNavigation._();

  static Future<void> openConversation(
    BuildContext context,
    Map<String, String> data,
  ) async {
    final conversationId = int.tryParse(data['conversationId'] ?? '') ?? 0;
    if (conversationId == 0) return;

    final chat = context.read<ChatProvider>();
    final myId = context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
    final fallbackName = data['title'] ?? context.l10n.discussionFallback;
    final fallbackUserId = int.tryParse(data['callerId'] ?? '');
    final isGroupFromPayload =
        data['isGroup'] == '1' || data['isGroup'] == 'true';
    final groupNameFromPayload = data['groupName'] ?? '';

    var conv = await _findConversation(chat, conversationId);
    if (!context.mounted) return;
    if (conv == null) {
      final displayName = isGroupFromPayload &&
              groupNameFromPayload.isNotEmpty
          ? groupNameFromPayload
          : fallbackName;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: displayName,
            conversationId: conversationId,
            userId: fallbackUserId,
            isGroup: isGroupFromPayload,
          ),
        ),
      );
      return;
    }

    final displayName = _displayName(context, conv, myId, fallbackName);
    // conversationCounterpartId renvoie mon propre id pour une conversation
    // avec soi-même — c'est ce qui permet à ChatDetailScreen de la reconnaître.
    final counterpartId = conversationCounterpartId(conv, myId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: displayName,
          conversationId: conv.conversID,
          userId: counterpartId ?? fallbackUserId,
          isGroup: conv.isGroup,
          avatarUrl: conversationDisplayAvatar(conv, myId),
        ),
      ),
    );
  }

  static Future<LocalConversation?> _findConversation(
    ChatProvider chat,
    int conversationId,
  ) async {
    var conv =
        await chat.repository.dao.watchConversation(conversationId).first;
    if (conv != null) return conv;
    await chat.refreshConversations(force: true);
    return chat.repository.dao.watchConversation(conversationId).first;
  }

  /// Nom d'affichage, avec repli sur le nom porté par la notification.
  ///
  /// Se distingue de [conversationDisplayName] par ce repli : quand la conv
  /// locale ne connaît pas encore l'autre participant, la charge utile de la
  /// notification est une meilleure source que « Inconnu ».
  static String _displayName(
    BuildContext context,
    LocalConversation conv,
    int myId,
    String fallback,
  ) {
    if (conv.isGroup) {
      return conv.groupName?.isNotEmpty == true
          ? conv.groupName!
          : context.l10n.groupFallback;
    }
    if (isSelfConversation(conv, myId)) {
      return conversationDisplayName(conv, myId);
    }
    // Le serveur envoie `nom` (et non `username`) : cette clé-là ne matchait
    // jamais, le repli s'appliquait donc systématiquement.
    final name = otherParticipant(conv, myId)?['nom']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }

  /// Ouvre la cible d'une diffusion officielle (message privé ou statut 24 h).
  static Future<void> openBroadcast(
    BuildContext context,
    Map<String, String> data, {
    required VoidCallback switchToStatusesTab,
  }) async {
    final kind = int.tryParse(data['kind'] ?? '') ?? 0;
    if (kind == 1) {
      switchToStatusesTab();
      await _openBroadcastStatus(context, data);
      return;
    }
    await _openBroadcastMessage(context, data);
  }

  static Future<void> _openBroadcastMessage(
    BuildContext context,
    Map<String, String> data,
  ) async {
    final senderId = int.tryParse(data['senderId'] ?? '') ?? 0;
    if (senderId == 0) return;

    final chat = context.read<ChatProvider>();
    final myId = context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
    final fallbackName = data['title'] ?? context.l10n.discussionFallback;

    await chat.refreshConversations(force: true);
    if (!context.mounted) return;

    final convs = await chat.repository.dao.getAllConversations();
    final convId = findLocalDirectConversationId(convs, myId, senderId);

    LocalConversation? conv;
    if (convId != null) {
      conv = await chat.repository.dao.watchConversation(convId).first;
    }

    if (!context.mounted) return;

    if (conv != null) {
      final resolved = conv;
      final displayName = _displayName(context, resolved, myId, fallbackName);
      final counterpartId = conversationCounterpartId(resolved, myId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: displayName,
            conversationId: resolved.conversID,
            userId: counterpartId ?? senderId,
            isGroup: resolved.isGroup,
            avatarUrl: conversationDisplayAvatar(resolved, myId),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: fallbackName,
          userId: senderId,
          isGroup: false,
        ),
      ),
    );
  }

  static Future<void> _openBroadcastStatus(
    BuildContext context,
    Map<String, String> data,
  ) async {
    final senderId = int.tryParse(data['senderId'] ?? '') ?? 0;
    final status = context.read<StatusProvider>();
    await status.refresh();
    if (!context.mounted) return;

    if (senderId <= 0) return;

    final statuses = status.byAuthor[senderId];
    if (statuses == null || statuses.isEmpty) return;

    final firstUnseen = statuses.indexWhere((s) => !s.seenByMe);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          contactGroups: [statuses],
          startContactIndex: 0,
          startItemIndex: firstUnseen >= 0 ? firstUnseen : 0,
          isMine: false,
        ),
      ),
    );
  }
}
