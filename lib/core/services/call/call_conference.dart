// « Ajouter à l'appel » / transfert : escalade d'un appel 1-à-1 vers une session
// à trois, puis retrait éventuel de l'initiateur (part of call_service.dart).
//
// Le maillage média est celui des appels de groupe — group_offer /
// group_answer / group_ice_candidate. La connexion 1-à-1 n'est ni fermée ni
// renégociée : elle devient le premier lien du maillage.
part of '../call_service.dart';

extension CallConference on CallService {
  /// Invite [inviteeId] à rejoindre (join) ou recevoir le transfert (transfer).
  void addParticipant(
    int inviteeId, {
    String? myName,
    String? myPhoto,
    bool transfer = false,
  }) {
    if (!canAddParticipant) return;
    // Inviter quelqu'un est émettre : refusé sans abonnement, même au milieu d'un
    // appel que le compte a reçu.
    if (!EntitlementService.allowsOutgoing) {
      EntitlementService.maybeInstance?.reportOutgoingBlocked();
      return;
    }
    final mode = transfer ? 'transfer' : 'join';
    debugPrint('[CallService] ➕ demande d\'ajout de $inviteeId mode=$mode');
    _confMode = mode;
    _isTransferInitiator = transfer;
    _transferTargetId = transfer ? inviteeId.toString() : null;
    _transferStatus =
        transfer ? CallTransferStatus.inviting : CallTransferStatus.inviting;
    _apiClient.sendSocketEvent(SocketEvents.callAddParticipant, {
      'targetUserId': inviteeId.toString(),
      'mode': mode,
      if (myName != null) 'callerName': myName,
      if (myPhoto != null) 'callerPhoto': myPhoto,
    });
    notify();
  }

  /// Annule l'invitation en cours. Réservé à celui qui l'a lancée.
  void cancelAddParticipant() {
    if (_confSessionId == null || !_confInviteIsMine) return;
    debugPrint('[CallService] ✖ annulation de l\'invitation');
    _apiClient.sendSocketEvent(SocketEvents.callAddCancel, {});
    _transferStatus = CallTransferStatus.cancelled;
    _clearTransferCountdown();
    notify();
  }

