
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/conversation_display.dart';
import 'notification_navigation.dart';
import 'notifications/notification_dedup_store.dart';
import 'notifications/notification_diagnostics.dart';
import 'notifications/notification_identity.dart';
import 'notifications/notification_body.dart';
import 'notifications/notification_buffer_store.dart';
import 'notifications/notification_prefs_cache.dart';
import '../theme/locale_controller.dart';

// IDs suffixés `_v2` : introduisent le son de notification par défaut. Un canal
// Android étant immuable une fois créé, on change d'ID (et on supprime l'ancien
// dans [ensureInitialized]) pour que le son s'applique sans réinstallation.
// `playSound: true` + `sound: null` → son de notification par défaut du système.
AndroidNotificationChannel get _kChannelMessages => AndroidNotificationChannel(
  'talky_messages_v2',
  resolveL10n().messagesChannelName,
  importance: Importance.high,
  playSound: true,
);
AndroidNotificationChannel get _kChannelMeetings => AndroidNotificationChannel(
  'talky_meetings_v2',
  resolveL10n().navMeetings,
  description: resolveL10n().meetingInvitationsAndReminders,
  importance: Importance.max,
  playSound: true,
);

/// Alertes de trajet de confiance — **le seul canal de l'application conçu pour
/// traverser le silence.**
///
/// `audioAttributesUsage: alarm` n'est pas un détail de son : sur Android, un
/// canal en usage *alarme* passe la catégorie « alarmes » de « Ne pas déranger »,
/// autorisée par défaut, là où un canal en usage *notification* est étouffé.
/// C'est la seule voie accessible sans `ACCESS_NOTIFICATION_POLICY`, une
/// permission que l'utilisateur doit accorder à la main dans les réglages
/// système et que presque personne n'accorde.
///
/// Une alerte de sûreté qu'un mode silencieux peut étouffer n'est pas une
/// alerte. Ce canal est réservé à `trip_alert` et `trip_sos` — l'étendre à
/// autre chose apprendrait à l'utilisateur à le couper, et le jour où il compte
/// il serait déjà désactivé.
///
/// L'identifiant doit rester **exactement** celui qu'envoie le serveur dans
/// `message.android.notification.channelId` (notificationService.js) : un
/// identifiant inconnu fait retomber Android sur un canal par défaut, et tout ce
/// qui précède est perdu.
AndroidNotificationChannel get _kChannelTripAlert => AndroidNotificationChannel(
  'alanya_trip_alert',
  resolveL10n().tripsAlertChannelName,
  description: resolveL10n().tripsAlertChannelBody,
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

/// Rappels de trajet adressés au porteur seul : échéance et relances.
///
/// Canal distinct et **ordinaire**, délibérément. Ces rappels ne réveillent
/// personne d'autre, et les faire passer par le canal d'alarme reviendrait à
/// crier quatre fois par trajet — au bout de trois trajets, l'utilisateur
/// couperait le canal, alerte comprise.
AndroidNotificationChannel get _kChannelTrip => AndroidNotificationChannel(
  'alanya_trip',
  resolveL10n().tripsChannelName,
  description: resolveL10n().tripsChannelBody,
  importance: Importance.high,
  playSound: true,
);

const String kPushActiveConvKey = 'push_active_conv_id';
const String kConvTagPrefix = 'conv_';
const int kMeetingNotifOffset = 1000000000;

/// Décalage des identifiants de notification de trajet. Sans lui, un trajet et
/// une conversation pourraient produire le même identifiant et s'effacer l'un
/// l'autre dans le tiroir.
const int kTripNotifOffset = 1200000000;

/// Identifiant du bouton « Appeler » posé sur une alerte de trajet.
///
/// Il revient dans `NotificationResponse.actionId` et permet de distinguer
/// « il a appuyé sur Appeler » de « il a appuyé sur la notification ».
const String kTripCallAction = 'trip_call';
const int kMaxBufferedMessages = 7;

/// Utilisateur local dans MessagingStyle (aligné sur MessageNotificationHelper Kotlin).
const String _kMessagingStyleLocalUser = 'Moi';

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
    // Supprime les anciens canaux silencieux (avant introduction du son).
    try {
      await android?.deleteNotificationChannel('talky_messages');
      await android?.deleteNotificationChannel('talky_meetings');
    } catch (_) {}
    await android?.createNotificationChannel(_kChannelMessages);
    await android?.createNotificationChannel(_kChannelMeetings);
    await android?.createNotificationChannel(_kChannelTripAlert);
    await android?.createNotificationChannel(_kChannelTrip);

    // Ancienne notif résumé « X conversations » — ne plus utiliser.
    await _plugin.cancel(0);
    try {
      await _plugin.cancel(kMessagesSummaryId);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notif_active_conv_ids');
    await prefs.remove(kGroupConvIdsKey);
    await NotificationBufferStore.purgeLegacySharedPreferences();

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

    final isGroup = data['isGroup'] == '1' || data['isGroup'] == true;
    final groupName = data['groupName']?.toString() ?? '';
    final senderName = NotificationBody.resolveSenderName(
      data: data,
      title: title,
      isGroup: isGroup,
      fallback: resolveL10n().appTitle,
    );
    var messageBody = body ?? bodyFromPayload(data);
    if (isGroup) {
      messageBody = NotificationBody.stripLeadingSenderPrefix(
        senderName,
        messageBody,
      );
    }
    if (messageBody.isEmpty && senderName.isEmpty) return;

    final displayTitle = isGroup && groupName.isNotEmpty
        ? groupName
        : senderName;
    // Pas de re-préfixe : MessagingStyle (Person) et iOS (subtitle) portent
    // déjà le nom. Le serveur préfixe `body` pour le FCM système / APNs.
    final displayBody =
        NotificationPrefsCache.sanitizeBodyForDisplay(messageBody);

    final buffer = await NotificationBufferStore.append(
      conversationId: conversationId,
      sender: senderName,
      body: displayBody,
    );

    final payload = encodeNotificationPayload(data);
    final threadId = 'conv_$conversationId';

    final style = _buildMessagingStyle(
      messages: buffer,
      isGroup: isGroup,
      groupName: groupName,
    );

    final fallbackBody = bufferedDisplayBody(buffer, isGroup: isGroup);

    final iosDetails = DarwinNotificationDetails(
      threadIdentifier: threadId,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: isGroup ? senderName : null,
    );

    final visibility = NotificationPrefsCache.hideContentOnLockscreen
        ? NotificationVisibility.private
        : NotificationVisibility.public;

    final notifId = NotificationIdentity.notificationIdForConversation(conversationId);
    final convTag = NotificationIdentity.tagForConversation(conversationId);

    try {
      await _plugin.show(
        notifId,
        displayTitle,
        displayBody,
        NotificationDetails(
          android: _androidMessageDetails(conversationId, convTag, style, visibility: visibility),
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
              visibility: visibility,
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

  /// Notification de trajet de confiance, affichée par l'application.
  ///
  /// N'intervient qu'au **premier plan** : application ouverte, Android
  /// n'affiche pas lui-même le bloc `notification` de FCM et laisse la main à
  /// Dart. Fermée ou en arrière-plan, c'est le système qui affiche, sur le canal
  /// que le serveur a désigné — d'où l'obligation d'employer ici exactement les
  /// mêmes identifiants de canal, sans quoi la même alerte aurait deux
  /// comportements selon l'état de l'application.
  ///
  /// L'identifiant de notification dérive du **trajet**, pas du type : un trajet
  /// occupe une ligne, et le rappel d'échéance remplace le pré-avis au lieu de
  /// s'empiler à côté. C'est le pendant du `tag` posé côté serveur.
  static Future<void> showTripNotification(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final type = data['type']?.toString() ?? '';
    final notifTitle =
        title ?? data['title']?.toString() ?? resolveL10n().trips;
    final notifBody = body ?? data['body']?.toString() ?? '';
    if (notifTitle.isEmpty && notifBody.isEmpty) return;

    final alerte = type == 'trip_alert' || type == 'trip_sos';
    final canal = alerte ? _kChannelTripAlert : _kChannelTrip;

    final tripId = int.tryParse(data['tripId']?.toString() ?? '') ?? 0;
    final id = kTripNotifOffset + (tripId % 100000);

    await _plugin.show(
      id,
      notifTitle,
      notifBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: alerte ? Importance.max : Importance.high,
          priority: alerte ? Priority.max : Priority.high,
          // `category: alarm` double le réglage du canal. Le canal décide, mais
          // la catégorie oriente les surfaces qui ne le lisent pas — écran de
          // verrouillage, Android Auto, montres connectées.
          category: alerte ? AndroidNotificationCategory.alarm : null,
          icon: kNotificationIcon,
          color: alerte ? const Color(0xFFEF4444) : kNotificationAccentColor,
          largeIcon: kNotificationLargeIcon,
          styleInformation: notifBody.isNotEmpty
              ? BigTextStyleInformation(notifBody)
              : null,
          // « Appeler », directement depuis la notification.
          //
          // Sans ce bouton, le parcours d'un proche inquiet est : appuyer sur la
          // notification, attendre l'écran de suivi, trouver le bouton, appuyer.
          // Trois gestes au moment où l'on en veut zéro. Suivre un point sur une
          // carte pendant que quelqu'un ne confirme pas son arrivée est une
          // position insupportable si l'on n'a rien à en faire ; l'appel est le
          // seul geste qui transforme l'inquiétude en action.
          //
          // Réservé aux alertes : sur un rappel d'échéance adressé au porteur
          // lui-même, « Appeler » n'aurait aucun sens.
          actions: alerte
              ? <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    kTripCallAction,
                    resolveL10n().tripsCall,
                    showsUserInterface: true,
                    cancelNotification: false,
                  ),
                ]
              : null,
        ),
        iOS: DarwinNotificationDetails(
          // Un fil par trajet : les rappels se regroupent au lieu d'inonder.
          threadIdentifier: 'trip_$tripId',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: alerte
              // `timeSensitive` traverse « Mode de concentration » sur iOS.
              // C'est l'équivalent le plus proche du canal d'alarme Android, et
              // il ne demande aucune permission particulière.
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: encodeNotificationPayload(data),
    );
  }

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
    await NotificationBufferStore.clear(conversationId);
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
      final raw = m['body'] ?? '';
      if (!isGroup) return raw;
      final sender = (m['sender'] ?? '').trim();
      if (sender.isEmpty) return raw;
      final body = NotificationBody.stripLeadingSenderPrefix(sender, raw);
      if (body.startsWith('$sender: ')) return body;
      return '$sender: $body';
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
    StyleInformation styleInformation, {
    NotificationVisibility visibility = NotificationVisibility.public,
  }) {
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
      visibility: visibility,
      styleInformation: styleInformation,
    );
  }

  // Legacy buffer helpers removed — voir NotificationBufferStore.

  static MessagingStyleInformation _buildMessagingStyle({
    required List<Map<String, String>> messages,
    required bool isGroup,
    required String groupName,
  }) {
    final styleMessages = messages.map((m) {
      final ts = DateTime.tryParse(m['ts'] ?? '') ?? DateTime.now();
      final sender = (m['sender'] ?? '').trim();
      final isLocalUser = sender == _kMessagingStyleLocalUser;
      final raw = m['body'] ?? '';
      final text = isGroup && !isLocalUser
          ? NotificationBody.stripLeadingSenderPrefix(sender, raw)
          : raw;
      return Message(
        text,
        ts,
        isLocalUser
            ? null
            : Person(
                name: sender.isNotEmpty ? sender : resolveL10n().appTitle,
              ),
      );
    }).toList();

    return MessagingStyleInformation(
      Person(name: _kMessagingStyleLocalUser),
      conversationTitle: isGroup && groupName.isNotEmpty ? groupName : null,
      groupConversation: isGroup,
      messages: styleMessages,
    );
  }

}
