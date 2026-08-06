import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import '../../models/qr_models.dart';
import '../../talky_api_client.dart';
import '../theme/locale_controller.dart';
import 'callkit_service.dart';
import 'local_notification_helper.dart';
import 'notification_navigation.dart';
import 'notifications/notification_diagnostics.dart';
import 'notifications/notification_dedup_store.dart';
import 'notifications/push_device_coordinator.dart';
import 'ringtone_preferences.dart';
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

/// Android V2 : TalkyFirebaseMessagingService affiche CallKit en arrière-plan.
bool get _androidNativeCallsHandlePush => _androidNativeMessagesHandlePush;

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
      final callId = (data['callId'] ?? data['roomId'] ?? '').toString();
      if (_androidNativeCallsHandlePush) {
        debugPrint('[Push] background call ignoré (natif Android): $callId');
        return;
      }
      if (!kIsWeb) {
        if (await EndedCallRegistry.isEnded(callId)) {
          debugPrint('[Push] background call ignoré (callId terminé): $callId');
          return;
        }

        // CallKit (Android/iOS natif) ne sait jouer que la sonnerie système
        // ou une ressource compilée dans l'app — jamais un fichier choisi
        // par l'utilisateur au runtime (voir RingtonePreferences). Sur
        // Android uniquement, ce handler tourne dans un vrai isolate Dart :
        // on peut donc jouer nous-mêmes le fichier personnalisé avec
        // RingtoneService (lecteur audio générique), en demandant à CallKit
        // de rester silencieux pour éviter que les deux sons se superposent.
        // Sur iOS, ce handler Dart n'est pas fiable pour réveiller l'app à
        // l'arrivée d'un appel (pas de PushKit) : on laisse CallKit gérer
        // son propre son, inchangé.
        await RingtonePreferences.preload();
        final selection = RingtonePreferences.currentSelection;
        final playCustomRingtoneOurselves =
            Platform.isAndroid && selection.type != RingtoneSourceType.system;

        await CallKitService.instance.showIncoming(
          callId: callId,
          callerId: (data['callerId'] ?? '').toString(),
          callerName: (data['callerName'] ?? data['title'] ?? resolveL10n().callNoun).toString(),
          callerPhoto: data['photo']?.toString(),
          isVideo: data['isVideo'] == 'true',
          roomId: data['roomId']?.toString(),
          silent: playCustomRingtoneOurselves,
        );

        if (playCustomRingtoneOurselves) {
          await _playCustomRingtoneUntilCallResolved(callId);
        }
      }
    } else if (type == 'call_ended') {
      await dispatchCallEndedPush(
        callId: (data['callId'] ?? '').toString().trim(),
      );
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

/// Callback main-isolate : fermeture écran d'appel (CallService).
Future<void> Function({String? callId, String? callerId})?
    onCallEndedNotification;

Future<void> dispatchCallEndedPush({
  String? callId,
  String? callerId,
}) async {
  if (!kIsWeb) {
    final id = (callId ?? '').trim();
    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
      await CallKitService.instance.endCall(id);
    } else {
      await CallKitService.instance.endAll();
    }
    await RingtoneService.stopAll();
  }
  try {
    await onCallEndedNotification?.call(callId: callId, callerId: callerId);
  } catch (e) {
    debugPrint('[Push] onCallEndedNotification error: $e');
  }
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

/// Joue la sonnerie personnalisée (fournie par l'app ou importée) directement
/// depuis cet isolate d'arrière-plan Android, et attend que l'appel soit
/// résolu (décroché, refusé, expiré, terminé côté serveur) pour l'arrêter.
///
/// N'est appelée que quand CallKit a été mis en silencieux côté Android
/// (voir [firebaseMessagingBackgroundHandler]) : sans ça les deux sonneries
/// se superposeraient.
Future<void> _playCustomRingtoneUntilCallResolved(String callId) async {
  StreamSubscription<CallEvent?>? sub;
  Timer? safetyTimer;
  final resolved = Completer<void>();

  void resolveOnce() {
    if (!resolved.isCompleted) resolved.complete();
  }

  try {
    await RingtoneService.instance.init();
    await RingtoneService.instance.startIncomingRingtone();

    sub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          final extra = event.body['extra'] as Map? ?? const {};
          final eventCallId = (extra['callId'] ?? event.body['id'] ?? '').toString();
          // Un id vide peut survenir selon la version du plugin : dans le
          // doute on considère que ça nous concerne plutôt que de laisser
          // la sonnerie tourner indéfiniment.
          if (eventCallId.isEmpty || eventCallId == callId) resolveOnce();
          break;
        default:
          break;
      }
    });

    // Filet de sécurité : si jamais aucun événement CallKit n'arrive (perte
    // réseau, plugin qui ne remonte rien...), on ne bloque pas l'isolate
    // indéfiniment. La notification d'appel CallKit expire elle-même après
    // `duration: 30000` (voir CallKitService.showIncoming) ; on arrête donc
    // légèrement après pour rester cohérent avec ce qui s'affiche à l'écran.
    safetyTimer = Timer(const Duration(seconds: 33), resolveOnce);

    await resolved.future;
  } catch (e) {
    debugPrint('[Push] custom background ringtone error: $e');
  } finally {
    safetyTimer?.cancel();
    await sub?.cancel();
    try {
      await RingtoneService.stopAll();
    } catch (e) {
      debugPrint('[Push] stopAll after background ringtone error: $e');
    }
  }
}

