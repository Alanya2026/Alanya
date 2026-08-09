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
    final peerId = int.tryParse(data['peerId']?.toString() ?? '');
    final serverCallId = data['callId']?.toString();
    if (peerId == null || serverCallId == null || serverCallId.isEmpty) {
      debugPrint('[CallService] 🛡 call_resume ignoré: payload invalide');
      return;
    }

    final canResume = await _canConfirmCallResume(
      serverCallId: serverCallId,
      peerId: peerId,
    );
    if (!canResume) {
      // Backend n'émet call_resume qu'au device owner ; un reject ici solde
      // l'in_call fantôme owner. Les reject d'un non-owner sont ignorés serveur.
      debugPrint(
        '[CallService] call_resume_reject callId=$serverCallId peer=$peerId (no_local_call_state)',
      );
      _apiClient.sendSocketEvent(SocketEvents.callResumeReject, {
        'callId': serverCallId,
        'reason': 'no_local_call_state',
      });
      return;
    }

    _apiClient.sendSocketEvent(SocketEvents.callResumeAck, {
      'callId': serverCallId,
    });
    debugPrint('[CallService] call_resume_ack callId=$serverCallId peer=$peerId');

    // Déjà en communication : ack suffit sauf si PC morte → rejoin.
    if (_status == CallStatus.connected && !_isRestoringOutgoing) {
      if (_currentCallId == null || _currentCallId!.isEmpty) {
        _currentCallId = serverCallId;
      }
      final pcDead = _webrtc.peerConnection == null || !_webrtc.isPcUsable;
      if (pcDead && isRestartInitiator) {
        debugPrint('[CallService] call_resume: PC morte → rejoin');
        try {
          if (_webrtc.peerConnection == null) {
            await _initWebRtcForOutgoingRestore(isVideo: _isVideo);
          }
          await _acquireCallSessionIfNeeded(isVideo: _isVideo);
          await _sendCallRejoinOffer(iceRestart: true);
        } catch (e) {
          debugPrint('[CallService] call_resume rejoin PC morte échoué: $e');
        }
      } else if (pcDead && !isRestartInitiator) {
        _enterReconnecting(reason: 'resume_dead_pc_callee');
      }
      return;
    }

    if (_status == CallStatus.reconnecting && !_isRestoringOutgoing) {
      if (isRestartInitiator) {
        unawaited(_attemptIceRestart());
      }
      return;
    }

    // Snapshot / CallKit présents mais UI encore idle → amorcer la restore.
    if (!_isRestoringOutgoing &&
        _status != CallStatus.connecting &&
        _status != CallStatus.outgoing) {
      final bootstrapped = await _bootstrapOutgoingRestoreFromResume(
        serverCallId: serverCallId,
        peerId: peerId,
        isVideo: data['isVideo'] == true,
      );
      if (!bootstrapped) {
        debugPrint(
          '[CallService] call_resume ack sans restore (status=$_status)',
        );
        return;
      }
    }

    if (!_isRestoringOutgoing && _status != CallStatus.connecting) return;
    if (_remoteUserId != null && peerId != _remoteUserId) return;

    _cancelOutgoingRestoreTimeout();

    _currentCallId = serverCallId;

    final isVideo = data['isVideo'] == true || _isVideo;
    _isVideo = isVideo;

    debugPrint('[CallService] 🔄 call_resume peer=$peerId callId=$serverCallId');

    try {
      await _initWebRtcForOutgoingRestore(isVideo: isVideo);
      await _acquireCallSessionIfNeeded(isVideo: isVideo);
      await _sendCallRejoinOffer(iceRestart: true);
    } catch (e) {
      debugPrint('[CallService] call_resume échoué: $e');
      await _terminateRestoredOutgoing(showMessage: true);
    }
  }

  Future<void> _acquireCallSessionIfNeeded({required bool isVideo}) async {
    if (kIsWeb) return;
    if (CallSessionGuard.instance.isActive) {
      await _markCallSessionConnected();
      return;
    }
    await _acquireCallSession(
      isVideo: isVideo,
      displayName: _remoteUserName ?? LocaleController.instance.l10n.callNoun,
      handle: (_remoteUserId ?? 0).toString(),
    );
    await _markCallSessionConnected();
  }

  /// Preuve locale qu'une reprise est légitime (évite de conserver un in_call fantôme).
  Future<bool> _canConfirmCallResume({
    required String serverCallId,
    required int peerId,
  }) async {
    if (_isTerminalCallId(serverCallId) ||
        await EndedCallRegistry.isEnded(serverCallId)) {
      return false;
    }

    if (_isRestoringOutgoing &&
        (_remoteUserId == peerId || _currentCallId == serverCallId)) {
      return true;
    }

    if ((_status == CallStatus.connecting ||
            _status == CallStatus.connected ||
            _status == CallStatus.reconnecting ||
            _status == CallStatus.outgoing) &&
        (_remoteUserId == peerId || _currentCallId == serverCallId)) {
      return true;
    }

    final snap = await PendingOutgoingCallStore.read();
    if (snap != null && snap.remoteUserId == peerId) {
      if (snap.serverCallId == serverCallId ||
          snap.clientCallId == serverCallId ||
          snap.serverCallId == null ||
          snap.serverCallId!.isEmpty) {
        if (!await EndedCallRegistry.isEnded(snap.clientCallId)) {
          return true;
        }
      }
    }

    if (!kIsWeb) {
      final active = await _callKit.getActiveCall();
      if (active != null) {
        final activeId = (active['callId'] ?? '').toString();
        final activeCaller = (active['callerId'] ?? '').toString();
        if (activeId == serverCallId) return true;
        if (activeCaller == peerId.toString() &&
            (activeId.isEmpty ||
                activeId == _currentCallId ||
                (snap != null && activeId == snap.clientCallId))) {
          return true;
        }
        if (snap != null &&
            activeId == snap.clientCallId &&
            snap.remoteUserId == peerId) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> _bootstrapOutgoingRestoreFromResume({
    required String serverCallId,
    required int peerId,
    required bool isVideo,
  }) async {
    final snap = await PendingOutgoingCallStore.read();
    if (snap == null || snap.remoteUserId != peerId) return false;
    if (await EndedCallRegistry.isEnded(snap.clientCallId)) return false;

    debugPrint(
      '[CallService] 🔄 bootstrap restore depuis call_resume '
      'client=${snap.clientCallId} server=$serverCallId',
    );
    _currentCallId = serverCallId;
    _remoteUserId = snap.remoteUserId;
    _remoteUserName = snap.remoteUserName;
    _remoteUserPhoto = snap.remoteUserPhoto;
    _isVideo = snap.isVideo || isVideo;
    _status = CallStatus.connecting;
    _isRestoringOutgoing = true;
    notify();
    _armOutgoingRestoreTimeout();
    return true;
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
        'generation': _webrtc.iceGeneration,
        if (_currentCallId != null) 'callId': _currentCallId,
      });
    };
    _wireOneToOneConnectionStateHandlers();
    _isOutgoingCaller = true;

    if (!kIsWeb) {
      _isSpeakerOn = isVideo;
      await audio.AudioHelper.setSpeakerphoneOn(isVideo);
    }
  }

  Future<void> _sendCallRejoinOffer({bool iceRestart = false}) async {
    if (_remoteUserId == null) return;
    final generation =
        iceRestart ? _webrtc.bumpIceGeneration() : _webrtc.iceGeneration;
    final offer = await _webrtc.createOffer(iceRestart: iceRestart);
    _apiClient.sendSocketEvent(SocketEvents.callRejoin, {
      'targetUserId': _remoteUserId.toString(),
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'generation': generation,
      if (_currentCallId != null) 'callId': _currentCallId,
    });
    debugPrint(
      '[CallService] 📤 call_rejoin envoyé iceRestart=$iceRestart gen=$generation',
    );
  }

  Future<void> _handleCallRejoinOffer(Map<String, dynamic> data) async {
    final peerId = int.tryParse(data['peerId']?.toString() ?? '');
    final offerMap = data['offer'];
    if (peerId == null || offerMap is! Map || offerMap['sdp'] == null) return;
    if (_remoteUserId != null && peerId != _remoteUserId) return;

    final allowed = _status == CallStatus.connected ||
        _status == CallStatus.reconnecting ||
        _isRestoringOutgoing ||
        (_status == CallStatus.connecting && _remoteUserId == peerId);
    if (!allowed) {
      debugPrint('[CallService] 🛡 call_rejoin_offer ignoré status=$_status');
      return;
    }

    final gen = data['generation'] is int
        ? data['generation'] as int
        : int.tryParse(data['generation']?.toString() ?? '');
    if (gen != null) {
      while (_webrtc.iceGeneration < gen) {
        _webrtc.bumpIceGeneration();
      }
    }

    debugPrint('[CallService] 📥 call_rejoin_offer de peer=$peerId gen=$gen');

    try {
      if (_webrtc.peerConnection == null) {
        await _initWebRtcForOutgoingRestore(isVideo: _isVideo);
        await _acquireCallSessionIfNeeded(isVideo: _isVideo);
      }
      await _webrtc.handleOffer(
        RTCSessionDescription(
          offerMap['sdp'] as String,
          offerMap['type']?.toString() ?? 'offer',
        ),
      );
      final answer = await _webrtc.createAnswer();
      _apiClient.sendSocketEvent(SocketEvents.callRejoinAnswer, {
        'targetUserId': peerId.toString(),
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        if (gen != null) 'generation': gen,
        if (_currentCallId != null) 'callId': _currentCallId,
      });

      if (_isRestoringOutgoing || _status == CallStatus.connecting) {
        _completeOutgoingRestore();
      } else if (_status == CallStatus.connected ||
          _status == CallStatus.reconnecting) {
        _onOneToOneMediaReconnected();
        debugPrint('[CallService] Renégociation rejoin terminée');
      }
    } catch (e) {
      debugPrint('[CallService] call_rejoin_offer échoué: $e');
      if (_isRestoringOutgoing) {
        await _terminateRestoredOutgoing(showMessage: true);
      }
    }
  }

  Future<void> _handleCallRejoinAnswer(Map<String, dynamic> data) async {
    final allowed = _isRestoringOutgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.reconnecting ||
        _status == CallStatus.connected;
    if (!allowed) return;
    final answerMap = data['answer'];
    if (answerMap is! Map || answerMap['sdp'] == null) return;

    final gen = data['generation'] is int
        ? data['generation'] as int
        : int.tryParse(data['generation']?.toString() ?? '');
    if (!_webrtc.acceptsIceGeneration(gen)) {
      debugPrint('[CallService] 🛡 call_rejoin_answer gen périmée');
      return;
    }

    debugPrint('[CallService] 📥 call_rejoin_answer reçu');

    try {
      await _webrtc.handleAnswer(
        RTCSessionDescription(
          answerMap['sdp'] as String,
          answerMap['type']?.toString() ?? 'answer',
        ),
      );
      _markIceRestartComplete();
      if (_isRestoringOutgoing || _status == CallStatus.connecting) {
        _completeOutgoingRestore();
      } else {
        _onOneToOneMediaReconnected();
      }
    } catch (e) {
      debugPrint('[CallService] call_rejoin_answer échoué: $e');
      if (_isRestoringOutgoing) {
        await _terminateRestoredOutgoing(showMessage: true);
      }
    }
  }

  void _completeOutgoingRestore() {
    _cancelOutgoingRestoreTimeout();
    _isRestoringOutgoing = false;
    _status = CallStatus.connected;
    _cancelAllReconnectTimers();
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
