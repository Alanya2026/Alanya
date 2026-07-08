import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/media_album.dart';
import 'notification_navigation.dart';

const _kChannelMessages = AndroidNotificationChannel(
  'talky_messages',
  'Messages',
  importance: Importance.high,
);
const _kChannelMeetings = AndroidNotificationChannel(
  'talky_meetings',
  'Réunions',
  description: 'Invitations et rappels de réunion',
  importance: Importance.max,
);

const String kPushActiveConvKey = 'push_active_conv_id';
const String kNotifActiveConvsKey = 'notif_active_conv_ids';
const int kMeetingNotifOffset = 1000000000;
const int kSummaryNotifId = 0;
const int kMaxBufferedMessages = 7;

/// Helper partagé foreground / background pour les notifications locales.
class LocalNotificationHelper {
  LocalNotificationHelper._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized({
    void Function(NotificationResponse)? onTap,
  }) async {
    if (kIsWeb) return;
    if (_initialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onTap,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_kChannelMessages);
    await android?.createNotificationChannel(_kChannelMeetings);

    _initialized = true;
  }

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  // ── Conversation active (suppression) ─────────────────────────────────

  static Future<int?> getActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(kPushActiveConvKey);
    if (id == null || id == 0) return null;
    return id;
  }

  static Future<void> setActiveConversationId(int? conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    if (conversationId == null || conversationId == 0) {
      await prefs.remove(kPushActiveConvKey);
    } else {
      await prefs.setInt(kPushActiveConvKey, conversationId);
    }
  }

  static Future<bool> shouldSuppressMessage(int conversationId) async {
    final active = await getActiveConversationId();
    return active != null && active == conversationId;
  }

  // ── Affichage messages ───────────────────────────────────────────────

  static Future<void> showMessageNotification(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    bool suppressIfActive = true,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final conversationId =
        int.tryParse(data['conversationId']?.toString() ?? '') ?? 0;
    if (conversationId == 0) return;

    if (suppressIfActive && await shouldSuppressMessage(conversationId)) return;

    final senderName = title ?? data['title']?.toString() ?? 'Alanya';
    final messageBody = body ?? bodyFromPayload(data);
    if (messageBody.isEmpty && senderName.isEmpty) return;

    final isGroup = data['isGroup'] == '1' || data['isGroup'] == true;
    final groupName = data['groupName']?.toString() ?? '';

    final buffer = await _appendToBuffer(
      conversationId,
      sender: senderName,
      body: messageBody,
    );
    await _trackActiveConversation(conversationId);

    final payload = encodeNotificationPayload(data);
    final groupKey = 'talky_conv_$conversationId';
    final threadId = 'conv_$conversationId';

    final style = _buildMessagingStyle(
      messages: buffer,
      isGroup: isGroup,
      groupName: groupName,
      latestSender: senderName,
    );

    final displayTitle = isGroup && groupName.isNotEmpty
        ? groupName
        : senderName;
    final displayBody = isGroup ? '$senderName: $messageBody' : messageBody;

    final androidDetails = AndroidNotificationDetails(
      _kChannelMessages.id,
      _kChannelMessages.name,
      channelDescription: _kChannelMessages.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: groupKey,
      styleInformation: style,
    );

    try {
      await _plugin.show(
        conversationId,
        displayTitle,
        displayBody,
        NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            threadIdentifier: threadId,
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            subtitle: isGroup ? senderName : null,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // MessagingStyle peut échouer sur certains appareils en background.
      await _plugin.show(
        conversationId,
        displayTitle,
        displayBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelMessages.id,
            _kChannelMessages.name,
            channelDescription: _kChannelMessages.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            groupKey: groupKey,
            styleInformation: BigTextStyleInformation(displayBody),
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: threadId,
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    }

    await _updateSummaryNotification();
  }

  // ── Affichage réunions ───────────────────────────────────────────────

  static Future<void> showMeetingNotification(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final type = data['type']?.toString() ?? '';
    final meetingId = int.tryParse(data['meetingId']?.toString() ?? '') ?? 0;
    final title = data['title']?.toString() ?? 'Réunion';
    final body = data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final isReminder = type == 'meeting_reminder';
    final notifId =
        meetingId > 0 ? kMeetingNotifOffset + meetingId : meetingId;
    final payload = encodeNotificationPayload(data);

    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelMeetings.id,
          _kChannelMeetings.name,
          channelDescription: _kChannelMeetings.description,
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF3F51B5),
          icon: '@mipmap/ic_launcher',
          groupKey: 'talky_meetings',
          styleInformation:
              body.isNotEmpty ? BigTextStyleInformation(body) : null,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier:
              meetingId > 0 ? 'meeting_$meetingId' : 'talky_meetings',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isReminder
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }

  // ── Affichage générique (statuts, etc.) ──────────────────────────────

  static Future<void> showGenericNotification(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final notifTitle = title ?? data['title']?.toString() ?? 'Alanya';
    final notifBody = body ?? data['body']?.toString() ?? '';
    if (notifTitle.isEmpty && notifBody.isEmpty) return;

    final payload = encodeNotificationPayload(data);
    final type = data['type']?.toString() ?? '';
    final stableId = type.hashCode.abs() % 100000;

    await _plugin.show(
      stableId,
      notifTitle,
      notifBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelMessages.id,
          _kChannelMessages.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: notifBody.isNotEmpty
              ? BigTextStyleInformation(notifBody)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: type.isNotEmpty ? type : 'talky_generic',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ── Annulation ───────────────────────────────────────────────────────

  static Future<void> cancelConversation(int conversationId) async {
    if (kIsWeb || conversationId == 0) return;
    await _plugin.cancel(conversationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bufferKey(conversationId));
    await _untrackActiveConversation(conversationId);
    await _updateSummaryNotification();
  }

  static Future<void> cancelMeeting(int meetingId) async {
    if (kIsWeb || meetingId == 0) return;
    await _plugin.cancel(kMeetingNotifOffset + meetingId);
  }

  // ── Corps de notif ───────────────────────────────────────────────────

  static String bodyFromPayload(Map<String, dynamic> data) {
    final raw = data['body']?.toString();
    final normalized = normalizeConversationPreview(
      raw != null && raw.isNotEmpty ? raw : null,
    );
    if (normalized.isNotEmpty) return normalized;

    final type = int.tryParse(data['msgType']?.toString() ?? '') ?? 0;
    switch (type) {
      case 1:
        return '📷 Photo';
      case 2:
        return '🎥 Vidéo';
      case 3:
        return '🎵 Audio';
      case 4:
        return '📎 Fichier';
      default:
        return 'Nouveau message';
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  static String _bufferKey(int conversationId) => 'notif_msgs_$conversationId';

  static Future<List<Map<String, String>>> _appendToBuffer(
    int conversationId, {
    required String sender,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bufferKey(conversationId);
    final existing = prefs.getString(key);
    List<Map<String, String>> messages;
    if (existing != null) {
      try {
        final decoded = jsonDecode(existing) as List;
        messages = decoded
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      } catch (_) {
        messages = [];
      }
    } else {
      messages = [];
    }

    messages.add({
      'sender': sender,
      'body': body,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    if (messages.length > kMaxBufferedMessages) {
      messages = messages.sublist(messages.length - kMaxBufferedMessages);
    }
    await prefs.setString(key, jsonEncode(messages));
    return messages;
  }

  static MessagingStyleInformation _buildMessagingStyle({
    required List<Map<String, String>> messages,
    required bool isGroup,
    required String groupName,
    required String latestSender,
  }) {
    final styleMessages = messages.map((m) {
      final ts = DateTime.tryParse(m['ts'] ?? '') ?? DateTime.now();
      final sender = (m['sender'] ?? '').trim();
      return Message(
        m['body'] ?? '',
        ts,
        Person(name: sender.isNotEmpty ? sender : 'Alanya'),
      );
    }).toList();

    final personName = latestSender.trim().isNotEmpty ? latestSender : 'Alanya';
    return MessagingStyleInformation(
      Person(name: personName),
      conversationTitle: isGroup && groupName.isNotEmpty ? groupName : null,
      groupConversation: isGroup,
      messages: styleMessages,
    );
  }

  static Future<void> _trackActiveConversation(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadActiveConversationIds(prefs);
    if (!ids.contains(conversationId)) {
      ids.add(conversationId);
      await prefs.setStringList(
        kNotifActiveConvsKey,
        ids.map((e) => e.toString()).toList(),
      );
    }
  }

  static Future<void> _untrackActiveConversation(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadActiveConversationIds(prefs);
    ids.remove(conversationId);
    if (ids.isEmpty) {
      await prefs.remove(kNotifActiveConvsKey);
    } else {
      await prefs.setStringList(
        kNotifActiveConvsKey,
        ids.map((e) => e.toString()).toList(),
      );
    }
  }

  static Future<List<int>> _loadActiveConversationIds(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getStringList(kNotifActiveConvsKey) ?? [];
    return raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  static Future<void> _updateSummaryNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadActiveConversationIds(prefs);
    if (ids.length < 2) {
      await _plugin.cancel(kSummaryNotifId);
      return;
    }

    await _plugin.show(
      kSummaryNotifId,
      'Alanya',
      '${ids.length} conversations',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'talky_messages',
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          groupKey: 'talky_messages',
          setAsGroupSummary: true,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'talky_summary',
          presentAlert: true,
          presentBadge: true,
        ),
      ),
    );
  }
}
