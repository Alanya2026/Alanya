// Entrées d'appel entrant via push / CallKit (part of call_service.dart).
part of '../call_service.dart';

extension CallIncoming on CallService {
  Future<void> acceptIncomingCallFromPush({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) async {
    debugPrint('[CallService] 📲 acceptIncomingCallFromPush callId=$callId caller=$callerId');

    if (callId.isNotEmpty &&
        (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId))) {
      debugPrint('[CallService] 🛡 acceptIncoming ignoré (callId terminé): $callId');
      await _callKit.endAll(callId: callId);
      return;
    }

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    _remoteUserId = int.tryParse(callerId);
    _remoteUserName = callerName;
    _remoteUserPhoto = normalizeBackendUrl(callerPhoto);
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _autoAnswerOnNextIncoming = true;
    _autoAnswerCallerId = callerId;
    // Accepté depuis la notification/CallKit : on saute IncomingCallScreen et on
    // ouvre directement l'écran d'appel actif (voir HomeScreen + call_ui).
    _isAutoAnsweringFromPush = true;
    _status = CallStatus.incoming;
    _ensureRemoteIdentityResolved();
    notify();

    debugPrint('[CallService] !! Status = incoming, auto-answer armé (from push)');

    // Si l'offer est déjà arrivée, répondre immédiatement ; sinon on borne
    // l'attente de l'offre pour ne pas rester figé sur « connexion en cours ».
    if (_pendingOffer != null) {
      debugPrint('[CallService] ⚡ Offer déjà présente → réponse immédiate');
      await answerCall();
    } else {
      _armAwaitingOfferTimeout();
    }
  }

