// Appels 1-à-1 : initier, répondre, rejeter, terminer (part of call_service.dart).
part of '../call_service.dart';

extension CallOneToOne on CallService {
  /// Lance un appel vers [targetUserId]
  Future<void> initiateCall({
    required int targetUserId,
    required int myId,
    required String myName,
    String? myPhoto,
    required bool isVideo,
    String? targetUserName,
    String? targetUserPhoto,
  }) async {
    if (_status != CallStatus.idle) {
      _errorMessage = LocaleController.instance.l10n.aCallIsAlreadyInProgress;
      notify();
      return;
    }
    if (!await _ensureFullyConnectedForOutgoingCall()) return;
    _errorMessage = null;
    _status = CallStatus.outgoing;
    _remoteUserId = targetUserId;
    _remoteUserName = targetUserName;
    _remoteUserPhoto = targetUserPhoto;
    _isVideo = isVideo;
    notify();

    try {
      final iceServers = await _apiClient.fetchIceServers(force: true);
      await _webrtc.init(isVideo ? CallType.video : CallType.audio, iceServers: iceServers);
      _webrtc.onLocalStream  = (_) { notify(); };
      _webrtc.onRemoteStream = (_) { notify(); };

      // Initialiser le routage audio : haut-parleur par défaut en vidéo,
      // écouteur (oreille) par défaut en audio.
      if (!kIsWeb) {
        _isSpeakerOn = isVideo;
        await audio.AudioHelper.setSpeakerphoneOn(isVideo);
        debugPrint('[CallService] 🔊 Routage audio initialisé (haut-parleur ${isVideo ? "ON" : "OFF"})');
      }

      // ICE candidates envoyés au destinataire
      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, {
          'targetUserId': targetUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      // Connection failure handler
      _webrtc.onConnectionFailure = () {
        debugPrint('[CallService] ** Peer connection failed, ending call');
        _terminateCall();
      };

      final offer = await _webrtc.createOffer();

      _apiClient.sendSocketEvent(SocketEvents.callUser, {
        'targetUserId': targetUserId.toString(),
        'callerId': myId.toString(),
        'callerName': myName,
        'callerPhoto': myPhoto,
        'isVideo': isVideo,
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      });

      _status = CallStatus.connecting;

      if (!kIsWeb) {
        await _acquireCallSession(
          isVideo: isVideo,
          displayName: targetUserName ?? LocaleController.instance.l10n.callNoun,
          handle: targetUserId.toString(),
        );
      }

      // Ringback côté appelant
      _ringtone.startOutgoingRingback();

      // Filet de sécurité local : si aucun état terminal serveur n'arrive
      // (call_answered / call_busy / call_no_answer / call_rejected…), on
      // abandonne l'appel pour ne pas laisser le ringback tourner indéfiniment.
      _cancelOutgoingTimeout();
      _outgoingTimeoutTimer = Timer(CallService._outgoingTimeout, () async {
        if (_status == CallStatus.outgoing || _status == CallStatus.connecting) {
          debugPrint('[CallService] ⏰ Timeout local appel sortant — abandon');
          await _terminateCall();
          _showTransientMessage(LocaleController.instance.l10n.noAnswer);
        }
      });

      notify();
    } catch (e) {
      debugPrint('[CallService] Erreur initiateCall: $e');
      debugPrint('[CallService] Type d\'erreur: ${e.runtimeType}');

      // Déterminer le type d'erreur pour afficher un message clair
      String errorMsg = LocaleController.instance.l10n.errorStartingTheCall;
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission')) {
        errorMsg = LocaleController.instance.l10n.permissionDeniedPleaseAllowMicrophoneCamera;
      } else if (errorStr.contains('microphone') || errorStr.contains('audio')) {
        errorMsg = LocaleController.instance.l10n.microphoneErrorPleaseCheckYourPermissions;
      } else if (errorStr.contains('camera') || errorStr.contains('video')) {
        errorMsg = LocaleController.instance.l10n.cameraErrorPleaseCheckYourPermissions;
      } else if (errorStr.contains('navigator') || errorStr.contains('getusermedia')) {
        errorMsg = LocaleController.instance.l10n.mediaAccessErrorMakeSureHttps;
      } else if (errorStr.contains('notfounderror')) {
        errorMsg = LocaleController.instance.l10n.noMicrophoneCameraDeviceFoundOn;
      } else if (errorStr.contains('notreadableerror')) {
        errorMsg = LocaleController.instance.l10n.cannotAccessMicrophoneCameraCheckThat;
      } else {
        errorMsg = LocaleController.instance.l10n.errorColon(e.toString());
      }

      _errorMessage = errorMsg;
      await _releaseCallSession();
      await _webrtc.dispose();
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
  }

  Future<void> answerCall() async {
    if (_status != CallStatus.incoming || _remoteUserId == null) {
      debugPrint('[CallService] ** answerCall ignoré: status=$_status');
      return;
    }
    if (_pendingOffer == null) {
      debugPrint('[CallService] ⏳ answerCall: offer pas encore reçue, auto-answer armé');
      _autoAnswerOnNextIncoming = true;
      _autoAnswerCallerId = _remoteUserId.toString();
      return;
    }

    // Verrouille immédiatement pour bloquer un éventuel double-appel.
    _status = CallStatus.connecting;
    // L'auto-réponse a fait son office : on repasse en navigation normale pour
    // que la minimisation de l'écran d'appel ne le ré-ouvre pas en boucle.
    _isAutoAnsweringFromPush = false;
    notify();

    await _ringtone.stop();
    _errorMessage = null;
    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }
    int retries = 0;
    while (!_apiClient.isSocketReady && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
    if (!_apiClient.isSocketReady) {
      debugPrint('[CallService] ** Socket non prêt après 5s (connected=${_apiClient.isSocketConnected})');
      _errorMessage = LocaleController.instance.l10n.socketNotConnected;
      _status = CallStatus.idle;
      notify();
      return;
    }
    debugPrint('[CallService] !! Socket connecté, envoi answer');

    final offer = _pendingOffer!;
    _pendingOffer = null;

    try {
      final iceServers = await _apiClient.fetchIceServers(force: true);
      await _webrtc.init(_isVideo ? CallType.video : CallType.audio, iceServers: iceServers);
      _webrtc.onLocalStream  = (_) { notify(); };
      _webrtc.onRemoteStream = (_) { notify(); };

      if (!kIsWeb) {
        _isSpeakerOn = _isVideo;
        await audio.AudioHelper.setSpeakerphoneOn(_isVideo);
      }

      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, {
          'targetUserId': _remoteUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      // Connection failure handler
      _webrtc.onConnectionFailure = () {
        debugPrint('[CallService] ** Peer connection failed, ending call');
        _terminateCall();
      };

      await _webrtc.handleOffer(
        RTCSessionDescription(offer['sdp'] as String, 'offer'),
      );

      final answer = await _webrtc.createAnswer();

      _apiClient.sendSocketEvent(SocketEvents.answerCall, {
        'callerId': _remoteUserId.toString(),
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: false);
      if (!kIsWeb) {
        await _acquireCallSession(
          isVideo: _isVideo,
          displayName: _remoteUserName ?? LocaleController.instance.l10n.callNoun,
          handle: _remoteUserId.toString(),
          startCallKit: false,
        );
        await _markCallSessionConnected();
      }
      notify();
    } catch (e) {
      debugPrint('[CallService] Erreur answerCall: $e');
      debugPrint('[CallService] Type d\'erreur: ${e.runtimeType}');

      // Déterminer le type d'erreur pour afficher un message clair
      String errorMsg = LocaleController.instance.l10n.errorAcceptingCall;
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission')) {
        errorMsg = LocaleController.instance.l10n.permissionDeniedPleaseAllowMicrophoneCamera;
      } else if (errorStr.contains('microphone') || errorStr.contains('audio')) {
        errorMsg = LocaleController.instance.l10n.microphoneErrorPleaseCheckYourPermissions;
      } else if (errorStr.contains('camera') || errorStr.contains('video')) {
        errorMsg = LocaleController.instance.l10n.cameraErrorPleaseCheckYourPermissions;
      } else if (errorStr.contains('navigator') || errorStr.contains('getusermedia')) {
        errorMsg = LocaleController.instance.l10n.mediaAccessErrorMakeSureHttps;
      } else {
        errorMsg = LocaleController.instance.l10n.errorColon(e.toString());
      }

      _errorMessage = errorMsg;
      await rejectCall();
    }
  }

  /// Rejette l'appel entrant.
  Future<void> rejectCall() async {
    if (_remoteUserId == null) return;

    // Mémorise le callId comme terminal pour ignorer un rejeu `incoming_call`.
    _markTerminalCallId(_currentCallId);

    await _ringtone.stop();
    await _callKit.endAll();

    _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
      'callerId': _remoteUserId.toString(),
    });

    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }

