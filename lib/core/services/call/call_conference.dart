// « Ajouter à l'appel » : escalade d'un appel 1-à-1 vers une session à trois,
// puis retrait d'un participant sans interrompre les autres (part of call_service.dart).
//
// Le maillage média est celui des appels de groupe — les relais group_offer /
// group_answer / group_ice_candidate sont réutilisés tels quels. La seule
// particularité tient en une phrase : la connexion 1-à-1 déjà établie n'est ni
// fermée ni renégociée, elle devient le premier lien du maillage.
part of '../call_service.dart';

extension CallConference on CallService {
  /// Invite [inviteeId] à rejoindre l'appel en cours.
  ///
  /// Le serveur arbitre : droit d'ajout déjà utilisé, invité occupé ou bloqué
  /// reviennent en `call_add_rejected`. On n'anticipe rien localement, sinon les
  /// deux participants pourraient se croire chacun légitime.
  void addParticipant(int inviteeId, {String? myName, String? myPhoto}) {
    if (!canAddParticipant) return;
    debugPrint('[CallService] ➕ demande d\'ajout de $inviteeId');
    _apiClient.sendSocketEvent(SocketEvents.callAddParticipant, {
      'targetUserId': inviteeId.toString(),
      if (myName != null) 'callerName': myName,
      if (myPhoto != null) 'callerPhoto': myPhoto,
    });
  }

  /// Annule l'invitation en cours. Réservé à celui qui l'a lancée.
  void cancelAddParticipant() {
    if (_confSessionId == null || !_confInviteIsMine) return;
    debugPrint('[CallService] ✖ annulation de l\'invitation');
    _apiClient.sendSocketEvent(SocketEvents.callAddCancel, {});
  }

