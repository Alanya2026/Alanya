// Restauration d'appels sortants après kill (part of call_service.dart).
part of '../call_service.dart';

extension CallOutgoingRestore on CallService {
  bool get isRestoringOutgoing => _isRestoringOutgoing;

  Future<bool> shouldPreserveOutgoingCallKit(String callId) async {
    if (callId.isEmpty) return false;
    if (matchesActiveOutgoingSession(callId)) return true;
    if (await EndedCallRegistry.isEnded(callId)) return false;
    final snap = await PendingOutgoingCallStore.read();
    return snap != null && snap.clientCallId == callId;
  }

  /// Cold start : restaure l'état UI + attend call_resume / call_rejoin.
  Future<bool> restoreOutgoingFromColdStart(Map<String, dynamic> active) async {
    final callId = (active['callId'] as String? ?? '').trim();
    if (callId.isEmpty) return false;
    if (await EndedCallRegistry.isEnded(callId)) return false;
    if (matchesActiveOutgoingSession(callId)) return true;

    final snap = await PendingOutgoingCallStore.read();
    if (snap == null || snap.clientCallId != callId) return false;

    debugPrint('[CallService] 🔄 restoreOutgoingFromColdStart callId=$callId');

    _currentCallId = callId;
    _remoteUserId = snap.remoteUserId;
    _remoteUserName = snap.remoteUserName;
    _remoteUserPhoto = snap.remoteUserPhoto;
    _isVideo = snap.isVideo;
    _status = CallStatus.connecting;
    _isRestoringOutgoing = true;
    notify();

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    _armOutgoingRestoreTimeout();
    return true;
  }

