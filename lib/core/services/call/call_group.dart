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
    _markTerminalCallId(_groupRoomId);
    await _ringtone.stop();
    await _callKit.endAll(callId: _groupRoomId);
    _groupRoster.clear();
    _groupRoomId = null;
    // Reset canonique complet (identité, offre, flags, timers) pour ne pas
    // laisser d'état résiduel qui contaminerait le prochain appel.
    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }

  Future<void> _terminateGroupCall() async {
    final wasConnected = _status == CallStatus.connected;
    speakingDetector.stop();
    _markTerminalCallId(_groupRoomId);
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
    await _callKit.endAll(callId: _groupRoomId);
    await _webrtc.dispose();
    _durationTimer?.cancel();
    if (wasConnected) MessageSoundService.instance.playCallEnd();
    _groupRoomId = null;
    // Converge sur le reset 1-à-1 canonique : nettoie aussi _currentCallId
    // (sinon 'group_<room>' serait réutilisé comme id du prochain appel 1-à-1),
    // _pendingOffer, _remoteUser*, flags média/auto-réponse et timers.
    _resetCallState();
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

  Future<void> _createGroupPeerAndOffer(String userId, {bool iceRestart = false}) async {
    final pc = await _createGroupPeerConnection(userId);

    if (!iceRestart) {
      _webrtc.localStream?.getTracks().forEach((track) {
        pc.addTrack(track, _webrtc.localStream!);
      });
    }

    final generation = iceRestart
        ? (_groupPeerIceGeneration[userId] = (_groupPeerIceGeneration[userId] ?? 0) + 1)
        : (_groupPeerIceGeneration[userId] ??= 0);

    final offer = iceRestart
        ? await pc.createOffer({'iceRestart': true})
        : await pc.createOffer();
    await pc.setLocalDescription(offer);

    _apiClient.sendSocketEvent(SocketEvents.groupOffer, {
      'roomId': _groupRoomId,
      'fromUserId': '',
      'toUserId': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'generation': generation,
    });
  }

  Future<void> _handleGroupOffer(
    String fromUserId,
    Map offer, {
    int? generation,
  }) async {
    final pc = await _createGroupPeerConnection(fromUserId);

    if (generation != null) {
      final local = _groupPeerIceGeneration[fromUserId] ?? 0;
      if (generation < local) {
        debugPrint(
          '[CallService] 🛡 group_offer gen périmée peer=$fromUserId gen=$generation local=$local',
        );
        return;
      }
      _groupPeerIceGeneration[fromUserId] = generation;
    }

    final alreadyHadPc = _groupRemoteDescSet.contains(fromUserId);
    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, 'offer'),
    );
    _groupRemoteDescSet.add(fromUserId);
    await _flushGroupPendingIce(fromUserId);

    if (!alreadyHadPc) {
      _webrtc.localStream?.getTracks().forEach((track) {
        pc.addTrack(track, _webrtc.localStream!);
      });
    }

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _apiClient.sendSocketEvent(SocketEvents.groupAnswer, {
      'roomId': _groupRoomId,
      'fromUserId': '',
      'toUserId': fromUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      if (generation != null) 'generation': generation,
    });

    _groupPeerIsRestarting[fromUserId] = false;
    _cancelGroupPeerDisconnectGrace(fromUserId);
  }

  /// Initiator restart déterministe : userId le plus bas du pair.
  bool _isGroupRestartInitiator(String peerId) {
    final me = _localUserId?.toString() ?? _myRosterId;
    if (me == null || me.isEmpty) return false;
    return isGroupRestartInitiator(me: me, peerId: peerId);
  }

  Future<RTCPeerConnection> _createGroupPeerConnection(String userId) async {
    if (_groupPeerConnections.containsKey(userId)) {
      return _groupPeerConnections[userId]!;
    }

    final iceServers = await _apiClient.fetchIceServers();
    final iceConfig = {'iceServers': iceServers};

    final pc = await createPeerConnection(iceConfig);
    _groupPeerIceGeneration.putIfAbsent(userId, () => 0);

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[userId] = event.streams[0];
        notify();
      }
    };

    pc.onIceCandidate = (candidate) {
      _apiClient.sendSocketEvent(SocketEvents.groupIceCandidate, {
        'roomId': _groupRoomId,
        'fromUserId': '',
        'toUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'generation': _groupPeerIceGeneration[userId] ?? 0,
      });
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _cancelGroupPeerDisconnectGrace(userId);
        _groupPeerRetryCount[userId] = 0;
        _groupPeerIsRestarting[userId] = false;
        _maybeEmitConfReady(userId);
        return;
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cancelGroupPeerDisconnectGrace(userId);
        debugPrint('[CallService] Group peer $userId Closed → drop lien local seulement');
        _removeGroupPeer(userId);
        return;
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _cancelGroupPeerDisconnectGrace(userId);
        debugPrint('[CallService] Group peer $userId Failed → ICE restart si initiator');
        unawaited(_attemptGroupPeerIceRestart(userId));
        return;
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint(
          '[CallService] ⏳ Group peer $userId Disconnected — grâce 8s',
        );
        _armGroupPeerDisconnectGrace(userId);
      }
    };

    _groupPeerConnections[userId] = pc;
    return pc;
  }

  static const _groupPeerDisconnectGraceDuration = Duration(seconds: 8);

  void _armGroupPeerDisconnectGrace(String userId) {
    _cancelGroupPeerDisconnectGrace(userId);
    _groupPeerDisconnectGrace[userId] = Timer(
      _groupPeerDisconnectGraceDuration,
      () {
        _groupPeerDisconnectGrace.remove(userId);
        if (!_groupPeerConnections.containsKey(userId)) return;
        final st = _groupPeerConnections[userId]?.connectionState;
        if (st == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          return;
        }
        debugPrint(
          '[CallService] Group peer $userId toujours Disconnected après grâce',
        );
        // Initiator : ICE restart. Autre côté : attend l'offer ; si rien,
        // drop du lien local seulement (pas leaveCallSession serveur).
        if (_isGroupRestartInitiator(userId)) {
          unawaited(_attemptGroupPeerIceRestart(userId));
        } else {
          // Callee mesh : timeout local supplémentaire avant drop lien.
          _groupPeerDisconnectGrace[userId] = Timer(
            const Duration(seconds: 20),
            () {
              _groupPeerDisconnectGrace.remove(userId);
              if (!_groupPeerConnections.containsKey(userId)) return;
              final s = _groupPeerConnections[userId]?.connectionState;
              if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
                return;
              }
              debugPrint(
                '[CallService] Group peer $userId sans offer restart → drop lien local',
              );
              _removeGroupPeer(userId);
            },
          );
        }
      },
    );
  }

  Future<void> _attemptGroupPeerIceRestart(String userId) async {
    if (!_isGroupRestartInitiator(userId)) return;
    if (_groupPeerIsRestarting[userId] == true) return;
    if (!_groupPeerConnections.containsKey(userId)) return;

    final retries = _groupPeerRetryCount[userId] ?? 0;
    if (retries >= CallService._maxGroupPeerIceRestarts) {
      debugPrint(
        '[CallService] Group peer $userId ICE max → drop lien local (pas leaveSession)',
      );
      _removeGroupPeer(userId);
      return;
    }

    _groupPeerIsRestarting[userId] = true;
    _groupPeerRetryCount[userId] = retries + 1;
    // Purge ICE buffer de l'ancienne génération.
    _groupPendingIce.remove(userId);

    try {
      debugPrint(
        '[CallService] Group ICE restart peer=$userId #${retries + 1}',
      );
      await _createGroupPeerAndOffer(userId, iceRestart: true);
    } catch (e) {
      debugPrint('[CallService] ** Group ICE restart échoué $userId: $e');
      _groupPeerIsRestarting[userId] = false;
      if ((_groupPeerRetryCount[userId] ?? 0) >= CallService._maxGroupPeerIceRestarts) {
        _removeGroupPeer(userId);
      }
    }
  }

  void _cancelGroupPeerDisconnectGrace(String userId) {
    _groupPeerDisconnectGrace.remove(userId)?.cancel();
  }

  void _cancelAllGroupPeerDisconnectGrace() {
    for (final t in _groupPeerDisconnectGrace.values) {
      t.cancel();
    }
    _groupPeerDisconnectGrace.clear();
  }

  void _clearGroupPeerReconnectState([String? userId]) {
    if (userId != null) {
      _groupPeerIceGeneration.remove(userId);
      _groupPeerRetryCount.remove(userId);
      _groupPeerIsRestarting.remove(userId);
      return;
    }
    _groupPeerIceGeneration.clear();
    _groupPeerRetryCount.clear();
    _groupPeerIsRestarting.clear();
  }

  void _removeGroupPeer(
    String userId, {
    bool disarmOriginFailure = false,
  }) {
    _cancelGroupPeerDisconnectGrace(userId);
    _clearGroupPeerReconnectState(userId);
    final pc = _groupPeerConnections[userId];
    // PC 1-à-1 partagé dans le mesh : close() déclenche onConnectionFailure.
    // Sans désarmement, le départ d'A (transfert) raccroche B à tort.
    if (disarmOriginFailure ||
        (pc != null && identical(pc, _webrtc.peerConnection))) {
      _webrtc.onConnectionFailure = null;
      _webrtc.onConnectionStateChanged = null;
    }
    pc?.close();
    _groupPeerConnections.remove(userId);
    _groupRemoteStreams.remove(userId);
    _groupParticipants.remove(userId);
    _groupPendingIce.remove(userId);
    _groupRemoteDescSet.remove(userId);
    // Intentionnel : ne pas appeler leaveCallSession / end_call ici.
    // Une perte de lien local ≠ expulsion serveur du participant.
    notify();
  }

  void _clearAllGroupPeers({bool disarmOriginFailure = true}) {
    _cancelAllGroupPeerDisconnectGrace();
    _clearGroupPeerReconnectState();
    if (disarmOriginFailure) {
      _webrtc.onConnectionFailure = null;
      _webrtc.onConnectionStateChanged = null;
    }
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();
    _groupParticipants.clear();
    _groupPendingIce.clear();
    _groupRemoteDescSet.clear();
    _groupRoster.clear();
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