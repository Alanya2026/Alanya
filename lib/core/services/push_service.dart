import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import '../../talky_api_client.dart';
import '../theme/locale_controller.dart';
import 'callkit_service.dart';
import 'local_notification_helper.dart';
import 'notification_navigation.dart';
import 'ringtone_service.dart';

const String _kDefaultFirebaseVapidKey =
    'BBde_uFKtUbLFwAQZ0Kd5ENuaPD1LuRf2ZvvHMPZ3wigioZpjIf7a9rh3pFcI2TRYRrC1YmoiRnAJ4n8io5QBTk';
const String _kFirebaseVapidKey = String.fromEnvironment(
  'FIREBASE_VAPID_KEY',
  defaultValue: _kDefaultFirebaseVapidKey,
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
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Déjà initialisé dans cet isolate ou erreur transitoire.
    debugPrint('[Push] background Firebase init: $e');
  }

  try {
    final data = message.data;
    final type = data['type']?.toString();

    if (type == 'call' || type == 'group_call') {
      if (!kIsWeb) {
        await CallKitService.instance.showIncoming(
          callId: (data['callId'] ?? data['roomId'] ?? '').toString(),
          callerId: (data['callerId'] ?? '').toString(),
          callerName: (data['callerName'] ?? data['title'] ?? resolveL10n().callNoun).toString(),
          callerPhoto: data['photo']?.toString(),
          isVideo: data['isVideo'] == 'true',
          roomId: data['roomId']?.toString(),
          silent: false,
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
  } catch (e, st) {
    debugPrint('[Push] background handler error: $e\n$st');
  }
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  if (kIsWeb) return;
  // Filet de sécurité : si le backend a inclus un bloc `notification`
  // (affiché directement par le système Android app tuée), on n'en construit
  // pas un doublon local. En foreground, onMessage affiche le MessagingStyle.
  if (message.notification != null) return;
  final data = Map<String, dynamic>.from(message.data);
  final type = data['type']?.toString();
  final title = (data['title'] ?? message.notification?.title ?? '').toString();
  final body = (data['body'] ?? message.notification?.body ?? '').toString();
  if (title.isEmpty && body.isEmpty) return;

  // iOS : l'alerte APNS (configurée côté backend) affiche déjà la notif
  // quand l'app est fermée — éviter le doublon avec une notif locale.
  final iosHandledByApns = !kIsWeb &&
      Platform.isIOS &&
      (type == 'message' ||
          type == 'meeting_invite' ||
          type == 'meeting_reminder' ||
          type == 'status_view');
  if (iosHandledByApns) return;

  await LocalNotificationHelper.ensureInitialized();

  if (type == 'message') {
    await LocalNotificationHelper.showMessageNotification(
      data,
      title: title.isNotEmpty ? title : null,
      body: body.isNotEmpty ? body : null,
      suppressIfActive: false,
    );
  } else if (type == 'meeting_invite' || type == 'meeting_reminder') {
    await LocalNotificationHelper.showMeetingNotification(data);
  } else {
    await LocalNotificationHelper.showGenericNotification(
      data,
      title: title.isNotEmpty ? title : null,
      body: body.isNotEmpty ? body : null,
    );
  }
}

class PushService {
  PushService._(this._apiClient, this._navKey);

  static PushService? _instance;
  static PushService get instance => _instance!;

  final TalkyApiClient _apiClient;
  final GlobalKey<NavigatorState>? _navKey;

  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  String? _token;
  String? get currentToken => _token;

  static NotificationAction? _pendingAction;

  static final StreamController<NotificationAction> _actionCtrl =
      StreamController.broadcast();
  static Stream<NotificationAction> get notificationActions =>
      _actionCtrl.stream;

  static NotificationAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  static final StreamController<MeetingNotifData> _meetingCtrl =
      StreamController.broadcast();
  static Stream<MeetingNotifData> get meetingNotifications =>
      _meetingCtrl.stream;

  /// Vérifie si une conversation est actuellement ouverte (lecture SharedPreferences).
  static Future<bool> isConversationActive(int conversationId) =>
      LocalNotificationHelper.shouldSuppressMessage(conversationId);

  static Future<PushService> init(
    TalkyApiClient apiClient, {
    GlobalKey<NavigatorState>? navKey,
  }) async {
    _instance ??= PushService._(apiClient, navKey);
    await _instance!._setup();
    return _instance!;
  }

  Future<void> _setup() async {
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

    if (!kIsWeb) {
      await LocalNotificationHelper.ensureInitialized(
        onTap: _onLocalNotifTap,
      );

      await _maybeRequestBatteryOptimizationExemption();

      final launchDetails =
          await LocalNotificationHelper.plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails!.notificationResponse?.payload;
        final action = decodeNotificationPayload(payload);
        if (action != null) {
          debugPrint('[Push] cold start via notif locale: type=${action.type}');
          _dispatchNotificationAction(action);
        }
      }
    }

    try {
      _token = kIsWeb && _kFirebaseVapidKey.isNotEmpty
          ? await _fm.getToken(vapidKey: _kFirebaseVapidKey)
          : await _fm.getToken();
      debugPrint('[Push] Token: ${_token?.substring(0, 12)}…');
      if (_token != null) await _safeUpdateToken(_token!);
    } catch (e) {
      debugPrint('[Push] getToken error: $e');
    }

    _onTokenRefreshSub = _fm.onTokenRefresh.listen((t) {
      _token = t;
      _safeUpdateToken(t);
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);

    final initial = await _fm.getInitialMessage();
    if (initial != null) {
      debugPrint('[Push] cold start via FCM: type=${initial.data['type']}');
      _handleOpenedApp(initial);
    }
  }

  Future<void> _safeUpdateToken(String token) async {
    try {
      await _apiClient.updateFcmToken(token);
      debugPrint('[Push] FCM token enregistré côté backend');
    } catch (e) {
      debugPrint('[Push] updateFcmToken failed: $e');
    }
  }

  /// Demande l'exemption d'optimisation batterie sur Android (nécessaire pour
  /// réveiller CallKit via FCM quand l'app est tuée). Clé v2 : une nouvelle
  /// proposition après le fix (l'ancien flag marquait aussi les refus).
  Future<void> _maybeRequestBatteryOptimizationExemption() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('asked_battery_opt_v2') == true) return;
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
      // Une seule proposition pour cette génération de flag (pas de harcèlement).
      await prefs.setBool('asked_battery_opt_v2', true);
    } catch (e) {
      debugPrint('[Push] exemption optimisation batterie: $e');
    }
  }

  /// Ré-enregistre le token FCM après login (init peut avoir eu lieu avant auth).
  static Future<void> syncTokenWithBackend() async {
    final svc = _instance;
    if (svc == null) return;
    try {
      final token = svc._token ?? await svc._fm.getToken();
      if (token != null) {
        svc._token = token;
        await svc._safeUpdateToken(token);
      }
    } catch (e) {
      debugPrint('[Push] syncTokenWithBackend failed: $e');
    }
  }

  void _handleForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();

    debugPrint('[Push] foreground: type=$type');
    if (type == 'call_ended') return;

    if (type == 'meeting_invite' || type == 'meeting_reminder') {
      await LocalNotificationHelper.showMeetingNotification(data);
      _dispatchNotificationAction(
        NotificationAction.fromMap(data, fromTap: false),
      );
      return;
    }

    if (type == 'call' || type == 'group_call') {
      debugPrint('[Push] Appel géré via CallKit (pas de notif locale)');
      return;
    }

    if (type == 'message') {
      _dispatchNotificationAction(
        NotificationAction.fromMap(data, fromTap: false),
      );

      final convId =
          int.tryParse(data['conversationId']?.toString() ?? '') ?? 0;
      if (convId > 0 && await isConversationActive(convId)) {
        return;
      }

      final title =
          (data['title'] ?? message.notification?.title ?? '').toString();
      final body =
          (data['body'] ?? message.notification?.body ?? '').toString();
      if (title.isNotEmpty || body.isNotEmpty) {
        await LocalNotificationHelper.showMessageNotification(
          data,
          title: title.isNotEmpty ? title : null,
          body: body.isNotEmpty ? body : null,
        );
      }
      return;
    }

    if (!kIsWeb) {
      final title =
          (data['title'] ?? message.notification?.title ?? '').toString();
      final body =
          (data['body'] ?? message.notification?.body ?? '').toString();
      if (title.isNotEmpty || body.isNotEmpty) {
        await LocalNotificationHelper.showGenericNotification(
          data,
          title: title.isNotEmpty ? title : null,
          body: body.isNotEmpty ? body : null,
        );
      }
    }
  }

  void _handleOpenedApp(RemoteMessage message) {
    final data = message.data;
    debugPrint('[Push] opened from notif: type=${data['type']}');
    if (data.isEmpty) return;
    _dispatchNotificationAction(NotificationAction.fromMap(data));
  }

  static void _onLocalNotifTap(NotificationResponse response) {
    final action = decodeNotificationPayload(response.payload);
    if (action == null) return;
    debugPrint('[Push] tap notif locale: type=${action.type}');
    _instance?._dispatchNotificationAction(action);
  }

  void _dispatchNotificationAction(NotificationAction action) {
    if (action.type.isEmpty) return;

    _pendingAction = action;
    _actionCtrl.add(action);

    if (action.type == 'meeting_invite' || action.type == 'meeting_reminder') {
      _emitMeetingRefresh(action.data);
    }

    if (action.fromTap) {
      _navKey?.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _emitMeetingRefresh(Map<String, String> data) {
    final meetingId = int.tryParse(data['meetingId'] ?? '') ?? 0;
    _meetingCtrl.add(MeetingNotifData(
      type: data['type'] ?? '',
      meetingId: meetingId,
      meetingTitle: data['meetingTitle'] ?? '',
      organiserName: data['organiserName'] ?? '',
      meetingTime: data['meetingTime'] ?? '',
    ));
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}
