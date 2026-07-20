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
    notify();

    debugPrint('[CallService] !! Status = incoming, auto-answer armé (from push)');

    // Si l'offer est déjà arrivée, répondre immédiatement
    if (_pendingOffer != null) {
      debugPrint('[CallService] ⚡ Offer déjà présente → réponse immédiate');
      await answerCall();
    }
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
    if (_status != CallStatus.idle) return;
    if (callId.startsWith('meeting_')) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit meeting callId=$callId');
      return;
    }
    if (callId.isNotEmpty &&
        (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId))) {
      debugPrint('[CallService] 🛡 ignore CallKit terminé: $callId');
      await _callKit.endAll(callId: callId);
      return;
    }
    final isGroupCall = roomId != null && roomId.isNotEmpty;
    final parsedCallerId = int.tryParse(callerId);
    if (!isGroupCall && parsedCallerId == null) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit invalide: callerId=$callerId');
      return;
    }
    if (callerName.trim().isEmpty && parsedCallerId == null) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit sans identité exploitable');
      return;
    }
    if (_status != CallStatus.idle) return;

    debugPrint('[CallService] 📲 prepareIncomingFromCallKit callId=$callId caller=$callerId');

    _remoteUserId = parsedCallerId;
    _remoteUserName = callerName;
    _remoteUserPhoto = normalizeBackendUrl(callerPhoto);
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _groupRoomId = (roomId != null && roomId.isNotEmpty) ? roomId : null;
    _status = CallStatus.incoming;
    notify();
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
        _status == CallStatus.connecting ||
        _status == CallStatus.connected) {
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
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
