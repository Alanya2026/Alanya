import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/conversation_display.dart';
import 'notification_navigation.dart';
import 'notifications/notification_dedup_store.dart';
import 'notifications/notification_diagnostics.dart';
import 'notifications/notification_identity.dart';
import '../theme/locale_controller.dart';

AndroidNotificationChannel get _kChannelMessages => AndroidNotificationChannel(
  'talky_messages',
  resolveL10n().messagesChannelName,
  importance: Importance.high,
);
AndroidNotificationChannel get _kChannelMeetings => AndroidNotificationChannel(
  'talky_meetings',
  resolveL10n().navMeetings,
  description: resolveL10n().meetingInvitationsAndReminders,
  importance: Importance.max,
);

const String kPushActiveConvKey = 'push_active_conv_id';
const String kConvTagPrefix = 'conv_';
const int kMeetingNotifOffset = 1000000000;
const int kMaxBufferedMessages = 7;

/// Id de la notification résumé (legacy — annulée au démarrage).
const int kMessagesSummaryId = 2147483646;

/// Liste legacy des conversations groupées (nettoyée au démarrage).
const String kGroupConvIdsKey = 'notif_group_conv_ids';

/// Petite icône (barre de statut) : silhouette blanche monochrome du logo.
/// Android n'utilise que le canal alpha du small icon → une icône couleur
/// (ic_launcher) apparaîtrait en carré blanc. On passe donc par un drawable dédié.
const String kNotificationIcon = '@drawable/ic_stat_notification';

/// Grande icône (à droite de la notif, façon WhatsApp) : logo couleur complet.
const AndroidBitmap<Object> kNotificationLargeIcon =
    DrawableResourceAndroidBitmap('@mipmap/ic_launcher');

