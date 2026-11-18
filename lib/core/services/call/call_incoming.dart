// Entrées d'appel entrant via push / CallKit (part of call_service.dart).
part of '../call_service.dart';

extension CallIncoming on CallService {
  Future<void> acceptIncomingCallFromPush({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
    String? sessionKind,
    String? mode,
  }) async {
    debugPrint('[CallService] 📲 acceptIncomingCallFromPush callId=$callId caller=$callerId '
        'sessionKind=$sessionKind mode=$mode roomId=$roomId');

    // Idempotence : double événement CallKit (stream + pending), double clic
    // sur « Accepter », ou repli activeCalls() après un accept déjà dispatché —
    // si cet appel est déjà en cours de réponse, ne pas réarmer l'état (sinon
    // _status repasse à incoming en pleine négociation WebRTC).
    if (callId.isNotEmpty && _currentCallId == callId) {
      final alreadyHandling = _status == CallStatus.connecting ||
          _status == CallStatus.connected ||
          _status == CallStatus.joining ||
          (_status == CallStatus.incoming && _autoAnswerOnNextIncoming);
      if (alreadyHandling) {
        debugPrint('[CallService] 🛡 acceptIncoming ignoré (déjà en cours): $callId');
        return;
      }
    }

    if (callId.isNotEmpty &&
        (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId))) {
      debugPrint('[CallService] 🛡 acceptIncoming ignoré (callId terminé): $callId');
      await _callKit.endAll(callId: callId);
      return;
    }

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    final isConf = isConferenceCallIncoming(
      sessionKind: sessionKind,
      callId: callId,
      roomId: roomId,
    );

    _remoteUserId = int.tryParse(callerId);
    _remoteUserName = callerName;
    _remoteUserPhoto = normalizeBackendUrl(callerPhoto);
    _isVideo = isVideo;
    _adoptServerCallId(callId);
    _autoAnswerOnNextIncoming = true;
    _autoAnswerCallerId = callerId;
    _isAutoAnsweringFromPush = true;
    _clearIncomingPresentation(callId: callId.isNotEmpty ? callId : null);

    // L'acceptation est connue : le filet de 55 s n'a plus lieu d'être. À son
    // expiration il appelle `notifyCallEndedFromExternal` SANS
    // `localOnlyIfIncoming`, donc il *refuse* un appel accepté resté en
    // « entrant » — exactement le sort réservé aux appels de groupe jusqu'ici.
    _cancelIncomingRingSafety();

    final genre = acceptedSessionKind(isConference: isConf, roomId: roomId);

    if (genre == AcceptedSessionKind.groupe) {
      final salon = roomId!.trim();
      _groupRoomId = salon;
      _status = CallStatus.incoming;
      _ensureRemoteIdentityResolved();
      notify();
      debugPrint('[CallService] ⚡ décrochage groupe depuis un push → joinGroupCall');
      await _rejoindreGroupeDepuisPush(salon);
      return;
    }

    if (isConf) {
      final sessionId = (roomId != null && roomId.isNotEmpty)
          ? roomId
          : callId;
      _confSessionId = sessionId;
      _confMode = (mode == 'transfer') ? 'transfer' : 'join';
      _confInvitedBy = GroupParticipantInfo(
        id: callerId,
        name: callerName.isNotEmpty
            ? callerName
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(callerPhoto),
      );
      _status = CallStatus.incoming;
      _ensureRemoteIdentityResolved();
      notify();
      debugPrint('[CallService] ⚡ cold-start conférence → acceptConferenceInvite');
      await acceptConferenceInvite();
      return;
    }

    _status = CallStatus.incoming;
    _ensureRemoteIdentityResolved();
    notify();

    debugPrint('[CallService] !! Status = incoming, auto-answer armé (from push)');

