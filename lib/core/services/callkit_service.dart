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
  IncomingCallAction? _pendingAction;

  Future<void> init() async {
    if (kIsWeb) return;

    _eventSub ??= FlutterCallkitIncoming.onEvent.listen((event) {
      if (event != null) _handleEvent(event);
    });
  }

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
      appName: 'Alanya',
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
        ringtonePath: silent ? '' : 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Appels entrants',
        missedCallNotificationChannelName: 'Appels manqués',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Démarre un appel sortant / réunion — active le foreground service Android.
  Future<void> startOutgoingCall({
    required String callId,
    required String displayName,
    required String handle,
    required bool isVideo,
  }) async {
    if (kIsWeb) return;

    final params = CallKitParams(
      id: callId,
      nameCaller: displayName,
      appName: 'Alanya',
      handle: handle,
      type: isVideo ? 1 : 0,
      duration: 0,
      extra: {
        'callId': callId,
        'callerName': displayName,
        'isVideo': isVideo,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: '',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Appels en cours',
        missedCallNotificationChannelName: 'Appels manqués',
      ),
    );

    try {
      await FlutterCallkitIncoming.startCall(params);
      debugPrint('[CallKit] startCall callId=$callId');
    } catch (e) {
      debugPrint('[CallKit] startCall error: $e');
    }
  }

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

  IncomingCallAction? consumePendingAction() {
    final p = _pendingAction;
    _pendingAction = null;
    return p;
  }

  /// Métadonnées du 1er appel CallKit encore actif (entrant non décliné/terminé).
  /// Sert au démarrage à froid quand l'utilisateur a tapé le corps de la notif
  /// (aucun event accept/decline n'est émis) : permet d'afficher l'écran d'appel.
  /// Retourne null si aucun appel actif.
  Future<Map<String, dynamic>?> getActiveCall() async {
    if (kIsWeb) return null;
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final c = calls.first as Map?;
        if (c == null) return null;
        final extra = (c['extra'] as Map?) ?? const {};
        return {
          'callId':      (extra['callId'] ?? c['id'] ?? '').toString(),
          'callerId':    (extra['callerId'] ?? c['handle'] ?? '').toString(),
          'callerName':  (extra['callerName'] ?? c['nameCaller'] ?? '').toString(),
          'callerPhoto': extra['callerPhoto']?.toString(),
          'isVideo':     extra['isVideo'] == true || extra['isVideo'] == 'true',
          'roomId':      extra['roomId']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('[CallKit] activeCalls error: $e');
    }
    return null;
  }

  void dispose() {
    _eventSub?.cancel();
    _actions.close();
  }
}