  /// Termine l'appel en cours.
  Future<void> endCall() async {
    _callEndedByUs = true;
    debugPrint('[CallService] 📞 endCall() - Appel terminé par nous');
    if (_remoteUserId != null) {
      final mode = _status == CallStatus.connected
          ? await _webrtc.detectConnectionMode()
          : null;
      _apiClient.sendSocketEvent(SocketEvents.endCall, {
        'targetUserId': _remoteUserId.toString(),
        if (mode != null) 'mode': mode,
      });
    }
    await _terminateCall();
  }

  Future<void> _terminateCall() async {
    speakingDetector.stop();
    await _ringtone.stop();
    await _releaseCallSession();
    await _callKit.endAll();
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _resetCallState();
    _status = CallStatus.ended;
    notify();
    _status = CallStatus.idle;
    await Future.microtask(() {});
    notify();
    try {
      await onCallTerminatedHook?.call();
    } catch (e) {
      debugPrint('[CallService] onCallTerminatedHook échoué: $e');
    }
  }

  void _resetCallState() {
    _resetCallUiState();
    _cancelOutgoingTimeout();
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserPhoto = null;
    _pendingOffer = null;
    _currentCallId = null;
    _callDuration = 0;
    _isMuted = false;
    _isVideoOn = true;
    _isSpeakerOn = false;
    _isRemoteMuted = false;
    _isRemoteVideoOn = true;
    _durationTimer?.cancel();
    _callEndedByUs = false;
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    _isAutoAnsweringFromPush = false;
  }
}