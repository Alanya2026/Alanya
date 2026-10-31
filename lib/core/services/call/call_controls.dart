// Contrôles médias (micro, caméra, haut-parleur) + timer de durée.
// part of call_service.dart.
part of '../call_service.dart';

extension CallControls on CallService {
  Future<void> toggleMute() async {
    await _webrtc.toggleMic();
    _isMuted = !_isMuted;
    speakingDetector.setSpeakerMuted(SpeakingDetector.localKey, _isMuted);
    // Notifier les autres participants de l'état micro
    final isGroup = _groupRoomId != null;
    if (isGroup) {
      _apiClient.sendSocketEvent(SocketEvents.groupMuteState, {
        'roomId': _groupRoomId,
        'isMuted': _isMuted,
      });
    } else if (_remoteUserId != null) {
      _apiClient.sendSocketEvent(SocketEvents.callMuteState, {
        'toUserId': _remoteUserId,
        'isMuted': _isMuted,
      });
    }
    notify();
  }

  Future<void> toggleCamera() async {
    if (!_isVideo || !_webrtc.hasLocalVideoTrack) {
      await _enableCameraWithRenegotiation();
      return;
    }
    await _webrtc.toggleCamera();
    _isVideoOn = !_isVideoOn;
    final isGroup = _groupRoomId != null;
    if (isGroup) {
      _apiClient.sendSocketEvent(SocketEvents.groupVideoState, {
        'roomId': _groupRoomId,
        'isVideoOn': _isVideoOn,
      });
    } else if (_remoteUserId != null) {
      _apiClient.sendSocketEvent(SocketEvents.callVideoState, {
        'toUserId': _remoteUserId,
        'isVideoOn': _isVideoOn,
      });
    }
    notify();
  }

  Future<void> upgradeAudioToVideo() =>
      _enableCameraWithRenegotiation(announceMode: true);

