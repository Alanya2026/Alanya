import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../talky_api_client.dart';
import 'callkit_service.dart';
import 'ringtone_service.dart';
const String _kDefaultFirebaseVapidKey =
    'BBde_uFKtUbLFwAQZ0Kd5ENuaPD1LuRf2ZvvHMPZ3wigioZpjIf7a9rh3pFcI2TRYRrC1YmoiRnAJ4n8io5QBTk';
const String _kFirebaseVapidKey = String.fromEnvironment(
  'FIREBASE_VAPID_KEY',
  defaultValue: _kDefaultFirebaseVapidKey,
);

// Canaux Android dédiés
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

/// Données d'une notification meeting diffusées sur [PushService.meetingNotifications].
class MeetingNotifData {
  final String type;        
  final int meetingId;
  final String meetingTitle;
  final String organiserName;
  final String meetingTime;  
  const MeetingNotifData({
    required this.type,
    required this.meetingId,
    required this.meetingTitle,
    required this.organiserName,
    this.meetingTime = '',
  });
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type']?.toString();

  if (type == 'call' || type == 'group_call') {
    if (!kIsWeb) {
      await CallKitService.instance.showIncoming(
        callId:      (data['callId'] ?? data['roomId'] ?? '').toString(),
        callerId:    (data['callerId'] ?? '').toString(),
        callerName:  (data['callerName'] ?? data['title'] ?? 'Appel').toString(),
        callerPhoto: data['photo']?.toString(),
        isVideo:     data['isVideo'] == 'true',
        roomId:      data['roomId']?.toString(),
        silent: true,
      );
    }
  } else if (type == 'call_ended') {
    if (!kIsWeb) {
      await CallKitService.instance.endAll();
      await RingtoneService.stopAll();
    }
  } else { 
    await _showBackgroundNotification(message);
  }
}

/// Affiche une notification locale  
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  if (kIsWeb) return;
  final data = message.data;
  final type = data['type']?.toString();
  final title = (data['title'] ?? message.notification?.title ?? '').toString();
  final body = (data['body'] ?? message.notification?.body ?? '').toString();
  if (title.isEmpty && body.isEmpty) return;

  final isMeeting = type == 'meeting_invite' || type == 'meeting_reminder';
  final channelId = isMeeting ? 'talky_meetings' : 'talky_messages';
  final channelName = isMeeting ? 'Réunions' : 'Messages';

  final plugin = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(initSettings);

  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(channelId, channelName, importance: Importance.high),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

class PushService {
  PushService._(this._apiClient, this._navKey);

  static PushService? _instance;
  static PushService get instance => _instance!;

  final TalkyApiClient _apiClient;
  final GlobalKey<NavigatorState>? _navKey;

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  String? _token;
  String? get currentToken => _token;

  static final StreamController<MeetingNotifData> _meetingCtrl =
      StreamController.broadcast();
  static Stream<MeetingNotifData> get meetingNotifications =>
      _meetingCtrl.stream;

  static Future<PushService> init(
    TalkyApiClient apiClient, {
    GlobalKey<NavigatorState>? navKey,
  }) async {
    _instance ??= PushService._(apiClient, navKey);
    await _instance!._setup();
    return _instance!;
  }

  Future<void> _setup() async {
    // Permission utilisateur
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] ** Notifications refusées par l\'utilisateur');
      return;
    }

    // Initialiser flutter_local_notifications (mobile uniquement)
    if (!kIsWeb) {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotifTap,
      );

      // Créer les canaux Android
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(_kChannelMessages);
      await plugin?.createNotificationChannel(_kChannelMeetings);
    }

    // Token FCM
    try {
      _token = kIsWeb && _kFirebaseVapidKey.isNotEmpty
          ? await _fm.getToken(vapidKey: _kFirebaseVapidKey)
          : await _fm.getToken();
      debugPrint('[Push] Token: ${_token?.substring(0, 12)}…');
      if (_token != null) await _safeUpdateToken(_token!);
    } catch (e) {
      debugPrint('[Push] getToken error: $e');
    }

    // Rotation du token
    _onTokenRefreshSub = _fm.onTokenRefresh.listen((t) {
      _token = t;
      _safeUpdateToken(t);
    });

    // Messages foreground
    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    // App ouverte depuis notif background → tap
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);

    // App tuée → tap sur notif → redémarrage
    final initial = await _fm.getInitialMessage();
    if (initial != null) _handleOpenedApp(initial);
  }

  Future<void> _safeUpdateToken(String token) async {
    try {
      await _apiClient.updateFcmToken(token);
      debugPrint('[Push] FCM token enregistré côté backend');
    } catch (e) {
      debugPrint('[Push] updateFcmToken failed: $e');
    }
  }

  // Foreground

  void _handleForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();

    debugPrint('[Push] foreground: type=$type'); 
    if (type == 'call_ended') return;

    if (type == 'meeting_invite' || type == 'meeting_reminder') {
      await _showMeetingLocalNotif(data);
      _dispatchMeetingData(data);
      return;
    }
 
    if (type == 'call' || type == 'group_call') {
      debugPrint('[Push] ℹ️ Appel géré via CallKit (pas de notif locale)'); 
      return;
    }

    // Autres types : notif locale standard
    if (!kIsWeb) {
      final title =
          (data['title'] ?? message.notification?.title ?? '').toString();
      final body =
          (data['body'] ?? message.notification?.body ?? '').toString();
      if (title.isNotEmpty || body.isNotEmpty) {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'talky_messages',
              'Messages',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }
  }

  // Tap sur notif  

  void _handleOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    debugPrint('[Push] opened from notif: type=$type');

    if (type == 'meeting_invite' || type == 'meeting_reminder') {
      _dispatchMeetingData(data);
    }
  }

  // Tap sur notif locale (foreground) ───────────────────────────────

  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return; 
    final parts = payload.split('|');
    if (parts.length < 4) return;
    final data = {
      'type':          parts[0],
      'meetingId':     parts[1],
      'meetingTitle':  parts[2],
      'organiserName': parts[3],
      'meetingTime':   parts.length > 4 ? parts[4] : '',
    };
    _dispatchMeetingData(data);
  }
 
  Future<void> _showMeetingLocalNotif(Map<String, dynamic> data) async {
    if (kIsWeb) return;

    final type         = data['type']?.toString() ?? '';
    final title        = data['title']?.toString() ?? 'Réunion';
    final body         = data['body']?.toString() ?? '';
    final meetingId    = data['meetingId']?.toString() ?? '';
    final meetingTitle = data['meetingTitle']?.toString() ?? '';
    final organiser    = data['organiserName']?.toString() ?? '';
    final meetingTime  = data['meetingTime']?.toString() ?? '';

    final payload = '$type|$meetingId|$meetingTitle|$organiser|$meetingTime';

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'talky_meetings',
          'Réunions',
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF3F51B5), // indigo
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: payload,
    );
  }

  void _dispatchMeetingData(Map<String, dynamic> data) {
    final meetingIdStr = data['meetingId']?.toString() ?? '0';
    final meetingId = int.tryParse(meetingIdStr) ?? 0;

    final notif = MeetingNotifData(
      type:          data['type']?.toString() ?? '',
      meetingId:     meetingId,
      meetingTitle:  data['meetingTitle']?.toString() ?? '',
      organiserName: data['organiserName']?.toString() ?? '',
      meetingTime:   data['meetingTime']?.toString() ?? '',
    );

    _meetingCtrl.add(notif);
    _navKey?.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}
