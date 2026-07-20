// Appels de groupe : création, join, leave, mesh WebRTC (part of call_service.dart).
part of '../call_service.dart';

extension CallGroup on CallService {
  /// Crée un appel de groupe et invite [targetUserIds].
  ///
  /// [targets] (optionnel) pré-remplit le roster pour afficher noms et photos
  /// dans la grille avant que les participants ne rejoignent.
  Future<void> createGroupCall({
    required String roomId,
    required int myId,
    required String myName,
    String? myPhoto,
    required List<int> targetUserIds,
    required bool isVideo,
    List<GroupParticipantInfo>? targets,
  }) async {
    if (_status != CallStatus.idle) return;
    if (!await _ensureFullyConnectedForOutgoingCall()) return;

    final maxOthers = CallLimits.maxSelectable(isVideo: isVideo);
    if (targetUserIds.length > maxOthers) {
      debugPrint(
        '[CallService] createGroupCall refusé : ${targetUserIds.length} cibles '
        '(max $maxOthers en ${CallLimits.mediaLabel(isVideo: isVideo)})',
      );
      return;
    }

    _groupRoomId = roomId;
    _status = CallStatus.outgoing;
    // Pré-remplit le roster : moi-même + les cibles connues
    _groupRoster[myId.toString()] = GroupParticipantInfo(
      id: myId.toString(),
      name: myName,
      photo: myPhoto,
    );
    if (targets != null) {
      for (final t in targets) {
        _groupRoster[t.id] = t;
      }
    }
    notify();

    try {
      await _initLocalStream(isVideo);

      _apiClient.sendSocketEvent(SocketEvents.createGroupCall, {
        'roomId': roomId,
        'callerId': myId.toString(),
        'callerName': myName,
        'callerPhoto': myPhoto,
        'isVideo': isVideo,
        'targetUserIds': targetUserIds.map((id) => id.toString()).toList(),
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: true);
      if (!kIsWeb) {
        _currentCallId = 'group_$roomId';
        await _acquireCallSession(
          isVideo: isVideo,
          displayName: LocaleController.instance.l10n.groupCall,
          handle: roomId,
        );
        await _markCallSessionConnected();
      }
      notify();
    } catch (e) {
      debugPrint('[CallService] Erreur createGroupCall: $e');
      await _releaseCallSession();
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Rejoint un appel de groupe existant (après invitation).
  ///
  /// [callerInfo] (optionnel) ajoute l'appelant au roster (utile si on n'a
  /// pas reçu l'event `groupCallInvite` qui le peuple normalement).
  Future<void> joinGroupCall({
    required String roomId,
    required int myId,
    required String myName,
    String? myPhoto,
    required bool isVideo,
    GroupParticipantInfo? callerInfo,
  }) async {
    _groupRoomId = roomId;
    _status = CallStatus.joining;
    // Moi-même dans le roster
    _groupRoster[myId.toString()] = GroupParticipantInfo(
      id: myId.toString(),
      name: myName,
      photo: myPhoto,
    );
    if (callerInfo != null) {
      _groupRoster[callerInfo.id] = callerInfo;
    }
    notify();

    try {
      await _initLocalStream(isVideo);


      _apiClient.sendSocketEvent(SocketEvents.joinGroupCall, {
        'roomId': roomId,
        'userId': myId.toString(),
        'userName': myName,
        'userPhoto': myPhoto,
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      _startSpeakingDetection(groupMode: true);
      if (!kIsWeb) {
        _currentCallId = 'group_$roomId';
        await _acquireCallSession(
          isVideo: isVideo,
          displayName: LocaleController.instance.l10n.groupCall,
          handle: roomId,
        );
        await _markCallSessionConnected();
      }
      notify();
    } catch (e) {
      debugPrint('[CallService] Erreur joinGroupCall: $e');
      await _releaseCallSession();
      _status = CallStatus.idle;
      notify();
    }
  }

  Future<void> leaveGroupCall() async {
    if (_groupRoomId == null) return;

    _apiClient.sendSocketEvent(SocketEvents.leaveGroupCall, {
      'roomId': _groupRoomId,
    });

    await _terminateGroupCall();
  }

  Future<void> endGroupCall() async {
    if (_groupRoomId == null) return;

    _apiClient.sendSocketEvent(SocketEvents.endGroupCall, {
      'roomId': _groupRoomId,
    });

    await _terminateGroupCall();
  }

  /// Rejet local d'une invitation entrante d'appel de groupe.
  /// Le backend n'expose pas de "reject_group_call" — on se contente de
  /// reset l'état local pour ne pas rester bloqué en CallStatus.incoming.
  Future<void> rejectGroupCall() async {
    if (_groupRoomId == null && _status != CallStatus.incoming) return;
    await _ringtone.stop();
    await _callKit.endAll();
    _groupRoster.clear();
    _groupRoomId = null;
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserPhoto = null;
    _status = CallStatus.idle;
    notify();
  }

  Future<void> _terminateGroupCall() async {
    speakingDetector.stop();
    for (final pc in _groupPeerConnections.values) {
      await pc.close();
    }
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();
    _groupParticipants.clear();
    _groupPendingIce.clear();
    _groupRemoteDescSet.clear();
    _groupRoster.clear();
    await _releaseCallSession();
    await _callKit.endAll();
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _groupRoomId = null;
    _callDuration = 0;
    _resetCallUiState();
    _status = CallStatus.idle;
    notify();
  }

  Future<void> _initLocalStream(bool isVideo) async {
    final iceServers = await _apiClient.fetchIceServers();
    await _webrtc.init(isVideo ? CallType.video : CallType.audio, iceServers: iceServers);

    // Initialiser le routage audio pour les appels de groupe aussi (mobile uniquement) :
    // haut-parleur par défaut en vidéo, écouteur par défaut en audio.
    if (!kIsWeb) {
      _isSpeakerOn = isVideo;
      await audio.AudioHelper.setSpeakerphoneOn(isVideo);
      debugPrint('[CallService] 🔊 Routage audio initialisé (haut-parleur ${isVideo ? "ON" : "OFF"})');
    }
  }

  Future<void> _createGroupPeerAndOffer(String userId) async {
    final pc = await _createGroupPeerConnection(userId);

    _webrtc.localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _webrtc.localStream!);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // Payload exact attendu par le backend
    _apiClient.sendSocketEvent(SocketEvents.groupOffer, {
      'roomId': _groupRoomId,
      'fromUserId': '', // rempli par socket.alanyaID côté serveur
      'toUserId': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> _handleGroupOffer(String fromUserId, Map offer) async {
    final pc = await _createGroupPeerConnection(fromUserId);

    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, 'offer'),
    );
    _groupRemoteDescSet.add(fromUserId);
    await _flushGroupPendingIce(fromUserId);

    _webrtc.localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _webrtc.localStream!);
    });

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // Payload exact attendu par le backend
    _apiClient.sendSocketEvent(SocketEvents.groupAnswer, {
      'roomId': _groupRoomId,
      'fromUserId': '',
      'toUserId': fromUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<RTCPeerConnection> _createGroupPeerConnection(String userId) async {
    if (_groupPeerConnections.containsKey(userId)) {
      return _groupPeerConnections[userId]!;
    }

    final iceServers = await _apiClient.fetchIceServers();
    final iceConfig = {'iceServers': iceServers};

    final pc = await createPeerConnection(iceConfig);

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[userId] = event.streams[0];
        notify();
      }
    };

    pc.onIceCandidate = (candidate) {
      // Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.groupIceCandidate, {
        'roomId': _groupRoomId,
        'fromUserId': '',
        'toUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('[CallService] ** Group peer $userId connection failed: $state');
        _removeGroupPeer(userId);
      }
    };

    _groupPeerConnections[userId] = pc;
    return pc;
  }

  void _removeGroupPeer(String userId) {
    _groupPeerConnections[userId]?.close();
    _groupPeerConnections.remove(userId);
    _groupRemoteStreams.remove(userId);
    _groupParticipants.remove(userId);
    _groupPendingIce.remove(userId);
    _groupRemoteDescSet.remove(userId);
    notify();
  }

  Future<void> _flushGroupPendingIce(String userId) async {
    final pc = _groupPeerConnections[userId];
    final pending = _groupPendingIce.remove(userId);
    if (pc == null || pending == null || pending.isEmpty) return;
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('[CallService] group addCandidate (flush) échoué $userId: $e');
      }
    }
  }
}