  Future<void> persistOutgoingSnapshot({
    required String phase,
    String? serverCallId,
  }) async {
    final callId = _currentCallId;
    final remoteId = _remoteUserId;
    if (callId == null || callId.isEmpty || remoteId == null) return;

    await PendingOutgoingCallStore.save(
      OutgoingCallSnapshot(
        clientCallId: callId,
        serverCallId: serverCallId,
        remoteUserId: remoteId,
        remoteUserName: _remoteUserName ?? '',
        remoteUserPhoto: _remoteUserPhoto,
        isVideo: _isVideo,
        phase: phase,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _clearOutgoingSnapshot() async {
    await PendingOutgoingCallStore.clear();
  }

  void _armOutgoingRestoreTimeout() {
    _cancelOutgoingRestoreTimeout();
    _outgoingRestoreTimer = Timer(const Duration(seconds: 20), () async {
      if (!_isRestoringOutgoing) return;
      debugPrint('[CallService] ⏰ Timeout restauration appel sortant');
      await _terminateRestoredOutgoing(showMessage: true);
    });
  }

  void _cancelOutgoingRestoreTimeout() {
    _outgoingRestoreTimer?.cancel();
    _outgoingRestoreTimer = null;
  }

  Future<void> _handleCallResume(Map<String, dynamic> data) async {
    if (!_isRestoringOutgoing && _status != CallStatus.connecting) return;

    final peerId = int.tryParse(data['peerId']?.toString() ?? '');
    if (peerId == null || peerId != _remoteUserId) return;

    _cancelOutgoingRestoreTimeout();

    final serverCallId = data['callId']?.toString();
    if (serverCallId != null && serverCallId.isNotEmpty) {
      _currentCallId = serverCallId;
    }

    final isVideo = data['isVideo'] == true || _isVideo;
    _isVideo = isVideo;

    debugPrint('[CallService] 🔄 call_resume peer=$peerId callId=$serverCallId');

    try {
      await _initWebRtcForOutgoingRestore(isVideo: isVideo);
      await _sendCallRejoinOffer();
    } catch (e) {
      debugPrint('[CallService] call_resume échoué: $e');
      await _terminateRestoredOutgoing(showMessage: true);
    }
  }

  Future<void> _initWebRtcForOutgoingRestore({required bool isVideo}) async {
    final iceServers = await _apiClient.fetchIceServers(force: true);
    await _webrtc.init(isVideo ? CallType.video : CallType.audio, iceServers: iceServers);
    _webrtc.onLocalStream = (_) { notify(); };
    _webrtc.onRemoteStream = (_) { notify(); };
    _webrtc.onIceCandidate = (candidate) {
      if (_remoteUserId == null) return;
      _apiClient.sendSocketEvent(SocketEvents.iceCandidate, {
        'targetUserId': _remoteUserId.toString(),
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
    _webrtc.onConnectionFailure = () {
      debugPrint('[CallService] ** Reconnexion WebRTC échouée');
      unawaited(_terminateRestoredOutgoing(showMessage: true));
    };

    if (!kIsWeb) {
      _isSpeakerOn = isVideo;
      await audio.AudioHelper.setSpeakerphoneOn(isVideo);
    }
  }

  Future<void> _sendCallRejoinOffer() async {
    if (_remoteUserId == null) return;
    final offer = await _webrtc.createOffer();
    _apiClient.sendSocketEvent(SocketEvents.callRejoin, {
      'targetUserId': _remoteUserId.toString(),
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
    debugPrint('[CallService] 📤 call_rejoin envoyé');
  }

  Future<void> _handleCallRejoinOffer(Map<String, dynamic> data) async {
    final peerId = int.tryParse(data['peerId']?.toString() ?? '');
    final offerMap = data['offer'];
    if (peerId == null || offerMap is! Map || offerMap['sdp'] == null) return;
    if (_remoteUserId != null && peerId != _remoteUserId) return;

    final allowed = _status == CallStatus.connected ||
        _isRestoringOutgoing ||
        (_status == CallStatus.connecting && _remoteUserId == peerId);
    if (!allowed) {
      debugPrint('[CallService] 🛡 call_rejoin_offer ignoré status=$_status');
      return;
    }

    debugPrint('[CallService] 📥 call_rejoin_offer de peer=$peerId');

    try {
      if (_webrtc.peerConnection == null) {
        await _initWebRtcForOutgoingRestore(isVideo: _isVideo);
      }
      await _webrtc.handleOffer(
        RTCSessionDescription(offerMap['sdp'] as String, offerMap['type']?.toString() ?? 'offer'),
      );
      final answer = await _webrtc.createAnswer();
      _apiClient.sendSocketEvent(SocketEvents.callRejoinAnswer, {
        'targetUserId': peerId.toString(),
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });

      if (_isRestoringOutgoing || _status == CallStatus.connecting) {
        _completeOutgoingRestore();
      } else if (_status == CallStatus.connected) {
        debugPrint('[CallService] Renégociation rejoin terminée (pair déjà connecté)');
      }
    } catch (e) {
      debugPrint('[CallService] call_rejoin_offer échoué: $e');
      if (_isRestoringOutgoing) {
        await _terminateRestoredOutgoing(showMessage: true);
      }
    }
  }

  Future<void> _handleCallRejoinAnswer(Map<String, dynamic> data) async {
    if (!_isRestoringOutgoing && _status != CallStatus.connecting) return;
    final answerMap = data['answer'];
    if (answerMap is! Map || answerMap['sdp'] == null) return;

    debugPrint('[CallService] 📥 call_rejoin_answer reçu');

    try {
      await _webrtc.handleAnswer(
        RTCSessionDescription(answerMap['sdp'] as String, answerMap['type']?.toString() ?? 'answer'),
      );
      _completeOutgoingRestore();
    } catch (e) {
      debugPrint('[CallService] call_rejoin_answer échoué: $e');
      await _terminateRestoredOutgoing(showMessage: true);
    }
  }

  void _completeOutgoingRestore() {
    _cancelOutgoingRestoreTimeout();
    _isRestoringOutgoing = false;
    _status = CallStatus.connected;
    _startDurationTimer();
    _startSpeakingDetection(groupMode: false);
    notify();
    if (!kIsWeb) {
      unawaited(_markCallSessionConnected());
    }
    unawaited(persistOutgoingSnapshot(phase: 'connected', serverCallId: _currentCallId));
    debugPrint('[CallService] !! Appel sortant restauré → CONNECTED');
  }

  Future<void> _terminateRestoredOutgoing({bool showMessage = false}) async {
    if (!_isRestoringOutgoing && _status == CallStatus.idle) return;
    _cancelOutgoingRestoreTimeout();
    _isRestoringOutgoing = false;
    _markTerminalCallId(_currentCallId);
    await _terminateCall();
    if (showMessage) {
      _showTransientMessage(LocaleController.instance.l10n.callEnded);
    }
  }
}
