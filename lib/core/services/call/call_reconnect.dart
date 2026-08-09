// Reconnexion mid-call 1-à-1 (grâce Disconnected, ICE restart caller-only).
part of '../call_service.dart';

extension CallReconnect on CallService {
  bool get isRestartInitiator {
    return isOneToOneRestartInitiator(isOutgoingCaller: _isOutgoingCaller);
  }

  void _wireOneToOneConnectionStateHandlers() {
    _webrtc.onConnectionFailure = null;
    _webrtc.onConnectionStateChanged = (state) {
      _onOneToOneConnectionState(state);
    };
  }

  void _onOneToOneConnectionState(RTCPeerConnectionState state) {
    if (_status != CallStatus.connected &&
        _status != CallStatus.reconnecting) {
      return;
    }
    if (_isEndingCall || _callEndedByUs) return;

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _onOneToOneMediaReconnected();
      return;
    }

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      debugPrint('[CallService] PC closed (terminal) → endCall');
      unawaited(endCall());
      return;
    }

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
      debugPrint('[CallService] PC Disconnected → grâce reconnect');
      _enterReconnecting(reason: 'disconnected');
      _armDisconnectGraceThenRestart();
      return;
    }

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      debugPrint('[CallService] PC Failed → ICE restart (caller) / wait (callee)');
      _enterReconnecting(reason: 'failed');
      if (isRestartInitiator) {
        unawaited(_attemptIceRestart());
      }
      // Callee : attend l'offer ; timeout global gère la fin.
    }
  }

  void _enterReconnecting({required String reason}) {
    if (_status == CallStatus.ended || _status == CallStatus.idle) return;
    if (_status != CallStatus.reconnecting) {
      _status = CallStatus.reconnecting;
      notify();
      debugPrint('[CallService] status=reconnecting ($reason)');
    }
    _armGlobalReconnectTimeout();
  }

  void _onOneToOneMediaReconnected() {
    _cancelDisconnectGrace();
    _cancelGlobalReconnectTimeout();
    _iceRestartCount = 0;
    _isIceRestarting = false;
    if (_status == CallStatus.reconnecting) {
      _status = CallStatus.connected;
      notify();
      debugPrint('[CallService] status=connected (media recovered)');
    }
  }

  void _armDisconnectGraceThenRestart() {
    _cancelDisconnectGrace();
    _reconnectGraceTimer = Timer(CallService._reconnectGraceDuration, () {
      _reconnectGraceTimer = null;
      if (_status != CallStatus.reconnecting) return;
      if (_webrtc.isPcConnected) {
        _onOneToOneMediaReconnected();
        return;
      }
      if (isRestartInitiator) {
        unawaited(_attemptIceRestart());
      }
    });
  }

  void _cancelDisconnectGrace() {
    _reconnectGraceTimer?.cancel();
    _reconnectGraceTimer = null;
  }

  void _armGlobalReconnectTimeout() {
    if (_globalReconnectTimer != null) return;
    _globalReconnectTimer = Timer(CallService._globalReconnectTimeout, () {
      _globalReconnectTimer = null;
      if (_status != CallStatus.reconnecting) return;
      debugPrint('[CallService] ⏰ Timeout reconnect global → endCall');
      unawaited(endCall());
    });
  }

  void _cancelGlobalReconnectTimeout() {
    _globalReconnectTimer?.cancel();
    _globalReconnectTimer = null;
  }

  void _cancelAllReconnectTimers() {
    _cancelDisconnectGrace();
    _cancelGlobalReconnectTimeout();
    _isIceRestarting = false;
  }

  Future<void> _attemptIceRestart() async {
    if (!isRestartInitiator) return;
    if (_isEndingCall || _callEndedByUs) return;
    if (_status != CallStatus.reconnecting && _status != CallStatus.connected) {
      return;
    }
    if (_isIceRestarting) return;
    if (_iceRestartCount >= CallService._maxIceRestarts) {
      debugPrint('[CallService] ICE restart max atteint → endCall');
      await endCall();
      return;
    }

    final pc = _webrtc.peerConnection;
    if (pc == null) {
      // Pas de branche Recreating dans ce lot : ICE restart uniquement.
      // PC null / max retries → fin propre (end_call), pas de recreate PC.
      debugPrint('[CallService] ICE restart impossible (PC null) → endCall');
      await endCall();
      return;
    }

    _isIceRestarting = true;
    _iceRestartCount += 1;
    final generation = _webrtc.bumpIceGeneration();
    debugPrint(
      '[CallService] ICE restart #$_iceRestartCount generation=$generation',
    );

    try {
      final offer = await _webrtc.createOffer(iceRestart: true);
      final peer = _remoteUserId;
      if (peer == null) {
        _isIceRestarting = false;
        return;
      }
      _apiClient.sendSocketEvent(SocketEvents.callRejoin, {
        'targetUserId': peer.toString(),
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'generation': generation,
        if (_currentCallId != null) 'callId': _currentCallId,
      });
    } catch (e) {
      debugPrint('[CallService] ** ICE restart failed: $e');
      _isIceRestarting = false;
      if (_iceRestartCount >= CallService._maxIceRestarts) {
        await endCall();
      }
    }
  }

  /// Appelé quand le PC redevient connected après rejoin answer.
  void _markIceRestartComplete() {
    _isIceRestarting = false;
  }
}
