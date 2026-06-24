import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_database.dart';
import '../db/chat_dao.dart' show decodeParticipants;
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../screens/chats/chat_detail_screen.dart';

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
    final fallbackName = data['title'] ?? 'Discussion';
    final fallbackUserId = int.tryParse(data['callerId'] ?? '');

    var conv = await _findConversation(chat, conversationId);
    if (conv == null) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: fallbackName,
            conversationId: conversationId,
            userId: fallbackUserId,
            isGroup: false,
          ),
        ),
      );
      return;
    }

    final other = _otherParticipant(conv, myId);
    final displayName = _displayName(conv, myId, fallbackName);
    final displayAvatar =
        conv.isGroup ? conv.groupPhoto : other?['avatar_url'] as String?;
    final otherId = _toInt(other?['alanyaID']);

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: displayName,
          conversationId: conv.conversID,
          userId: otherId != 0 ? otherId : fallbackUserId,
          isGroup: conv.isGroup,
          avatarUrl: displayAvatar,
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
    await chat.refreshConversations();
    return chat.repository.dao.watchConversation(conversationId).first;
  }

  static Map<String, dynamic>? _otherParticipant(
    LocalConversation conv,
    int myId,
  ) {
    final parts = decodeParticipants(conv.participantsJson);
    for (final p in parts) {
      final id = _toInt(p['alanyaID']);
      if (myId != 0 && id != 0 && id != myId) return p;
    }
    return null;
  }

  static String _displayName(
    LocalConversation conv,
    int myId,
    String fallback,
  ) {
    if (conv.isGroup) {
      return conv.groupName?.isNotEmpty == true ? conv.groupName! : 'Groupe';
    }
    final other = _otherParticipant(conv, myId);
    final name = other?['username']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