  /// Vérifie qu'une notification d'appel entrant peut préparer l'écran entrant.
  Future<bool> canPrepareIncomingFromCallKit({
    required String callId,
    required String callerId,
    required String callerName,
    String? roomId,
  }) async {
    if (_status != CallStatus.idle) return false;
    if (callId.isEmpty || callId.startsWith('meeting_')) return false;
    if (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId)) {
      return false;
    }
    final isGroupCall = roomId != null && roomId.isNotEmpty;
    final parsedCallerId = int.tryParse(callerId);
    if (!isGroupCall && parsedCallerId == null) return false;
    if (callerName.trim().isEmpty && parsedCallerId == null) return false;
    return true;
  }

  /// Prépare l'état d'appel entrant à partir d'un appel CallKit encore actif,
  /// SANS armer l'auto-réponse. Utilisé au démarrage à froid quand l'utilisateur
  /// a tapé le corps de la notif (pas le bouton « Accepter ») : on affiche l'écran
  /// d'appel entrant qui sonne et l'utilisateur décroche manuellement.
  void prepareIncomingFromCallKit({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) {
    unawaited(_prepareIncomingFromCallKitAsync(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      isVideo: isVideo,
      roomId: roomId,
    ));
  }

  Future<void> _prepareIncomingFromCallKitAsync({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) async {
    if (!await canPrepareIncomingFromCallKit(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      roomId: roomId,
    )) {
      if (callId.isNotEmpty) {
        if (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId)) {
          debugPrint('[CallService] 🛡 ignore CallKit terminé: $callId');
        } else {
          debugPrint('[CallService] 🛡 ignore incoming CallKit invalide: callerId=$callerId');
        }
        await _callKit.endAll(callId: callId);
      }
      return;
    }
    if (_status != CallStatus.idle) return;

    final parsedCallerId = int.tryParse(callerId);

    debugPrint('[CallService] 📲 prepareIncomingFromCallKit callId=$callId caller=$callerId');

    _remoteUserId = parsedCallerId;
    _remoteUserName = callerName;
    _remoteUserPhoto = normalizeBackendUrl(callerPhoto);
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _groupRoomId = (roomId != null && roomId.isNotEmpty) ? roomId : null;
    _status = CallStatus.incoming;
    _ensureRemoteIdentityResolved();
    notify();
  }

  /// Synchronise l'état Flutter quand CallKit/PushKit affiche un entrant
  /// (app au premier plan ou réveil) avant l'arrivée du socket WebRTC.
  Future<void> handleIncomingCallKitPreview({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) async {
    if (callId.isNotEmpty &&
        (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId))) {
      debugPrint(
        '[CallService] 🛡 PushKit preview ignoré (callId terminé): $callId',
      );
      await _callKit.endAll(callId: callId);
      return;
    }

    // Premier plan : Flutter gère l'UI — retirer CallKit sans refuser l'appel.
    if (_isAppForeground) {
      await _dismissStrayIncomingCallKit(callId);
      if (_status == CallStatus.incoming &&
          (_currentCallId == null || _currentCallId == callId)) {
        debugPrint('[CallService] preview ignoré (déjà entrant via socket): $callId');
        return;
      }
      if (_status != CallStatus.idle) {
        debugPrint('[CallService] 🛡 preview foreground refusé (occupé): $callId');
        return;
      }
      if (!await canPrepareIncomingFromCallKit(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        roomId: roomId,
      )) {
        return;
      }
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
      debugPrint('[CallService] preview foreground → préparer avant socket: $callId');
      await _prepareIncomingFromCallKitAsync(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideo: isVideo,
        roomId: roomId,
      );
      return;
    }

    if (!await canPrepareIncomingFromCallKit(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      roomId: roomId,
    )) {
      debugPrint(
        '[CallService] 🛡 PushKit preview refusé (occupé ou invalide): $callId',
      );
      await _callKit.endAll(callId: callId);
      return;
    }

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    await _prepareIncomingFromCallKitAsync(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      isVideo: isVideo,
      roomId: roomId,
    );
  }

  /// Appelée depuis main.dart quand l'utilisateur refuse un appel via CallKit.
  ///
  /// On coupe immédiatement CallKit + sonnerie, on mémorise le callId comme
  /// terminal, on persiste le refus, puis on tente HTTP (prioritaire, marche
  /// sans socket) et socket en secours. Le flush à `auth:verified` / bootstrap
  /// rejoue ce qui n'a pas encore abouti.
  Future<void> rejectIncomingCallFromPush({
    required String callerId,
    String? callId,
  }) async {
    debugPrint('[CallService] 📲 rejectIncomingCallFromPush caller=$callerId callId=$callId');

    final resolvedCallId = callId ?? _currentCallId;
    _markTerminalCallId(resolvedCallId);
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    _isAutoAnsweringFromPush = false;

    await _ringtone.stop();
    await _callKit.endAll(callId: resolvedCallId);

    final cid = int.tryParse(callerId);
    if (cid != null) {
      await PendingCallRejectStore.enqueue(
        callerId: callerId,
        callId: resolvedCallId,
      );
      unawaited(_deliverReject(
        callerId: callerId,
        callerIdInt: cid,
        callId: resolvedCallId,
      ));
    }

    if (_status == CallStatus.incoming ||
        _status == CallStatus.outgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.connected) {
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Dispatch centralisé des actions CallKit (accept / decline / ended).
  Future<void> handleCallKitAction(IncomingCallAction action) async {
    switch (action.action) {
      case IncomingCallActionType.incomingPreview:
        await handleIncomingCallKitPreview(
          callId: action.callId,
          callerId: action.callerId,
          callerName: action.callerName,
          callerPhoto: action.callerPhoto,
          isVideo: action.isVideo,
          roomId: action.roomId,
        );
        break;
      case IncomingCallActionType.accept:
        await acceptIncomingCallFromPush(
          callId: action.callId,
          callerId: action.callerId,
          callerName: action.callerName,
          callerPhoto: action.callerPhoto,
          isVideo: action.isVideo,
          roomId: action.roomId,
        );
        break;
      case IncomingCallActionType.decline:
      case IncomingCallActionType.timeout:
        await rejectIncomingCallFromPush(
          callerId: action.callerId,
          callId: action.callId,
        );
        break;
      case IncomingCallActionType.ended:
        await notifyCallEndedFromExternal(
          callId: action.callId,
          callerId: action.callerId,
        );
        break;
    }
  }

  /// Fermeture UI + teardown quand l'appel se termine depuis CallKit, FCM
  /// `call_ended` ou le listener natif ACTIVE_CALLS.
  Future<void> notifyCallEndedFromExternal({
    String? callId,
    String? callerId,
  }) async {
    final id = (callId ?? '').trim();
    debugPrint(
      '[CallService] notifyCallEndedFromExternal callId=$id status=$_status',
    );

    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
    }

    if (_status == CallStatus.outgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.connected) {
      if (id.isEmpty || id == _currentCallId) {
        await endCall();
      } else {
        _markTerminalCallId(id);
        await _terminateCall();
      }
      return;
    }

    if (_status == CallStatus.incoming) {
      await rejectIncomingCallFromPush(
        callerId: callerId ?? _remoteUserId?.toString() ?? '',
        callId: id.isNotEmpty ? id : _currentCallId,
      );
      return;
    }

    if (id.isNotEmpty) _markTerminalCallId(id);
    await _ringtone.stop();
    await _callKit.endAll(callId: id.isNotEmpty ? id : null);
    if (_status != CallStatus.idle) {
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Au resume : si FCM a marqué l'appel terminé pendant que l'UI était ouverte.
  Future<void> syncWithEndedRegistry() async {
    final id = _currentCallId;
    if (id == null || id.isEmpty) return;
    if (_status == CallStatus.idle || _status == CallStatus.ended) return;
    if (!await EndedCallRegistry.isEnded(id)) return;
    debugPrint('[CallService] syncWithEndedRegistry → terminate $id');
    await notifyCallEndedFromExternal(callId: id);
  }

  /// Envoie le refus via HTTP puis socket. Retire de la file si au moins
  /// un canal a réussi.
  Future<void> _deliverReject({
    required String callerId,
    required int callerIdInt,
    String? callId,
  }) async {
    var delivered = false;

    try {
      await _apiClient.rejectCallHttp(callerId: callerIdInt, callId: callId);
      delivered = true;
      debugPrint('[CallService] !! reject HTTP ok caller=$callerIdInt');
    } catch (e) {
      debugPrint('[CallService] reject HTTP error: $e');
    }

    if (_apiClient.isSocketReady) {
      try {
        _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
          'callerId': callerIdInt,
          if (callId != null && callId.isNotEmpty) 'callId': callId,
        });
        delivered = true;
      } catch (e) {
        debugPrint('[CallService] rejectCall socket error: $e');
      }
    } else if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    if (delivered) {
      await PendingCallRejectStore.remove(callerId: callerId, callId: callId);
    }
  }

  /// Rejoue les refus persistés (mémoire disque + éventuel enqueue natif).
  /// Appelé depuis `auth:verified` et au bootstrap AuthWrapper.
  Future<void> flushPendingRejects() async {
    final pending = await PendingCallRejectStore.list();
    if (pending.isEmpty) return;
    debugPrint('[CallService] 🔁 flushPendingRejects count=${pending.length}');
    for (final item in pending) {
      final callerId = item['callerId'] ?? '';
      final callId = item['callId'];
      final cid = int.tryParse(callerId);
      if (cid == null) {
        await PendingCallRejectStore.remove(callerId: callerId, callId: callId);
        continue;
      }
      await _deliverReject(
        callerId: callerId,
        callerIdInt: cid,
        callId: callId,
      );
    }
  }

  /// Alias privé pour les listeners socket.
  void _flushPendingRejects() {
    unawaited(flushPendingRejects());
  }

  /// Rejoue les end_call mis en file quand le socket n'était pas prêt.
  void _flushPendingEndCalls() {
    if (_pendingEndCalls.isEmpty) return;
    if (!_apiClient.isSocketReady) return;
    final pending = List<Map<String, dynamic>>.from(_pendingEndCalls);
    _pendingEndCalls.clear();
    for (final payload in pending) {
      debugPrint('[CallService] 🔁 Rejeu end_call en file → $payload');
      try {
        _apiClient.sendSocketEvent(SocketEvents.endCall, payload);
      } catch (e) {
        debugPrint('[CallService] rejeu end_call échoué: $e');
        _pendingEndCalls.add(payload);
      }
    }
  }
}