/// Couleur d'accent (bleu du logo) qui teinte la petite icône monochrome.
const Color kNotificationAccentColor = Color(0xFF114B86);

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
      android: AndroidInitializationSettings(kNotificationIcon),
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

    // Ancienne notif résumé « X conversations » — ne plus utiliser.
    await _plugin.cancel(0);
    try {
      await _plugin.cancel(kMessagesSummaryId);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notif_active_conv_ids');
    await prefs.remove(kGroupConvIdsKey);

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

    final msgID = int.tryParse(data['msgID']?.toString() ?? '') ?? 0;
    final eventId = data['eventId']?.toString() ?? '';

    if (await NotificationDedupStore.isAlreadyHandled(
      msgID: msgID > 0 ? msgID : null,
      eventId: eventId.isNotEmpty ? eventId : null,
    )) {
      NotificationDiagnostics.deduplicated(
        reason: 'already_handled',
        msgID: msgID > 0 ? msgID : null,
        eventId: eventId.isNotEmpty ? eventId : null,
      );
      return;
    }

    final reserved = await NotificationDedupStore.tryReserve(
      msgID: msgID > 0 ? msgID : null,
      eventId: eventId.isNotEmpty ? eventId : null,
    );
    if (!reserved) {
      NotificationDiagnostics.deduplicated(
        reason: 'reserved_or_shown',
        msgID: msgID > 0 ? msgID : null,
        eventId: eventId.isNotEmpty ? eventId : null,
      );
      return;
    }

    final senderName = title ?? data['title']?.toString() ?? resolveL10n().appTitle;
    final messageBody = body ?? bodyFromPayload(data);
    if (messageBody.isEmpty && senderName.isEmpty) return;

    final isGroup = data['isGroup'] == '1' || data['isGroup'] == true;
    final groupName = data['groupName']?.toString() ?? '';

    final buffer = await _appendToBuffer(
      conversationId,
      sender: senderName,
      body: messageBody,
    );

    final payload = encodeNotificationPayload(data);
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
    final fallbackBody = bufferedDisplayBody(buffer, isGroup: isGroup);

    final iosDetails = DarwinNotificationDetails(
      threadIdentifier: threadId,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: isGroup ? senderName : null,
    );

    final notifId = NotificationIdentity.notificationIdForConversation(conversationId);
    final convTag = NotificationIdentity.tagForConversation(conversationId);

    try {
      await _plugin.show(
        notifId,
        displayTitle,
        displayBody,
        NotificationDetails(
          android: _androidMessageDetails(conversationId, convTag, style),
          iOS: iosDetails,
        ),
        payload: payload,
      );
      await NotificationDedupStore.markShown(
        msgID: msgID > 0 ? msgID : null,
        eventId: eventId.isNotEmpty ? eventId : null,
      );
      NotificationDiagnostics.displayed(
        conversationId: conversationId,
        msgID: msgID > 0 ? msgID : null,
        eventId: eventId.isNotEmpty ? eventId : null,
      );
    } catch (e) {
      // MessagingStyle peut échouer sur certains appareils en background.
      try {
        await _plugin.show(
          notifId,
          displayTitle,
          displayBody,
          NotificationDetails(
            android: _androidMessageDetails(
              conversationId,
              convTag,
              BigTextStyleInformation(fallbackBody),
            ),
            iOS: iosDetails,
          ),
          payload: payload,
        );
        await NotificationDedupStore.markShown(
          msgID: msgID > 0 ? msgID : null,
          eventId: eventId.isNotEmpty ? eventId : null,
        );
        NotificationDiagnostics.displayed(
          conversationId: conversationId,
          msgID: msgID > 0 ? msgID : null,
          eventId: eventId.isNotEmpty ? eventId : null,
        );
      } catch (e2) {
        await NotificationDedupStore.releaseReservation(
          msgID: msgID > 0 ? msgID : null,
          eventId: eventId.isNotEmpty ? eventId : null,
        );
        rethrow;
      }
    }
  }

  // ── Affichage réunions ───────────────────────────────────────────────

  static Future<void> showMeetingNotification(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final type = data['type']?.toString() ?? '';
    final meetingId = int.tryParse(data['meetingId']?.toString() ?? '') ?? 0;
    final title = data['title']?.toString() ?? resolveL10n().meeting;
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
          color: kNotificationAccentColor,
          icon: kNotificationIcon,
          largeIcon: kNotificationLargeIcon,
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

    final notifTitle = title ?? data['title']?.toString() ?? resolveL10n().appTitle;
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
          icon: kNotificationIcon,
          color: kNotificationAccentColor,
          largeIcon: kNotificationLargeIcon,
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
    final notifId = NotificationIdentity.notificationIdForConversation(conversationId);
    final tag = NotificationIdentity.tagForConversation(conversationId);
    try {
      await _plugin.cancel(notifId, tag: tag);
    } catch (_) {
      // Plugin absent (tests unitaires / plateforme non supportée).
    }
    NotificationDiagnostics.cancelled(
      conversationId: conversationId,
      reason: 'read_or_open',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bufferKey(conversationId));
  }

  static Future<void> cancelMeeting(int meetingId) async {
    if (kIsWeb || meetingId == 0) return;
    await _plugin.cancel(kMeetingNotifOffset + meetingId);
  }

  // ── Corps de notif ───────────────────────────────────────────────────

  /// Corps multi-lignes pour le fallback Android quand [MessagingStyle] échoue.
  static String bufferedDisplayBody(
    List<Map<String, String>> buffer, {
    required bool isGroup,
  }) {
    if (buffer.isEmpty) return '';

    final lines = buffer.map((m) {
      final body = m['body'] ?? '';
      if (!isGroup) return body;
      final sender = (m['sender'] ?? '').trim();
      return sender.isNotEmpty ? '$sender: $body' : body;
    }).where((line) => line.isNotEmpty);

    return lines.join('\n');
  }

  static String bodyFromPayload(Map<String, dynamic> data) {
    final l10n = resolveL10n();
    final raw = data['body']?.toString();
    final normalized = displayConversationPreview(
      raw != null && raw.isNotEmpty ? raw : null,
      l10n,
    );
    if (normalized.isNotEmpty) return normalized;

    final type = int.tryParse(data['msgType']?.toString() ?? '') ?? 0;
    switch (type) {
      case 1:
        return l10n.photo;
      case 2:
        return l10n.video;
      case 3:
        return l10n.audio;
      case 4:
        return l10n.file;
      case 5:
        return l10n.location;
      case 7:
        return l10n.contact;
      default:
        return l10n.newMessage;
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  static String _convTag(int conversationId) =>
      NotificationIdentity.tagForConversation(conversationId);

  static AndroidNotificationDetails _androidMessageDetails(
    int conversationId,
    String tag,
    StyleInformation styleInformation,
  ) {
    // Pas de groupKey / résumé global : chaque conversation = une bulle
    // indépendante (évite qu'un résumé unique « écrase » les autres notifs).
    return AndroidNotificationDetails(
      _kChannelMessages.id,
      _kChannelMessages.name,
      channelDescription: _kChannelMessages.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: kNotificationIcon,
      color: kNotificationAccentColor,
      largeIcon: kNotificationLargeIcon,
      tag: tag,
      styleInformation: styleInformation,
    );
  }

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
        Person(name: sender.isNotEmpty ? sender : resolveL10n().appTitle),
      );
    }).toList();

    final personName = latestSender.trim().isNotEmpty ? latestSender : resolveL10n().appTitle;
    return MessagingStyleInformation(
      Person(name: personName),
      conversationTitle: isGroup && groupName.isNotEmpty ? groupName : null,
      groupConversation: isGroup,
      messages: styleMessages,
    );
  }

}