  /// Côté invité : accepte de rejoindre l'appel à trois.
  Future<void> acceptConferenceInvite() async {
    final sessionId = _confSessionId;
    final myId = _localUserId;
    if (sessionId == null || myId == null) return;
    if (_status != CallStatus.incoming && _status != CallStatus.joining) {
      // Cold-start peut déjà être en joining.
      if (_status != CallStatus.connected) return;
    }
    final myName = _localUserName;
    final myPhoto = _localUserPhoto;

    _status = CallStatus.joining;
    notify();

    try {
      await _ringtone.stop();
      await _initLocalStream(_isVideo);

      _groupRoomId = sessionId;
      _myRosterId = myId.toString();
      _groupRoster[myId.toString()] = GroupParticipantInfo(
        id: myId.toString(),
        name: myName,
        photo: myPhoto,
      );

      // Invitation de second tour : ce téléphone a pu quitter cette session
      // plus tôt et l'avoir marquée terminée. Il la rejoint : la marque
      // tomberait sinon sur la file du join et sur la reprise d'appel.
      if (_currentCallId != null && _currentCallId != sessionId) {
        _forgetTerminalCallId(sessionId);
      }
      _emitOrQueueConfJoin(sessionId);

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: true);
      if (!kIsWeb) {
        // L'identifiant de l'invitation, sous lequel CallKit la présente déjà ;
        // à défaut, celui de la session.
        _adoptServerCallId(_currentCallId ?? sessionId);
        await _acquireCallSession(
          isVideo: _isVideo,
          displayName: LocaleController.instance.l10n.groupCall,
          handle: sessionId,
        );
        await _markCallSessionConnected();
      }
      notify();
    } catch (e) {
      debugPrint('[CallService] ** acceptConferenceInvite: $e');
      await _releaseCallSession();
      await _terminateConference();
    }
  }

  void _emitOrQueueConfJoin(String sessionId) {
    if (_apiClient.isSocketReady) {
      _apiClient.sendSocketEvent(SocketEvents.callConfJoin, {});
      _pendingConfJoinSessionId = null;
      return;
    }
    debugPrint('[CallService] ⏳ call_conf_join en file (socket pas prêt)');
    _pendingConfJoinSessionId = sessionId;
    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }
  }

  /// Flush de la file call_conf_join avec gardes anti-session périmée.
  void _flushPendingConfJoin() {
    final sessionId = _pendingConfJoinSessionId;
    if (sessionId == null) return;

    final decision = confJoinFlushDecision(
      pendingSessionId: sessionId,
      confSessionId: _confSessionId,
      isTerminal: _isTerminalCallId(sessionId),
      callStatusName: _status.name,
      socketReady: _apiClient.isSocketReady,
    );
    switch (decision) {
      case ConfQueueFlushResult.drop:
        debugPrint('[CallService] 🛡 conf join flush drop session=$sessionId');
        _pendingConfJoinSessionId = null;
        return;
      case ConfQueueFlushResult.keep:
        return;
      case ConfQueueFlushResult.emit:
        break;
    }
    _pendingConfJoinSessionId = null;
    debugPrint('[CallService] 🔁 flush call_conf_join session=$sessionId');
    _apiClient.sendSocketEvent(SocketEvents.callConfJoin, {});
  }

  /// Côté invité : refuse l'invitation.
  Future<void> rejectConferenceInvite() async {
    if (_confSessionId == null) return;
    _pendingConfJoinSessionId = null;
    _apiClient.sendSocketEvent(SocketEvents.callConfReject, {});
    // L'invitation, pas la session : c'est sous son identifiant que CallKit la
    // présente, et la session pourra réinviter ce téléphone plus tard.
    final inviteId = _currentCallId ?? _confSessionId;
    _markTerminalCallId(inviteId);
    await _ringtone.stop();
    await _callKit.endAll(callId: inviteId);
    await _terminateConference();
  }

  String _addRejectionReason(String code) {
    switch (code) {
      case 'ADD_ALREADY_USED':
        return 'already_used';
      case 'TARGET_BUSY':
        return 'busy';
      case 'TARGET_BLOCKED':
        return 'blocked';
      case 'NOT_IN_CALL':
        return 'not_in_call';
      case 'TARGET_SELF':
      case 'TARGET_ALREADY_IN_CALL':
      case 'INVALID':
        return 'invalid';
      default:
        return 'internal';
    }
  }

  void _promoteOneToOneToMesh() {
    if (_groupRoomId != null) return;
    final peerId = _remoteUserId?.toString();
    final myId = _localUserId;
    if (peerId == null || myId == null) return;
    final myName = _localUserName;
    final myPhoto = _localUserPhoto;

    final pc = _webrtc.peerConnection;
    final role = originLinkRole(
      meshLinkExists: _groupPeerConnections.containsKey(peerId),
      meshLinkIsOrigin: pc != null && identical(_groupPeerConnections[peerId], pc),
    );
    if (role == OriginLinkRole.verser) {
      if (pc != null) _groupPeerConnections[peerId] = pc;
      final remote = _webrtc.remoteStream;
      if (remote != null) _groupRemoteStreams[peerId] = remote;
      _groupRemoteDescSet.add(peerId);
    }

    _groupRoster[peerId] = GroupParticipantInfo(
      id: peerId,
      name: _remoteUserName ?? LocaleController.instance.l10n.participantFallback,
      photo: _remoteUserPhoto,
      isMuted: _isRemoteMuted,
      isVideoOn: _isRemoteVideoOn,
    );
    _groupRoster[myId.toString()] = GroupParticipantInfo(
      id: myId.toString(),
      name: myName,
      photo: myPhoto,
      isMuted: _isMuted,
      isVideoOn: _isVideoOn,
    );
    _myRosterId = myId.toString();

    _groupRoomId = _confSessionId;
    if (role != OriginLinkRole.ignorer) _guardOriginLinkFailure(peerId);
    _startSpeakingDetection(groupMode: true);
    debugPrint('[CallService] 🔗 connexion 1-à-1 versée dans le maillage (pair=$peerId)');
  }

  void _guardOriginLinkFailure(String peerId) {
    _webrtc.onConnectionFailure = () {
      // Après demote / départ volontaire d'un pair : un flux mesh restant
      // prouve que l'appel continue — ne pas raccrocher (piège transfert).
      final hasMeshPeer = _groupRemoteStreams.isNotEmpty ||
          _groupPeerConnections.keys.any((id) => id != peerId);
      if (_confSessionId == null) {
        if (hasMeshPeer) {
          debugPrint(
            '[CallService] 🔌 lien d\'origine tombé hors session conf '
            'mais pair mesh restant — on continue',
          );
          _webrtc.onConnectionFailure = null;
          return;
        }
        debugPrint('[CallService] ** lien tombé hors session : fin d\'appel');
        _terminateCall();
        return;
      }

      debugPrint('[CallService] 🔌 lien d\'origine ($peerId) tombé en session');
      _removeGroupPeer(peerId, disarmOriginFailure: true);

      if (_groupPeerConnections.isEmpty && _groupRemoteStreams.isEmpty) {
        debugPrint('[CallService] ** plus aucun pair : fin d\'appel');
        _terminateCall();
        return;
      }

      _demoteMeshToOneToOne();
      // PC d'origine mort : ne plus laisser un Closed tardif tuer B↔C.
      _webrtc.onConnectionFailure = null;
      notify();
    };
  }

  void _onConfAddPending(Map data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null) return;

    // Nouveau tour : ce qui restait du précédent ne vaut plus, et je suis
    // désormais un présent — même si j'étais entré comme invité.
    _resetConfRound();
    _confSessionId = sessionId;
    _confInviteIsMine = data['byUserId']?.toString() == _localUserId?.toString();
    final mode = data['mode']?.toString();
    if (mode == 'transfer' || mode == 'join') _confMode = mode!;
    _isTransferInitiator = _confInviteIsMine && _confMode == 'transfer';
    _transferStatus = CallTransferStatus.awaitingJoin;

    final invitee = data['invitee'];
    if (invitee is Map) {
      final inviteeId = invitee['id'].toString();
      _confPendingInvitee = GroupParticipantInfo(
        id: inviteeId,
        name: (invitee['name'] as String?)?.isNotEmpty == true
            ? invitee['name'] as String
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(invitee['photo']?.toString()),
      );
      if (_confMode == 'transfer') {
        _transferTargetId = inviteeId;
      }
    }

    _promoteOneToOneToMesh();
    notify();
  }

  Future<void> _onConfJoined(Map data) async {
    final user = data['user'];
    if (user is! Map) return;
    final userId = user['id'].toString();
    final mode = data['mode']?.toString();
    if (mode == 'transfer' || mode == 'join') _confMode = mode!;

    final known = _groupRoster[userId];
    _groupRoster[userId] = GroupParticipantInfo(
      id: userId,
      name: (user['name'] as String?)?.isNotEmpty == true
          ? user['name'] as String
          : LocaleController.instance.l10n.participantFallback,
      photo: normalizeBackendUrl(user['photo']?.toString()),
      // Une carte reconstruite ne doit pas rouvrir un micro déjà coupé.
      isMuted: known?.isMuted ?? false,
      isVideoOn: known?.isVideoOn ?? true,
    );
    // L'arrivant ne sait rien de mes états : je les lui réaffirme.
    _broadcastMyMediaState();
    _confPendingInvitee = null;
    if (_confMode == 'transfer' && _isTransferInitiator) {
      _transferStatus = CallTransferStatus.awaitingMediaReady;
    }
    notify();

    if (_groupPeerConnections.containsKey(userId)) return;
    await _createGroupPeerAndOffer(userId);
  }

  void _onConfPeers(Map data) {
    final peers = data['peers'];
    if (peers is! List) return;
    final mode = data['mode']?.toString();
    if (mode == 'transfer' || mode == 'join') _confMode = mode!;
    for (final p in peers) {
      if (p is! Map) continue;
      final id = p['id'].toString();
      final known = _groupRoster[id];
      _groupRoster[id] = GroupParticipantInfo(
        id: id,
        name: (p['name'] as String?)?.isNotEmpty == true
            ? p['name'] as String
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(p['photo']?.toString()),
        // Un état déjà reçu prime sur les valeurs par défaut de la carte.
        isMuted: known?.isMuted ?? false,
        isVideoOn: known?.isVideoOn ?? true,
      );
    }
    _groupParticipants = peers
        .whereType<Map>()
        .map((p) => p['id'].toString())
        .toList();
    // Je viens d'entrer : les autres ne savent pas si mon micro est coupé.
    _broadcastMyMediaState();
    notify();
  }

  /// Remet à zéro l'état d'un tour d'invitation, sans toucher à la session.
  ///
  /// Appelé à chaque nouvelle invitation, à chaque retour à deux et à chaque
  /// échec. Sans lui, l'ancien invité restait marqué comme tel
  /// (`_confInvitedBy`) et n'émettait jamais le `call_conf_ready` qui déclenche
  /// un second transfert ; une cible de transfert périmée survivait à un ajout
  /// simple ; une clé `ready` déjà émise bloquait le même pair au tour suivant.
  void _resetConfRound() {
    _confPendingInvitee = null;
    _confInviteIsMine = false;
    _confInvitedBy = null;
    _confMode = 'join';
    _isTransferInitiator = false;
    _transferTargetId = null;
    _transferStatus = CallTransferStatus.none;
    _clearTransferCountdown();
    _confReadySent.clear();
    _pendingConfReady.clear();
  }

  void _onConfFailed(Map data) {
    final invitee = _confPendingInvitee;
    final reason = data['reason']?.toString() ?? 'declined';
    debugPrint('[CallService] ✖ invitation soldée (${invitee?.name ?? '?'}) : $reason');

    final inviteeId = data['userId']?.toString();
    if (inviteeId != null) _removeGroupPeer(inviteeId);

    // Le serveur garde la session quand quelqu'un y est déjà entré : elle
    // porte l'appel, et raccrocher doit continuer d'y passer.
    if (!confFailedKeepsSession(data)) _confSessionId = null;
    _resetConfRound();
    _transferStatus = CallTransferStatus.cancelled;
    _lastConfFailure = reason == 'media_not_ready' ? 'media_not_ready' : reason;
    _pendingConfJoinSessionId = null;

    _demoteMeshToOneToOne();
    notify();
  }

  void _onConfLeft(Map data) {
    final userId = data['userId']?.toString();
    if (userId == null) return;
    final reason = data['reason']?.toString();
    debugPrint('[CallService] 👋 $userId a quitté la session reason=$reason');

    // Ce départ est le mien : le serveur m'a retiré de la session. Il ne le
    // disait à personne d'autre que les restants, et l'écran d'appel restait
    // ouvert sur une conférence que j'avais quittée sans le savoir.
    //
    // Sortie immédiate, avant tout le reste : ce qui suit démonte un PAIR qui
    // s'en va, et rien de cela n'a de sens quand c'est moi.
    if (confLeftMeVise(leftUserId: userId, myRosterId: _myRosterId)) {
      debugPrint(
        '[CallService] 🚪 retiré de la session par le serveur reason=$reason',
      );
      unawaited(_terminateCall(force: true));
      return;
    }

    if (reason == 'media_not_ready') {
      _lastConfFailure = 'media_not_ready';
    } else {
      _lastConfDeparture = _groupRoster[userId]?.name;
    }

    // Départ de l'ancien pair 1-à-1 (ex. initiateur transfert) : désarmer
    // avant close pour éviter le raccrochage intempestif du lien d'origine.
    final isOriginPeer = userId == _remoteUserId?.toString() ||
        identical(_groupPeerConnections[userId], _webrtc.peerConnection);
    _removeGroupPeer(userId, disarmOriginFailure: isOriginPeer);
    // Le partant quitte aussi le roster : sans quoi le repli de
    // `_demoteMeshToOneToOne` pouvait le prendre pour le restant — et
    // raccrocher aurait visé un absent —, et sa tuile reparaissait au tour
    // suivant.
    if (userId != _myRosterId) _groupRoster.remove(userId);

    final remaining = (data['remaining'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    if (remaining.isNotEmpty) _groupParticipants = remaining;

    if (_isTransferInitiator &&
        _transferStatus == CallTransferStatus.countdown) {
      // Un autre est parti pendant le countdown : le serveur annule le leave auto.
      _transferStatus = CallTransferStatus.cancelled;
      _clearTransferCountdown();
    }

    _demoteMeshToOneToOne();
    if (isOriginPeer) {
      _webrtc.onConnectionFailure = null;
    }
    // Retombé à deux : le tour est clos, et le droit d'ajout revient.
    if (_groupRoomId == null) _resetConfRound();

    // Plus aucun pair média : solde local (évite un appel fantôme si
    // call_ended serveur arrive avant/après et est filtré par l'entonnoir).
    if (_groupPeerConnections.isEmpty && _groupRemoteStreams.isEmpty) {
      debugPrint('[CallService] 👋 plus aucun pair après conf_left → fin locale');
      unawaited(_terminateCall(force: true));
      return;
    }
    notify();
  }

  void _onTransferArmed(Map data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null || sessionId != _confSessionId) return;
    if (!_isTransferInitiator) return;
    final leaveInMs = int.tryParse(data['leaveInMs']?.toString() ?? '') ??
        (data['leaveInMs'] is num ? (data['leaveInMs'] as num).toInt() : null) ??
        10000;
    _transferLeaveInMs = leaveInMs;
    _transferArmedAt = DateTime.now();
    _transferStatus = CallTransferStatus.countdown;
    debugPrint('[CallService] ⏱ transfer armed leaveInMs=$leaveInMs');
    notify();
  }

  void _clearTransferCountdown() {
    _transferLeaveInMs = null;
    _transferArmedAt = null;
  }

  Future<void> _onTransferDone(Map data) async {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null) return;
    if (_confSessionId != null && _confSessionId != sessionId) return;

    final reason = data['reason']?.toString() ?? 'automatic';
    final transferred =
        data['transferredUserId']?.toString() ?? data['to']?.toString();
    final localId = _localUserId?.toString();
    // Uniquement l'initiateur qui part doit teardown — B/C continuent.
    final amLeaving = transferred == null ||
        transferred.isEmpty ||
        (localId != null && transferred == localId);
    if (!amLeaving) {
      debugPrint(
        '[CallService] transfer_done ignoré (je ne suis pas le partant '
        'transferred=$transferred local=$localId)',
      );
      return;
    }

    debugPrint('[CallService] ✔ transfer done reason=$reason — départ local');
    _transferStatus = CallTransferStatus.completed;
    _isTransferInitiator = false;
    _transferTargetId = null;
    _clearTransferCountdown();
    notify();

    if (_status == CallStatus.connected ||
        _status == CallStatus.joining ||
        _status == CallStatus.connecting) {
      // Soldate conf + mesh AVANT terminate pour ne pas laisser un Closed
      // WebRTC côté B/C être confondu avec une panne locale ici, et pour
      // autoriser l'entonnoir _terminateCall (force).
      _webrtc.onConnectionFailure = null;
      _clearAllGroupPeers(disarmOriginFailure: true);
      _confSessionId = null;
      _groupRoomId = null;
      await _terminateCall(force: true);
    }
  }

  /// Émis une seule fois par (session, peer) quand PC↔C est connected.
  /// Uniquement pour un participant **restant** en mode transfer
  /// (ni l'initiateur, ni C la cible).
  void _maybeEmitConfReady(String peerId) {
    if (!canLocalEmitConfReady(
      confMode: _confMode,
      isTransferInitiator: _isTransferInitiator,
      isConfInvitee: _confInvitedBy != null,
      peerId: peerId,
      localUserId: _localUserId,
      transferTargetId: _transferTargetId,
    )) {
      return;
    }
    // Négociation SDP terminée côté local — pas de ready sur une PC « Connected »
    // fantôme avant answer/remote description (sinon leaveTimer serveur trop tôt).
    if (!_groupRemoteDescSet.contains(peerId)) return;

    final sessionId = _confSessionId;
    if (sessionId == null) return;

    final key = confReadyKey(sessionId, peerId);
    if (_confReadySent.contains(key) || _pendingConfReady.contains(key)) return;

    if (!_apiClient.isSocketReady) {
      debugPrint('[CallService] ⏳ call_conf_ready en file peer=$peerId');
      _pendingConfReady.add(key);
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
      return;
    }

    _emitConfReady(sessionId, peerId, key);
  }

  void _emitConfReady(String sessionId, String peerId, String key) {
    if (_confReadySent.contains(key)) return;
    _confReadySent.add(key);
    _pendingConfReady.remove(key);
    debugPrint('[CallService] 📡 call_conf_ready peer=$peerId');
    _apiClient.sendSocketEvent(SocketEvents.callConfReady, {
      'sessionId': sessionId,
      'peerId': peerId,
    });
  }

  /// Flush des ready mis en file, avec gardes anti-session périmée.
  void _flushPendingConfReady() {
    if (_pendingConfReady.isEmpty) return;
    if (!_apiClient.isSocketReady) return;

    final pending = Set<String>.from(_pendingConfReady);
    for (final key in pending) {
      final parts = key.split('|');
      if (parts.length != 2) {
        _pendingConfReady.remove(key);
        continue;
      }
      final sessionId = parts[0];
      final peerId = parts[1];

      final decision = confReadyFlushDecision(
        keySessionId: sessionId,
        confSessionId: _confSessionId,
        isTerminal: _isTerminalCallId(sessionId),
        confMode: _confMode,
        isTransferInitiator: _isTransferInitiator,
        callStatusName: _status.name,
        socketReady: _apiClient.isSocketReady,
      );
      switch (decision) {
        case ConfQueueFlushResult.drop:
          debugPrint('[CallService] 🛡 conf ready flush drop key=$key');
          _pendingConfReady.remove(key);
          continue;
        case ConfQueueFlushResult.keep:
          return;
        case ConfQueueFlushResult.emit:
          _emitConfReady(sessionId, peerId, key);
      }
    }
  }

  void _demoteMeshToOneToOne() {
    if (_groupRoomId == null) return;
    if (_confPendingInvitee != null) return;
    if (_groupRemoteStreams.length > 1) return;

    final remainingId = _groupRemoteStreams.keys.isNotEmpty
        ? _groupRemoteStreams.keys.first
        : (_groupRoster.keys.where((k) => k != _myRosterId).isNotEmpty
            ? _groupRoster.keys.firstWhere((k) => k != _myRosterId)
            : null);
    if (remainingId == null) return;

    final card = _groupRoster[remainingId];
    _remoteUserId = int.tryParse(remainingId);
    if (card != null) {
      _remoteUserName = card.name;
      _remoteUserPhoto = card.photo;
      _isRemoteMuted = card.isMuted;
      _isRemoteVideoOn = card.isVideoOn;
    }

    _groupRoomId = null;
    // Le PC 1-à-1 d'origine peut être mort (pair parti) : l'UI lit
    // activeRemoteStream via _groupRemoteStreams. Ne plus tuer l'appel sur
    // Closed tardif du lien d'origine.
    _webrtc.onConnectionFailure = null;
    _startSpeakingDetection(groupMode: false);
    debugPrint('[CallService] ↩ retour à l\'affichage à deux (pair=$remainingId)');
  }

  Future<void> _terminateConference() async {
    speakingDetector.stop();
    // Le média de la conférence est celui du lien 1-à-1 d'origine : sans
    // dispose, quitter une conférence laissait micro et caméra capturés.
    await _webrtc.dispose();
    _confSessionId = null;
    _confPendingInvitee = null;
    _confInvitedBy = null;
    _confInviteIsMine = false;
    _isTransferInitiator = false;
    _transferTargetId = null;
    _clearTransferCountdown();
    _transferStatus = CallTransferStatus.none;
    _confMode = 'join';
    _confReadySent.clear();
    _pendingConfReady.clear();
    _pendingConfJoinSessionId = null;
    _groupRoster.clear();
    _pendingGroupMedia.clear();
    _groupRoomId = null;
    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }
}
