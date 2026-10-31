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
    // Essai fini, aucun abonnement : le compte reçoit, il n'appelle pas. Refusé
    // ici, avant toute fenêtre d'appel — rien à défaire. Le panneau de
    // l'abonnement s'ouvre ; le serveur refuserait de toute façon.
    if (!EntitlementService.allowsOutgoing) {
      EntitlementService.maybeInstance?.reportOutgoingBlocked();
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
      final type = isVideo ? CallType.video : CallType.audio;
      _webrtc.onLocalStream = (_) {
        notify();
      };
      _webrtc.onRemoteStream = (_) {
        notify();
      };

      // Capture et serveurs ICE sont indépendants : les lancer de front met le
      // micro en route sans attendre le réseau. Voir `answerCall` pour le
      // détail du raisonnement — c'est là que le décalage se voyait le plus.
      final mediaFuture = _webrtc.acquireLocalMedia(type);
      final iceFuture = _apiClient.fetchIceServers();

      // Borner l'acquisition : entre le décrochage et l'envoi de la réponse,
      // plus aucune horloge ne couvre l'appel — `_armAwaitingOfferTimeout` et
      // `_armIncomingRingSafety` viennent d'être désarmés, et rien ne surveille
      // l'état `connecting`. Or `acquireLocalMedia` demande la permission micro
      // si elle n'a jamais été accordée : au démarrage à froid depuis l'écran
      // verrouillé, MainActivity s'affiche par-dessus le verrou mais la boîte
      // de dialogue système, elle, non — la réponse n'arrive qu'après
      // déverrouillage, et l'attente ne se terminait jamais.
      try {
        await mediaFuture.timeout(CallService._mediaAcquireTimeout);
      } on TimeoutException {
        debugPrint('[CallService] ⏰ acquisition média sans réponse → teardown');
        _errorMessage = LocaleController.instance.l10n.callFailed;
        await _terminateCall();
        return;
      }
      notify();

      // Sortie audio : un casque déjà connecté l'emporte, sinon haut-parleur
      // en vidéo et écouteur en audio, comme avant.
      await _initAudioRoute(isVideo: isVideo);

      await _webrtc.buildPeerConnection(type, iceServers: await iceFuture);

      // ICE candidates envoyés au destinataire. Ils sont aussi conservés :
      // tant que le téléphone d'en face sonne, le serveur n'a pas d'appareil
      // où les router, et WebRTC ne repasse jamais deux fois par le même
      // candidat. Sans ce doublon local, le destinataire décroche sans un seul
      // candidat distant. Voir `_replayOutgoingIce`.
      _webrtc.onIceCandidate = (candidate) {
        final payload = <String, dynamic>{
          'targetUserId': targetUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'generation': _webrtc.iceGeneration,
          if (_currentCallId != null) 'callId': _currentCallId,
        };
        if (_outgoingIceOutbox.length < CallService._maxOutgoingIceReplay) {
          _outgoingIceOutbox.add((
            generation: _webrtc.iceGeneration,
            payload: payload,
          ));
        }
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, payload);
      };

      _wireOneToOneConnectionStateHandlers();

      final offer = await _webrtc.createOffer();

      _apiClient.sendSocketEvent(SocketEvents.callUser, {
        'targetUserId': targetUserId.toString(),
        'callerId': myId.toString(),
        'callerName': myName,
        'callerPhoto': myPhoto,
        'isVideo': isVideo,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });

      _status = CallStatus.connecting;

      if (!kIsWeb) {
        await _acquireCallSession(
          isVideo: isVideo,
          displayName:
              targetUserName ?? LocaleController.instance.l10n.callNoun,
          handle: targetUserId.toString(),
        );
        await persistOutgoingSnapshot(phase: 'connecting');
      }

      // Un état terminal a pu arriver PENDANT les `await` ci-dessus.
      //
      // `_acquireCallSession` monte CallKit et le service de premier plan :
      // cent à trois cents millisecondes sur Android. Le serveur, lui, répond
      // parfois bien plus vite — `call_voicemail` en particulier, qui n'a
      // personne à faire sonner et ne fait qu'écrire une ligne d'historique.
      // Son gestionnaire démontait alors l'appel, puis cette fonction
      // reprenait ici et démarrait une sonnerie de retour sur un appel déjà
      // mort. `startOutgoingRingback` ne vérifie aucun état, et le filet des
      // 50 secondes ci-dessous teste un statut qui n'est plus actif : plus
      // rien n'arrêtait le son. L'appelant entendait la sonnerie tourner sous
      // l'écran d'enregistrement, jusqu'à ce qu'il tue l'application.
      //
      // Vaut pour tous les états terminaux rapides — `call_busy`,
      // `call_failed`, `call_rejected` — pas seulement pour le répondeur.
      if (_status != CallStatus.outgoing && _status != CallStatus.connecting) {
        debugPrint(
          '[CallService] 🛡 initiateCall: appel déjà terminé pendant la mise en place',
        );
        return;
      }

      // Ringback côté appelant
      _ringtone.startOutgoingRingback();

      // Filet de sécurité local : si aucun état terminal serveur n'arrive
      // (call_answered / call_busy / call_no_answer / call_rejected…), on
      // abandonne l'appel pour ne pas laisser le ringback tourner indéfiniment.
      _cancelOutgoingTimeout();
      _outgoingTimeoutTimer = Timer(CallService._outgoingTimeout, () async {
        if (_status == CallStatus.outgoing ||
            _status == CallStatus.connecting) {
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

      // Le tri se faisait sur `e.toString().contains(...)`. Le message de
      // getUserMedia n'est stable ni entre versions de flutter_webrtc, ni
      // entre Android et iOS, et la branche par défaut affichait l'exception.
      _errorMessage = presenterErreurGlobale(e, domaine: ErrorDomain.appel);
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
      debugPrint(
        '[CallService] ⏳ answerCall: offre pas encore reçue → attente bornée',
      );
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

    final offer = _pendingOffer!;
    _pendingOffer = null;

    // L'appel qu'on décroche peut disparaître pendant qu'on le décroche : un
    // aperçu CallKit mal interprété, un `call_ended` en retard, un refus venu
    // d'un autre appareil. Rien ici ne le revérifiait, et la suite continuait
    // sur un état remis à zéro — voir `answerStillValid`.
    final callIdAuDepart = _currentCallId;
    Future<bool> appelToujoursLa() async {
      if (answerStillValid(
        callStatusName: _status.name,
        callIdAtStart: callIdAuDepart,
        currentCallId: _currentCallId,
        endingCall: _isEndingCall || _callEndedByUs,
      )) {
        return true;
      }
      debugPrint(
        '[CallService] 🛡 décrochage abandonné : l\'appel $callIdAuDepart a '
        'disparu en route (statut=$_status courant=$_currentCallId)',
      );
      // Rien à annoncer au serveur ni au pair : celui qui a démonté l'appel
      // s'en est déjà chargé. On ne touche pas non plus à la pile média si un
      // autre appel l'a reprise — sinon la capture qu'on vient d'ouvrir est la
      // nôtre, et le micro resterait chaud.
      if (_currentCallId == null &&
          (_status == CallStatus.idle || _status == CallStatus.ended)) {
        await _webrtc.dispose();
      }
      return false;
    }

    try {
      final type = _isVideo ? CallType.video : CallType.audio;
      _webrtc.onLocalStream = (_) {
        notify();
      };
      _webrtc.onRemoteStream = (_) {
        notify();
      };

      // Le micro d'abord, le réseau ensuite.
      //
      // Ces trois attentes sont indépendantes, et elles étaient enchaînées :
      // l'attente du socket (jusqu'à 5 s au réveil par push), puis un
      // aller-retour HTTPS vers `/turn/credentials`, puis seulement
      // `getUserMedia`. La capture ne dépend pourtant ni du socket ni des
      // serveurs ICE — c'est ce qui faisait s'allumer le micro plusieurs
      // secondes après le décrochage, là où WhatsApp paraît instantané parce
      // que rien n'est placé entre le tap et l'ouverture du périphérique.
      //
      // `fetchIceServers` ne lève jamais : elle retombe sur les STUN publics
      // en interne. `ensureSocketReady` est neutralisée par prudence — si
      // l'acquisition média échoue la première, plus personne ne l'attendrait.
      final mediaFuture = _webrtc.acquireLocalMedia(type);
      final iceFuture = _apiClient.fetchIceServers();
      final socketFuture = _apiClient.ensureSocketReady().catchError(
        (_) => false,
      );

      await mediaFuture;
      if (!await appelToujoursLa()) return;
      notify();

      await _initAudioRoute(isVideo: _isVideo);

      if (!await socketFuture) {
        debugPrint(
          '[CallService] ** Socket non prêt après 5s (connected=${_apiClient.isSocketConnected})',
        );
        _errorMessage = LocaleController.instance.l10n.socketNotConnected;
        // Teardown complet (au lieu d'un simple idle) : ferme CallKit, coupe la
        // sonnerie et réinitialise l'état pour ne pas laisser d'écran/état
        // fantôme — et libère la capture qu'on vient tout juste d'ouvrir.
        // Le nettoyage côté appelant est assuré par le timeout serveur.
        await _terminateCall();
        return;
      }
      debugPrint('[CallService] !! Socket connecté, envoi answer');
      if (!await appelToujoursLa()) return;

      await _webrtc.buildPeerConnection(type, iceServers: await iceFuture);

      // Le répondeur garde ses candidats, comme l'appelant garde les siens.
      //
      // Il n'avait pas de tampon : ses candidats partaient directement, et
      // `sendSocketEvent` les jette en rendant `false` quand le socket n'est
      // pas prêt — valeur ignorée ici. Côté serveur, `ice_candidate` sort aussi
      // sans rien dire tant que la propriété d'appareil n'est pas revendiquée,
      // ce qui n'arrive qu'au traitement de `answer_call`.
      //
      // Or les candidats relais, ceux qui passent par TURN, sont les derniers
      // rassemblés — plusieurs secondes après le décrochage, exactement la
      // fenêtre où un socket monté au démarrage à froid peut hoqueter. Et
      // WebRTC ne repasse jamais par `onIceCandidate` pour un candidat déjà
      // émis. Sur un réseau qui exige TURN, l'appelant se retrouvait sans
      // aucune paire testable : silence des deux côtés.
      _webrtc.onIceCandidate = (candidate) {
        final payload = <String, dynamic>{
          'targetUserId': _remoteUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'generation': _webrtc.iceGeneration,
          if (_currentCallId != null) 'callId': _currentCallId,
        };
        if (_outgoingIceOutbox.length < CallService._maxOutgoingIceReplay) {
          _outgoingIceOutbox.add((
            generation: _webrtc.iceGeneration,
            payload: payload,
          ));
        }
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, payload);
      };

      _wireOneToOneConnectionStateHandlers();

      await _webrtc.handleOffer(
        RTCSessionDescription(offer['sdp'] as String, 'offer'),
      );

      final answer = await _webrtc.createAnswer();
      // Dernier contrôle avant d'écrire chez les autres : au-delà, la réponse
      // part sur le socket et engage le serveur.
      if (!await appelToujoursLa()) return;

      // La réponse WebRTC est le seul message que l'appelant attend, et elle
      // partait sans accusé ni file — contrairement au raccrochage, qui a reçu
      // les deux. Perdue sur un socket zombie, elle ne repartait jamais :
      // l'appelé affichait « en cours » avec son chronomètre, l'appelant
      // restait sur « connexion », et aucun média ne passait jusqu'à l'échec
      // ICE puis au délai global.
      //
      // Entre la vérification du socket et cette émission, il s'écoule
      // `buildPeerConnection`, `handleOffer` et `createAnswer` — plusieurs
      // centaines de millisecondes d'allers-retours natifs, sur un socket monté
      // quelques secondes plus tôt au démarrage à froid.
      final reponseAccusee = await _apiClient.sendSocketEventAcked(
        SocketEvents.answerCall,
        {
          'callerId': _remoteUserId.toString(),
          'callId': _currentCallId,
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        },
      );
      if (!reponseAccusee) {
        debugPrint(
          '[CallService] ** réponse WebRTC sans accusé → reconstruction et '
          'seconde tentative',
        );
        // Le socket paraissait prêt et n'a rien accusé : il est mort sans le
        // dire. On le reconstruit et on réémet une fois — l'appel n'a pas
        // d'autre chance, et le serveur traite une seconde réponse par son
        // refus explicite plutôt que par un dégât.
        await _apiClient.forceReconnect();
        final secondeChance = await _apiClient.sendSocketEventAcked(
          SocketEvents.answerCall,
          {
            'callerId': _remoteUserId.toString(),
            'callId': _currentCallId,
            'answer': {'sdp': answer.sdp, 'type': answer.type},
          },
        );
        if (!secondeChance) {
          debugPrint('[CallService] ** réponse WebRTC perdue → teardown');
          _errorMessage = LocaleController.instance.l10n.callFailed;
          await _terminateCall();
          return;
        }
      }

      // L'accusé a pu se faire attendre : sans ce contrôle, un appel démonté
      // entre-temps repassait « connecté » sous un identifiant fabriqué par
      // `_ensureCallId`, et la fin d'appel du serveur ne le reconnaissait plus.
      if (!await appelToujoursLa()) return;

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
          displayName:
              _remoteUserName ?? LocaleController.instance.l10n.callNoun,
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

      _errorMessage = presenterErreurGlobale(e, domaine: ErrorDomain.appel);
      await rejectCall();
    }
  }

  /// Rejette l'appel entrant.
  Future<void> rejectCall() async {
    // Toujours nettoyer CallKit/sonnerie même sans remoteUserId (écran fantôme).
    _markTerminalCallId(_currentCallId);

    await _ringtone.stop();
    await _callKit.endAll(callId: _callKitCallId ?? _currentCallId);

    if (_remoteUserId != null) {
      _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
        'callerId': _remoteUserId.toString(),
      });
    }

    // Atteint depuis le catch d'answerCall, donc après un init() qui a pu
    // réussir : sans ces deux libérations, le micro restait chaud (et le
    // service de premier plan debout) après un décrochage raté.
    await _releaseCallSession();
    await _webrtc.dispose();

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
        final mode =
            (_status == CallStatus.connected ||
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

  /// Le raccrochage n'attend pas : on rend la main tout de suite et le sort de
  /// l'émission se règle en arrière-plan.
  void _emitEndCallOrEnqueue(Map<String, dynamic> payload) {
    unawaited(_emettreRaccrochage(payload));
  }

  /// Émet le raccrochage, et **le remet en file s'il n'est pas accusé**.
  ///
  /// `isSocketReady` ne prouve rien sur un socket zombie : le TCP est mort,
  /// mais Socket.IO ne le constate qu'au bout de son ping — 25 s d'intervalle,
  /// 20 s de patience. Pendant ces quarante-cinq secondes, le raccrochage part
  /// dans le vide sans un mot, et le pair reste sur « Reconnexion… » jusqu'à
  /// son propre délai alors que l'appel est fini de ce côté-ci. Le cas est
  /// d'autant plus probable que l'appel a duré.
  ///
  /// Un accusé tranche. Sans lui, la mise en file seule ne suffirait pas : le
  /// rejeu attend `auth:verified`, qui n'arrivera jamais tant que personne ne
  /// reconstruit le socket. Ici l'appel est déjà terminé localement — il n'y a
  /// plus de signalisation à couper, c'est donc le moment de le faire.
  ///
  /// Réémettre est sans danger : le serveur traite un second `end_call` par sa
  /// sortie « déjà hors appel », qui ne touche à rien.
  Future<void> _emettreRaccrochage(Map<String, dynamic> payload) async {
    if (!_apiClient.isSocketReady) {
      debugPrint('[CallService] ⏳ Socket non prêt → end_call mis en file');
      _pendingEndCalls.add(payload);
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
      return;
    }

    bool accuse;
    try {
      accuse = await _apiClient.sendSocketEventAcked(
        SocketEvents.endCall,
        payload,
      );
    } catch (e) {
      debugPrint('[CallService] endCall socket error: $e');
      accuse = false;
    }
    if (accuse) return;

    debugPrint(
      '[CallService] ** end_call sans accusé → file + reconstruction du socket',
    );
    _pendingEndCalls.add(payload);
    unawaited(_apiClient.forceReconnect());
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
    final wasConnected =
        _status == CallStatus.connected || _status == CallStatus.reconnecting;
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
      await _callKit.endAll(callId: _callKitCallId ?? _currentCallId);
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
    final pendingVideoAnswer = _videoUpgradeAnswer;
    if (pendingVideoAnswer != null && !pendingVideoAnswer.isCompleted) {
      pendingVideoAnswer.completeError(StateError('Appel terminé'));
    }
    _videoUpgradeAnswer = null;
    _videoTransitionId = null;
    _videoTransitionInFlight = false;
    _pendingRemoteVideoCommitId = null;
    _resetCallUiState();
    _clearIncomingPresentation();
    _cancelOutgoingTimeout();
    _cancelAwaitingOfferTimeout();
    _cancelIncomingRingSafety();
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserPhoto = null;
    _outgoingIceOutbox.clear();
    _pendingOffer = null;
    _currentCallId = null;
    _callKitCallId = null;
    _serverCallIdKnown = false;
    _callDuration = 0;
    _isMuted = false;
    _isVideoOn = true;
    _isSpeakerOn = false;
    _stopWatchingAudioOutputs();
    _audioRoute = CallAudioRoute.earpiece;
    _audioRoutes = const [CallAudioRoute.earpiece, CallAudioRoute.speaker];
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
