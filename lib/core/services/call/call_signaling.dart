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
      _currentCallId = incomingCallId;
      _status = CallStatus.incoming;
      debugPrint('[CallService] !!Statut changé à INCOMING. Caller: $_remoteUserName ($_remoteUserId), Vidéo: $_isVideo');

      _ensureRemoteIdentityResolved();

      // Owner UI avant notify : FG → Flutter, BG → CallKit (pas IncomingCallScreen).
      if (_isAutoAnsweringFromPush) {
        _clearIncomingPresentation(callId: incomingCallId);
      } else if (_isAppForeground) {
        _claimIncomingPresentation(
          incomingCallId,
          IncomingPresentationOwner.flutterScreen,
        );
      } else {
        _claimIncomingPresentation(
          incomingCallId,
          IncomingPresentationOwner.nativeCallKit,
        );
      }
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

      // Politique sonnerie / UI hors app :
      //  - auto-réponse depuis push → pas de sonnerie.
      //  - app en arrière-plan → CallKit (UI système + sonnerie), même si FCM
      //    n'est pas encore arrivé / a échoué.
      //  - app au premier plan → RingtoneService (IncomingCallScreen).
      if (_isAutoAnsweringFromPush) {
        debugPrint('[CallService] 🔇 Sonnerie entrante ignorée: auto-réponse en cours');
      } else if (!_isAppForeground) {
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
      } else {
        unawaited(_dismissStrayIncomingCallKit(incomingCallId));
        _ringtone
            .startIncomingRingtone(
              override: ListRingtonePreferences.resolveCall(_remoteUserId!),
            )
            .catchError((e) {
          debugPrint('[CallService] ** Erreur sonnerie (non-bloquante): $e');
        });
        _armIncomingRingSafety();
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
        _status = CallStatus.connected;
        _startDurationTimer();
        _startSpeakingDetection(groupMode: false);
        final serverCallId = data['callId']?.toString();
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
      debugPrint('[CallService] 📞 Appel rejeté');
      final callId = (data is Map ? data['callId'] : null)?.toString();
      _markTerminalCallId(callId ?? _currentCallId);
      await _terminateCall();
    });

    // Appel terminé par l'autre côté, ou stop multi-device (answered/rejected elsewhere).
    _apiClient.onSocketEvent(SocketEvents.callEnded, (data) async {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final callId = map['callId']?.toString();
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
      if (code == 'CALL_ANSWERED_ELSEWHERE' ||
          code == 'CALL_ALREADY_JOINED_ON_OTHER_DEVICE') {
        _markTerminalCallId(callId ?? _currentCallId);
        await _callKit.endAll(callId: callId ?? _currentCallId);
        if (_status == CallStatus.incoming || _status == CallStatus.joining) {
          await _terminateCall();
        }
        return;
      }
      if (code == 'DEVICE_ID_REQUIRED' || code == 'CALL_ID_UNAVAILABLE') {
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
      debugPrint('[CallService] Appel échoué: reason=$reason code=$code');
      _cancelOutgoingTimeout();
      _markTerminalCallId(_currentCallId);
      await _terminateCall();
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
      final c = data['candidate'] as Map;
      _webrtc.addIceCandidate(
        RTCIceCandidate(
          c['candidate'] as String,
          c['sdpMid'] as String?,
          c['sdpMLineIndex'] as int?,
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
      _remoteUserId = int.tryParse(data['callerId'].toString());
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = normalizeBackendUrl(data['callerPhoto']?.toString());
      _isVideo = data['isVideo'] == true;
      _groupRoomId = data['roomId'] as String?;
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
      if (_isAppForeground) {
        _claimIncomingPresentation(
          _groupRoomId,
          IncomingPresentationOwner.flutterScreen,
        );
      } else {
        _claimIncomingPresentation(
          _groupRoomId,
          IncomingPresentationOwner.nativeCallKit,
        );
      }
      notify();

      if (!_isAppForeground) {
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
      }
    });

    // Nouveau participant dans le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      final userName = (data['userName'] as String?) ?? '';
      final userPhoto = data['userPhoto'] as String?;
      _groupRoster[userId] = GroupParticipantInfo(
        id: userId,
        name: userName.isNotEmpty
            ? userName
            : LocaleController.instance.l10n.participantFallback,
        photo: userPhoto,
      );
      notify();
      if (_groupPeerConnections.containsKey(userId)) return;
      await _createGroupPeerAndOffer(userId);
    });

    // Liste des participants existants
    _apiClient.onSocketEvent(SocketEvents.groupParticipants, (data) {
      if (data is! Map) return;
      final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _groupParticipants = participants;
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
      _removeGroupPeer(userId);
    });

    // Appel de groupe terminé
    _apiClient.onSocketEvent(SocketEvents.groupCallEnded, (_) {
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
      if (_isTerminalCallId(sessionId)) {
        debugPrint('[CallService] 🛡 call_conf_invite ignoré: session déjà soldée');
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
      _currentCallId = sessionId;
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
        if (_isAppForeground) {
          _claimIncomingPresentation(
            sessionId,
            IncomingPresentationOwner.flutterScreen,
          );
        } else {
          _claimIncomingPresentation(
            sessionId,
            IncomingPresentationOwner.nativeCallKit,
          );
        }
        notify();

        if (!_isAppForeground) {
          if (_nativeAndroidHandlesIncomingCallUi) {
            debugPrint('[CallService] 📲 CallKit natif Android (session à trois)');
          } else {
            unawaited(
              _callKit
                  .showIncoming(
                    callId: sessionId,
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
      _lastConfFailure = _addRejectionReason(code);
      _transferStatus = CallTransferStatus.cancelled;
      _isTransferInitiator = false;
      _transferTargetId = null;
      _transferLeaveInMs = null;
      _transferArmedAt = null;
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
      if (_groupRoster.containsKey(userId)) {
        _groupRoster[userId]!.isMuted = isMuted;
        speakingDetector.setSpeakerMuted(userId, isMuted);
        notify();
      }
    });

    // État caméra groupe : un participant a coupé/activé sa caméra
    _apiClient.onSocketEvent(SocketEvents.groupVideoState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isVideoOn = data['isVideoOn'] != false;
      if (userId == null) return;
      debugPrint('[CallService] 📹 Group video state: userId=$userId isVideoOn=$isVideoOn');
      if (_groupRoster.containsKey(userId)) {
        _groupRoster[userId]!.isVideoOn = isVideoOn;
        notify();
      }
    });
  }
}