class PushService {
  PushService._(this._apiClient, this._navKey);

  static PushService? _instance;
  static PushService get instance => _instance!;

  static const _nativeOpenChannel = MethodChannel('com.alanya/notification_open');
  static const _nativeCallChannel = MethodChannel('com.alanya/call_native');

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

      await _bindNativeNotificationOpens();
      await _bindNativeCallEvents();

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
    // Filet de course : le serveur ne pousse que sans socket au premier plan,
    // mais la socket a pu tomber juste avant. Même dialogue que l'événement.
    if (type == 'qr_contact_scanned') {
      _apiClient.injectQrContactScan(_qrScanFromPush(data));
      return;
    }
    if (type == 'call_ended') {
      await dispatchCallEndedPush(
        callId: (data['callId'] ?? '').toString().trim(),
      );
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
      // Premier plan : pas de CallKit — socket → IncomingCallScreen + sonnerie.
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
      debugPrint('[Push] foreground call → socket (pas de CallKit): $callId');
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
    // L'app était fermée ou derrière : l'événement socket du scan est perdu,
    // la data de la push permet de rejouer l'invitation d'ajout en retour.
    if (data['type']?.toString() == 'qr_contact_scanned') {
      _apiClient.injectQrContactScan(_qrScanFromPush(data));
      return;
    }
    _dispatchNotificationAction(NotificationAction.fromMap(data));
  }

  /// Reconstruit l'événement de scan depuis la data FCM (valeurs en chaînes).
  static QrContactScan _qrScanFromPush(Map<String, dynamic> data) {
    final avatar = (data['byAvatar'] ?? '').toString().trim();
    return QrContactScan(
      alanyaID: int.tryParse(data['byAlanyaID']?.toString() ?? '') ?? 0,
      nom: (data['byNom'] ?? '').toString(),
      pseudo: (data['byPseudo'] ?? '').toString(),
      avatarUrl: avatar.isEmpty ? null : avatar,
      alreadyMutual: data['alreadyMutual']?.toString() == '1',
    );
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

  /// Tap sur notification MessagingStyle native (Android Phase 4).
  Future<void> _bindNativeNotificationOpens() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _nativeOpenChannel.setMethodCallHandler((call) async {
        if (call.method != 'onOpen') return;
        final raw = call.arguments;
        if (raw is! Map) return;
        final data = raw.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        debugPrint(
          '[Push] native notif open: type=${data['type']} conv=${data['conversationId']}',
        );
        _dispatchNotificationAction(
          NotificationAction.fromMap(data, fromTap: true),
        );
      });

      final initial = await _nativeOpenChannel.invokeMethod<dynamic>('getInitialOpen');
      if (initial is Map) {
        final data = initial.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        if ((data['conversationId'] ?? '').isNotEmpty) {
          debugPrint(
            '[Push] native notif cold start: conv=${data['conversationId']}',
          );
          _dispatchNotificationAction(
            NotificationAction.fromMap(data, fromTap: true),
          );
        }
      }
    } catch (e) {
      debugPrint('[Push] bindNativeNotificationOpens: $e');
    }
  }

  /// Raccrochage / refus depuis notification CallKit native (ACTIVE_CALLS).
  Future<void> _bindNativeCallEvents() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _nativeCallChannel.setMethodCallHandler((call) async {
        if (call.method != 'onCallEnded') return;
        final raw = call.arguments;
        if (raw is! Map) return;
        final args = raw.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        debugPrint(
          '[Push] native call ended: callId=${args['callId']} caller=${args['callerId']}',
        );
        await dispatchCallEndedPush(
          callId: args['callId'],
          callerId: args['callerId'],
        );
      });
    } catch (e) {
      debugPrint('[Push] bindNativeCallEvents: $e');
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
