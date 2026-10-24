import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../theme/locale_controller.dart';
import 'call/call_terminal_guards.dart';
import 'call/ended_call_registry.dart';
import 'ringtone_preferences.dart';
import '../utils/contact_aliases.dart';

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

/// Identifiant métier d'un événement CallKit **terminal**, ou `null` si
/// l'événement n'en est pas un.
///
/// Extrait pour que la connaissance de la hiérarchie scellée de la 3.x tienne
/// dans ce fichier : `push_service` recopiait le même aiguillage sur l'ancienne
/// forme `{event, body}`.
///
/// Rend `''` quand l'événement est terminal mais sans identifiant exploitable —
/// l'appelant préférera alors se sentir concerné plutôt que de laisser une
/// sonnerie tourner indéfiniment.
String? terminalCallEventId(CallEvent event) {
  switch (event) {
    case CallEventActionCallAccept(:final callKitParams):
    case CallEventActionCallDecline(:final callKitParams):
    case CallEventActionCallEnded(:final callKitParams):
      final extra = callKitParams.extra ?? const {};
      return (extra['callId'] ?? callKitParams.id).toString();
    case CallEventActionCallTimeout(:final id):
      return id;
    default:
      return null;
  }
}

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

  /// callId dont CallKit présente **réellement** un entrant, ou `null`.
  ///
  /// À ne pas confondre avec [_lastShownCallId], qui ne retient que ce que
  /// *Dart* a demandé d'afficher. Sur Android V2 — le mode par défaut — ce
  /// n'est presque jamais Dart : le handler FCM sort avant d'afficher, et c'est
  /// `CallIncomingHelper` qui pose la notification côté Kotlin. Aucun code Dart
  /// ne le savait, et l'arbitrage de présentation était donc aveugle au cas le
  /// plus fréquent — d'où des écrans et des sonneries en double.
  ///
  /// La source est l'état que le plugin persiste dans ses préférences, lu par
  /// [getActiveCall]. Il est durable : il survit à la mort du processus, ce que
  /// ne fait aucun drapeau en mémoire, de part ni d'autre de la frontière.
  String? _nativeIncomingCallId;

  /// Voir [_nativeIncomingCallId].
  String? get nativeIncomingCallId => _nativeIncomingCallId;

  /// CallKit présente-t-il déjà un entrant pour [callId] ?
  ///
  /// Alimente le paramètre `isCallKitActive` de `decideIncomingPresentation`.
  bool isShowingIncoming(String? callId) {
    final id = callId?.trim() ?? '';
    if (id.isEmpty) return false;
    return id == _nativeIncomingCallId;
  }

  /// Relit l'état CallKit persisté et met [_nativeIncomingCallId] à jour.
  ///
  /// Appelée à l'initialisation et à chaque retour au premier plan : ce sont
  /// les deux instants où Dart peut avoir manqué un affichage natif.
  Future<void> refreshNativeIncomingState() async {
    if (kIsWeb) return;
    final active = await getActiveCall();
    final id = (active?['callId'] as String? ?? '').trim();
    // Un appel déjà accepté n'est plus un entrant à présenter.
    final accepted = active?['isAccepted'] == true;
    final next = (id.isNotEmpty && !accepted) ? id : null;
    if (next == _nativeIncomingCallId) return;
    _nativeIncomingCallId = next;
    debugPrint('[CallKit] entrant natif = ${next ?? "aucun"}');
  }

  static const _nativeCallChannel = MethodChannel('com.alanya/call_native');

  /// Fond de l'écran d'appel plein écran Android : volontairement transparent.
  ///
  /// Le dégradé de `IncomingCallScreen` est porté par le layout natif
  /// (res/layout/activity_callkit_incoming.xml) ; le plugin, lui, peint cette
  /// couleur en aplat par-dessus. Un aplat opaque effacerait donc la maquette.
  static const _callkitBackgroundColor = '#00000000';

  /// Couleur de texte de ce même écran, accordée à values/values-night.
  ///
  /// Le layout est une ressource Android : ses couleurs suivent le mode nuit
  /// du **système**, pas le `ThemeMode` choisi dans l'application (aucune
  /// ressource ne sait lire une préférence Flutter). Le texte étant le seul
  /// élément que le plugin repeint depuis Dart, on résout la même bascule —
  /// sinon un utilisateur en thème clair sur un système sombre lirait du texte
  /// sombre sur notre dégradé de nuit.
  static String get _callkitTextColor =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? '#FFFFFFFF' // CallUiColors.dark.onBackground
          : '#FF1A1D23'; // CallUiColors.light.onBackground

  /// Même règle que `CallService._isAppForeground`, et la même correction :
  /// un état encore inconnu est un arrière-plan. Ici l'enjeu est l'inverse du
  /// sien — `showIncoming` sort quand l'application est au premier plan, donc
  /// l'ancienne réponse faisait **taire** CallKit au démarrage à froid, sur
  /// tout chemin qui ne passe pas par l'affichage natif Android.
  bool _isAppForeground() =>
      appIsForeground(WidgetsBinding.instance.lifecycleState?.name);

  void setVoipTokenListener(void Function(String token)? listener) {
    _onVoipTokenUpdated = listener;
  }

  void setIncomingCallPreviewListener(
    void Function(IncomingCallAction action)? listener,
  ) {
    _onIncomingCallPreview = listener;
  }

  /// Dernier `extra` connu pour chaque entrée CallKit.
  ///
  /// La 3.x a typé ses événements, et deux d'entre eux — `timeout` et
  /// `connected` — ne portent plus que l'identifiant. Or le chemin `timeout`
  /// enfile un refus, et ce refus a besoin du `callerId`, qui vit dans
  /// `extra` : sans lui, l'appelant entendrait sonner jusqu'au délai serveur
  /// de 45 secondes.
  ///
  /// La carte est alimentée à l'affichage et à chaque relecture de l'état
  /// persisté. Elle est en mémoire, donc vide après une mort du processus —
  /// mais sur Android ce cas est déjà couvert par le listener `ACTIVE_CALLS`
  /// de `TalkyApplication`, qui lit `extra` côté natif et poste le refus.
  final Map<String, Map<String, dynamic>> _extraById = {};

  void _rememberExtra(String? id, Map<String, dynamic>? extra) {
    final key = id?.trim() ?? '';
    if (key.isEmpty || extra == null || extra.isEmpty) return;
    // Borne dure : une entrée par appel, et on ne garde pas un historique.
    if (_extraById.length > 8) _extraById.clear();
    _extraById[key] = Map<String, dynamic>.from(extra);
  }

  IncomingCallAction _actionFromParams(
    CallKitParams params,
    IncomingCallActionType actionType,
  ) {
    final extra = params.extra ?? _extraById[params.id.trim()] ?? const {};
    return IncomingCallAction(
      callId: (extra['callId'] ?? params.id).toString(),
      callerId: (extra['callerId'] ?? params.handle ?? '').toString(),
      callerName: (extra['callerName'] ?? params.nameCaller ?? '').toString(),
      callerPhoto: extra['callerPhoto']?.toString(),
      isVideo: extra['isVideo'] == true ||
          extra['isVideo'] == 'true' ||
          params.type == 1,
      roomId: extra['roomId']?.toString(),
      sessionKind: extra['sessionKind']?.toString(),
      mode: extra['mode']?.toString(),
      isOutgoing:
          extra['isOutgoing'] == true || extra['isOutgoing'] == 'true',
      action: actionType,
    );
  }

  /// Reconstruit une action à partir du seul identifiant, pour les événements
  /// que la 3.x a dépouillés. Voir [_extraById].
  IncomingCallAction _actionFromId(
    String id,
    IncomingCallActionType actionType,
  ) {
    final extra = _extraById[id.trim()] ?? const {};
    if (extra.isEmpty) {
      debugPrint(
        '[CallKit] ** $actionType sans extra connu pour $id — '
        'le refus repose sur le chemin natif',
      );
    }
    return IncomingCallAction(
      callId: (extra['callId'] ?? id).toString(),
      callerId: (extra['callerId'] ?? '').toString(),
      callerName: (extra['callerName'] ?? '').toString(),
      callerPhoto: extra['callerPhoto']?.toString(),
      isVideo: extra['isVideo'] == true || extra['isVideo'] == 'true',
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

    // Semer l'état natif : au démarrage à froid derrière un push, la
    // notification CallKit est déjà posée quand Dart démarre.
    //
    // Sans l'attendre — `init()` est sur le chemin critique du lancement, et un
    // canal de plateforme pas encore prêt le bloquerait. L'arbitrage du
    // démarrage à froid ne dépend pas de ce cache : `prepareIncomingFromCallKit`
    // sait par construction que CallKit possède l'entrée et le dit lui-même.
    unawaited(refreshNativeIncomingState());
    unawaited(_journaliserPleinEcran());
  }

  /// Signale si l'appel entrant peut encore s'afficher en plein écran.
  ///
  /// Depuis le 22 janvier 2025, Google Play révoque `USE_FULL_SCREEN_INTENT` à
  /// l'installation pour toute application qui n'a pas déclaré de
  /// fonctionnalité d'appel dans la Play Console. Sans elle, un appel arrivant
  /// téléphone verrouillé ne fait plus qu'une notification en bandeau : la
  /// dégradation est majeure et parfaitement silencieuse.
  ///
  /// Le plugin gère le repli tout seul depuis la 3.x — il vérifie et retombe
  /// sur une notification ordinaire. Ce qui manquait, c'est de le savoir. Le
  /// journal est le canal de diagnostic qui marche vraiment ici ; proposer à
  /// l'utilisateur d'aller la réaccorder (`requestFullIntentPermission`) est un
  /// geste d'interface, à faire depuis un écran de réglages, pas au démarrage.
  Future<void> _journaliserPleinEcran() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final autorise = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (autorise) {
        debugPrint('[CallKit] plein écran autorisé');
        return;
      }
      debugPrint(
        '[CallKit] ** plein écran REFUSÉ — un appel arrivant téléphone '
        'verrouillé ne fera qu\'une notification. Déclaration d\'appel '
        'manquante en Play Console, ou permission retirée par l\'utilisateur.',
      );
    } catch (e) {
      debugPrint('[CallKit] canUseFullScreenIntent: $e');
    }
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
    // L'écran d'appel du système affiche mon nom personnalisé. Hors de
    // l'isolate principal (push reçu app fermée), le registre se relit du disque.
    await ContactAliases.preload();
    callerName = ContactAliases.nameFor(int.tryParse(callerId), callerName);

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
    // Le natif présente peut-être déjà cet appel sans que Dart l'ait demandé —
    // c'est le cas ordinaire sur Android, où la notification vient du push.
    // Le réafficher relance la sonnerie du plugin et, pire, remet l'entrée
    // CallKit à « non décrochée » : tout ce qui suit la prend alors pour un
    // refus. `_lastShownCallId` ne retient que ce que Dart a demandé, d'où
    // cette seconde garde.
    if (id.isNotEmpty && id == _nativeIncomingCallId) {
      debugPrint('[CallKit] showIncoming ignoré (déjà présenté par le natif): $id');
      return;
    }
    if (id.isNotEmpty) {
      final actif = await getActiveCall();
      final actifId = (actif?['callId'] as String?)?.trim() ?? '';
      if (actifId == id && actif?['isAccepted'] == true) {
        debugPrint('[CallKit] showIncoming ignoré (déjà décroché): $id');
        return;
      }
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
    if (id.isNotEmpty) {
      _lastShownCallId = id;
      _nativeIncomingCallId = id;
    }

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
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: l10n.callMissed,
        callbackText: l10n.commonCallBack,
      ),
      // Android : ne PAS démarrer le foreground service au tap « Accepter » —
      // le service ne peut pas honorer startForeground() si l'engine Flutter
      // n'est pas encore attaché (crash ForegroundServiceDidNotStartInTime).
      // Le FGS légitime est `CallMediaForegroundService`, démarré par
      // `CallSessionGuard.acquire` une fois l'appel répondu, engine prêt. Même
      // contrat que le chemin natif (CallIncomingHelper.buildIncomingBundle).
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
        // Depuis la 3.x, les libellés des boutons appartiennent aux paramètres
        // Android — ils étaient à la racine de `CallKitParams`.
        textAccept: l10n.commonAccept,
        textDecline: l10n.commonDecline,
        // 'silence' = res/raw/silence.wav → CallKit reste muet (le plugin
        // interprète '' comme « sonnerie système par défaut », pas comme muet).
        // La sonnerie importée est alors jouée par RingtoneService (Flutter) ou
        // CustomRingtonePlayer (natif) selon le cycle de vie de l'app.
        ringtonePath: silent ? 'silence' : RingtonePreferences.resolveAndroidCallKitRingtone(),
        backgroundColor: _callkitBackgroundColor,
        textColor: _callkitTextColor,
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
  /// Marque toujours le dismiss comme programmatique avant `endCall`, sinon le
  /// listener natif interprète le retrait comme un refus utilisateur → reject.
  Future<void> dismissIncomingUiSilently({String? callId}) async {
    if (kIsWeb) return;
    final id = (callId ?? _lastShownCallId ?? '').trim();
    if (id.isEmpty) return;
    await _markProgrammaticDismissNative([id]);
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
    if (id == _nativeIncomingCallId) _nativeIncomingCallId = null;
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
      // Deux notifications s'affichaient pendant chaque appel, des deux côtés.
      // Android en impose une par service au premier plan, et il en démarrait
      // deux : le nôtre (`CallMediaForegroundService`, lancé juste avant par
      // `CallSessionGuard.acquire`) et celui du plugin, que cet appel-ci
      // déclenchait — le drapeau absent vaut `true` par défaut.
      //
      // On garde le nôtre : il porte le type `phoneCall`, dont dépend le micro
      // quand l'écran s'éteint, et il s'arrête au balayage depuis les récents,
      // ce que celui du plugin ne fait pas (`stopWithTask="false"`).
      //
      // Ceci n'ôte que la notification : `registerTelecomOutgoingCall` s'exécute
      // avant elle et sans condition, donc l'appel reste déclaré à Telecom — ce
      // dont dépend le routage du haut-parleur (voir `TelecomAudioRouter`).
      callingNotification: const NotificationParams(showNotification: false),
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
        backgroundColor: _callkitBackgroundColor,
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
      if (id == _nativeIncomingCallId) {
        _nativeIncomingCallId = null;
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

  /// Ferme les entrées CallKit — **celle de [callId] seule si elle est nommée**.
  ///
  /// `endAllCalls()` retire TOUTES les entrées sans considération d'identifiant,
  /// et cette méthode est appelée partout sur les chemins push et CallKit :
  /// refus depuis la notification, entrée invalide ou périmée, fin externe. Une
  /// réunion en cours en arrière-plan y perdait son entrée `meeting_<id>` — donc
  /// sa notification, son chronomètre, son retour depuis le tiroir — au moindre
  /// appel refusé à côté. Et l'écouteur `ACTIVE_CALLS` arrête le service du
  /// plugin dès que la liste se vide.
  ///
  /// Quand l'appelant sait quel appel il ferme, il n'y a aucune raison
  /// d'emporter les autres. Le nettoyage global reste accessible en appelant
  /// sans identifiant — c'est ce que fait `purgeStaleActiveCalls`.
  Future<void> endAll({String? callId}) async {
    if (kIsWeb) return;
    final id = callId?.trim() ?? '';
    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
      if (id == _lastShownCallId) _lastShownCallId = null;
      if (id == _nativeIncomingCallId) _nativeIncomingCallId = null;
      await _markProgrammaticDismissNative([id]);
      try {
        await FlutterCallkitIncoming.endCall(id);
      } catch (e) {
        debugPrint('[CallKit] endAll(ciblé) error: $e');
      }
      return;
    }
    _lastShownCallId = null;
    _nativeIncomingCallId = null;
    // endAllCalls retire TOUTES les entrées ACTIVE_CALLS : marquer chacune
    // comme retrait programmatique, pas seulement [callId].
    final toMark = <String>{if (id.isNotEmpty) id};
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      {
        for (final c in calls) {
          final cid = c.id.trim();
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

  /// Aiguillage des événements CallKit.
  ///
  /// La 3.x remplace `{event: Event, body: Map}` par une hiérarchie scellée :
  /// chaque événement porte ce qu'il a vraiment, et le compilateur vérifie
  /// qu'on les traite tous. Deux d'entre eux ne portent plus que
  /// l'identifiant — voir [_extraById] pour ce que ça coûtait et comment on
  /// le rattrape.
  void _handleEvent(CallEvent event) {
    switch (event) {
      case CallEventActionDidUpdateDevicePushTokenVoip():
        // Le jeton ne voyage plus dans l'événement : il se demande.
        unawaited(_relayerJetonVoip());
        return;

      case CallEventActionCallIncoming(:final callKitParams):
        _rememberExtra(callKitParams.id, callKitParams.extra);
        final action = _actionFromParams(
          callKitParams,
          IncomingCallActionType.incomingPreview,
        );
        debugPrint('[CallKit] incoming preview callId=${action.callId}');
        _onIncomingCallPreview?.call(action);
        return;

      case CallEventActionCallAccept(:final callKitParams):
        _rememberExtra(callKitParams.id, callKitParams.extra);
        _emettre(_actionFromParams(
          callKitParams,
          IncomingCallActionType.accept,
        ));
        return;

      case CallEventActionCallDecline(:final callKitParams):
        _rememberExtra(callKitParams.id, callKitParams.extra);
        _emettre(_actionFromParams(
          callKitParams,
          IncomingCallActionType.decline,
        ));
        return;

      case CallEventActionCallEnded(:final callKitParams):
        _rememberExtra(callKitParams.id, callKitParams.extra);
        _emettre(_actionFromParams(
          callKitParams,
          IncomingCallActionType.ended,
        ));
        return;

      case CallEventActionCallTimeout(:final id):
        // Sonnerie expirée : compte comme un refus, et ce refus a besoin du
        // `callerId` que cet événement ne porte plus.
        _emettre(_actionFromId(id, IncomingCallActionType.timeout));
        return;

      // Rien à faire ici : `start` est notre propre sortant, `connected` est
      // déjà su, et les bascules muet/attente/DTMF/groupe ne nous concernent
      // pas — l'appel est piloté par notre propre interface.
      case CallEventActionCallStart():
      case CallEventActionCallConnected():
      case CallEventActionCallCallback():
      case CallEventActionCallToggleHold():
      case CallEventActionCallToggleMute():
      case CallEventActionCallToggleDmtf():
      case CallEventActionCallToggleGroup():
      case CallEventActionCallToggleAudioSession():
      case CallEventActionCallCustom():
        return;
    }
  }

  Future<void> _relayerJetonVoip() async {
    try {
      final token = (await FlutterCallkitIncoming.getDevicePushTokenVoIP())
              ?.trim() ??
          '';
      if (token.isEmpty) return;
      debugPrint('[CallKit] voip token reçu len=${token.length}');
      _onVoipTokenUpdated?.call(token);
    } catch (e) {
      debugPrint('[CallKit] getDevicePushTokenVoIP: $e');
    }
  }

  /// Exclusif, pas cumulatif : avec un listener actif, l'action part par le
  /// stream UNIQUEMENT. La stocker aussi en pending la ferait traiter deux
  /// fois (stream immédiat + consumePendingAction au bootstrap) → double
  /// accept/reject. Sans listener (événement avant _bootstrap), pending est
  /// le seul canal et sera consommé au démarrage.
  void _emettre(IncomingCallAction action) {
    debugPrint('[CallKit] event=${action.action} callId=${action.callId}');
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
      // La 3.x rend des `CallKitParams` typés là où la 2.x rendait des `Map`.
      // Le code lisait `raw as Map?` : compilable — rien n'interdit à un
      // sous-type d'implémenter `Map` — mais il aurait levé à chaque appel, et
      // celui-ci est central : démarrage à froid, relecture de l'état natif,
      // purge des entrées résiduelles.
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls.isEmpty) return null;

      CallKitParams? best;
      var bestShownAt = -1;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final c in calls) {
        final extra = c.extra ?? const {};
        final shownAt = int.tryParse('${extra['shownAt'] ?? ''}') ?? 0;
        if (shownAt > 0) {
          final age = now - shownAt;
          final maxAge = c.isAccepted
              ? _maxAcceptedAge.inMilliseconds
              : _maxUnacceptedAge.inMilliseconds;
          if (age > maxAge) {
            debugPrint(
              '[CallKit] entrée périmée ignorée '
              '(age=${age ~/ 1000}s accepted=${c.isAccepted}): ${c.id}',
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
      final extra = best.extra ?? const {};
      // Le natif a pu poser cette entrée sans que Dart le sache : c'est aussi
      // ici qu'on récupère son `extra`, dont dépendent les événements que la
      // 3.x ne porte plus qu'avec un identifiant.
      _rememberExtra(best.id, best.extra);
      return {
        'callId':      (extra['callId'] ?? best.id).toString(),
        'callerId':    (extra['callerId'] ?? best.handle ?? '').toString(),
        'callerName':  (extra['callerName'] ?? best.nameCaller ?? '').toString(),
        'callerPhoto': extra['callerPhoto']?.toString(),
        'isVideo':     extra['isVideo'] == true || extra['isVideo'] == 'true',
        'roomId':      extra['roomId']?.toString(),
        'sessionKind': extra['sessionKind']?.toString(),
        'mode':        extra['mode']?.toString(),
        'isOutgoing':  extra['isOutgoing'] == true || extra['isOutgoing'] == 'true',
        'isAccepted':  best.isAccepted,
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
      if (calls.isNotEmpty) {
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
