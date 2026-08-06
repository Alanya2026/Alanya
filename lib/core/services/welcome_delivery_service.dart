import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/locale_controller.dart';
import '../../providers/chat_provider.dart';
import '../../screens/chats/chat_detail_screen.dart';
import '../../screens/chats/contact_detail_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../talky_api_client.dart';

/// Livraison du message de bienvenue ALANYA et navigation vers la conversation.
class WelcomeDeliveryService {
  WelcomeDeliveryService._();

  static Future<WelcomeDeliveryResult?> deliverAndOpenChat(
    BuildContext context, {
    bool openChat = true,
  }) async {
    try {
      final api = context.read<TalkyApiClient>();
      final locale = LocaleController.instance.locale?.languageCode ?? 'fr';
      final raw = await api.deliverWelcome(locale: locale);
      final result = WelcomeDeliveryResult.fromMap(raw);
      if (!context.mounted) return result;

      if (result.skipped && !result.alreadyDelivered) return result;

      await context.read<ChatProvider>().refreshConversations(force: true);
      if (!context.mounted) return result;

      if (openChat &&
          result.delivered &&
          result.conversationId != null &&
          result.conversationId! > 0 &&
          result.senderId != null &&
          result.senderId! > 0) {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                userName: result.senderName ?? 'Alanya',
                conversationId: result.conversationId,
                userId: result.senderId,
                avatarUrl: result.senderAvatar,
              ),
            ),
          ),
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('[WelcomeDelivery] échec: $e\n$st');
      return null;
    }
  }

  /// Navigation in-app depuis un bouton CTA de bienvenue.
  static void handleWelcomeRoute(
    BuildContext context,
    String route, {
    int? officialUserId,
  }) {
    final normalized = route.trim().toLowerCase();
    switch (normalized) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        return;
      case 'statuses':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 2)),
          (_) => false,
        );
        return;
      case 'help':
        if (officialUserId != null && officialUserId > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactDetailScreen(userId: officialUserId),
            ),
          );
        }
        return;
      default:
        return;
    }
  }
}

class WelcomeDeliveryResult {
  const WelcomeDeliveryResult({
    this.delivered = false,
    this.alreadyDelivered = false,
    this.skipped = false,
    this.conversationId,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.messageCount = 0,
  });

  final bool delivered;
  final bool alreadyDelivered;
  final bool skipped;
  final int? conversationId;
  final int? senderId;
  final String? senderName;
  final String? senderAvatar;
  final int messageCount;

  factory WelcomeDeliveryResult.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return WelcomeDeliveryResult(
      delivered: map['delivered'] == true,
      alreadyDelivered: map['alreadyDelivered'] == true,
      skipped: map['skipped'] == true,
      conversationId: parseInt(map['conversationId']),
      senderId: parseInt(map['senderId']),
      senderName: map['senderName']?.toString(),
      senderAvatar: map['senderAvatar']?.toString(),
      messageCount: parseInt(map['messageCount']) ?? 0,
    );
  }
}
