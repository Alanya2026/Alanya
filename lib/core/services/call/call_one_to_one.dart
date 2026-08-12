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
    // Point de passage obligé de tous les appels sortants (pavé numérique,
    // en-tête de conversation, modal profil, journal d'appels…) : un seul
    // garde-fou suffit donc à couvrir l'auto-appel partout.
    if (targetUserId == myId) {
      _errorMessage = LocaleController.instance.l10n.cannotCallYourself;
      notify();
      return;
    }
    if (_status != CallStatus.idle) {
      _errorMessage = LocaleController.instance.l10n.aCallIsAlreadyInProgress;
      notify();
      return;
    }
    if (!await _ensureFullyConnectedForOutgoingCall()) return;
    _errorMessage = null;
    _status = CallStatus.outgoing;
    _isOutgoingCaller = true;
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
          'generation': _webrtc.iceGeneration,
          if (_currentCallId != null) 'callId': _currentCallId,
        });
      };

      _wireOneToOneConnectionStateHandlers();

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
        await persistOutgoingSnapshot(phase: 'connecting');
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
          _markTerminalCallId(_currentCallId);
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
      debugPrint('[CallService] ⏳ answerCall: offre pas encore reçue → attente bornée');
      // Ne PAS revenir en silence (bouton mort). On arme l'auto-réponse pour la
      // vraie offre, on coupe la sonnerie puisque l'utilisateur a accepté, on
      // affiche « connexion en cours » et on borne l'attente (teardown si l'offre
      // n'arrive jamais — appel périmé / rejeu fantôme).
      _autoAnswerOnNextIncoming = true;
      _autoAnswerCallerId = _remoteUserId!.toString();
      _isAutoAnsweringFromPush = true;
      _clearIncomingPresentation(callId: _activeIncomingPresentationCallId);
      await _ringtone.stop();
      notify();
      _armAwaitingOfferTimeout();
      return;
    }

    // L'offre est là : plus besoin des filets d'attente/sonnerie entrante.
    _cancelAwaitingOfferTimeout();
    _cancelIncomingRingSafety();

    // Verrouille immédiatement pour bloquer un éventuel double-appel.
    _status = CallStatus.connecting;
    _isOutgoingCaller = false;
    // L'auto-réponse a fait son office : on repasse en navigation normale pour
    // que la minimisation de l'écran d'appel ne le ré-ouvre pas en boucle.
    _isAutoAnsweringFromPush = false;
    _clearIncomingPresentation(callId: _activeIncomingPresentationCallId);
    notify();

    await _ringtone.stop();
    _errorMessage = null;
    final socketReady = await _apiClient.ensureSocketReady();
    if (!socketReady) {
      debugPrint('[CallService] ** Socket non prêt après 5s (connected=${_apiClient.isSocketConnected})');
      _errorMessage = LocaleController.instance.l10n.socketNotConnected;
      // Teardown complet (au lieu d'un simple idle) : ferme CallKit, coupe la
      // sonnerie et réinitialise l'état pour ne pas laisser d'écran/état fantôme.
      // Le nettoyage côté appelant est assuré par le timeout serveur (no-answer).
      await _terminateCall();
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
          'generation': _webrtc.iceGeneration,
          if (_currentCallId != null) 'callId': _currentCallId,
        });
      };

      _wireOneToOneConnectionStateHandlers();

      await _webrtc.handleOffer(
        RTCSessionDescription(offer['sdp'] as String, 'offer'),
      );

      final answer = await _webrtc.createAnswer();

      _apiClient.sendSocketEvent(SocketEvents.answerCall, {
        'callerId': _remoteUserId.toString(),
        'callId': _currentCallId,
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: false);
      // Notifier l'UI immédiatement : l'audio WebRTC est prêt. La session
      // CallKit/FGS ne doit pas bloquer le passage à « En cours » (cold-start),
      // c'est pourquoi notify() est appelé avant _acquireCallSession ci-dessous.
      notify();
      if (!kIsWeb) {
        await _acquireCallSession(
          isVideo: _isVideo,
          displayName: _remoteUserName ?? LocaleController.instance.l10n.callNoun,
          handle: _remoteUserId.toString(),
          // startCallKit: true, y compris pour un entrant déjà accepté : c'est
          // ICI que le foreground service Android est démarré, et nulle part
          // ailleurs. Le tap « Accepter » ne démarre plus de FGS
          // (EXTRA_CALLKIT_CALLING_SHOW=false, voir CallIncomingHelper) car le
          // service ne peut pas honorer startForeground() sans engine Flutter
          // (crash ForegroundServiceDidNotStartInTime, app tuée). Une fois ici,
          // l'engine est prêt → le service se construit avec un manager valide.
          startCallKit: true,
        );
        await _markCallSessionConnected();
      }
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
    // Toujours nettoyer CallKit/sonnerie même sans remoteUserId (écran fantôme).
    _markTerminalCallId(_currentCallId);

    await _ringtone.stop();
    await _callKit.endAll(callId: _currentCallId);

    if (_remoteUserId != null) {
      _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
        'callerId': _remoteUserId.toString(),
      });
    }

    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }

  /// Termine l'appel en cours.
  Future<void> endCall() async {
    if (_isEndingCall ||
        _status == CallStatus.ended ||
        _status == CallStatus.idle) {
      debugPrint(
        '[CallService] endCall() ignoré (déjà en fin status=$_status '
        'ending=$_isEndingCall)',
      );
      return;
    }
    _isEndingCall = true;
    _callEndedByUs = true;
    _cancelAllReconnectTimers();
    debugPrint('[CallService] 📞 endCall() - Appel terminé par nous');
    _markTerminalCallId(_currentCallId);

    try {
      if (_remoteUserId != null) {
        final mode = (_status == CallStatus.connected ||
                _status == CallStatus.reconnecting)
            ? await _webrtc.detectConnectionMode()
            : null;
        final payload = <String, dynamic>{
          'targetUserId': _remoteUserId.toString(),
          if (mode != null) 'mode': mode,
        };
        _emitEndCallOrEnqueue(payload);
      }
      // Hangup volontaire : force même s'il reste des pairs mesh (on part seuls).
      await _terminateCall(fromEndCall: true, force: true);
    } finally {
      _isEndingCall = false;
    }
  }

  void _emitEndCallOrEnqueue(Map<String, dynamic> payload) {
    if (_apiClient.isSocketReady) {
      try {
        _apiClient.sendSocketEvent(SocketEvents.endCall, payload);
      } catch (e) {
        debugPrint('[CallService] endCall socket error: $e');
        _pendingEndCalls.add(payload);
      }
    } else {
      debugPrint('[CallService] ⏳ Socket non prêt → end_call mis en file');
      _pendingEndCalls.add(payload);
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
    }
  }

  /// [fromEndCall] : true si déjà sous la garde `_isEndingCall` de [endCall].
  /// [force] : autorise le teardown même si une session conf a encore des pairs
  /// (départ volontaire initiateur transfert / hangup local).
  Future<void> _terminateCall({
    bool fromEndCall = false,
    bool force = false,
  }) async {
    if (_isEndingCall && !fromEndCall) {
      debugPrint('[CallService] _terminateCall ignoré (déjà en fin)');
      return;
    }

    // Entonnoir anti raccrochage intempestif (piège transfert / conf) :
    // bloquer seulement tant qu'il reste 2+ pairs mesh (vrai appel à 3).
    // À deux (1 pair), un hangup / Closed doit pouvoir terminer l'appel.
    if (!force && _confSessionId != null && _groupPeerConnections.length >= 2) {
      debugPrint(
        '[CallService] 🛡 _terminateCall bloqué (session=$_confSessionId '
        'pairs=${_groupPeerConnections.keys.toList()})',
      );
      return;
    }

    if (!fromEndCall) _isEndingCall = true;

    if (_confSessionId != null) {
      debugPrint(
        '[CallService] ⚠ _terminateCall PENDANT une session '
        '(session=$_confSessionId, invitéEnAttente=${_confPendingInvitee?.id}, '
        'force=$force)\n'
        '${StackTrace.current}',
      );
    }
    // Capturé avant le teardown : le son ne doit sonner que si une conversation
    // était établie, pas sur un rejet, un timeout ou un échec de connexion.
    final wasConnected = _status == CallStatus.connected ||
        _status == CallStatus.reconnecting;
    try {
      speakingDetector.stop();
      _cancelAllReconnectTimers();
      _markTerminalCallId(_currentCallId);
      _cancelOutgoingRestoreTimeout();
      _isRestoringOutgoing = false;
      await _clearOutgoingSnapshot();
      await _ringtone.stop();
      await _releaseCallSession();
      // Mesh d'abord, sans retrigger onConnectionFailure → end_call parasite.
      _webrtc.onConnectionFailure = null;
      _webrtc.onConnectionStateChanged = null;
      _clearAllGroupPeers(disarmOriginFailure: true);
      await _callKit.endAll(callId: _currentCallId);
      await _webrtc.dispose();
      _durationTimer?.cancel();
      // Après la libération de la session audio : le son part sur le canal
      // notification (haut-parleur) et non plus dans l'écouteur de l'appel.
      if (wasConnected) MessageSoundService.instance.playCallEnd();
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
    } finally {
      if (!fromEndCall) _isEndingCall = false;
    }
  }

  void _resetCallState() {
    _resetCallUiState();
    _clearIncomingPresentation();
    _cancelOutgoingTimeout();
    _cancelAwaitingOfferTimeout();
    _cancelIncomingRingSafety();
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
    _isRestoringOutgoing = false;
    _cancelOutgoingRestoreTimeout();
    _isOutgoingCaller = false;
    _iceRestartCount = 0;
    _isIceRestarting = false;
    _cancelAllReconnectTimers();
    // Session à trois : tout est soldé avec l'appel. Le droit d'ajout et le
    // mode grille dépendent aussi de _groupRoomId : le conserver après la fin
    // d'une conférence ferait traiter le prochain appel 1-à-1 comme un groupe.
    _groupRoomId = null;
    _confSessionId = null;
    _confPendingInvitee = null;
    _confInvitedBy = null;
    _confInviteIsMine = false;
    _isTransferInitiator = false;
    _transferTargetId = null;
    _transferLeaveInMs = null;
    _transferArmedAt = null;
    _transferStatus = CallTransferStatus.none;
    _confMode = 'join';
    _confReadySent.clear();
    _pendingConfReady.clear();
    _pendingConfJoinSessionId = null;
    _myRosterId = null;
  }
}