// callkit_service.dart
//
// Wrapper autour de flutter_callkit_incoming pour afficher un écran d'appel
// système (Android ConnectionService) quand un FCM data-only `type=call`
// arrive — y compris quand l'app est tuée ou en background.
//
// Web : non supporté par flutter_callkit_incoming. PushService gère les
// notifications Web via le service worker (web/firebase-messaging-sw.js).

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class IncomingCallAction {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final String? roomId;
  final IncomingCallActionType action;

  IncomingCallAction({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.isVideo,
    required this.roomId,
    required this.action,
  });
}

enum IncomingCallActionType { accept, decline, timeout, ended }

class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  final StreamController<IncomingCallAction> _actions =
      StreamController<IncomingCallAction>.broadcast();

  Stream<IncomingCallAction> get actions => _actions.stream;

  StreamSubscription? _eventSub;

  // Quand l'app est tuée et que l'user clique "Accepter" sur CallKit, l'event
  // arrive AVANT que les listeners Dart de AuthWrapper soient prêts. On stocke
  // le dernier event "actionnable" pour qu'il soit consommé après init.
  IncomingCallAction? _pendingAction;

  Future<void> init() async {
    if (kIsWeb) return;

    _eventSub ??= FlutterCallkitIncoming.onEvent.listen((event) {
      if (event != null) _handleEvent(event);
    });
  }

  /// Affiche l'écran d'appel système. À appeler depuis le handler FCM
  /// (foreground et background) sur réception d'un push `type=call|group_call`.
  ///
  /// [silent] : true en foreground pour afficher la notif visuelle sans
  /// jouer la sonnerie CallKit (le RingtoneService de l'app gère la sonnerie
  /// ; ça évite le doublon). False en background → CallKit joue la sonnerie
  /// système puisque l'app n'a pas la main pour le faire.
  Future<void> showIncoming({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
    bool silent = false,
  }) async {
    if (kIsWeb) return;

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Talky',
      avatar: callerPhoto,
      handle: callerId,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accepter',
      textDecline: 'Refuser',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Appel manqué',
        callbackText: 'Rappeler',
      ),
      extra: {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerPhoto': callerPhoto ?? '',
        'isVideo': isVideo,
        'roomId': roomId ?? '',
      },
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        // En mode silent, on passe une chaîne vide → CallKit n'attaque pas
        // la sonnerie système. Le RingtoneService de l'app reste seul à jouer.
        ringtonePath: silent ? '' : 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Appels entrants',
        missedCallNotificationChannelName: 'Appels manqués',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Transitionne la notif CallKit en mode "appel en cours" (durée qui défile,
  /// plus de boutons Accept/Decline). À appeler dès que CallStatus == connected.
  Future<void> setConnected(String callId) async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      debugPrint('[CallKit] setCallConnected error: $e');
    }
  }

  Future<void> endCall(String callId) async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallKit] endCall error: $e');
    }
  }

  Future<void> endAll() async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] endAllCalls error: $e');
    }
  }

  void _handleEvent(CallEvent event) {
    final extra = event.body['extra'] as Map? ?? const {};
    IncomingCallActionType? actionType;

    switch (event.event) {
      case Event.actionCallAccept:
        actionType = IncomingCallActionType.accept;
        break;
      case Event.actionCallDecline:
      case Event.actionCallEnded:
        actionType = IncomingCallActionType.decline;
        break;
      case Event.actionCallTimeout:
        actionType = IncomingCallActionType.timeout;
        break;
      default:
        return;
    }

    debugPrint('[CallKit] event=$actionType callId=${extra['callId']}');

    final action = IncomingCallAction(
      callId:      (extra['callId'] ?? event.body['id'] ?? '').toString(),
      callerId:    (extra['callerId'] ?? '').toString(),
      callerName:  (extra['callerName'] ?? '').toString(),
      callerPhoto: extra['callerPhoto']?.toString(),
      isVideo:     extra['isVideo'] == true || extra['isVideo'] == 'true',
      roomId:      extra['roomId']?.toString(),
      action:      actionType,
    );
    _pendingAction = action;
    _actions.add(action);
  }

  /// À appeler depuis main/AuthWrapper après init pour récupérer un éventuel
  /// event arrivé avant que le listener Dart soit prêt (cas typique : l'app
  /// est lancée par un tap "Accepter" sur la notif CallKit alors qu'elle était
  /// tuée).
  IncomingCallAction? consumePendingAction() {
    final p = _pendingAction;
    _pendingAction = null;
    return p;
  }

  void dispose() {
    _eventSub?.cancel();
    _actions.close();
  }
}
