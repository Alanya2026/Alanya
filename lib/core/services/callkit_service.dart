import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../theme/locale_controller.dart';
import 'call/ended_call_registry.dart';

class IncomingCallAction {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final String? roomId;
  final bool isOutgoing;
  final IncomingCallActionType action;

  IncomingCallAction({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.isVideo,
    required this.roomId,
    this.isOutgoing = false,
    required this.action,
  });
}

enum IncomingCallActionType { incomingPreview, accept, decline, timeout, ended }

class CallKitService {
  CallKitService._();
  static final CallKitService instance = CallKitService._();

  final StreamController<IncomingCallAction> _actions =
      StreamController<IncomingCallAction>.broadcast();

  Stream<IncomingCallAction> get actions => _actions.stream;

  StreamSubscription? _eventSub;
  IncomingCallAction? _pendingAction;
  void Function(String token)? _onVoipTokenUpdated;
  void Function(IncomingCallAction action)? _onIncomingCallPreview;

  /// Dernier callId pour lequel [showIncoming] a été appelé (anti-doublon
  /// FCM + socket en arrière-plan).
  String? _lastShownCallId;

  void setVoipTokenListener(void Function(String token)? listener) {
    _onVoipTokenUpdated = listener;
  }

  void setIncomingCallPreviewListener(
    void Function(IncomingCallAction action)? listener,
  ) {
    _onIncomingCallPreview = listener;
  }

  IncomingCallAction _parseCallAction(
    CallEvent event,
    IncomingCallActionType actionType,
  ) {
    final extra = event.body['extra'] as Map? ?? const {};
    return IncomingCallAction(
      callId: (extra['callId'] ?? event.body['id'] ?? '').toString(),
      callerId: (extra['callerId'] ?? event.body['handle'] ?? '').toString(),
      callerName: (extra['callerName'] ?? event.body['nameCaller'] ?? '')
          .toString(),
      callerPhoto: extra['callerPhoto']?.toString(),
      isVideo: extra['isVideo'] == true ||
          extra['isVideo'] == 'true' ||
          event.body['type'] == 1,
      roomId: extra['roomId']?.toString(),
      isOutgoing:
          extra['isOutgoing'] == true || extra['isOutgoing'] == 'true',
      action: actionType,
    );
  }

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

    final id = callId.trim();
    if (id.isNotEmpty && await EndedCallRegistry.isEnded(id)) {
      debugPrint('[CallKit] showIncoming ignoré (callId terminé): $id');
      return;
    }
    if (id.isNotEmpty && id == _lastShownCallId) {
      debugPrint('[CallKit] showIncoming ignoré (déjà affiché): $id');
      return;
    }
    if (id.isNotEmpty &&
        _lastShownCallId != null &&
        _lastShownCallId!.isNotEmpty &&
        _lastShownCallId != id) {
      debugPrint(
        '[CallKit] collision appels: fin de $_lastShownCallId avant $id',
      );
      await endCall(_lastShownCallId!);
    }
    if (id.isNotEmpty) _lastShownCallId = id;

    final l10n = resolveL10n();
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: l10n.appTitle,
      avatar: callerPhoto,
      handle: callerId,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: l10n.commonAccept,
      textDecline: l10n.commonDecline,
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: l10n.callMissed,
        callbackText: l10n.commonCallBack,
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
        incomingCallNotificationChannelName: l10n.incomingCallsChannel,
        missedCallNotificationChannelName: l10n.missedCalls,
        isShowFullLockedScreen: true,
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

    final l10n = resolveL10n();
    final params = CallKitParams(
      id: callId,
      nameCaller: displayName,
      appName: l10n.appTitle,
      handle: handle,
      type: isVideo ? 1 : 0,
      duration: 0,
      extra: {
        'callId': callId,
        'callerId': handle,
        'callerName': displayName,
        'isVideo': isVideo,
        'isOutgoing': true,
      },
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: '',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: l10n.ongoingCallsChannel,
        missedCallNotificationChannelName: l10n.missedCalls,
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
      await FlutterCallkitIncoming.setCallConnected(callId)
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('[CallKit] setCallConnected timeout callId=$callId');
    } catch (e) {
      debugPrint('[CallKit] setCallConnected error: $e');
    }
  }

  Future<void> endCall(String callId) async {
    if (kIsWeb) return;
    final id = callId.trim();
    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
      if (id == _lastShownCallId) {
        _lastShownCallId = null;
      }
    }
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallKit] endCall error: $e');
    }
  }

  Future<void> endAll({String? callId}) async {
    if (kIsWeb) return;
    final id = callId?.trim() ?? '';
    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
    }
    _lastShownCallId = null;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] endAllCalls error: $e');
    }
  }

  void _handleEvent(CallEvent event) {
    if (event.event == Event.actionDidUpdateDevicePushTokenVoip) {
      final token = event.body['deviceTokenVoIP']?.toString().trim() ?? '';
      if (token.isNotEmpty) {
        debugPrint('[CallKit] voip token reçu len=${token.length}');
        _onVoipTokenUpdated?.call(token);
      }
      return;
    }

    if (event.event == Event.actionCallIncoming) {
      final action = _parseCallAction(event, IncomingCallActionType.incomingPreview);
      debugPrint('[CallKit] incoming preview callId=${action.callId}');
      _onIncomingCallPreview?.call(action);
      return;
    }

    IncomingCallActionType? actionType;

    switch (event.event) {
      case Event.actionCallAccept:
        actionType = IncomingCallActionType.accept;
        break;
      case Event.actionCallDecline:
        actionType = IncomingCallActionType.decline;
        break;
      case Event.actionCallEnded:
        actionType = IncomingCallActionType.ended;
        break;
      case Event.actionCallTimeout:
        actionType = IncomingCallActionType.timeout;
        break;
      default:
        return;
    }

    debugPrint('[CallKit] event=$actionType callId=${event.body['id']}');

    final action = _parseCallAction(event, actionType);
    _pendingAction = action;
    _actions.add(action);
  }

  IncomingCallAction? consumePendingAction() {
    final p = _pendingAction;
    _pendingAction = null;
    return p;
  }

  /// Métadonnées du 1er appel CallKit encore actif (entrant non décliné/terminé).
  /// Sert au démarrage à froid quand l'événement accept/decline est perdu :
  /// - [isAccepted] true → bouton « Accepter » tapé avant le boot Flutter
  /// - [isAccepted] false → corps de notif tapé, afficher l'écran d'appel entrant
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
          'isOutgoing':  extra['isOutgoing'] == true || extra['isOutgoing'] == 'true',
          'isAccepted':  c['isAccepted'] == true || c['isAccepted'] == 'true',
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
