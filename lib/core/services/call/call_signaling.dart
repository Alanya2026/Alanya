// Mise en place des listeners Socket.IO (1-à-1 et groupe) — part of call_service.dart.
part of '../call_service.dart';

extension CallSignaling on CallService {
  void _setupSocketListeners() {
    // Appels 1-à-1

    // Appel entrant
    _apiClient.onSocketEvent(SocketEvents.incomingCall, (data) async {
      debugPrint('[CallService] 📞 Appel entrant reçu: $data');
      if (data is! Map) {
        debugPrint('[CallService] ** Données invalides pour incoming_call');
        return;
      }
      final incomingCallerId = data['callerId']?.toString() ?? '';
      // Cold start via CallKit : l'utilisateur a déjà tapé « Accepter » avant que
      // l'offre WebRTC arrive — on attend l'offer avec status=incoming.
      final waitingForOffer = _status == CallStatus.incoming && _pendingOffer == null;
      final callerMatches = incomingCallerId.isNotEmpty &&
          (incomingCallerId == _remoteUserId?.toString() ||
              (_autoAnswerOnNextIncoming && _autoAnswerCallerId == incomingCallerId));
      // Glare : les deux correspondent se appellent — basculer sortant → entrant.
      final outgoingGlare = (_status == CallStatus.outgoing ||
              _status == CallStatus.connecting) &&
          incomingCallerId.isNotEmpty &&
          incomingCallerId == _remoteUserId?.toString();
      if (_status != CallStatus.idle &&
          !(waitingForOffer && callerMatches) &&
          !outgoingGlare) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: status=$_status');
        return;
      }
      if (outgoingGlare) {
        debugPrint(
          '[CallService] 🔀 Glare: abandon sortant vers $incomingCallerId → entrant',
        );
        _cancelOutgoingTimeout();
        await _ringtone.stop();
        await _releaseCallSession();
        await _webrtc.dispose();
        await _callKit.endAll();
        _resetCallState();
        _status = CallStatus.idle;
      }
      if (_isMeetingActive()) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: réunion active');
        return;
      }
      if (incomingCallerId.isEmpty) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: callerId absent');
        return;
      }
      final incomingCallId = data['callId']?.toString();
      // Idempotence : appel déjà accepté/refusé/terminé → ignorer le rejeu (auth
      // replay). On consulte AUSSI le registre persistant (EndedCallRegistry),
      // comme tous les points d'entrée push/CallKit : sinon au cold-start (map
      // mémoire vidée) un appel déjà terminé — marqué par l'isolate FCM ou une
      // session précédente — ré-afficherait un écran/sonnerie fantôme.
      if (_isTerminalCallId(incomingCallId) ||
          await EndedCallRegistry.isEnded(incomingCallId)) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: callId=$incomingCallId déjà traité (terminal)');
        return;
      }
      if (_alreadyHandledIncomingCallId(incomingCallId)) {
        debugPrint('[CallService] 🛡 incoming_call dupliqué ignoré: callId=$incomingCallId');
        return;
      }
      final offer = data['offer'];
      if (offer is! Map || offer['sdp'] == null) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: offer absente/invalide');
        return;
      }
      _remoteUserId = int.tryParse(incomingCallerId);
      if (_remoteUserId == null) {
        debugPrint('[CallService] 🛡 incoming_call ignoré: callerId non numérique');
        return;
      }
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = normalizeBackendUrl(data['callerPhoto']?.toString());
      _isVideo = data['isVideo'] == true;
      _pendingOffer = Map<String, dynamic>.from(offer);
      // Appel confirmé vivant par le socket → plus besoin du filet d'attente d'offre.
      _cancelAwaitingOfferTimeout();
      _adoptServerCallId(incomingCallId);
      _status = CallStatus.incoming;
      debugPrint('[CallService] !!Statut changé à INCOMING. Caller: $_remoteUserName ($_remoteUserId), Vidéo: $_isVideo');

      // Préchauffage : la sonnerie dure plusieurs secondes, autant s'en servir.
      //
      // Ni l'un ni l'autre ne touche à un périphérique — aucun témoin de
      // confidentialité ne s'allume ici, la capture reste pour le décrochage.
      // On ne fait que mettre en cache ce que `answerCall` attendait jusqu'ici
      // en série après le tap : les identifiants TURN (un aller-retour HTTPS)
      // et l'accord sur micro/caméra (une boîte de dialogue système au tout
      // premier appel). Les deux relectures y seront alors immédiates.
      unawaited(_apiClient.fetchIceServers());
      unawaited(
        CallPermissionsHelper.ensureCallMediaPermissions(isVideo: _isVideo),
      );

      _ensureRemoteIdentityResolved();

      // Une seule autorité décide qui présente — voir
      // `_resolveIncomingPresentation`. L'action rendue pilote aussi
      // l'affichage CallKit et la sonnerie, plus bas.
      final presentation = _resolveIncomingPresentation(
        callId: incomingCallId,
        intent: IncomingPresentationIntent.signal,
      );
      // Aucun entrant ne doit rester posé sans horloge locale : c'est le seul
      // recours si ni CallKit ni le serveur ne concluent.
      _armIncomingRingSafety();
      notify();

      if (_autoAnswerOnNextIncoming && _autoAnswerCallerId == incomingCallerId) {
        debugPrint('[CallService] ⚡ Auto-answer en 500ms (CallKit pré-accepté)');
        _autoAnswerOnNextIncoming = false;
        _autoAnswerCallerId = null;

        // !! Attendre 500ms pour que l'app soit bien initialisée avant d'auto-répondre
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          await answerCall();
        } catch (e) {
          debugPrint('[CallService] ** Auto-answer failed: $e');
        }
        return;
      }

      // La politique tient dans l'action rendue : CallKit possède l'entrant
      // (interface système et sonnerie), Flutter le possède (IncomingCallScreen
      // et RingtoneService), ou personne ne le présente — auto-réponse en cours,
      // ou entrant déjà présenté pour ce même identifiant.
      if (presentation == IncomingPresentationAction.showNativeCallKit) {
        if (_nativeAndroidHandlesIncomingCallUi) {
          debugPrint(
            '[CallService] 📲 CallKit natif Android (socket ignoré pour UI): '
            'callId=$incomingCallId',
          );
        } else {
          debugPrint('[CallService] 📲 CallKit depuis socket (app en arrière-plan)');
          unawaited(
            _callKit
                .showIncoming(
                  callId: incomingCallId ?? '',
                  callerId: incomingCallerId,
                  callerName: _remoteUserName ?? resolveL10n().callNoun,
                  callerPhoto: _remoteUserPhoto,
                  isVideo: _isVideo,
                  silent: false,
                )
                .catchError((e) {
              debugPrint('[CallService] ** CallKit showIncoming error: $e');
            }),
          );
        }
      } else if (presentation ==
          IncomingPresentationAction.showFlutterIncoming) {
        _startFlutterIncomingRinging(incomingCallId ?? '');
      } else {
        debugPrint(
          '[CallService] 🔇 Sonnerie entrante ignorée (présentation=$presentation)',
        );
      }
    });

    // Le serveur a créé l'appel et le destinataire sonne : il nous annonce
    // l'identifiant sous lequel il en parlera désormais.
    //
    // C'est le seul moment où l'appelant peut l'apprendre avant le décrochage,
    // et donc la seule façon pour lui de reconnaître un refus reçu pendant la
    // sonnerie. Jusqu'ici, `_currentCallId` restait l'horodatage de
    // `_ensureCallId()` : le refus du correspondant était jeté, le ringback
    // continuait, et le filet des 45 secondes concluait « pas de réponse ».
    //
    // CallKit n'est pas suivi : son entrée reste ouverte sous l'identifiant
    // fabriqué, conservé dans `_callKitCallId`.
    _apiClient.onSocketEvent(SocketEvents.callRinging, (data) async {
      final serverCallId = (data is Map ? data['callId'] : null)?.toString();
      if (_status != CallStatus.outgoing && _status != CallStatus.connecting) {
        debugPrint('[CallService] 🛡 call_ringing ignoré: status=$_status');
        return;
      }
      if (!shouldAdoptServerCallId(
        serverCallId: serverCallId,
        currentCallId: _currentCallId,
      )) {
        return;
      }
      debugPrint(
        '[CallService] 📞 call_ringing → callId serveur adopté: '
        '$_currentCallId → $serverCallId (CallKit reste sur $_callKitCallId)',
      );
      _adoptServerCallId(serverCallId);
      // Un état terminal a pu être écrit sous cet identifiant pendant qu'on
      // l'ignorait — un refus très rapide, ou l'isolate FCM d'un push arrivé
      // avant nous. On ne le découvrait jamais : le registre était interrogé
      // sur une clé que personne n'écrivait.
      if (await EndedCallRegistry.isEnded(serverCallId!)) {
        debugPrint('[CallService] 🛡 call_ringing: $serverCallId déjà terminal → fin');
        await notifyCallEndedFromExternal(callId: serverCallId);
        return;
      }
      if (!kIsWeb) {
        unawaited(persistOutgoingSnapshot(
          phase: 'connecting',
          serverCallId: serverCallId,
        ));
      }
    });

    // Appel accepté par l'autre
    _apiClient.onSocketEvent(SocketEvents.callAnswered, (data) async {
      debugPrint('[CallService] 📞 call_answered reçu: $data');

      if (_status != CallStatus.connecting) {
        debugPrint('[CallService] ** call_answered ignoré : statut=$_status');
        return;
      }

      // 🛑 Arrêter le ringback dès que le destinataire décroche
      _cancelOutgoingTimeout();
      await _ringtone.stop();

      if (data is! Map || data['answer'] == null) {
        debugPrint('[CallService] ** Données call_answered invalides');
        return;
      }

      try {
        final answer = data['answer'] as Map;
        await _webrtc.handleAnswer(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        debugPrint('[CallService] !! Answer acceptée → CONNECTED');
        // Le destinataire vient d'acquérir un appareil actif : ses candidats
        // à lui vont passer, mais les nôtres, émis pendant qu'il sonnait,
        // n'avaient nulle part où aller. On les rejoue.
        _replayOutgoingIce();
        _status = CallStatus.connected;
        _startDurationTimer();
        _startSpeakingDetection(groupMode: false);
        final serverCallId = data['callId']?.toString();
        // Adopter l'identifiant du serveur. Côté appelant, `_currentCallId`
        // n'était qu'un horodatage fabriqué pour ouvrir la session CallKit :
        // aucune des treize affectations ne le remplaçait au décrochage. Toutes
        // les comparaisons `callId == _currentCallId` étaient donc fausses de ce
        // côté, et `EndedCallRegistry` écrivait une clé que personne ne
        // relisait — la protection anti-appel-fantôme entre isolates ne
        // protégeait que l'appelé. CallKit, lui, garde `_callKitCallId`.
        if (shouldAdoptServerCallId(
          serverCallId: serverCallId,
          currentCallId: _currentCallId,
        )) {
          debugPrint(
            '[CallService] callId serveur adopté: $_currentCallId → $serverCallId '
            '(CallKit reste sur $_callKitCallId)',
          );
          _adoptServerCallId(serverCallId);
        }
        unawaited(persistOutgoingSnapshot(
          phase: 'connected',
          serverCallId: serverCallId,
        ));
        // UI « En cours » tout de suite ; CallKit setConnected en arrière-plan.
        notify();
        if (!kIsWeb) {
          await _markCallSessionConnected();
        }
      } catch (e) {
        debugPrint('[CallService] ** Erreur handleAnswer: $e — teardown + notif du pair');
        // L'appel a été décroché mais la négociation locale échoue : on termine
        // proprement ET on prévient le pair (end_call), au lieu de juste repasser
        // idle — ce qui laissait fuiter CallSessionGuard / WebRTC / CallKit.
        await endCall();
      }
    });

    // Appel rejeté par le destinataire
    _apiClient.onSocketEvent(SocketEvents.callRejected, (data) async {
      final callId = (data is Map ? data['callId'] : null)?.toString();
      debugPrint('[CallService] 📞 Appel rejeté callId=$callId status=$_status');
      // Même garde que call_busy / call_no_answer juste en dessous. Sans elle,
      // un refus tardif — celui d'une invitation en conférence que la couche
      // native poste en refus 1-à-1, par exemple — raccrochait l'appel en cours.
      if (!acceptsOutgoingTerminalEvent(
        callStatusName: _status.name,
        eventCallId: callId,
        currentCallId: _currentCallId,
        currentCallIdIsLocal: !_serverCallIdKnown,
      )) {
        debugPrint('[CallService] 🛡 call_rejected ignoré: status=$_status callId=$callId');
        return;
      }
      _markTerminalCallId(callId ?? _currentCallId);
      await _terminateCall();
    });

    // Appel terminé par l'autre côté, ou stop multi-device (answered/rejected elsewhere).
    _apiClient.onSocketEvent(SocketEvents.callEnded, (data) async {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      // Adressé à un invité, il vise son invitation — l'identifiant que son
      // CallKit connaît —, pas la session.
      final callId = endedCallId(map);
      final reason = map['reason']?.toString();
      final claimedElsewhere = reason == 'answered_elsewhere' ||
          reason == 'rejected_elsewhere' ||
          map['claimedByAnotherDevice'] == true ||
          map['claimedByAnotherDevice']?.toString() == 'true';

      debugPrint(
        '[CallService] 📞 call_ended callId=$callId reason=$reason '
        'claimedElsewhere=$claimedElsewhere status=$_status',
      );

      // Déjà en média actif sur CE device : ignorer (ne doit normalement pas
      // arriver — serveur exclut le gagnant — mais filet anti-course).
      if (claimedElsewhere &&
          (_status == CallStatus.connected ||
              _status == CallStatus.connecting ||
              _status == CallStatus.joining) &&
          (callId == null ||
              callId.isEmpty ||
              callId == _currentCallId ||
              callId == _confSessionId ||
              callId == _groupRoomId)) {
        debugPrint('[CallService] 🛡 call_ended elsewhere ignoré (média local actif)');
        return;
      }

      _markTerminalCallId(callId ?? _currentCallId);

      if (claimedElsewhere) {
        // Stop local uniquement : pas de reject_call.
        await _callKit.endAll(callId: callId ?? _currentCallId);
        if (_status == CallStatus.incoming ||
            _status == CallStatus.idle ||
            _status == CallStatus.joining) {
          await _terminateCall();
        } else if (callId != null &&
            callId.isNotEmpty &&
            callId != _currentCallId &&
            callId != _confSessionId) {
          // Autre callId : juste CallKit déjà coupé.
          return;
        } else {
          await _terminateCall();
        }
        return;
      }

      // La branche `claimedElsewhere` ci-dessus compare le callId ; celle-ci ne
      // le faisait pas. Le serveur émet `call_ended` depuis treize endroits —
      // fin, refus, grâce de déconnexion, resume_ack_timeout, transfert — et un
      // événement en retard raccrochait l'appel suivant.
      // Second terme : appel sortant dont le serveur n'a pas encore annoncé
      // l'identifiant. `endsCurrentCall` ne compare alors qu'un horodatage
      // fabriqué, et son refus laissait la sonnerie de retour tourner.
      if (!endsCurrentCall(
            eventCallId: callId,
            currentCallId: _currentCallId,
            confSessionId: _confSessionId,
            groupRoomId: _groupRoomId,
          ) &&
          !acceptsOutgoingTerminalEvent(
            callStatusName: _status.name,
            eventCallId: callId,
            currentCallId: _currentCallId,
            currentCallIdIsLocal: !_serverCallIdKnown,
          )) {
        debugPrint(
          '[CallService] 🛡 call_ended ignoré (autre appel) callId=$callId '
          'courant=$_currentCallId',
        );
        return;
      }

      // Pendant une conf à 3+ encore peuplée, un call_ended parasite ne doit
      // pas raccrocher les restants. Dès qu'il ne reste qu'un pair (retour à
      // deux), call_ended = l'autre a raccroché → on coupe l'appel.
      final meshPeerCount = _groupPeerConnections.length;
      if (_confSessionId != null && meshPeerCount >= 2) {
        debugPrint(
          '[CallService] 🛡 call_ended ignoré (conf encore à $meshPeerCount '
          'pairs session=$_confSessionId)',
        );
        return;
      }

      await _terminateCall(force: true);
    });

    _apiClient.onSocketEvent(SocketEvents.callError, (data) async {
      final code = (data is Map ? data['code'] : null)?.toString();
      final callId = (data is Map ? data['callId'] : null)?.toString();
      debugPrint('[CallService] call_error code=$code callId=$callId');
      // Le serveur ne connaît plus cet appel : notre réponse est arrivée après
      // sa fin. Ce code était ignoré, et l'accusé de réception du serveur dit
      // « ok » même dans ce cas : le décrochage se croyait abouti et affichait
      // un appel en cours avec personne en face.
      if (code == 'CALL_NOT_RINGING') {
        if (_status == CallStatus.connecting ||
            _status == CallStatus.incoming) {
          debugPrint(
            '[CallService] ** call_error CALL_NOT_RINGING → abandon du décrochage',
          );
          _markTerminalCallId(callId ?? _currentCallId);
          await _terminateCall();
        }
        return;
      }
      if (code == 'CALL_ANSWERED_ELSEWHERE' ||
          code == 'CALL_ALREADY_JOINED_ON_OTHER_DEVICE') {
        _markTerminalCallId(callId ?? _currentCallId);
        await _callKit.endAll(callId: callId ?? _currentCallId);
        if (_status == CallStatus.incoming || _status == CallStatus.joining) {
          await _terminateCall();
        }
        return;
      }
      // Le serveur refuse de lancer un appel de groupe : essai fini, aucun
      // abonnement (le droit en cache disait oui — un code a pu expirer).
      if (code == 'SUBSCRIPTION_REQUIRED') {
        if (_status == CallStatus.outgoing) {
          _cancelOutgoingTimeout();
          await _terminateCall();
        }
        EntitlementService.maybeInstance?.reportOutgoingBlocked();
        return;
      }
      if (code == 'DEVICE_ID_REQUIRED' || code == 'CALL_ID_UNAVAILABLE') {
        if (!acceptsOutgoingTerminalEvent(
          callStatusName: _status.name,
          eventCallId: callId,
          currentCallId: _currentCallId,
          currentCallIdIsLocal: !_serverCallIdKnown,
        )) {
          debugPrint('[CallService] 🛡 call_error $code ignoré: status=$_status');
          return;
        }
        _showTransientMessage(
          LocaleController.instance.l10n.callFailed,
        );
        await _terminateCall();
      }
    });

    // Appel échoué (destinataire hors-ligne, données invalides, appel bloqué…)
    _apiClient.onSocketEvent(SocketEvents.callFailed, (data) async {
      final reason = (data is Map ? data['reason'] : null)?.toString();
      final code = (data is Map ? data['code'] : null)?.toString();
      final failedCallId = (data is Map ? data['callId'] : null)?.toString();
      debugPrint(
        '[CallService] Appel échoué: reason=$reason code=$code '
        'callId=$failedCallId status=$_status',
      );
      // Ce handler ne lisait pas le callId du payload et marquait
      // `_currentCallId` comme terminal : il agissait par construction sur
      // l'appel en cours au moment de la livraison, quel que soit l'appel
      // auquel l'échec se rapportait.
      if (!acceptsOutgoingTerminalEvent(
        callStatusName: _status.name,
        eventCallId: failedCallId,
        currentCallId: _currentCallId,
        currentCallIdIsLocal: !_serverCallIdKnown,
      )) {
        debugPrint('[CallService] 🛡 call_failed ignoré: status=$_status callId=$failedCallId');
        return;
      }
      _cancelOutgoingTimeout();
      _markTerminalCallId(failedCallId ?? _currentCallId);
      await _terminateCall();
      // Refus d'abonnement : le panneau parle, pas un texte du serveur affiché
      // tel quel dans une barre d'état.
      if (code == 'SUBSCRIPTION_REQUIRED') {
        EntitlementService.maybeInstance?.reportOutgoingBlocked();
        return;
      }
      if (code == 'CALL_BLOCKED') {
        _showTransientMessage(LocaleController.instance.l10n.callImpossible);
      } else if (code == 'CALLER_BUSY') {
        _showTransientMessage(LocaleController.instance.l10n.aCallIsAlreadyInProgress);
      } else if (reason != null && reason.isNotEmpty) {
        _showTransientMessage(reason);
      } else {
        _showTransientMessage(LocaleController.instance.l10n.callFailed);
      }
    });

    // Correspondant occupé (déjà en sonnerie ou en communication côté serveur).
    // ≠ « Un appel est déjà en cours » (état local de l'appelant) : ici c'est le
    // destinataire distant qui est occupé.
    _apiClient.onSocketEvent(SocketEvents.callBusy, (data) async {
      debugPrint('[CallService] 📵 call_busy reçu: $data');
      if (_status != CallStatus.outgoing && _status != CallStatus.connecting) {
        debugPrint('[CallService] 🛡 call_busy ignoré: status=$_status');
        return;
      }
      _cancelOutgoingTimeout();
      _markTerminalCallId(_currentCallId);
      await _terminateCall();
      _showTransientMessage(LocaleController.instance.l10n.theOtherPartyIsBusy);
    });

    // Le répondeur du correspondant est actif : le serveur n'a RIEN armé — pas
    // de `ringing`, pas d'`incoming_call`, pas de push. Rien n'a sonné chez
    // lui, et rien ne sonnera. On démonte le sortant et on propose de laisser
    // un message.
    //
    // L'ordre des six étapes ci-dessous n'est pas négociable :
    //
    //  1. la garde, avant tout — `acceptsOutgoingTerminalEvent` accepte
    //     justement parce qu'aucun `call_ringing` n'a été émis et que
    //     `_currentCallId` est donc encore l'horodatage fabriqué localement.
    //     C'est le cas que son paramètre `currentCallIdIsLocal` couvre ;
    //  2. le filet local de 50 s doit être désarmé TOUT DE SUITE. Un message
    //     d'une minute le laisserait expirer par-dessus la feuille
    //     d'enregistrement et afficher « Pas de réponse » sur un appel qui
    //     n'attendait aucune réponse ;
    //  3. adopter l'identifiant serveur, seul moyen de rapprocher l'appel du
    //     `call_log_updated` qui arrive en même temps ;
    //  4. marquer les DEUX identités comme terminales. Celle de CallKit, que
    //     l'adoption vient de remplacer, resterait sinon orpheline dans le
    //     registre, et un `call_ended` tardif venu de l'isolate FCM tomberait
    //     sur une clé que personne n'a écrite ;
    //  5. `_terminateCall()` — et non `endCall()` : le serveur n'a ouvert
    //     aucun appel, un `end_call` y chercherait quelque chose qui n'existe
    //     pas. C'est lui qui coupe la sonnerie de retour, rend CallKit, ferme
    //     la connexion pair-à-pair et RELÂCHE LA SESSION AUDIO ;
    //  6. la feuille en dernier, pour la raison du point 5 : l'enregistreur
    //     démarré sur une session encore en catégorie `call` produit un
    //     fichier en bande téléphonique sur Android et rien sur iOS.
    _apiClient.onSocketEvent(SocketEvents.callVoicemail, (data) async {
      debugPrint('[CallService] 📼 call_voicemail reçu: $data');
      final map = data is Map ? data : const {};
      final serverCallId = map['callId']?.toString();

      if (!acceptsOutgoingTerminalEvent(
        callStatusName: _status.name,
        eventCallId: serverCallId,
        currentCallId: _currentCallId,
        currentCallIdIsLocal: !_serverCallIdKnown,
      )) {
        debugPrint('[CallService] 🛡 call_voicemail ignoré: status=$_status');
        return;
      }

      _cancelOutgoingTimeout();

      // Le téléchargement de l'annonce part MAINTENANT, sans être attendu.
      //
      // `_terminateCall()` ci-dessous prend plusieurs centaines de
      // millisecondes — rendre CallKit, fermer la connexion pair-à-pair,
      // relâcher la session audio. Le transfert s'y superpose au lieu de s'y
      // ajouter, et l'annonce est généralement prête quand la feuille s'ouvre.
      // Au deuxième appel vers la même personne, le cache répond sans réseau.
      VoicemailGreetingPlayer.instance.prefetch(map['greetingUrl']?.toString());

      final idCallKit = _callKitCallId;
      final idLocal = _currentCallId;
      if (serverCallId != null && serverCallId.isNotEmpty) {
        _adoptServerCallId(serverCallId);
        _markTerminalCallId(serverCallId);
      }
      _markTerminalCallId(idLocal);
      _markTerminalCallId(idCallKit);

      // Retenus avant `_terminateCall`, qui remet l'identité distante à zéro.
      final peerId = _remoteUserId;
      final peerName = _remoteUserName ?? '';
      final conversationID = map['conversationID'] is int
          ? map['conversationID'] as int
          : int.tryParse(map['conversationID']?.toString() ?? '');
      // Le téléphone d'en face a-t-il sonné ? Ce n'est pas la même situation :
      // « n'a pas répondu » quand le délai s'est écoulé ou que l'appel a été
      // refusé, « est indisponible » quand un créneau de silence ou une ligne
      // occupée l'a renvoyé sans le faire sonner.
      final didRing = map['didRing'] == true;

      await _terminateCall();

      if (peerId == null) return;
      unawaited(showVoicemailSheet(
        peerUserId: peerId,
        peerName: peerName,
        conversationID: conversationID,
        didRing: didRing,
      ));
    });

    // Pas de réponse (timeout serveur sur un appel resté en sonnerie).
    _apiClient.onSocketEvent(SocketEvents.callNoAnswer, (data) async {
      debugPrint('[CallService] 📴 call_no_answer reçu: $data');
      if (_status != CallStatus.outgoing && _status != CallStatus.connecting) {
        debugPrint('[CallService] 🛡 call_no_answer ignoré: status=$_status');
        return;
      }
      _cancelOutgoingTimeout();
      final callId = (data is Map ? data['callId'] : null)?.toString();
      _markTerminalCallId(callId ?? _currentCallId);
      await _terminateCall();
      _showTransientMessage(LocaleController.instance.l10n.noAnswer);
    });

    // Socket (ré)authentifié : rejoue les fins d'appel et refus mis en file.
    _apiClient.onSocketEvent(SocketEvents.authVerified, (_) {
      _flushPendingEndCalls();
      _flushPendingRejects();
      _flushPendingConfJoin();
      _flushPendingConfReady();
      _rejoinGroupRoomIfNeeded();
      // Le socket est revenu : ce que le rejeu du décrochage n'avait pas pu
      // émettre peut enfin partir.
      _replayOutgoingIce();
    });

    _apiClient.onSocketEvent(SocketEvents.callResume, (data) async {
      if (data is Map) await _handleCallResume(Map<String, dynamic>.from(data));
    });

    _apiClient.onSocketEvent(SocketEvents.callRejoinOffer, (data) async {
      if (data is Map) await _handleCallRejoinOffer(Map<String, dynamic>.from(data));
    });

    _apiClient.onSocketEvent(SocketEvents.callRejoinAnswer, (data) async {
      if (data is Map) await _handleCallRejoinAnswer(Map<String, dynamic>.from(data));
    });

    // ICE candidate 1-à-1
    _apiClient.onSocketEvent(SocketEvents.iceCandidate, (data) {
      if (data is! Map || data['candidate'] == null) return;
      // Pas de session locale : ignorer les ICE d'un appel fantôme / terminé.
      if (_status == CallStatus.idle ||
          _status == CallStatus.ended ||
          (!_isRestoringOutgoing &&
              _status != CallStatus.reconnecting &&
              _webrtc.peerConnection == null)) {
        debugPrint(
          '[CallService] 🛡 ice_candidate ignoré (status=$_status pc=${_webrtc.peerConnection != null})',
        );
        return;
      }
      final gen = data['generation'] is int
          ? data['generation'] as int
          : int.tryParse(data['generation']?.toString() ?? '');
      if (!_webrtc.acceptsIceGeneration(gen)) {
        debugPrint('[CallService] 🛡 ice_candidate génération périmée gen=$gen');
        return;
      }
      // `as String` non nullable levait ici sur un candidat sans chaîne — or
      // l'émetteur relaie le champ brut, et `webrtc_service` le traite lui-même
      // comme nullable. L'exception remontait dans un écouteur socket, où
      // personne ne l'attrape : le candidat était perdu sans un mot, sur le
      // chemin le plus tendu de l'établissement de l'appel. Un candidat vide se
      // jette explicitement — c'est la marque de fin de collecte.
      final c = data['candidate'];
      if (c is! Map) {
        debugPrint('[CallService] 🧊 ice_candidate sans candidat exploitable');
        return;
      }
      final ligne = c['candidate']?.toString();
      if (ligne == null || ligne.isEmpty) {
        debugPrint('[CallService] 🧊 ice_candidate vide (fin de collecte)');
        return;
      }
      final index = c['sdpMLineIndex'];
      _webrtc.addIceCandidate(
        RTCIceCandidate(
          ligne,
          c['sdpMid']?.toString(),
          index is int ? index : int.tryParse(index?.toString() ?? ''),
        ),
        generation: gen,
      );
    });

    // Appels de groupe
    // Invitation à un appel de groupe
    _apiClient.onSocketEvent(SocketEvents.groupCallInvite, (data) {
      if (data is! Map) return;
      if (_status != CallStatus.idle) {
        debugPrint('[CallService] 🛡 group_call_invite ignoré: status=$_status');
        return;
      }
      if (_isMeetingActive()) {
        debugPrint('[CallService] 🛡 group_call_invite ignoré: réunion active');
        return;
      }
      // Sans identifiant de salon, il n'y a rien à présenter et rien à
      // rejoindre — mais poser le statut « entrant » suffisait à rendre
      // l'appareil sourd : la revendication était refusée (identifiant vide),
      // aucune interface ne s'ouvrait, aucun filet n'était armé, et tous les
      // points d'entrée refusent un entrant tant que `_status != idle`. Plus
      // aucun appel ne pouvait arriver, sauf un `call_ended` de forme 1-à-1
      // venu du serveur. On refuse d'entrer dans cet état.
      final roomId = (data['roomId'] as String?)?.trim() ?? '';
      if (!groupInviteIsPresentable(roomId)) {
        debugPrint(
          '[CallService] 🛡 group_call_invite sans roomId → ignoré '
          '(ne pas bloquer l\'appareil)',
        );
        return;
      }

      _remoteUserId = int.tryParse(data['callerId'].toString());
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = normalizeBackendUrl(data['callerPhoto']?.toString());
      _isVideo = data['isVideo'] == true;
      _groupRoomId = roomId;
      // Le caller est notre seule info connue à l'instant T → on le pose dans le roster
      final callerId = data['callerId']?.toString();
      if (callerId != null && callerId.isNotEmpty) {
        _groupRoster[callerId] = GroupParticipantInfo(
          id: callerId,
          name: (_remoteUserName?.isNotEmpty == true)
              ? _remoteUserName!
              : resolveL10n().participantFallback,
          photo: _remoteUserPhoto,
        );
      }
      _status = CallStatus.incoming;
      final presentation = _resolveIncomingPresentation(
        callId: roomId,
        intent: IncomingPresentationIntent.signal,
      );
      _armIncomingRingSafety();
      notify();

      if (presentation == IncomingPresentationAction.showNativeCallKit) {
        if (_nativeAndroidHandlesIncomingCallUi) {
          debugPrint(
            '[CallService] 📲 CallKit natif Android groupe (socket ignoré pour UI)',
          );
        } else {
          debugPrint('[CallService] 📲 CallKit groupe depuis socket (app en arrière-plan)');
          unawaited(
            _callKit
                .showIncoming(
                  callId: _groupRoomId ?? '',
                  callerId: callerId ?? '',
                  callerName: _remoteUserName ?? resolveL10n().groupCall,
                  callerPhoto: _remoteUserPhoto,
                  isVideo: _isVideo,
                  roomId: _groupRoomId,
                  silent: false,
                )
                .catchError((e) {
              debugPrint('[CallService] ** CallKit group showIncoming error: $e');
            }),
          );
        }
      } else if (presentation ==
          IncomingPresentationAction.showFlutterIncoming) {
        // Manquait entièrement : l'écran s'ouvrait en silence.
        _startFlutterIncomingRinging(roomId);
      }
    });

    // Nouveau participant dans le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      final userName = (data['userName'] as String?) ?? '';
      final userPhoto = data['userPhoto'] as String?;
      final known = _groupRoster[userId];
      _groupRoster[userId] = GroupParticipantInfo(
        id: userId,
        name: userName.isNotEmpty
            ? userName
            : LocaleController.instance.l10n.participantFallback,
        photo: userPhoto,
        isMuted: known?.isMuted ?? false,
        isVideoOn: known?.isVideoOn ?? true,
      );
      _applyPendingGroupStates(userId);
      // Même trou que côté conférence : l'arrivant ignore mes états média.
      _broadcastMyMediaState();
      notify();
      if (_groupPeerConnections.containsKey(userId)) return;
      await _createGroupPeerAndOffer(userId);
    });

    // Liste des participants existants
    _apiClient.onSocketEvent(SocketEvents.groupParticipants, (data) {
      if (data is! Map) return;
      final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _groupParticipants = participants;
      // Le serveur fait foi : qui n'y figure plus est parti pendant mon absence,
      // et son `group_user_left` s'est perdu avec ma socket.
      for (final id in rosterEntriesToDrop(
        serverIds: participants,
        localIds: _groupRoster.keys.toList(),
        myId: _myRosterId,
      )) {
        debugPrint('[CallService] roster purgé de $id (absent de group_participants)');
        _groupRoster.remove(id);
        _pendingGroupMedia.forget(id);
        _removeGroupPeer(id);
      }
      // Je viens d'entrer : les autres ne savent pas si mon micro est coupé.
      //
      // La branche conférence fait ce geste depuis toujours, dans le handler
      // jumeau `call_conf_peers` ; celle du groupe ne l'a jamais fait. Les
      // autres me plaçaient donc à leur roster avec les valeurs par défaut de
      // `group_user_joined` — micro ouvert, caméra allumée — quel que soit mon
      // état réel. Et l'oubli était invisible, puisque `group_participants` ne
      // sortait jamais du serveur.
      //
      // C'est aussi ce qui rend la reprise après coupure honnête : au rejoin,
      // les autres reconstruisent ma carte à partir de `group_user_joined`, et
      // sans cette réaffirmation je leur apparaîtrais micro ouvert alors que je
      // l'ai coupé pendant l'appel.
      _broadcastMyMediaState();
      notify();
      // Pour les IDs sans entrée roster, on résout le nom/photo via l'API.
      for (final id in participants) {
        if (_groupRoster.containsKey(id)) continue;
        final intId = int.tryParse(id);
        if (intId == null) continue;
        _apiClient.getUserById(intId).then((u) {
          final nom = (u['nom'] as String?) ?? '';
          final pseudo = (u['pseudo'] as String?) ?? '';
          _groupRoster[id] = GroupParticipantInfo(
            id: id,
            name: nom.isNotEmpty
                ? nom
                : (pseudo.isNotEmpty
                    ? pseudo
                    : LocaleController.instance.l10n.participantFallback),
            photo: u['avatar_url'] as String?,
          );
          _applyPendingGroupStates(id);
          notify();
        }).catchError((e) {
          debugPrint('[CallService] roster getUserById($id) failed: $e');
        });
      }
    });

    // Participant quitte le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserLeft, (data) {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      // Le roster doit être purgé ici, et seulement ici : c'est le serveur qui
      // dit qu'il est parti. `_removeGroupPeer` sert aussi quand le lien média
      // local lâche — le participant est alors toujours dans l'appel, et lui
      // retirer son entrée le ferait disparaître de la grille à tort.
      //
      // Depuis que la grille part du roster plutôt que des flux, l'oubli se
      // voyait dans l'autre sens : le partant gardait sa tuile et restait
      // compté jusqu'à la fin de l'appel.
      _groupRoster.remove(userId);
      _pendingGroupMedia.forget(userId);
      _removeGroupPeer(userId);
    });

    // Appel de groupe terminé
    // Le payload est vide côté serveur aujourd'hui, mais rien ne vérifiait la
    // salle ni le statut : un événement tardif de la salle précédente détruisait
    // le média de l'appel en cours.
    _apiClient.onSocketEvent(SocketEvents.groupCallEnded, (data) {
      final roomId = (data is Map ? data['roomId'] : null)?.toString();
      if (!endsGroupCall(
        groupRoomId: _groupRoomId,
        eventRoomId: roomId,
        callStatusName: _status.name,
      )) {
        debugPrint(
          '[CallService] 🛡 group_call_ended ignoré: salle=$roomId '
          'courante=$_groupRoomId status=$_status',
        );
        return;
      }
      _terminateGroupCall();
    });

    // « Ajouter à l'appel » — session à trois
    //
    // Le maillage média n'apparaît pas ici : les offres, réponses et candidats
    // passent par les mêmes relais group_* que les appels de groupe, déjà
    // écoutés plus bas.

    // Une invitation vient d'être lancée (reçu par les DEUX présents).
    _apiClient.onSocketEvent(SocketEvents.callAddPending, (data) {
      if (data is! Map) return;
      _onConfAddPending(data);
    });

    // Côté invité : on me propose de rejoindre un appel en cours.
    _apiClient.onSocketEvent(SocketEvents.callConfInvite, (data) {
      if (data is! Map) return;
      if (_isMeetingActive()) {
        debugPrint('[CallService] 🛡 call_conf_invite ignoré: réunion active');
        return;
      }

      final sessionId = data['sessionId']?.toString();
      if (sessionId == null) return;
      // Chaque invitation a son identifiant — le sessionId à la première,
      // `…_r<n>` ensuite. C'est lui que ce téléphone présente et marque
      // terminé : réinvité dans une session qu'il a déjà quittée, il ne doit
      // pas tomber sur la marque de son départ.
      final inviteId = conferenceInviteId(data) ?? sessionId;
      if (_isTerminalCallId(inviteId)) {
        debugPrint('[CallService] 🛡 call_conf_invite ignoré: invitation déjà soldée ($inviteId)');
        return;
      }

      // Fusion Push/Socket : même session déjà en incoming → compléter sans re-sonner.
      final sameSession = shouldMergeConfInvite(
        callStatusName: _status.name,
        confSessionId: _confSessionId,
        currentCallId: _currentCallId,
        incomingSessionId: sessionId,
      );
      if (_status != CallStatus.idle && !sameSession) {
        debugPrint('[CallService] 🛡 call_conf_invite ignoré: status=$_status');
        return;
      }

      _confSessionId = sessionId;
      _isVideo = data['isVideo'] == true;
      _adoptServerCallId(inviteId);
      final mode = data['mode']?.toString();
      if (mode == 'transfer' || mode == 'join') _confMode = mode!;

      final from = data['from'];
      if (from is Map) {
        _confInvitedBy = GroupParticipantInfo(
          id: from['id'].toString(),
          name: (from['name'] as String?)?.isNotEmpty == true
              ? from['name'] as String
              : resolveL10n().participantFallback,
          photo: normalizeBackendUrl(from['photo']?.toString()),
        );
        _remoteUserId = int.tryParse(from['id'].toString());
        _remoteUserName = _confInvitedBy!.name;
        _remoteUserPhoto = _confInvitedBy!.photo;
      }

      _onConfPeers(data);

      if (!sameSession) {
        _status = CallStatus.incoming;
        final presentation = _resolveIncomingPresentation(
          callId: inviteId,
          intent: IncomingPresentationIntent.signal,
        );
        _armIncomingRingSafety();
        notify();

        if (presentation == IncomingPresentationAction.showNativeCallKit) {
          if (_nativeAndroidHandlesIncomingCallUi) {
            debugPrint('[CallService] 📲 CallKit natif Android (session à trois)');
          } else {
            unawaited(
              _callKit
                  .showIncoming(
                    // L'invitation pour CallKit, la session dans roomId.
                    callId: inviteId,
                    callerId: _confInvitedBy?.id ?? '',
                    callerName: _confInvitedBy?.name ?? resolveL10n().groupCall,
                    callerPhoto: _confInvitedBy?.photo,
                    isVideo: _isVideo,
                    roomId: sessionId,
                    sessionKind: 'conference',
                    mode: _confMode,
                    silent: false,
                  )
                  .catchError((e) {
                debugPrint('[CallService] ** CallKit conf showIncoming error: $e');
              }),
            );
          }
        } else if (presentation ==
            IncomingPresentationAction.showFlutterIncoming) {
          // Manquait entièrement, comme côté groupe : l'invitation à une
          // session à trois s'affichait sans un son.
          _startFlutterIncomingRinging(inviteId);
        }
      } else {
        debugPrint('[CallService] 🔀 call_conf_invite fusionné session=$sessionId');
        notify();
      }
    });

    // L'invité est entré : chaque présent lui ouvre une connexion.
    _apiClient.onSocketEvent(SocketEvents.callConfJoined, (data) async {
      if (data is! Map) return;
      await _onConfJoined(data);
    });

    // Côté invité : qui va m'offrir. Rien à initier de mon côté.
    _apiClient.onSocketEvent(SocketEvents.callConfPeers, (data) {
      if (data is! Map) return;
      _onConfPeers(data);
      notify();
    });

    // Invitation soldée sans que l'invité entre : le droit d'ajout est rendu.
    _apiClient.onSocketEvent(SocketEvents.callConfFailed, (data) {
      if (data is! Map) return;
      _onConfFailed(data);
    });

    // Un participant s'est retiré : les autres continuent.
    _apiClient.onSocketEvent(SocketEvents.callConfLeft, (data) {
      if (data is! Map) return;
      _onConfLeft(data);
    });

    _apiClient.onSocketEvent(SocketEvents.callTransferArmed, (data) {
      if (data is! Map) return;
      _onTransferArmed(data);
    });

    _apiClient.onSocketEvent(SocketEvents.callTransferDone, (data) async {
      if (data is! Map) return;
      await _onTransferDone(data);
    });

    // Demande d'ajout refusée par le serveur.
    _apiClient.onSocketEvent(SocketEvents.callAddRejected, (data) {
      if (data is! Map) return;
      final code = data['code']?.toString() ?? 'INTERNAL';
      debugPrint('[CallService] ✖ ajout refusé: $code');
      if (code == 'SUBSCRIPTION_REQUIRED') {
        EntitlementService.maybeInstance?.reportOutgoingBlocked();
      }
      _lastConfFailure = _addRejectionReason(code);
      // Deux appuis simultanés : le perdant peut recevoir le call_add_pending
      // du gagnant avant son propre refus. Effacer le tour ici retirerait la
      // cible du transfert gagnant, et ce téléphone n'émettrait jamais le
      // call_conf_ready qui le déclenche.
      if (addRejectedResetsRound(hasPendingInvitee: _confPendingInvitee != null)) {
        _transferStatus = CallTransferStatus.cancelled;
        _isTransferInitiator = false;
        _transferTargetId = null;
        _transferLeaveInMs = null;
        _transferArmedAt = null;
        _confMode = 'join';
      }
      notify();
    });

    // WebRTC groupe : offer reçue
    _apiClient.onSocketEvent(SocketEvents.groupOffer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final offer = data['offer'] as Map?;
      if (offer == null) return;
      final gen = data['generation'] is int
          ? data['generation'] as int
          : int.tryParse(data['generation']?.toString() ?? '');
      await _handleGroupOffer(fromUserId, offer, generation: gen);
    });

    // WebRTC groupe : answer reçue
    _apiClient.onSocketEvent(SocketEvents.groupAnswer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final answer = data['answer'] as Map?;
      if (answer == null) return;
      final gen = data['generation'] is int
          ? data['generation'] as int
          : int.tryParse(data['generation']?.toString() ?? '');
      final localGen = _groupPeerIceGeneration[fromUserId] ?? 0;
      if (gen != null && gen < localGen) {
        debugPrint('[CallService] 🛡 group_answer gen périmée peer=$fromUserId');
        return;
      }
      final pc = _groupPeerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        _groupRemoteDescSet.add(fromUserId);
        _groupPeerIsRestarting[fromUserId] = false;
        await _flushGroupPendingIce(fromUserId);
      }
    });

    // WebRTC groupe : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.groupIceCandidate, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final c = data['candidate'] as Map?;
      if (c == null) return;
      final gen = data['generation'] is int
          ? data['generation'] as int
          : int.tryParse(data['generation']?.toString() ?? '');
      final localGen = _groupPeerIceGeneration[fromUserId] ?? 0;
      if (gen != null && gen < localGen) {
        debugPrint('[CallService] 🛡 group_ice gen périmée peer=$fromUserId');
        return;
      }
      final candidate = RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null || !_groupRemoteDescSet.contains(fromUserId)) {
        final buf = _groupPendingIce.putIfAbsent(fromUserId, () => []);
        if (buf.length < 64) buf.add(candidate);
        return;
      }
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[CallService] group addCandidate échoué $fromUserId: $e');
      }
    });
 
    // Mute state 1-à-1 : l'autre participant a coupé/activé son micro
    _apiClient.onSocketEvent(SocketEvents.callMuteState, (data) {
      if (data is! Map) return;
      _isRemoteMuted = data['isMuted'] == true;
      debugPrint('[CallService] 🎙 Remote mute state: $_isRemoteMuted');
      final remoteId = _remoteUserId?.toString();
      if (remoteId != null) {
        speakingDetector.setSpeakerMuted(remoteId, _isRemoteMuted);
      }
      notify();
    });

    // État caméra 1-à-1 : l'autre participant a coupé/activé sa caméra
    _apiClient.onSocketEvent(SocketEvents.callVideoState, (data) {
      if (data is! Map) return;
      _isRemoteVideoOn = data['isVideoOn'] != false;
      debugPrint('[CallService] 📹 Remote video state: $_isRemoteVideoOn');
      notify();
    });

    // Mute state groupe : un participant a coupé/activé son micro
    _apiClient.onSocketEvent(SocketEvents.groupMuteState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isMuted = data['isMuted'] == true;
      if (userId == null) return;
      debugPrint('[CallService] 🎙 Group mute state: userId=$userId isMuted=$isMuted');
      // Un état reçu avant l'entrée de roster était perdu sans retour : le
      // serveur ne le réémet pas, et l'émetteur n'a aucun moyen de savoir
      // qu'on l'a jeté. On le garde de côté jusqu'à ce que le roster arrive.
      _pendingGroupMedia.recordMuted(userId, isMuted);
      _applyPendingGroupStates(userId);
    });

    // État caméra groupe : un participant a coupé/activé sa caméra
    _apiClient.onSocketEvent(SocketEvents.groupVideoState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isVideoOn = data['isVideoOn'] != false;
      if (userId == null) return;
      debugPrint('[CallService] 📹 Group video state: userId=$userId isVideoOn=$isVideoOn');
      _pendingGroupMedia.recordVideoOn(userId, isVideoOn);
      _applyPendingGroupStates(userId);
    });
  }

  /// Applique à [userId] les états micro/caméra reçus, s'il est au roster.
  ///
  /// Appelé à la réception de l'état comme à la création de l'entrée : selon
  /// l'ordre d'arrivée, c'est l'un ou l'autre qui déclenche.
  void _applyPendingGroupStates(String userId) {
    final info = _groupRoster[userId];
    if (info == null) return;
    final etat = _pendingGroupMedia.take(userId);
    if (etat.isMuted != null) {
      info.isMuted = etat.isMuted!;
      speakingDetector.setSpeakerMuted(userId, etat.isMuted!);
    }
    if (etat.isVideoOn != null) info.isVideoOn = etat.isVideoOn!;
    if (etat.isMuted != null || etat.isVideoOn != null) notify();
  }
}