  Future<void> _enableCameraWithRenegotiation({
    bool announceMode = false,
  }) async {
    if (_groupRoomId != null ||
        _confSessionId != null ||
        _remoteUserId == null ||
        _status != CallStatus.connected ||
        _videoTransitionInFlight ||
        (!announceMode && !_isVideo)) {
      return;
    }
    if (announceMode && !isAudioToVideoAvailable) return;

    final transitionId =
        '${DateTime.now().microsecondsSinceEpoch}-${_remoteUserId}';
    final completer = Completer<RTCSessionDescription>();
    _videoTransitionInFlight = true;
    _videoTransitionId = transitionId;
    _videoUpgradeAnswer = completer;
    notify();

    try {
      await _webrtc.addLocalVideoTrack();
      final offer = await _webrtc.createOffer();
      final sent = _apiClient.sendSocketEvent(
        SocketEvents.callVideoUpgradeOffer,
        {
          'targetUserId': _remoteUserId.toString(),
          'callId': _currentCallId,
          'transitionId': transitionId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        },
      );
      if (!sent) throw StateError('Socket indisponible pour la vidéo');

      final answer = await completer.future.timeout(
        const Duration(seconds: 15),
      );
      await _webrtc.handleAnswer(answer);
      final commitAck = Completer<void>();
      _videoUpgradeCommitAck = commitAck;
      final sentCommit = _apiClient
          .sendSocketEvent(SocketEvents.callVideoUpgradeCommit, {
            'targetUserId': _remoteUserId.toString(),
            'callId': _currentCallId,
            'transitionId': transitionId,
          });
      if (!sentCommit) throw StateError('Commit vidéo impossible');
      await commitAck.future.timeout(const Duration(seconds: 5));
      _isVideo = true;
      _isVideoOn = true;
      await CallSessionGuard.instance.updateMode(SessionMode.video);
      await _bindSessionRenderers();
      _apiClient.sendSocketEvent(SocketEvents.callVideoState, {
        'toUserId': _remoteUserId,
        'isVideoOn': true,
      });
      notify();
    } catch (error) {
      final rolledBack = await _webrtc.rollbackNegotiation();
      final discarded = await _webrtc.discardLocalVideoTrack();
      if (!rolledBack || !discarded) {
        debugPrint(
          '[CallService] ** nettoyage vidéo incomplet après échec '
          '(rollback=$rolledBack, piste=$discarded)',
        );
      }
      _apiClient.sendSocketEvent(SocketEvents.callVideoUpgradeCancel, {
        'targetUserId': _remoteUserId,
        'callId': _currentCallId,
        'transitionId': transitionId,
      });
      _showTransientMessage(LocaleController.instance.l10n.callFailed);
      debugPrint('[CallService] ** transition audio → vidéo échouée: $error');
    } finally {
      if (identical(_videoUpgradeAnswer, completer)) {
        _videoUpgradeAnswer = null;
        _videoUpgradeCommitAck = null;
        _videoTransitionId = null;
        _videoTransitionInFlight = false;
        notify();
      }
    }
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  /// Réémet mes états micro et caméra vers la salle.
  ///
  /// Rien ne transporte ces états à l'entrée d'un participant : `call_conf_peers`
  /// et `call_conf_joined` ne portent que l'identité, et les cartes de roster
  /// naissent « micro ouvert, caméra allumée ». Celui qui rejoignait voyait donc
  /// tout le monde non muet, et les autres le voyaient non muet lui aussi, quels
  /// que soient les états réels. Chacun réaffirme les siens à chaque arrivée.
  void _broadcastMyMediaState() {
    final roomId = _groupRoomId;
    if (roomId == null) return;
    _apiClient.sendSocketEvent(SocketEvents.groupMuteState, {
      'roomId': roomId,
      'isMuted': _isMuted,
    });
    _apiClient.sendSocketEvent(SocketEvents.groupVideoState, {
      'roomId': roomId,
      'isVideoOn': _isVideoOn,
    });
  }

  /// Passe à la sortie audio suivante.
  ///
  /// Avec les seules sorties intégrées, le bouton se comporte comme la bascule
  /// haut-parleur d'avant. Dès qu'un casque filaire ou Bluetooth est présent, il
  /// fait le tour des sorties disponibles.
  Future<void> toggleSpeaker() async {
    await setAudioRoute(
      nextAudioRoute(current: _audioRoute, available: _audioRoutes),
    );
  }

  /// Sélectionne une sortie précise.
  ///
  /// La sortie demandée fait foi, sauf si le natif en rapporte une TROISIÈME —
  /// voir [routeApresDemande]. Adopter sans réserve ce que Telecom relit figeait
  /// le bouton : sa relecture arrive avant qu'il n'ait fini d'appliquer, donc
  /// elle annonce encore l'ancienne sortie, et l'appui suivant recalculait la
  /// même cible. Il en fallait deux pour changer de sortie.
  Future<void> setAudioRoute(CallAudioRoute route) async {
    // Lu avant l'aller-retour : c'est lui qui permet de reconnaître une
    // relecture périmée, et il aura changé après.
    final precedente = _audioRoute;
    final rapportee = await audio.AudioHelper.applyAudioRoute(
      route,
      // Telecom ne connaît l'appel que sous l'identifiant qui a ouvert la
      // session CallKit, jamais sous celui du serveur.
      telecomCallId: _callKitCallId,
    );
    _adopterSortiesOffertes(rapportee.supportedMask);
    final effective = routeApresDemande(
      precedente: precedente,
      demandee: route,
      rapportee: rapportee.routeName,
    );
    _retenirRoute(effective);
    // La sortie audio dit où est le téléphone : sur l'écouteur interne, il est
    // contre l'oreille et l'écran doit s'éteindre à l'approche. Ce point de
    // passage est unique — choix d'ouverture, bouton, casque branché en cours
    // d'appel y aboutissent tous —, donc c'est le seul endroit à prévenir.
    await CallSessionGuard.instance.updateAudioRoute(effective);
    debugPrint('[CallService] 🔊 Sortie audio: ${effective.name}');
    notify();
  }

  /// Retient les sorties que le natif déclare atteignables.
  ///
  /// Le masque de Telecom est une meilleure source que l'énumération des
  /// périphériques, qui n'annonce pas toujours l'écouteur interne. Il ne
  /// souffre pas du décalage qui affecte la route : il ne change qu'au
  /// branchement d'un appareil.
  void _adopterSortiesOffertes(int? masque) {
    if (masque == null) return;
    final offertes = routesFromSupportedMask(masque);
    if (offertes.isNotEmpty) _audioRoutes = offertes;
  }

  /// Fixe la sortie courante, et l'état du bouton qui en découle.
  void _retenirRoute(CallAudioRoute route) {
    _audioRoute = route;
    _isSpeakerOn = speakerphoneForRoute(route);
  }

  /// Choisit la sortie d'ouverture d'un appel et se met à l'écoute des
  /// branchements.
  ///
  /// Remplace le `setSpeakerphoneOn(isVideo)` posé à l'initialisation : un
  /// casque déjà connecté doit être pris, plutôt que de renvoyer le son dans le
  /// haut-parleur du téléphone.
  Future<void> _initAudioRoute({required bool isVideo}) async {
    if (kIsWeb) return;
    final kinds = await audio.AudioHelper.availableOutputKinds();
    _audioRoutes = availableAudioRoutes(kinds);
    await setAudioRoute(defaultAudioRoute(kinds: kinds, isVideo: isVideo));
    _watchAudioOutputs(isVideo: isVideo);
  }

  /// Un casque branché ou débranché en cours d'appel doit se voir sans que
  /// l'utilisateur ait à toucher quoi que ce soit.
  void _watchAudioOutputs({required bool isVideo}) {
    _audioOutputsSub?.cancel();
    _audioOutputsSub = audio.AudioHelper.audioOutputsChanged.listen((_) async {
      final kinds = await audio.AudioHelper.availableOutputKinds();
      _audioRoutes = availableAudioRoutes(kinds);
      final resolved = resolveAudioRouteAfterChange(
        current: _audioRoute,
        kinds: kinds,
        isVideo: isVideo,
      );
      if (resolved != _audioRoute) {
        await setAudioRoute(resolved);
      } else {
        // Un casque qui se connecte peut faire rebasculer Telecom tout seul :
        // relire plutôt que supposer que rien n'a bougé. Ici la lecture fait
        // foi sans réserve — rien n'a été demandé, donc elle ne peut pas être
        // en retard sur une demande.
        final lue = await audio.AudioHelper.readAppliedRoute(_callKitCallId);
        if (lue != null) {
          _adopterSortiesOffertes(lue.supportedMask);
          _retenirRoute(
            resolveAppliedRoute(
              requested: _audioRoute,
              reportedName: lue.routeName,
            ),
          );
        }
        notify();
      }
    });
  }

  void _stopWatchingAudioOutputs() {
    _audioOutputsSub?.cancel();
    _audioOutputsSub = null;
  }

  void _startDurationTimer() {
    _callDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notify();
    });
  }
}
