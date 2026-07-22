import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import '../../talky_api_client.dart';
import '../theme/locale_controller.dart';
import 'callkit_service.dart';
import 'local_notification_helper.dart';
import 'notification_navigation.dart';
import 'notifications/notification_diagnostics.dart';
import 'notifications/notification_dedup_store.dart';
import 'notifications/push_device_coordinator.dart';
import 'ringtone_service.dart';
import 'call/ended_call_registry.dart';
import 'call/call_permissions_helper.dart';

const String _kDefaultFirebaseVapidKey =
    'BBde_uFKtUbLFwAQZ0Kd5ENuaPD1LuRf2ZvvHMPZ3wigioZpjIf7a9rh3pFcI2TRYRrC1YmoiRnAJ4n8io5QBTk';
const String _kFirebaseVapidKey = String.fromEnvironment(
  'FIREBASE_VAPID_KEY',
  defaultValue: _kDefaultFirebaseVapidKey,
);

/// Aligné sur `talkyNotificationNativeV2` (build.gradle.kts). Les messages
/// Android passent par TalkyFirebaseMessagingService — éviter le doublon Dart.
const bool _kAndroidNativeMessageNotifications = bool.fromEnvironment(
  'TALKY_ANDROID_NATIVE_NOTIF_V2',
  defaultValue: true,
);

bool get _androidNativeMessagesHandlePush =>
    !kIsWeb &&
    Platform.isAndroid &&
    _kAndroidNativeMessageNotifications;

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
    NotificationDiagnostics.pushBackground(Map<String, dynamic>.from(data));

    if (type == 'call' || type == 'group_call') {
      if (!kIsWeb) {
        final callId = (data['callId'] ?? data['roomId'] ?? '').toString();
        if (await EndedCallRegistry.isEnded(callId)) {
          debugPrint('[Push] background call ignoré (callId terminé): $callId');
          return;
        }
        await CallKitService.instance.showIncoming(
          callId: callId,
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
        final callId = (data['callId'] ?? '').toString().trim();
        if (callId.isNotEmpty) {
          await EndedCallRegistry.markEnded(callId);
          await CallKitService.instance.endCall(callId);
        } else {
          await CallKitService.instance.endAll();
        }
        await RingtoneService.stopAll();
      }
    } else if (type == 'message_read_sync') {
      await _handleMessageReadSync(Map<String, dynamic>.from(data));
    } else {
      await _showBackgroundNotification(message);
    }
  } catch (e, st) {
    debugPrint('[Push] background handler error: $e\n$st');
  }
}

Future<void> _handleMessageReadSync(Map<String, dynamic> data) async {
  final convId = int.tryParse(data['conversationId']?.toString() ?? '') ?? 0;
  if (convId <= 0) return;
  await LocalNotificationHelper.cancelConversation(convId);
  final msgID = int.tryParse(data['msgID']?.toString() ?? '') ?? 0;
  if (msgID > 0) {
    await NotificationDedupStore.markCancelled(msgID: msgID);
  }
  NotificationDiagnostics.cancelled(
    conversationId: convId,
    reason: 'read_sync',
  );
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  if (kIsWeb) return;
  final data = Map<String, dynamic>.from(message.data);
  final type = data['type']?.toString();

  if (type == 'message_read_sync') {
    await _handleMessageReadSync(data);
    return;
  }

  final title = (data['title'] ?? message.notification?.title ?? '').toString();
  final body = (data['body'] ?? message.notification?.body ?? '').toString();
  if (title.isEmpty && body.isEmpty) return;

  // iOS : l'alerte APNS affiche déjà la notif — éviter le doublon local.
  final iosHandledByApns = !kIsWeb &&
      Platform.isIOS &&
      (type == 'message' ||
          type == 'meeting_invite' ||
          type == 'meeting_reminder' ||
          type == 'status_view');
  if (iosHandledByApns) return;

  // Android messages : même si FCM a déjà posté un bloc `notification`
  // (filet app tuée), on reconstruit en MessagingStyle avec le même tag
  // `conv_*` → remplace la notif système et empile l'historique par
  // conversation au lieu d'écraser avec une seule ligne.
  // Meetings / statut : le système suffit → pas de doublon local.
  if (message.notification != null && type != 'message') return;

  await LocalNotificationHelper.ensureInitialized();

  if (type == 'message') {
    if (_androidNativeMessagesHandlePush) return;
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
  late final PushDeviceCoordinator _deviceCoordinator =
      PushDeviceCoordinator(_apiClient);

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
    if (!kIsWeb && Platform.isIOS) {
      CallKitService.instance.setVoipTokenListener((token) {
        unawaited(_deviceCoordinator.registerVoipToken(token));
      });
    }

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
      await CallPermissionsHelper.ensureCallDisplayPermissions();

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

  Future<void> syncDeviceLifecycle({
    required bool appInForeground,
    int activeConversationId = 0,
  }) async {
    _deviceCoordinator.scheduleStateUpdate(
      appInForeground: appInForeground,
      activeConversationId:
          activeConversationId > 0 ? activeConversationId : null,
    );
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
      if (!kIsWeb && Platform.isIOS) {
        final voipToken =
            await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (voipToken != null && voipToken.trim().isNotEmpty) {
          await svc._deviceCoordinator.registerVoipToken(voipToken.trim());
        }
      }
    } catch (e) {
      debugPrint('[Push] syncTokenWithBackend failed: $e');
    }
  }

  /// Détache l'appareil push côté serveur (logout).
  static Future<void> onSessionEnded() async {
    await _instance?._deviceCoordinator.onLogout();
  }

  void _handleForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();

    NotificationDiagnostics.pushForeground(Map<String, dynamic>.from(data));
    debugPrint('[Push] foreground: type=$type');
    if (type == 'call_ended') {
      if (!kIsWeb) {
        final callId = (data['callId'] ?? '').toString().trim();
        if (callId.isNotEmpty) {
          await EndedCallRegistry.markEnded(callId);
          await CallKitService.instance.endCall(callId);
        } else {
          await CallKitService.instance.endAll();
        }
        await RingtoneService.stopAll();
      }
      return;
    }

    if (type == 'meeting_invite' || type == 'meeting_reminder') {
      await LocalNotificationHelper.showMeetingNotification(data);
      _dispatchNotificationAction(
        NotificationAction.fromMap(data, fromTap: false),
      );
      return;
    }

    if (type == 'call' || type == 'group_call') {
      final callId = (data['callId'] ?? data['roomId'] ?? '').toString();
      if (await EndedCallRegistry.isEnded(callId)) {
        debugPrint('[Push] foreground call ignoré (callId terminé): $callId');
        return;
      }
      debugPrint('[Push] Appel géré via CallKit/socket (pas de notif locale)');
      return;
    }

    if (type == 'message_read_sync') {
      await _handleMessageReadSync(data);
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

      if (_androidNativeMessagesHandlePush) return;

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
    NotificationDiagnostics.tapAction(
      type: data['type']?.toString() ?? '',
      conversationId: int.tryParse(data['conversationId']?.toString() ?? ''),
    );
    debugPrint('[Push] opened from notif: type=${data['type']}');
    if (data.isEmpty) return;
    _dispatchNotificationAction(NotificationAction.fromMap(data));
  }

  static void _onLocalNotifTap(NotificationResponse response) {
    final action = decodeNotificationPayload(response.payload);
    if (action == null) return;
    NotificationDiagnostics.tapAction(
      type: action.type,
      conversationId: int.tryParse(action.data['conversationId'] ?? ''),
    );
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
