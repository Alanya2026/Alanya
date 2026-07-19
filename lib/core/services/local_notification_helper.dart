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
const String kConvTagPrefix = 'conv_';
const int kMeetingNotifOffset = 1000000000;
const int kMaxBufferedMessages = 7;

/// Clé de groupe partagée par toutes les notifs de messages : Android les
/// rassemble sous un même « bloc » applicatif (façon WhatsApp).
const String kMessagesGroupKey = 'com.alanya.talky.MESSAGES';

/// Id de la notification résumé (en-tête du bloc). Grand entier dédié pour ne
/// jamais entrer en collision avec un conversationId ou l'offset réunions.
const int kMessagesSummaryId = 2147483646;

/// Liste (SharedPreferences) des conversations ayant une notif active, pour
/// construire/rafraîchir le résumé du bloc.
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

    // Ancienne notif résumé « X conversations » (id 0) — ne plus utiliser.
    await _plugin.cancel(0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notif_active_conv_ids');

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

    try {
      await _plugin.show(
        conversationId,
        displayTitle,
        displayBody,
        NotificationDetails(
          android: _androidMessageDetails(conversationId, style),
          iOS: iosDetails,
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
          android: _androidMessageDetails(
            conversationId,
            BigTextStyleInformation(fallbackBody),
          ),
          iOS: iosDetails,
        ),
        payload: payload,
      );
    }

    // Regroupement façon WhatsApp : on trace la conversation et on (re)construit
    // la notification résumé qui coiffe le bloc applicatif.
    await _addGroupConvId(conversationId);
    await _refreshGroupSummary();
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
    try {
      await _plugin.cancel(conversationId, tag: _convTag(conversationId));
    } catch (_) {
      // Plugin absent (tests unitaires / plateforme non supportée).
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bufferKey(conversationId));
    await _removeGroupConvId(conversationId);
    await _refreshGroupSummary();
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
      case 5:
        return '📍 Position';
      default:
        return 'Nouveau message';
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  static String _convTag(int conversationId) =>
      '$kConvTagPrefix$conversationId';

  static AndroidNotificationDetails _androidMessageDetails(
    int conversationId,
    StyleInformation styleInformation,
  ) {
    return AndroidNotificationDetails(
      _kChannelMessages.id,
      _kChannelMessages.name,
      channelDescription: _kChannelMessages.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: kNotificationIcon,
      color: kNotificationAccentColor,
      largeIcon: kNotificationLargeIcon,
      tag: _convTag(conversationId),
      groupKey: kMessagesGroupKey,
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

  static Future<List<Map<String, String>>> _readBuffer(
    int conversationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_bufferKey(conversationId));
    if (existing == null) return [];
    try {
      final decoded = jsonDecode(existing) as List;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Regroupement (bloc applicatif façon WhatsApp) ─────────────────────

  static Future<List<int>> _groupConvIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kGroupConvIdsKey) ?? const [];
    return raw
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .where((id) => id != 0)
        .toList();
  }

  static Future<void> _addGroupConvId(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(kGroupConvIdsKey) ?? const []).toSet();
    ids.add('$conversationId');
    await prefs.setStringList(kGroupConvIdsKey, ids.toList());
  }

  static Future<void> _removeGroupConvId(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(kGroupConvIdsKey) ?? const []).toSet();
    ids.remove('$conversationId');
    await prefs.setStringList(kGroupConvIdsKey, ids.toList());
  }

  /// (Re)construit la notification résumé qui coiffe le bloc de messages.
  /// Auto-nettoyage : les conversations dont le buffer est vide sont retirées.
  static Future<void> _refreshGroupSummary() async {
    if (kIsWeb) return;
    final ids = await _groupConvIds();

    var totalMessages = 0;
    final lines = <String>[];
    final liveIds = <int>[];
    for (final id in ids) {
      final buffer = await _readBuffer(id);
      if (buffer.isEmpty) continue;
      liveIds.add(id);
      totalMessages += buffer.length;
      final last = buffer.last;
      final sender = (last['sender'] ?? '').trim();
      final body = last['body'] ?? '';
      lines.add(sender.isNotEmpty ? '$sender: $body' : body);
    }

    // Persiste l'ensemble nettoyé (retire les conversations sans buffer).
    if (liveIds.length != ids.length) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        kGroupConvIdsKey,
        liveIds.map((e) => '$e').toList(),
      );
    }

    if (liveIds.isEmpty) {
      try {
        await _plugin.cancel(kMessagesSummaryId);
      } catch (_) {
        // Plugin absent.
      }
      return;
    }

    final convCount = liveIds.length;
    final plural = totalMessages > 1 ? 's' : '';
    final summaryText = convCount > 1
        ? '$totalMessages messages · $convCount conversations'
        : '$totalMessages nouveau$plural message$plural';

    final inbox = InboxStyleInformation(
      lines,
      contentTitle: summaryText,
      summaryText: 'Alanya',
    );

    try {
      await _plugin.show(
        kMessagesSummaryId,
        'Alanya',
        summaryText,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelMessages.id,
            _kChannelMessages.name,
            channelDescription: _kChannelMessages.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: kNotificationIcon,
            color: kNotificationAccentColor,
            groupKey: kMessagesGroupKey,
            setAsGroupSummary: true,
            onlyAlertOnce: true,
            styleInformation: inbox,
          ),
        ),
      );
    } catch (_) {
      // Plateforme non supportée / plugin absent.
    }
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

}
