// Gestion session audio / foreground service pendant appels (part of call_service.dart).
part of '../call_service.dart';

extension CallSession on CallService {
  /// Identifiant présenté à CallKit, fabriqué si le serveur n'a pas encore
  /// donné le sien. Il est mémorisé à part : `_currentCallId` adoptera
  /// l'identifiant serveur au décrochage, alors que CallKit gardera celui-ci.
  String _ensureCallId() {
    if (_currentCallId == null || _currentCallId!.isEmpty) {
      _currentCallId = '${DateTime.now().millisecondsSinceEpoch}';
      // Fabriqué, donc inconnu du serveur : tant qu'il n'aura pas annoncé le
      // sien, les gardes de callId n'ont rien à comparer.
      _serverCallIdKnown = false;
    }
    _callKitCallId = _currentCallId;
    return _currentCallId!;
  }

  Future<void> _acquireCallSession({
    required bool isVideo,
    required String displayName,
    required String handle,
    bool startCallKit = true,
  }) async {
    if (kIsWeb) return;
    // Retenu avant `_ensureCallId`, qui va le réécrire : sur un refus, c'est le
    // seul moyen de retrouver sous quel identifiant la session est tenue.
    final tenuAvant = _callKitCallId;
    final callId = _ensureCallId();
    final pris = await CallSessionGuard.instance.acquire(
      mode: isVideo ? SessionMode.video : SessionMode.audio,
      callId: callId,
      displayName: displayName,
      handle: handle,
      isVideo: isVideo,
      startCallKit: startCallKit,
      getLocalStream: () => _webrtc.localStream,
      isVideoOn: () => _isVideoOn,
      isMuted: () => _isMuted,
      onReplaceAudioNeeded: () async {
        await _webrtc.replaceAudioTrack(
          keepMuted: _isMuted,
          type: _isVideo ? CallType.video : CallType.audio,
        );
      },
      // « Raccrocher » depuis la notification doit solder l'appel comme le
      // bouton de l'écran : prévenir le pair, puis démonter.
      onHangUp: () => endCall(),
    );
    if (!pris) {
      // Une autre session tient déjà le garde. On ne lie pas les rendus et on
      // ne réclame pas le mode image dans l'image : ils appartiennent à l'autre.
      //
      // Mais `_ensureCallId` a déjà réécrit `_callKitCallId`, et le laisser sur
      // un identifiant que le garde ne connaît pas orphelinerait la session.
      // C'est le cas d'un appel à deux converti en appel à trois : le garde tient
      // l'appel d'origine, `acceptConferenceInvite` réclame la session sous
      // l'identifiant de la conférence et se la voit refuser. `_releaseCallSession`
      // demandait ensuite de rendre cet identifiant-là, ne le reconnaissait pas et
      // repartait sans rien rendre — service au premier plan, wakelock, entrée
      // CallKit et éligibilité au Picture-in-Picture survivaient à l'appel, si
      // bien que quitter l'application ouvrait ensuite une vignette vide.
      _callKitCallId = tenuAvant;
      debugPrint('[CallService] ⛔ session média refusée pour $callId');
      return;
    }

    await _bindSessionRenderers();
    // L'éligibilité au PiP se déclare à l'ouverture, pas au moment de sortir :
    // Android n'accepte l'entrée que depuis `onUserLeaveHint`, quand il est
    // trop tard pour poser la question.
    await SystemPip.instance.setEligible(isVideo);
  }

  /// Ouvre les rendus vidéo pour la durée de la session.
  ///
  /// Ils appartenaient à l'écran plein, qui les créait à l'ouverture et les
  /// libérait à la fermeture. La fenêtre flottante doit continuer à montrer
  /// l'appel une fois l'écran quitté : la propriété remonte donc ici, aux
  /// bornes de la session.
  Future<void> _bindSessionRenderers() async {
    if (!isVideo) return;
    final renderers = SessionVideoRenderers.instance;
    await renderers.ensureInitialized();
    renderers.bind(this, () {
      renderers.syncMain(
        localStream: localStream,
        remoteStream: activeRemoteStream,
      );
      unawaited(renderers.syncGroup(groupRemoteStreams));
    });
  }

  Future<void> _markCallSessionConnected() async {
    if (kIsWeb) return;
    await CallSessionGuard.instance.markConnected();
    // `_initAudioRoute` a choisi la sortie d'ouverture avant que Telecom ne
    // tienne l'appel : cette première demande est partie dans le vide, on la
    // repose ici.
    final parTelecom = await _demanderRoute(_audioRoute);
    unawaited(_tenirRouteAudio(demandeDejaPrise: parTelecom));
  }

  /// Amène Telecom sur la sortie voulue, puis aligne l'interface sur ce qu'il
  /// fait vraiment.
  ///
  /// Quand on décroche, la connexion Telecom naît après la demande ci-dessus,
  /// et il prend l'écouteur par défaut. Mesuré sur un Xiaomi sous Android 16 :
  /// appel vidéo reçu avec l'icône sur le haut-parleur et le son à l'écouteur,
  /// c'est-à-dire très faible, et deux appuis pour s'en sortir.
  Future<void> _tenirRouteAudio({required bool demandeDejaPrise}) async {
    final callId = _callKitCallId;
    final voulue = _audioRoute;
    final jeton = ++_demandesDeRoute;
    bool valable() => _callKitCallId == callId && _demandesDeRoute == jeton;
    try {
      if (!demandeDejaPrise) {
        final prete = await audio.AudioHelper.waitForTelecomConnection(callId);
        if (!prete || !valable()) return;
        debugPrint('[CallService] 🔊 Telecom prêt, sortie redemandée');
        await _demanderRoute(voulue);
        if (!valable()) return;
      }
      final reelle = await convergerRouteTelecom(
        voulue: voulue,
        redemander: () => _demanderRoute(voulue),
        lire: () async => routeFromTelecomName(
          (await audio.AudioHelper.readAppliedRoute(callId))?.routeName,
        ),
        valable: valable,
      );
      if (reelle == null) return;
      debugPrint('[CallService] 🔊 Sortie tenue par Telecom: ${reelle.name}');
      if (reelle == _audioRoute) return;
      _retenirRoute(reelle);
      await CallSessionGuard.instance.updateAudioRoute(reelle);
      notify();
    } catch (e) {
      debugPrint('[CallService] ** suivi de la sortie audio: $e');
    }
  }

  Future<void> _releaseCallSession() async {
    if (kIsWeb) return;
    // La fenêtre flottante et les rendus vidéo appartiennent à celui qui tient
    // la session : les libérer depuis un appel dont l'acquisition avait été
    // REFUSÉE viderait l'écran de la réunion toujours en cours. On demande donc
    // d'abord si la session est bien la nôtre.
    final aNous = CallSessionGuard.instance.holdsSession(_callKitCallId);
    if (!aNous) {
      debugPrint(
        '[CallService] session média non tenue par $_callKitCallId — '
        'rien à rendre',
      );
      return;
    }
    // Avant le garde : la fenêtre flottante disparaît avec la session, et rien
    // ne doit rester branché sur des rendus en cours de libération.
    await SystemPip.instance.reset();
    await SessionVideoRenderers.instance.release();
    await CallSessionGuard.instance.release(callId: _callKitCallId);
  }
}