  /// Côté invité : accepte de rejoindre l'appel à trois.
  ///
  /// Le flux local est ouvert AVANT d'annoncer l'acceptation : les deux présents
  /// enverront leurs offres dès qu'ils l'apprennent, et `_handleGroupOffer` a
  /// besoin des pistes locales pour y répondre.
  Future<void> acceptConferenceInvite() async {
    final sessionId = _confSessionId;
    final myId = _localUserId;
    if (sessionId == null || myId == null || _status != CallStatus.incoming) return;
    final myName = _localUserName;
    final myPhoto = _localUserPhoto;

    _status = CallStatus.joining;
    notify();

    try {
      await _ringtone.stop();
      await _initLocalStream(_isVideo);

      // Le maillage s'adresse via _groupRoomId : la session en tient lieu.
      _groupRoomId = sessionId;
      _myRosterId = myId.toString();
      _groupRoster[myId.toString()] = GroupParticipantInfo(
        id: myId.toString(),
        name: myName,
        photo: myPhoto,
      );

      _apiClient.sendSocketEvent(SocketEvents.callConfJoin, {});

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

  /// Côté invité : refuse l'invitation.
  Future<void> rejectConferenceInvite() async {
    if (_confSessionId == null) return;
    _apiClient.sendSocketEvent(SocketEvents.callConfReject, {});
    _markTerminalCallId(_confSessionId);
    await _ringtone.stop();
    await _callKit.endAll(callId: _confSessionId);
    _terminateConference();
  }

  /// Traduit un code de refus serveur en raison affichable par l'interface.
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

  // ── Bascule 1-à-1 → maillage ────────────────────────────────────────────────

  /// Verse la connexion 1-à-1 en cours dans le maillage, sans y toucher.
  ///
  /// Ni `close()` ni renégociation : la RTCPeerConnection déjà établie et son
  /// flux distant sont simplement réindexés par identifiant d'utilisateur, là où
  /// la grille et le reste du code maillé savent les lire. C'est ce qui fait que
  /// les deux participants d'origine n'entendent aucune coupure — et qu'au
  /// départ du troisième, ils n'ont rien à reconstruire.
  void _promoteOneToOneToMesh() {
    if (_groupRoomId != null) return; // déjà maillé
    final peerId = _remoteUserId?.toString();
    final myId = _localUserId;
    if (peerId == null || myId == null) return;
    final myName = _localUserName;
    final myPhoto = _localUserPhoto;

    final pc = _webrtc.peerConnection;
    if (pc != null) _groupPeerConnections[peerId] = pc;
    final remote = _webrtc.remoteStream;
    if (remote != null) _groupRemoteStreams[peerId] = remote;
    // La description distante est posée de longue date sur ce lien : le marquer
    // évite que les prochains candidats ICE soient mis en attente pour rien.
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
    _startSpeakingDetection(groupMode: true);
    debugPrint('[CallService] 🔗 connexion 1-à-1 versée dans le maillage (pair=$peerId)');
  }

  // ── Réactions aux événements serveur ────────────────────────────────────────

  /// Une invitation vient d'être lancée : l'invité sonne, le droit est verrouillé.
  void _onConfAddPending(Map data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null) return;

    _confSessionId = sessionId;
    _confInviteIsMine = data['byUserId']?.toString() == _localUserId?.toString();

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

    // La grille apparaît dès la sonnerie : la tuile de l'invité préexiste à sa
    // réponse, c'est le seul moyen de rendre l'attente lisible.
    _promoteOneToOneToMesh();
    notify();
  }

  /// L'invité a accepté : chaque présent lui ouvre une connexion.
  ///
  /// Ce sont les présents qui offrent et l'arrivant qui répond — règle unique et
  /// suffisante pour qu'aucune offre n'en croise une autre.
  Future<void> _onConfJoined(Map data) async {
    final user = data['user'];
    if (user is! Map) return;
    final userId = user['id'].toString();

    _groupRoster[userId] = GroupParticipantInfo(
      id: userId,
      name: (user['name'] as String?)?.isNotEmpty == true
          ? user['name'] as String
          : LocaleController.instance.l10n.participantFallback,
      photo: normalizeBackendUrl(user['photo']?.toString()),
    );
    _confPendingInvitee = null;
    notify();

    if (_groupPeerConnections.containsKey(userId)) return;
    await _createGroupPeerAndOffer(userId);
  }

  /// Côté invité : la liste de ceux qui vont lui offrir. Rien à initier.
  void _onConfPeers(Map data) {
    final peers = data['peers'];
    if (peers is! List) return;
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

  /// L'invitation est soldée sans que l'invité soit entré.
  ///
  /// Effacer la session rend le droit d'ajout aux deux participants — sans quoi
  /// un simple refus condamnerait l'appel à ne plus jamais accueillir personne.
  void _onConfFailed(Map data) {
    final invitee = _confPendingInvitee;
    final reason = data['reason']?.toString() ?? 'declined';
    debugPrint('[CallService] ✖ invitation soldée (${invitee?.name ?? '?'}) : $reason');

    final inviteeId = data['userId']?.toString();
    if (inviteeId != null) _removeGroupPeer(inviteeId);

    _confSessionId = null;
    _confPendingInvitee = null;
    _confInviteIsMine = false;
    _lastConfFailure = reason;

    // Retour à un appel à deux : la grille n'a plus lieu d'être.
    _demoteMeshToOneToOne();
    notify();
  }

  /// Un participant s'est retiré. Les autres continuent.
  void _onConfLeft(Map data) {
    final userId = data['userId']?.toString();
    if (userId == null) return;
    debugPrint('[CallService] 👋 $userId a quitté la session');

    _lastConfDeparture = _groupRoster[userId]?.name;
    _removeGroupPeer(userId);

    final remaining = (data['remaining'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    if (remaining.isNotEmpty) _groupParticipants = remaining;

    // Le droit d'ajout reste consommé : _confSessionId n'est pas effacé.
    _demoteMeshToOneToOne();
    notify();
  }

  /// Ramène l'affichage à deux quand il ne reste qu'un correspondant.
  ///
  /// Le maillage n'est pas défait pour autant : la connexion survivante reste
  /// indexée par identifiant, et `activeRemoteStream` la donne à voir à l'écran
  /// d'appel ordinaire.
  void _demoteMeshToOneToOne() {
    if (_groupRoomId == null) return;
    if (_confPendingInvitee != null) return;      // un invité sonne encore
    if (_groupRemoteStreams.length > 1) return;   // toujours à trois

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

  /// Ferme la session sans toucher à l'appel : utilisé au refus et sur erreur.
  void _terminateConference() {
    speakingDetector.stop();
    _confSessionId = null;
    _confPendingInvitee = null;
    _confInvitedBy = null;
    _confInviteIsMine = false;
    _groupRoster.clear();
    _groupRoomId = null;
    _resetCallState();
    _status = CallStatus.idle;
    notify();
  }
}
