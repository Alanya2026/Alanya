// push_service.dart
//
// Facade unifiée FCM (Android + Web). Gère :
// - Initialisation Firebase Messaging
// - Permissions de notification
// - Récupération du token (et rotation via onTokenRefresh)
// - Réception des push :
//     * `type=call` ou `type=group_call` → délègue à CallKitService (mobile)
//       ou laisse le service worker afficher la notif (web)
//     * autres types (message, status_view, meeting_invite…) → notif locale
//       gérée par flutter_local_notifications (mobile uniquement, le SW gère
//       l'affichage côté web)
//
// IMPORTANT : pour fonctionner, ce service requiert :
// - main.dart : Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// - main.dart : @pragma('vm:entry-point') top-level firebaseMessagingBackgroundHandler
//   enregistré via FirebaseMessaging.onBackgroundMessage(...)
// - web/firebase-messaging-sw.js + manifest pour le PWA
// - AndroidManifest : POST_NOTIFICATIONS, FOREGROUND_SERVICE_PHONE_CALL, etc.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../talky_api_client.dart';
import 'callkit_service.dart';

/// VAPID key publique du projet Firebase (Web Push) — projet talky-2026.
/// Source : Firebase Console → Project Settings → Cloud Messaging → Web push
/// certificates. C'est une clé publique (pas un secret) — ok à committer.
/// Surchargeable au build avec `--dart-define=FIREBASE_VAPID_KEY=...` en cas
/// de rotation côté Firebase.
const String _kDefaultFirebaseVapidKey =
    'BBde_uFKtUbLFwAQZ0Kd5ENuaPD1LuRf2ZvvHMPZ3wigioZpjIf7a9rh3pFcI2TRYRrC1YmoiRnAJ4n8io5QBTk';
const String _kFirebaseVapidKey = String.fromEnvironment(
  'FIREBASE_VAPID_KEY',
  defaultValue: _kDefaultFirebaseVapidKey,
);

/// Handler invoqué par Firebase quand un message arrive alors que l'app est
/// tuée ou en background. Doit être un top-level / static, annoté
/// `@pragma('vm:entry-point')`. Voir main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type']?.toString();

  if (type == 'call' || type == 'group_call') {
    // Affiche l'écran d'appel système. Sur web, le service worker gère.
    if (!kIsWeb) {
      await CallKitService.instance.showIncoming(
        callId:      (data['callId'] ?? data['roomId'] ?? '').toString(),
        callerId:    (data['callerId'] ?? '').toString(),
        callerName:  (data['callerName'] ?? data['title'] ?? 'Appel').toString(),
        callerPhoto: data['photo']?.toString(),
        isVideo:     data['isVideo'] == 'true',
        roomId:      data['roomId']?.toString(),
      );
    }
  }
  // Les autres types sont affichés par le système (notification automatique
  // pour les messages avec `notification:` ; pour `data:` only, on les laisse
  // passer — l'app lira la queue au prochain démarrage).
}

class PushService {
  PushService._(this._apiClient);

  static PushService? _instance;
  static PushService get instance => _instance!;

  final TalkyApiClient _apiClient;

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  String? _token;
  String? get currentToken => _token;

  static Future<PushService> init(TalkyApiClient apiClient) async {
    _instance ??= PushService._(apiClient);
    await _instance!._setup();
    return _instance!;
  }

  Future<void> _setup() async {
    // 1. Permission utilisateur
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] ⚠️ Notifications refusées par l\'utilisateur');
      return;
    }

    // 2. Initialiser flutter_local_notifications (mobile uniquement) pour
    //    afficher les push foreground sur Android (sinon ils sont silencieux).
    if (!kIsWeb) {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _local.initialize(initSettings);
    }

    // 3. Récupérer le token et le pousser au backend
    try {
      _token = kIsWeb && _kFirebaseVapidKey.isNotEmpty
          ? await _fm.getToken(vapidKey: _kFirebaseVapidKey)
          : await _fm.getToken();
      debugPrint('[Push] Token: ${_token?.substring(0, 12)}…');
      if (_token != null) {
        await _safeUpdateToken(_token!);
      }
    } catch (e) {
      debugPrint('[Push] getToken error: $e');
    }

    // 4. Listener de rotation du token
    _onTokenRefreshSub = _fm.onTokenRefresh.listen((newToken) {
      _token = newToken;
      _safeUpdateToken(newToken);
    });

    // 5. Messages reçus app au premier plan
    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    // 6. App ouverte depuis une notif (background → tap)
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);

    // 7. Cas où l'app a été démarrée depuis une notif (terminated → tap)
    final initialMessage = await _fm.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedApp(initialMessage);
    }
  }

  Future<void> _safeUpdateToken(String token) async {
    try {
      await _apiClient.updateFcmToken(token);
      debugPrint('[Push] FCM token enregistré côté backend');
    } catch (e) {
      // Pas bloquant — l'utilisateur peut ne pas être encore loggé.
      debugPrint('[Push] updateFcmToken failed: $e');
    }
  }

  void _handleForeground(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();

    debugPrint('[Push] foreground: type=$type data=$data');

    if (type == 'call' || type == 'group_call') {
      // App au premier plan : pas de CallKit. L'event socket `incoming_call`
      // déclenche déjà IncomingCallScreen (plein écran) + RingtoneService.
      // CallKit en parallèle apporterait une sonnerie de notif additionnelle.
      return;
    }

    // Pour les autres types (message, status_view, meeting_invite…), afficher
    // une notification locale standard sur mobile. Sur web, le SW s'en charge.
    if (!kIsWeb) {
      final title = (data['title'] ?? message.notification?.title ?? '').toString();
      final body = (data['body'] ?? message.notification?.body ?? '').toString();
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

  void _handleOpenedApp(RemoteMessage message) {
    debugPrint('[Push] opened app from notif: ${message.data}');
    // Hook pour navigation deep-link future (ex: ouvrir la conversation,
    // l'écran de meeting, etc.). Pour l'instant juste log.
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}
