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
      final incomingCallerId = data['callerId'].toString();
      _remoteUserId = int.tryParse(incomingCallerId);
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = data['callerPhoto'] as String?;
      _isVideo = data['isVideo'] == true;
      _pendingOffer = data['offer'] as Map<String, dynamic>?;
      _currentCallId = data['callId']?.toString();
      _status = CallStatus.incoming;
      debugPrint('[CallService] !!Statut changé à INCOMING. Caller: $_remoteUserName ($_remoteUserId), Vidéo: $_isVideo');

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

      // Sonnerie système (téléphone par défaut de l'utilisateur).
      _ringtone.startIncomingRingtone().catchError((e) {
        debugPrint('[CallService] ** Erreur sonnerie (non-bloquante): $e');
      });
    });

    // Appel accepté par l'autre
    _apiClient.onSocketEvent(SocketEvents.callAnswered, (data) async {
      debugPrint('[CallService] 📞 call_answered reçu: $data');

      if (_status != CallStatus.connecting) {
        debugPrint('[CallService] ** call_answered ignoré : statut=$_status');
        return;
      }

      // 🛑 Arrêter le ringback dès que le destinataire décroche
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
      } catch (e) {
        debugPrint('[CallService] ** Erreur handleAnswer: $e');
        _status = CallStatus.idle;
      }
      notify();
    });

    // Appel rejeté par le destinataire
    _apiClient.onSocketEvent(SocketEvents.callRejected, (_) async {
      debugPrint('[CallService] 📞 Appel rejeté');
      await _terminateCall();
    });

    // Appel terminé par l'autre côté
    _apiClient.onSocketEvent(SocketEvents.callEnded, (_) async {
      debugPrint('[CallService] 📞 Appel terminé par l\'autre côté');
      await _terminateCall();
    });

    // Appel échoué (destinataire hors-ligne)
    _apiClient.onSocketEvent(SocketEvents.callFailed, (data) async {
      debugPrint('[CallService] Appel échoué: ${data?['reason']}');
      await _terminateCall();
    });

    // ICE candidate 1-à-1
    _apiClient.onSocketEvent(SocketEvents.iceCandidate, (data) {
      if (data is! Map || data['candidate'] == null) return;
      final c = data['candidate'] as Map;
      _webrtc.addIceCandidate(RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    });

    // Appels de groupe
    // Invitation à un appel de groupe
    _apiClient.onSocketEvent(SocketEvents.groupCallInvite, (data) {
      if (data is! Map) return;
      _remoteUserId = int.tryParse(data['callerId'].toString());
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = data['callerPhoto'] as String?;
      _isVideo = data['isVideo'] == true;
      _groupRoomId = data['roomId'] as String?;
      // Le caller est notre seule info connue à l'instant T → on le pose dans le roster
      final callerId = data['callerId']?.toString();
      if (callerId != null && callerId.isNotEmpty) {
        _groupRoster[callerId] = GroupParticipantInfo(
          id: callerId,
          name: (_remoteUserName?.isNotEmpty == true) ? _remoteUserName! : 'Participant',
          photo: _remoteUserPhoto,
        );
      }
      _status = CallStatus.incoming;
      notify();
    });

    // Nouveau participant dans le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      final userName = (data['userName'] as String?) ?? '';
      final userPhoto = data['userPhoto'] as String?;
      _groupRoster[userId] = GroupParticipantInfo(
        id: userId,
        name: userName.isNotEmpty ? userName : 'Participant',
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
            name: nom.isNotEmpty ? nom : (pseudo.isNotEmpty ? pseudo : 'Participant'),
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

    // WebRTC groupe : offer reçue
    _apiClient.onSocketEvent(SocketEvents.groupOffer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final offer = data['offer'] as Map?;
      if (offer == null) return;
      await _handleGroupOffer(fromUserId, offer);
    });

    // WebRTC groupe : answer reçue
    _apiClient.onSocketEvent(SocketEvents.groupAnswer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final answer = data['answer'] as Map?;
      if (answer == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        _groupRemoteDescSet.add(fromUserId);
        await _flushGroupPendingIce(fromUserId);
      }
    });

    // WebRTC groupe : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.groupIceCandidate, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final c = data['candidate'] as Map?;
      if (c == null) return;
      final candidate = RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null || !_groupRemoteDescSet.contains(fromUserId)) {
        _groupPendingIce.putIfAbsent(fromUserId, () => []).add(candidate);
        return;
      }
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[CallService] group addCandidate échoué $fromUserId: $e');
      }
    });
  }
}
