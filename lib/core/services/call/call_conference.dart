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
    final mode = transfer ? 'transfer' : 'join';
    debugPrint('[CallService] ➕ demande d\'ajout de $inviteeId mode=$mode');
    _confMode = mode;
    _isTransferInitiator = transfer;
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

      _emitOrQueueConfJoin(sessionId);

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: true);
      if (!kIsWeb) {
        _currentCallId = sessionId;
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
      _terminateConference();
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
    _pendingConfJoinSessionId = null;

    if (_confSessionId != sessionId) {
      debugPrint('[CallService] 🛡 conf join flush drop: session mismatch');
      return;
    }
    if (_isTerminalCallId(sessionId)) {
      debugPrint('[CallService] 🛡 conf join flush drop: session terminale');
      return;
    }
    if (_status != CallStatus.joining &&
        _status != CallStatus.incoming &&
        _status != CallStatus.connected) {
      debugPrint('[CallService] 🛡 conf join flush drop: status=$_status');
      return;
    }
    if (!_apiClient.isSocketReady) {
      _pendingConfJoinSessionId = sessionId;
      return;
    }
    debugPrint('[CallService] 🔁 flush call_conf_join session=$sessionId');
    _apiClient.sendSocketEvent(SocketEvents.callConfJoin, {});
  }

  /// Côté invité : refuse l'invitation.
  Future<void> rejectConferenceInvite() async {
    if (_confSessionId == null) return;
    _pendingConfJoinSessionId = null;
    _apiClient.sendSocketEvent(SocketEvents.callConfReject, {});
    _markTerminalCallId(_confSessionId);
    await _ringtone.stop();
    await _callKit.endAll(callId: _confSessionId);
    _terminateConference();
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
    if (pc != null) _groupPeerConnections[peerId] = pc;
    final remote = _webrtc.remoteStream;
    if (remote != null) _groupRemoteStreams[peerId] = remote;
    _groupRemoteDescSet.add(peerId);

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
    _guardOriginLinkFailure(peerId);
    _startSpeakingDetection(groupMode: true);
    debugPrint('[CallService] 🔗 connexion 1-à-1 versée dans le maillage (pair=$peerId)');
  }

  void _guardOriginLinkFailure(String peerId) {
    _webrtc.onConnectionFailure = () {
      if (_confSessionId == null) {
        debugPrint('[CallService] ** lien tombé hors session : fin d\'appel');
        _terminateCall();
        return;
      }

      debugPrint('[CallService] 🔌 lien d\'origine ($peerId) tombé en session');
      _removeGroupPeer(peerId);

      if (_groupPeerConnections.isEmpty) {
        debugPrint('[CallService] ** plus aucun pair : fin d\'appel');
        _terminateCall();
        return;
      }

      _demoteMeshToOneToOne();
      notify();
    };
  }

  void _onConfAddPending(Map data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null) return;

    _confSessionId = sessionId;
    _confInviteIsMine = data['byUserId']?.toString() == _localUserId?.toString();
    final mode = data['mode']?.toString();
    if (mode == 'transfer' || mode == 'join') _confMode = mode!;
    _isTransferInitiator = _confInviteIsMine && _confMode == 'transfer';
    _transferStatus = CallTransferStatus.awaitingJoin;

    final invitee = data['invitee'];
    if (invitee is Map) {
      _confPendingInvitee = GroupParticipantInfo(
        id: invitee['id'].toString(),
        name: (invitee['name'] as String?)?.isNotEmpty == true
            ? invitee['name'] as String
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(invitee['photo']?.toString()),
      );
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

    _groupRoster[userId] = GroupParticipantInfo(
      id: userId,
      name: (user['name'] as String?)?.isNotEmpty == true
          ? user['name'] as String
          : LocaleController.instance.l10n.participantFallback,
      photo: normalizeBackendUrl(user['photo']?.toString()),
    );
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
      _groupRoster[id] = GroupParticipantInfo(
        id: id,
        name: (p['name'] as String?)?.isNotEmpty == true
            ? p['name'] as String
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(p['photo']?.toString()),
      );
    }
    _groupParticipants = peers
        .whereType<Map>()
        .map((p) => p['id'].toString())
        .toList();
    notify();
  }

  void _onConfFailed(Map data) {
    final invitee = _confPendingInvitee;
    final reason = data['reason']?.toString() ?? 'declined';
    debugPrint('[CallService] ✖ invitation soldée (${invitee?.name ?? '?'}) : $reason');

    final inviteeId = data['userId']?.toString();
    if (inviteeId != null) _removeGroupPeer(inviteeId);

    _confSessionId = null;
    _confPendingInvitee = null;
    _confInviteIsMine = false;
    _isTransferInitiator = false;
    _transferStatus = CallTransferStatus.cancelled;
    _confMode = 'join';
    _lastConfFailure = reason == 'media_not_ready' ? 'media_not_ready' : reason;
    _confReadySent.clear();
    _pendingConfJoinSessionId = null;

    _demoteMeshToOneToOne();
    notify();
  }

  void _onConfLeft(Map data) {
    final userId = data['userId']?.toString();
    if (userId == null) return;
    final reason = data['reason']?.toString();
    debugPrint('[CallService] 👋 $userId a quitté la session reason=$reason');

    if (reason == 'media_not_ready') {
      _lastConfFailure = 'media_not_ready';
    } else {
      _lastConfDeparture = _groupRoster[userId]?.name;
    }
    _removeGroupPeer(userId);

    final remaining = (data['remaining'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    if (remaining.isNotEmpty) _groupParticipants = remaining;

    if (_isTransferInitiator &&
        _transferStatus == CallTransferStatus.countdown) {
      // Un autre est parti pendant le countdown : le serveur annule le leave auto.
      _transferStatus = CallTransferStatus.cancelled;
    }

    _demoteMeshToOneToOne();
    notify();
  }

  void _onTransferArmed(Map data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null || sessionId != _confSessionId) return;
    if (!_isTransferInitiator) return;
    _transferStatus = CallTransferStatus.countdown;
    debugPrint('[CallService] ⏱ transfer armed leaveInMs=${data['leaveInMs']}');
    notify();
  }

  Future<void> _onTransferDone(Map data) async {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null) return;
    if (_confSessionId != null && _confSessionId != sessionId) return;

    final reason = data['reason']?.toString() ?? 'automatic';
    debugPrint('[CallService] ✔ transfer done reason=$reason');
    _transferStatus = CallTransferStatus.completed;
    _isTransferInitiator = false;
    notify();

    // L'initiateur doit fermer son UI / session locale.
    if (_status == CallStatus.connected ||
        _status == CallStatus.joining ||
        _status == CallStatus.connecting) {
      await _terminateCall();
    }
  }

  /// Émis une seule fois par (session, peer) quand PC↔C est connected.
  /// Uniquement pour un participant restant en mode transfer (pas l'initiateur).
  void _maybeEmitConfReady(String peerId) {
    if (_confMode != 'transfer') return;
    if (_isTransferInitiator) return;
    final sessionId = _confSessionId;
    if (sessionId == null) return;
    final key = '$sessionId|$peerId';
    if (_confReadySent.contains(key)) return;
    _confReadySent.add(key);
    debugPrint('[CallService] 📡 call_conf_ready peer=$peerId');
    _apiClient.sendSocketEvent(SocketEvents.callConfReady, {
      'sessionId': sessionId,
      'peerId': peerId,
    });
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
    _startSpeakingDetection(groupMode: false);
    debugPrint('[CallService] ↩ retour à l\'affichage à deux (pair=$remainingId)');
  }

  void _terminateConference() {
    speakingDetector.stop();
    _confSessionId = null;
    _confPendingInvitee = null;
    _confInvitedBy = null;
    _confInviteIsMine = false;
    _isTransferInitiator = false;
    _transferStatus = CallTransferStatus.none;
    _confMode = 'join';
    _confReadySent.clear();
    _pendingConfJoinSessionId = null;
    _groupRoster.clear();
    _groupRoomId = null;
    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }
}
