import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../theme/locale_controller.dart';
import 'call/ended_call_registry.dart';
import 'ringtone_preferences.dart';

class IncomingCallAction {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final String? roomId;
  final String? sessionKind;
  final String? mode;
  final bool isOutgoing;
  final IncomingCallActionType action;

  IncomingCallAction({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.isVideo,
    required this.roomId,
    this.sessionKind,
    this.mode,
    this.isOutgoing = false,
    required this.action,
  });

  bool get isConference =>
      sessionKind == 'conference' ||
      callId.startsWith('conf_') ||
      (roomId != null && roomId!.startsWith('conf_'));
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

  static const _nativeCallChannel = MethodChannel('com.alanya/call_native');

  bool _isAppForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

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
      sessionKind: extra['sessionKind']?.toString(),
      mode: extra['mode']?.toString(),
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
    String? sessionKind,
    String? mode,
    bool silent = false,
  }) async {
    if (kIsWeb) return;

    if (_isAppForeground()) {
      debugPrint('[CallKit] showIncoming ignoré (app au premier plan)');
      return;
    }

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
      // Sous le timeout serveur (45 s) : la notif expire avant le « sans réponse ».
      duration: 40000,
      textAccept: l10n.commonAccept,
      textDecline: l10n.commonDecline,
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: l10n.callMissed,
        callbackText: l10n.commonCallBack,
      ),
      // Android : ne PAS démarrer le foreground service au tap « Accepter » —
      // le service ne peut pas honorer startForeground() si l'engine Flutter
      // n'est pas encore attaché (crash ForegroundServiceDidNotStartInTime).
      // Le FGS légitime est démarré par [startOutgoingCall] une fois l'appel
      // répondu, engine prêt. Même contrat que le chemin natif
      // (CallIncomingHelper.buildIncomingBundle).
      callingNotification: const NotificationParams(showNotification: false),
      extra: {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerPhoto': callerPhoto ?? '',
        'isVideo': isVideo,
        'roomId': roomId ?? '',
        if (sessionKind != null && sessionKind.isNotEmpty)
          'sessionKind': sessionKind,
        if (mode != null && mode.isNotEmpty) 'mode': mode,
        // Fraîcheur pour le cold start (voir getActiveCall) : une entrée
        // résiduelle ne doit jamais rejouer un accept/écran entrant fantôme.
        'shownAt': DateTime.now().millisecondsSinceEpoch,
      },
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        // 'silence' = res/raw/silence.wav → CallKit reste muet (le plugin
        // interprète '' comme « sonnerie système par défaut », pas comme muet).
        // La sonnerie importée est alors jouée par RingtoneService (Flutter) ou
        // CustomRingtonePlayer (natif) selon le cycle de vie de l'app.
        ringtonePath: silent ? 'silence' : RingtonePreferences.resolveAndroidCallKitRingtone(),
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: l10n.incomingCallsChannel,
        missedCallNotificationChannelName: l10n.missedCalls,
        isShowFullLockedScreen: true,
      ),
      ios: IOSParams(
        // null → CallKit garde sa sonnerie par défaut (seules les sonneries
        // "bundled" déclarées côté natif peuvent être résolues ici, voir
        // RingtoneOption.iosCafResource).
        ringtonePath: silent ? null : RingtonePreferences.resolveIosCallKitRingtone(),
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Retire la notif CallKit sans marquer l'appel terminé ni déclencher un refus
  /// côté natif (voir [CallDismissRegistry]).
  Future<void> dismissIncomingUiSilently({String? callId}) async {
    if (kIsWeb) return;
    final id = (callId ?? _lastShownCallId ?? '').trim();
    if (id.isEmpty) return;
    if (Platform.isAndroid) {
      try {
        await _nativeCallChannel.invokeMethod<void>(
          'dismissIncomingSilently',
          {'callId': id},
        );
      } catch (e) {
        debugPrint('[CallKit] dismissIncomingSilently native: $e');
      }
    }
    if (id == _lastShownCallId) _lastShownCallId = null;
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (e) {
      debugPrint('[CallKit] dismissIncomingUiSilently error: $e');
    }
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
        'shownAt': DateTime.now().millisecondsSinceEpoch,
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
    await _markProgrammaticDismissNative([id]);
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[CallKit] endCall error: $e');
    }
  }

  /// Préviens le natif que ces retraits CallKit viennent de Flutter (fin
  /// d'appel, nettoyage cold start, anti-doublon) et non d'un refus utilisateur.
  /// Sans ce marquage, le listener ACTIVE_CALLS de TalkyApplication interprète
  /// tout retrait non accepté comme un refus → POST /calls/reject qui peut tuer
  /// un appel réellement en train de sonner (reject fratricide).
  Future<void> _markProgrammaticDismissNative(List<String> callIds) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final ids = callIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;
    try {
      await _nativeCallChannel.invokeMethod<void>(
        'markProgrammaticDismiss',
        {'callIds': ids},
      );
    } catch (e) {
      debugPrint('[CallKit] markProgrammaticDismiss native: $e');
    }
  }

  Future<void> endAll({String? callId}) async {
    if (kIsWeb) return;
    final id = callId?.trim() ?? '';
    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
    }
    _lastShownCallId = null;
    // endAllCalls retire TOUTES les entrées ACTIVE_CALLS : marquer chacune
    // comme retrait programmatique, pas seulement [callId].
    final toMark = <String>{if (id.isNotEmpty) id};
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List) {
        for (final c in calls) {
          final cid = ((c as Map?)?['id'] ?? '').toString().trim();
          if (cid.isNotEmpty) toMark.add(cid);
        }
      }
    } catch (e) {
      debugPrint('[CallKit] activeCalls (endAll) error: $e');
    }
    await _markProgrammaticDismissNative(toMark.toList());
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
    // Exclusif, pas cumulatif : avec un listener actif, l'action part par le
    // stream UNIQUEMENT. La stocker aussi en pending la ferait traiter deux
    // fois (stream immédiat + consumePendingAction au bootstrap) → double
    // accept/reject. Sans listener (événement avant _bootstrap), pending est
    // le seul canal et sera consommé au démarrage.
    if (_actions.hasListener) {
      _actions.add(action);
    } else {
      _pendingAction = action;
    }
  }

  IncomingCallAction? consumePendingAction() {
    final p = _pendingAction;
    _pendingAction = null;
    return p;
  }

  /// Âge maximal d'une entrée non acceptée pour être rejouée au cold start :
  /// au-delà de la sonnerie (40 s) + marge, c'est un débris.
  static const _maxUnacceptedAge = Duration(seconds: 90);

  /// Âge maximal d'une entrée acceptée : passé ce délai, le process est mort en
  /// plein appel (crash/kill) et rejouer l'auto-réponse produirait un appel
  /// fantôme (l'appelant a raccroché depuis longtemps).
  static const _maxAcceptedAge = Duration(minutes: 3);

  /// Métadonnées de l'appel CallKit actif le plus récent et encore plausible.
  /// Sert au démarrage à froid quand l'événement accept/decline est perdu :
  /// - [isAccepted] true → bouton « Accepter » tapé avant le boot Flutter
  /// - [isAccepted] false → corps de notif tapé, afficher l'écran d'appel entrant
  /// Les entrées trop vieilles (débris d'un appel précédent, process tué en
  /// plein appel) sont ignorées — le nettoyage de main.dart les retirera.
  /// Retourne null si aucun appel actif plausible.
  Future<Map<String, dynamic>?> getActiveCall() async {
    if (kIsWeb) return null;
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List || calls.isEmpty) return null;

      Map? best;
      var bestShownAt = -1;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final raw in calls) {
        final c = raw as Map?;
        if (c == null) continue;
        final extra = (c['extra'] as Map?) ?? const {};
        final accepted = c['isAccepted'] == true || c['isAccepted'] == 'true';
        final shownAt = int.tryParse('${extra['shownAt'] ?? ''}') ?? 0;
        if (shownAt > 0) {
          final age = now - shownAt;
          final maxAge =
              accepted ? _maxAcceptedAge.inMilliseconds : _maxUnacceptedAge.inMilliseconds;
          if (age > maxAge) {
            debugPrint(
              '[CallKit] entrée périmée ignorée (age=${age ~/ 1000}s accepted=$accepted): ${c['id']}',
            );
            continue;
          }
        }
        // Entrées sans shownAt (anciennes versions, iOS) : conservées, mais un
        // candidat horodaté plus récent gagne toujours.
        if (best == null || shownAt > bestShownAt) {
          best = c;
          bestShownAt = shownAt;
        }
      }
      if (best == null) return null;
      final extra = (best['extra'] as Map?) ?? const {};
      return {
        'callId':      (extra['callId'] ?? best['id'] ?? '').toString(),
        'callerId':    (extra['callerId'] ?? best['handle'] ?? '').toString(),
        'callerName':  (extra['callerName'] ?? best['nameCaller'] ?? '').toString(),
        'callerPhoto': extra['callerPhoto']?.toString(),
        'isVideo':     extra['isVideo'] == true || extra['isVideo'] == 'true',
        'roomId':      extra['roomId']?.toString(),
        'sessionKind': extra['sessionKind']?.toString(),
        'mode':        extra['mode']?.toString(),
        'isOutgoing':  extra['isOutgoing'] == true || extra['isOutgoing'] == 'true',
        'isAccepted':  best['isAccepted'] == true || best['isAccepted'] == 'true',
      };
    } catch (e) {
      debugPrint('[CallKit] activeCalls error: $e');
    }
    return null;
  }

  /// Purge silencieuse des entrées CallKit résiduelles au démarrage, quand
  /// [getActiveCall] n'a rien retourné de plausible. Passe par [endAll], donc
  /// marquée programmatique côté natif : aucun POST /calls/reject déclenché.
  Future<void> purgeStaleActiveCalls() async {
    if (kIsWeb) return;
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        debugPrint('[CallKit] purge de ${calls.length} entrée(s) périmée(s)');
        await endAll();
      }
    } catch (e) {
      debugPrint('[CallKit] purgeStaleActiveCalls error: $e');
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _actions.close();
  }
}