    // Si l'offer est déjà arrivée, répondre immédiatement ; sinon on borne
    // l'attente de l'offre pour ne pas rester figé sur « connexion en cours ».
    if (_pendingOffer != null) {
      debugPrint('[CallService] ⚡ Offer déjà présente → réponse immédiate');
      await answerCall();
    } else if (roomId == null || roomId.isEmpty) {
      // 1-à-1 uniquement : borne l'attente de l'offre (le groupe n'utilise pas
      // _pendingOffer, il ne faut donc pas déclencher un teardown à tort).
      _armAwaitingOfferTimeout();
    }
  }

  /// Adopte un décrochage que le natif a enregistré sans que Flutter le sache.
  ///
  /// Depuis que `MainActivity` lit le décrochage dans son intent de lancement,
  /// l'entrée CallKit passe à « acceptée » de façon synchrone, sans course. Mais
  /// application en arrière-plan, le moteur Flutter est vivant et endormi : au
  /// réveil il reprenait l'entrant — revendiquant la présentation et relançant
  /// sa sonnerie sur un appel que l'utilisateur venait de décrocher.
  ///
  /// À interroger **avant** toute reprise. Rend `true` si l'appel a été adopté,
  /// auquel cas l'appelant n'a plus rien à faire.
  Future<bool> adoptNativeAcceptIfAny() async {
    if (kIsWeb) return false;
    final presentationId = _activeIncomingPresentationCallId;
    final actif = await _callKit.getActiveCall();
    if (!shouldAdoptNativeAccept(
      statusIsIncoming: _status == CallStatus.incoming,
      autoAnsweringFromPush: _isAutoAnsweringFromPush,
      presentationId: presentationId,
      activeCallId: actif?['callId'] as String?,
      activeAccepted: actif?['isAccepted'] == true,
    )) {
      return false;
    }
    debugPrint(
      '[CallService] ⚡ décrochage natif adopté au réveil: $presentationId',
    );
    await acceptIncomingCallFromPush(
      callId: (actif!['callId'] as String?) ?? '',
      callerId: (actif['callerId'] as String?) ?? '',
      callerName: (actif['callerName'] as String?) ?? '',
      callerPhoto: actif['callerPhoto'] as String?,
      isVideo: actif['isVideo'] == true,
      roomId: actif['roomId'] as String?,
      sessionKind: actif['sessionKind'] as String?,
      mode: actif['mode'] as String?,
    );
    return true;
  }

  /// Reprend, au retour au premier plan, un entrant que seule la notification
  /// connaît.
  ///
  /// Moteur vivant mais socket tombé en arrière-plan : le push fait sonner la
  /// notification native sans que Dart n'en sache rien, le statut reste `idle`.
  /// Ouvrir l'application — depuis l'icône, ou depuis la notification d'un appel
  /// vidéo (`IncomingVideoRedirect` côté Android) — montrait alors l'accueil
  /// pendant que la notification sonnait. Le démarrage à froid relit déjà cette
  /// entrée (`main.dart`) ; c'est la même reprise, à chaud.
  ///
  /// Android seulement : sur iOS, l'acceptation dans l'interface CallKit
  /// ramène l'application au premier plan avant que l'entrée ne soit marquée
  /// acceptée, et on retirerait l'appel que l'utilisateur vient de décrocher.
  /// Sur Android, `MainActivity` l'écrit de façon synchrone depuis son intent
  /// (`CallAcceptFromIntent`), avant que ce réveil ne soit livré.
  ///
  /// Rend `true` si un entrant a été préparé.
  Future<bool> adoptNativeIncomingIfAny() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (_status != CallStatus.idle ||
        _isAutoAnsweringFromPush ||
        _autoAnswerOnNextIncoming) {
      return false;
    }
    final actif = await _callKit.getActiveCall();
    if (!shouldAdoptNativeIncoming(
      statusIsIdle: _status == CallStatus.idle,
      autoAnswering: _isAutoAnsweringFromPush || _autoAnswerOnNextIncoming,
      activeCallId: actif?['callId'] as String?,
      activeAccepted: actif?['isAccepted'] == true,
      activeOutgoing: actif?['isOutgoing'] == true,
    )) {
      return false;
    }
    final callId = ((actif!['callId'] as String?) ?? '').trim();
    final callerId = (actif['callerId'] as String?) ?? '';
    final callerName = (actif['callerName'] as String?) ?? '';
    final roomId = actif['roomId'] as String?;
    // Vérifié AVANT : la reprise au premier plan retire d'abord la
    // notification, et un appel qu'on ne pourrait pas présenter serait perdu.
    if (!await canPrepareIncomingFromCallKit(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      roomId: roomId,
    )) {
      return false;
    }
    debugPrint('[CallService] 📲 entrant natif repris au réveil: $callId');
    await handleIncomingCallKitPreview(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: actif['callerPhoto'] as String?,
      isVideo: actif['isVideo'] == true,
      roomId: roomId,
      sessionKind: actif['sessionKind'] as String?,
      mode: actif['mode'] as String?,
    );
    return _status == CallStatus.incoming;
  }

  /// Rejoint un appel de groupe accepté depuis une notification.
  ///
  /// `joinGroupCall` n'avait qu'un appelant dans toute l'application — le bouton
  /// de l'écran entrant. Décrocher depuis la notification ne menait donc nulle
  /// part : l'appel restait « entrant » jusqu'au refus du filet de sécurité.
  ///
  /// L'identité locale est posée par le fournisseur au démarrage
  /// (`setLocalIdentity`). Si elle manque — session pas encore restaurée —, on
  /// ne peut pas rejoindre : on laisse alors l'entrant se présenter et
  /// l'utilisateur reprend la main, plutôt que d'attendre en silence.
  Future<void> _rejoindreGroupeDepuisPush(String roomId) async {
    final moi = _localUserId;
    if (moi == null) {
      debugPrint(
        '[CallService] ** identité locale absente → décrochage groupe différé',
      );
      _isAutoAnsweringFromPush = false;
      _autoAnswerOnNextIncoming = false;
      _armIncomingRingSafety();
      notify();
      return;
    }

    // L'entrée CallKit de l'invitation porte le salon ; `joinGroupCall` en
    // ouvrira une autre sous `group_$roomId`. Retirer la première, sinon deux
    // entrées coexistent pour un seul appel.
    await _callKit.endAll(callId: roomId);
    await _ringtone.stop();

    final invitant = _remoteUserId == null
        ? null
        : GroupParticipantInfo(
            id: _remoteUserId.toString(),
            name: (_remoteUserName?.isNotEmpty == true)
                ? _remoteUserName!
                : LocaleController.instance.l10n.participantFallback,
            photo: _remoteUserPhoto,
          );

    await joinGroupCall(
      roomId: roomId,
      myId: moi,
      myName: _localUserName,
      myPhoto: _localUserPhoto,
      isVideo: _isVideo,
      callerInfo: invitant,
    );
  }

  /// Vérifie qu'une notification d'appel entrant peut préparer l'écran entrant.
  Future<bool> canPrepareIncomingFromCallKit({
    required String callId,
    required String callerId,
    required String callerName,
    String? roomId,
  }) async {
    if (_status != CallStatus.idle) return false;
    if (callId.isEmpty || callId.startsWith('meeting_')) return false;
    if (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId)) {
      return false;
    }
    final isGroupCall = roomId != null && roomId.isNotEmpty;
    final parsedCallerId = int.tryParse(callerId);
    if (!isGroupCall && parsedCallerId == null) return false;
    if (callerName.trim().isEmpty && parsedCallerId == null) return false;
    return true;
  }

  /// Prépare l'état d'appel entrant à partir d'un appel CallKit encore actif,
  /// SANS armer l'auto-réponse. Utilisé au démarrage à froid quand l'utilisateur
  /// a tapé le corps de la notif (pas le bouton « Accepter ») : on affiche l'écran
  /// d'appel entrant qui sonne et l'utilisateur décroche manuellement.
  void prepareIncomingFromCallKit({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
    String? sessionKind,
    String? mode,
  }) {
    unawaited(_prepareIncomingFromCallKitAsync(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      isVideo: isVideo,
      roomId: roomId,
      sessionKind: sessionKind,
      mode: mode,
    ));
  }

  Future<void> _prepareIncomingFromCallKitAsync({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
    String? sessionKind,
    String? mode,
  }) async {
    if (!await canPrepareIncomingFromCallKit(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      roomId: roomId,
    )) {
      if (callId.isNotEmpty) {
        if (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId)) {
          debugPrint('[CallService] 🛡 ignore CallKit terminé: $callId');
        } else {
          debugPrint('[CallService] 🛡 ignore incoming CallKit invalide: callerId=$callerId');
        }
        await _callKit.endAll(callId: callId);
      }
      return;
    }
    if (_status != CallStatus.idle) return;

    final parsedCallerId = int.tryParse(callerId);

    debugPrint('[CallService] 📲 prepareIncomingFromCallKit callId=$callId caller=$callerId '
        'sessionKind=$sessionKind');

    _remoteUserId = parsedCallerId;
    _remoteUserName = callerName;
    _remoteUserPhoto = normalizeBackendUrl(callerPhoto);
    _isVideo = isVideo;
    _adoptServerCallId(callId);

    final isConf = isConferenceCallIncoming(
      sessionKind: sessionKind,
      callId: callId,
      roomId: roomId,
    );
    if (isConf) {
      final sessionId =
          (roomId != null && roomId.isNotEmpty) ? roomId : callId;
      _confSessionId = sessionId;
      _confMode = (mode == 'transfer') ? 'transfer' : 'join';
      _groupRoomId = sessionId;
      _confInvitedBy = GroupParticipantInfo(
        id: callerId,
        name: callerName.isNotEmpty
            ? callerName
            : LocaleController.instance.l10n.participantFallback,
        photo: normalizeBackendUrl(callerPhoto),
      );
    } else {
      _groupRoomId = (roomId != null && roomId.isNotEmpty) ? roomId : null;
    }

    _status = CallStatus.incoming;
    _ensureRemoteIdentityResolved();
    // Ce chemin n'existe que parce que CallKit a une entrée : c'est lui qui
    // possède l'entrant, sauf si l'application est au premier plan. On le lui
    // dit explicitement plutôt que de s'en remettre au cache — au démarrage à
    // froid, `main.dart` vient tout juste de lire cette entrée.
    final presentationId = callId.isNotEmpty ? callId : (_groupRoomId ?? '');
    final action = _resolveIncomingPresentation(
      callId: presentationId,
      intent: IncomingPresentationIntent.prepareFromCallKit,
      callKitActive: true,
    );
    // Flutter présente : retirer la notification et sonner nous-mêmes, comme
    // les chemins socket. Sans quoi l'écran Flutter s'affichait muet sous une
    // notification qui sonnait encore, jusqu'à ce que l'accueil fasse la
    // bascule — s'il la faisait.
    //
    // Android seulement : `MainActivity` y écrit un décrochage de façon
    // synchrone avant que Dart ne lise l'entrée, donc une entrée non acceptée
    // ici l'est vraiment. Sur iOS, CallKit peut ouvrir l'application avant de
    // la marquer acceptée ; la retirer couperait l'appel décroché. Là-bas,
    // l'accueil garde la main (`adoptNativeAcceptIfAny` puis la bascule).
    if (action == IncomingPresentationAction.showFlutterIncoming &&
        !kIsWeb &&
        Platform.isAndroid) {
      _startFlutterIncomingRinging(presentationId);
    }
    // Même règle que sur les chemins socket : jamais de statut « entrant »
    // sans horloge locale pour le débloquer.
    _armIncomingRingSafety();
    notify();
    // Filet anti-fantôme (1-à-1) : si l'offre WebRTC de confirmation n'arrive
    // jamais via le socket, on démonte au lieu de laisser un écran d'appel entrant
    // pour un appel déjà terminé (ex. appelant a raccroché, app tuée → « Inconnu »).
    if (_groupRoomId == null && !isConf) {
      _armAwaitingOfferTimeout();
    }
  }

  /// Synchronise l'état Flutter quand CallKit/PushKit affiche un entrant
  /// (app au premier plan ou réveil) avant l'arrivée du socket WebRTC.
  Future<void> handleIncomingCallKitPreview({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
    String? sessionKind,
    String? mode,
  }) async {
    // L'aperçu de l'appel qu'on est en train de mener n'est pas un autre appel.
    //
    // Le plugin le réaffiche dans des cas ordinaires, et la suite de cette
    // méthode le traitait alors comme un intrus : « occupé », donc on ferme.
    // Fermer marque l'appel terminé, fait émettre un refus par le plugin, et le
    // décrochage en cours est perdu des deux côtés. Voir
    // `previewTargetsCurrentCall`.
    if (previewTargetsCurrentCall(
      previewCallId: callId,
      callStatusName: _status.name,
      currentCallId: _currentCallId,
      callKitCallId: _callKitCallId,
      groupRoomId: _groupRoomId,
      confSessionId: _confSessionId,
    )) {
      debugPrint(
        '[CallService] 🛡 aperçu CallKit de l\'appel courant ignoré: $callId',
      );
      return;
    }

    if (callId.isNotEmpty &&
        (_isTerminalCallId(callId) || await EndedCallRegistry.isEnded(callId))) {
      debugPrint(
        '[CallService] 🛡 PushKit preview ignoré (callId terminé): $callId',
      );
      await _callKit.endAll(callId: callId);
      return;
    }

    // Premier plan : Flutter gère l'UI — retirer CallKit sans refuser l'appel.
    if (_isAppForeground) {
      await _dismissStrayIncomingCallKit(callId);
      if (_status == CallStatus.incoming &&
          (_currentCallId == null || _currentCallId == callId)) {
        debugPrint('[CallService] preview ignoré (déjà entrant via socket): $callId');
        return;
      }
      if (_status != CallStatus.idle) {
        debugPrint('[CallService] 🛡 preview foreground refusé (occupé): $callId');
        return;
      }
      if (!await canPrepareIncomingFromCallKit(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        roomId: roomId,
      )) {
        return;
      }
      if (!_apiClient.isSocketConnected) {
        _apiClient.connectSocket();
      }
      debugPrint('[CallService] preview foreground → préparer avant socket: $callId');
      await _prepareIncomingFromCallKitAsync(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideo: isVideo,
        roomId: roomId,
        sessionKind: sessionKind,
        mode: mode,
      );
      return;
    }

    if (!await canPrepareIncomingFromCallKit(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      roomId: roomId,
    )) {
      debugPrint(
        '[CallService] 🛡 PushKit preview refusé (occupé ou invalide): $callId',
      );
      await _callKit.endAll(callId: callId);
      return;
    }

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    await _prepareIncomingFromCallKitAsync(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      isVideo: isVideo,
      roomId: roomId,
      sessionKind: sessionKind,
      mode: mode,
    );
  }

  /// Appelée depuis main.dart quand l'utilisateur refuse un appel via CallKit.
  ///
  /// On coupe immédiatement CallKit + sonnerie, on mémorise le callId comme
  /// terminal, on persiste le refus, puis on tente HTTP (prioritaire, marche
  /// sans socket) et socket en secours. Le flush à `auth:verified` / bootstrap
  /// rejoue ce qui n'a pas encore abouti.
  Future<void> rejectIncomingCallFromPush({
    required String callerId,
    String? callId,
    bool isConference = false,
  }) async {
    debugPrint('[CallService] 📲 rejectIncomingCallFromPush caller=$callerId '
        'callId=$callId conf=$isConference');

    final resolvedCallId = callId ?? _currentCallId;
    final conf = isConference ||
        _confSessionId != null ||
        (resolvedCallId != null && resolvedCallId.startsWith('conf_'));

    _markTerminalCallId(resolvedCallId);
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    _isAutoAnsweringFromPush = false;
    _pendingConfJoinSessionId = null;

    await _ringtone.stop();
    await _callKit.endAll(callId: resolvedCallId);

    if (conf) {
      if (_confSessionId == null && resolvedCallId != null) {
        _confSessionId = resolvedCallId;
      }
      _apiClient.sendSocketEvent(SocketEvents.callConfReject, {});
      await _terminateConference();
      return;
    }

    // Un salon de groupe n'est pas un appel à deux : le poster faisait
    // réécrire par le serveur le dernier appel à deux entre les mêmes
    // personnes. Voir `shouldPostRejectToServer` — le refus d'un groupe est
    // purement local, comme `rejectGroupCall` le documente depuis toujours.
    if (!shouldPostRejectToServer(resolvedCallId)) {
      debugPrint(
        '[CallService] refus local (pas un appel à deux): $resolvedCallId',
      );
      await _terminateCall();
      return;
    }

    final cid = int.tryParse(callerId);
    if (cid != null) {
      await PendingCallRejectStore.enqueue(
        callerId: callerId,
        callId: resolvedCallId,
      );
      unawaited(_deliverReject(
        callerId: callerId,
        callerIdInt: cid,
        callId: resolvedCallId,
      ));
    }

    if (_status == CallStatus.incoming ||
        _status == CallStatus.outgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.connected) {
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Dispatch centralisé des actions CallKit (accept / decline / ended).
  Future<void> handleCallKitAction(IncomingCallAction action) async {
    switch (action.action) {
      case IncomingCallActionType.incomingPreview:
        await handleIncomingCallKitPreview(
          callId: action.callId,
          callerId: action.callerId,
          callerName: action.callerName,
          callerPhoto: action.callerPhoto,
          isVideo: action.isVideo,
          roomId: action.roomId,
          sessionKind: action.sessionKind,
          mode: action.mode,
        );
        break;
      case IncomingCallActionType.accept:
        await acceptIncomingCallFromPush(
          callId: action.callId,
          callerId: action.callerId,
          callerName: action.callerName,
          callerPhoto: action.callerPhoto,
          isVideo: action.isVideo,
          roomId: action.roomId,
          sessionKind: action.sessionKind,
          mode: action.mode,
        );
        break;
      // Refus explicite et sonnerie expirée arrivent tous deux ici. Seul le
      // premier se signale au serveur — voir `reportForTerminalAction`.
      case IncomingCallActionType.decline:
      case IncomingCallActionType.timeout:
        if (reportForTerminalAction(action.action.name) ==
            TerminalCallReport.refus) {
          await rejectIncomingCallFromPush(
            callerId: action.callerId,
            callId: action.callId,
            isConference: action.isConference,
          );
        } else {
          await notifyCallEndedFromExternal(
            callId: action.callId,
            callerId: action.callerId,
            localOnlyIfIncoming: true,
          );
        }
        break;
      case IncomingCallActionType.ended:
        // Dismiss OS / nettoyage local — ne pas reject_call (autre device peut
        // encore sonner ou avoir déjà décroché).
        await notifyCallEndedFromExternal(
          callId: action.callId,
          callerId: action.callerId,
          localOnlyIfIncoming: true,
        );
        break;
    }
  }

  /// Fermeture UI + teardown quand l'appel se termine depuis CallKit, FCM
  /// `call_ended` ou le listener natif ACTIVE_CALLS.
  Future<void> notifyCallEndedFromExternal({
    String? callId,
    String? callerId,
    bool localOnlyIfIncoming = false,
  }) async {
    final id = (callId ?? '').trim();
    debugPrint(
      '[CallService] notifyCallEndedFromExternal callId=$id status=$_status '
      'localOnlyIfIncoming=$localOnlyIfIncoming',
    );

    if (id.isNotEmpty) {
      await EndedCallRegistry.markEnded(id);
    }

    // Écho de l'abandon d'un sortant croisé (voir `_abandonnerSortantCroise`) :
    // cet appel-là est déjà démonté, et l'appel en cours est l'entrant adopté.
    if (id.isNotEmpty && _sortantsAbandonnes.remove(id)) {
      debugPrint(
        '[CallService] 🛡 fin de l’appel sortant abandonné ($id) ignorée',
      );
      return;
    }

    // Hangup local déjà en cours (CallKit `ended` pendant endAll) : ne pas
    // réémettre end_call — en conf ça coupait à tort l'inviteur via le
    // fallback 1-à-1 serveur.
    if (_isEndingCall || _callEndedByUs) {
      debugPrint(
        '[CallService] notifyCallEndedFromExternal: fin locale déjà en cours',
      );
      return;
    }

    // `reconnecting` compte comme un appel vivant : sans lui, un `call_ended`
    // FCM reçu pendant une reconnexion tombait dans la branche générique, qui
    // remet l'état à zéro sans libérer le micro, la caméra ni la session.
    if (_status == CallStatus.outgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.connected ||
        _status == CallStatus.reconnecting) {
      // `id` peut venir du serveur (FCM call_ended) comme de CallKit : sur un
      // appel sortant ce sont deux identifiants différents.
      // Troisième terme : sortant dont le serveur n'a pas encore annoncé
      // l'identifiant — ni `_currentCallId` ni `_callKitCallId` ne peuvent
      // désigner l'appel 2169 dont parle le push, et le refus de l'appelé
      // n'arrivait donc jamais jusqu'au teardown.
      if (id.isEmpty ||
          _matchesCurrentCallId(id) ||
          acceptsOutgoingTerminalEvent(
            callStatusName: _status.name,
            eventCallId: id,
            currentCallId: _currentCallId,
            currentCallIdIsLocal: !_serverCallIdKnown,
          )) {
        await endCall();
        return;
      }
      // Un `call_ended` qui désigne un AUTRE appel ne touche pas à celui-ci.
      //
      // Il tombait jusqu'ici dans un teardown complet : un push en retard —
      // celui de l'appel précédent, que le serveur envoie sans priorité et avec
      // une validité de 24 h — raccrochait la communication en cours. Même
      // famille que `call_ended` de groupe et `meeting:ended`, qui ont leur
      // garde depuis l'audit ; ce point d'entrée-là avait été manqué.
      //
      // On le marque terminal quand même : c'est ce qui empêche son écran
      // fantôme de se rouvrir, et c'est tout ce qu'il y a à en faire.
      debugPrint(
        '[CallService] 🛡 call_ended ignoré: $id ne désigne pas l\'appel en cours',
      );
      _markOneTerminalCallId(id);
      await _callKit.endAll(callId: id);
      return;
    }

    if (_status == CallStatus.incoming) {
      if (localOnlyIfIncoming) {
        _markTerminalCallId(id.isNotEmpty ? id : _currentCallId);
        await _ringtone.stop();
        await _callKit.endAll(callId: id.isNotEmpty ? id : _currentCallId);
        await _terminateCall();
        return;
      }
      await rejectIncomingCallFromPush(
        callerId: callerId ?? _remoteUserId?.toString() ?? '',
        callId: id.isNotEmpty ? id : _currentCallId,
      );
      return;
    }

    if (id.isNotEmpty) _markTerminalCallId(id);
    await _ringtone.stop();
    await _callKit.endAll(callId: id.isNotEmpty ? id : null);
    if (_status != CallStatus.idle) {
      _resetCallState();
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Au resume : si FCM a marqué l'appel terminé pendant que l'UI était ouverte.
  Future<void> syncWithEndedRegistry() async {
    final id = _currentCallId;
    if (id == null || id.isEmpty) return;
    if (_status == CallStatus.idle || _status == CallStatus.ended) return;
    if (!await EndedCallRegistry.isEnded(id)) return;
    debugPrint('[CallService] syncWithEndedRegistry → terminate $id');
    await notifyCallEndedFromExternal(callId: id);
  }

  /// Envoie le refus via HTTP puis socket. Retire de la file si au moins
  /// un canal a réussi.
  Future<void> _deliverReject({
    required String callerId,
    required int callerIdInt,
    String? callId,
  }) async {
    var delivered = false;

    try {
      await _apiClient.rejectCallHttp(callerId: callerIdInt, callId: callId);
      delivered = true;
      debugPrint('[CallService] !! reject HTTP ok caller=$callerIdInt');
    } catch (e) {
      debugPrint('[CallService] reject HTTP error: $e');
    }

    if (_apiClient.isSocketReady) {
      try {
        _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
          'callerId': callerIdInt,
          if (callId != null && callId.isNotEmpty) 'callId': callId,
        });
        delivered = true;
      } catch (e) {
        debugPrint('[CallService] rejectCall socket error: $e');
      }
    } else if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    if (delivered) {
      await PendingCallRejectStore.remove(callerId: callerId, callId: callId);
    }
  }

  /// Rejoue les refus persistés (mémoire disque + éventuel enqueue natif).
  /// Appelé depuis `auth:verified` et au bootstrap AuthWrapper.
  Future<void> flushPendingRejects() async {
    final pending = await PendingCallRejectStore.list();
    if (pending.isEmpty) return;
    debugPrint('[CallService] 🔁 flushPendingRejects count=${pending.length}');
    for (final item in pending) {
      final callerId = item['callerId'] ?? '';
      final callId = item['callId'];
      final cid = int.tryParse(callerId);
      if (cid == null) {
        await PendingCallRejectStore.remove(callerId: callerId, callId: callId);
        continue;
      }
      await _deliverReject(
        callerId: callerId,
        callerIdInt: cid,
        callId: callId,
      );
    }
  }

  /// Alias privé pour les listeners socket.
  void _flushPendingRejects() {
    unawaited(flushPendingRejects());
  }

  /// Rejoue les end_call mis en file quand le socket n'était pas prêt.
  void _flushPendingEndCalls() {
    if (_pendingEndCalls.isEmpty) return;
    if (!_apiClient.isSocketReady) return;
    final pending = List<Map<String, dynamic>>.from(_pendingEndCalls);
    _pendingEndCalls.clear();
    for (final payload in pending) {
      debugPrint('[CallService] 🔁 Rejeu end_call en file → $payload');
      // Accusé ici aussi : un rejeu perdu se perd définitivement, puisque
      // c'est déjà le filet. Sans accusé il repartait sur le socket fraîchement
      // authentifié en espérant qu'il tienne.
      unawaited(
        _apiClient
            .sendSocketEventAcked(SocketEvents.endCall, payload)
            .then((accuse) {
          if (accuse) return;
          debugPrint('[CallService] rejeu end_call sans accusé → remis en file');
          _pendingEndCalls.add(payload);
        }).catchError((e) {
          debugPrint('[CallService] rejeu end_call échoué: $e');
          _pendingEndCalls.add(payload);
        }),
      );
    }
  }
}
