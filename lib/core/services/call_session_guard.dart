import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme/locale_controller.dart';
import 'audio_helper.dart';
import 'call/background_media_rules.dart';
import 'call/call_audio_routes.dart';
import 'call/call_notification_content.dart';
import 'call/session_video_renderers.dart';
import 'callkit_service.dart';
import 'lock_screen_policy.dart';

enum SessionMode { audio, video }

/// Ce que vaut une acquisition de la session média.
enum SessionAcquisition {
  /// Personne ne tenait la session : on la configure.
  fraiche,

  /// Le même appel la tient déjà — imbrication légitime, on compte.
  imbriquee,

  /// Un AUTRE appel la tient. On ne compte pas, et on le dit.
  conflit,
}

/// Faut-il rendre la session média à la demande de [releasedBy] ?
///
/// `acquire` refuse déjà proprement un conflit, sans compter — mais `release`
/// décrémentait aveuglément. Une session dont l'acquisition avait été REFUSÉE
/// faisait donc quand même tomber le compteur à zéro en se retirant, et
/// démontait celle du voisin : service au premier plan arrêté, focus audio
/// rendu, entrée CallKit fermée, verrou de veille et capteur de proximité
/// relâchés — sur un appel, ou une réunion, toujours en cours.
///
/// Le chemin est celui qu'`acquire` documente déjà : rejoindre une réunion
/// pendant un appel, ou décrocher un appel pendant une réunion. La correction
/// d'`acquire` était donc à moitié faite ; c'est l'autre moitié.
///
/// Un appelant qui ne sait pas s'identifier garde l'ancien comportement : on ne
/// peut pas lui refuser ce qu'on ne sait pas attribuer.
bool shouldReleaseSession({
  required int refCount,
  required String? heldBy,
  required String? releasedBy,
}) {
  if (refCount <= 0) return false;
  final rendeur = releasedBy?.trim() ?? '';
  final tenant = heldBy?.trim() ?? '';
  if (rendeur.isEmpty || tenant.isEmpty) return true;
  return rendeur == tenant;
}

/// Décide du sort d'un `acquire`, sans rien toucher.
///
/// Extraite parce que la version précédente incrémentait le compteur dans les
/// trois cas puis sortait sans rien configurer dans les deux derniers : le
/// `release()` d'en face ne redescendait alors jamais à zéro, et le verrou de
/// veille, le capteur de proximité, le service au premier plan, le focus audio
/// et l'entrée CallKit restaient tenus indéfiniment.
SessionAcquisition classerAcquisition({
  required int refCount,
  required String? tenuPar,
  required String callId,
}) {
  if (refCount <= 0) return SessionAcquisition.fraiche;
  if (tenuPar == callId) return SessionAcquisition.imbriquee;
  return SessionAcquisition.conflit;
}

/// Maintient micro + foreground service actifs pendant appels/réunions (Android).
/// Vidéo : wakelock écran + pause caméra en veille.
///
/// En pause/inactive : réactive la track audio existante — **jamais** getUserMedia.
/// Si la track est morte au resume : callback optionnel [onReplaceAudioNeeded].
class CallSessionGuard with WidgetsBindingObserver {
  CallSessionGuard._();
  static final CallSessionGuard instance = CallSessionGuard._();

  static const _callMediaChannel =
      MethodChannel('com.alanya237.alanya/call_media');
  static const _proximityChannel =
      MethodChannel('com.alanya237.alanya/proximity');

  int _refCount = 0;
  SessionMode? _mode;
  String? _callId;
  bool _wakelockEnabled = false;
  bool _proximityEnabled = false;

  /// Dernière sortie audio connue, tenue à jour même hors session.
  ///
  /// `_initAudioRoute` choisit la sortie AVANT que la session ne soit acquise :
  /// sans mémoire, la première route serait perdue et l'écran ne s'éteindrait
  /// qu'au premier changement manuel.
  CallAudioRoute _route = CallAudioRoute.earpiece;
  bool _videoPausedByLifecycle = false;
  bool _audioTrackEnded = false;

  /// Qui est au bout, tel qu'affiché dans la notification de l'appel.
  ///
  /// Retenu parce que [markConnected] réécrit cette notification pour y lancer
  /// le chronomètre, et ne reçoit pas de quoi la reconstruire.
  String _displayName = '';

  /// Ce que doit faire le bouton « Raccrocher » de la notification.
  ///
  /// Il appartient à qui tient la session — `endCall` pour un appel,
  /// `leaveMeeting` pour une réunion — et le garde ne doit pas le deviner :
  /// terminer un appel pendant une réunion ne fermerait rien et laisserait la
  /// réunion sans service au premier plan.
  Future<void> Function()? _onHangUp;
  bool _nativeBound = false;
  bool _mediaFgsStarted = false;

  /// Instant de connexion de l'appel, en millisecondes epoch.
  ///
  /// Retenu parce que relancer le service réécrit sa notification : sans lui,
  /// chaque relance remettrait le chronomètre à zéro et l'appel paraîtrait
  /// recommencer.
  int _startedAtMs = 0;

  /// Le Picture-in-Picture système est ouvert (renseigné par le pont natif).
  ///
  /// Indispensable, et pas seulement informatif : en PiP Android, l'activité
  /// est en pause tout en restant visible, donc le seul cycle de vie ne suffit
  /// pas à décider du sort de la caméra.
  bool _systemPipActive = false;

  /// Dernier état connu du cycle de vie. Mémorisé parce que la décision sur la
  /// caméra se rejoue aussi à l'ouverture et à la fermeture du PiP, en dehors
  /// de tout changement de cycle de vie.
  bool _appBackgrounded = false;

  /// Le service au premier plan porte-t-il le type `microphone` ?
  ///
  /// C'est ce type, et lui seul, qui donne le droit de capturer quand Alanya
  /// n'est plus à l'écran. Renseigné par le natif après chaque
  /// `startForeground` — voir `CallMediaBridge.notifyMediaTypes`. Faux par
  /// défaut : tant que rien n'a confirmé la capture, on ne la suppose pas.
  bool _micFgsCovered = false;
  bool _cameraFgsCovered = false;

  /// True quand la plateforme autorise la capture caméra en arrière-plan.
  ///
  /// Android l'accorde au seul service de premier plan de type `camera` — d'où
  /// la lecture du type réellement obtenu, et non du simple fait qu'un service
  /// tourne : il a longtemps tourné en `phoneCall`, qui ne donne ni la caméra
  /// ni le micro. iOS le refuse tant que `multitasking-camera-access` n'est pas
  /// accordée, et n'a pas de service de premier plan pour le dire.
  bool get _cameraAllowedInBackground => _isAndroid && _cameraFgsCovered;

  MediaStream? Function()? _getLocalStream;
  bool Function()? _isVideoOn;
  bool Function()? _isMuted;
  Future<void> Function()? _onReplaceAudioNeeded;

  bool get isActive => _refCount > 0;

  /// Prend la session média, et **dit si elle est bien à cet appel-ci**.
  ///
  /// Le compteur de références sert à imbriquer plusieurs acquisitions du MÊME
  /// appel — `answerCall` après `acceptIncomingCallFromPush`, par exemple. Il
  /// incrémentait aussi pour un `callId` DIFFÉRENT, en sortant aussitôt sans
  /// rien configurer : `_callId` et le mode restaient ceux de la session
  /// précédente, et le `release()` d'en face ne pouvait plus redescendre à zéro.
  ///
  /// Le chemin est banal — rejoindre une réunion pendant un appel. La réunion
  /// n'obtenait aucune entrée CallKit, celle de l'appel était marquée
  /// « connectée », et à la fin de l'appel la notification restait affichée,
  /// chronomètre en marche, pour toute la durée de la réunion. Avec elle : le
  /// verrou de veille, le capteur de proximité, le service au premier plan et
  /// le focus audio, tous jamais rendus.
  ///
  /// Un conflit ne compte donc plus, et se voit.
  Future<bool> acquire({
    required SessionMode mode,
    required String callId,
    required String displayName,
    required String handle,
    required bool isVideo,
    bool startCallKit = true,
    MediaStream? Function()? getLocalStream,
    bool Function()? isVideoOn,
    bool Function()? isMuted,
    Future<void> Function()? onReplaceAudioNeeded,
    Future<void> Function()? onHangUp,
  }) async {
    // Le web n'a ni service au premier plan ni CallKit : rien à tenir, et donc
    // aucun échec à signaler.
    if (kIsWeb) return true;

    switch (classerAcquisition(
      refCount: _refCount,
      tenuPar: _callId,
      callId: callId,
    )) {
      case SessionAcquisition.imbriquee:
        _refCount++;
        debugPrint(
          '[CallSessionGuard] Déjà actif pour cet appel (ref=$_refCount)',
        );
        return true;
      case SessionAcquisition.conflit:
        debugPrint(
          '[CallSessionGuard] ⛔ conflit : session tenue par $_callId, '
          'refus de $callId — le compteur ne bouge pas',
        );
        return false;
      case SessionAcquisition.fraiche:
        break;
    }

    _refCount++;
    LockScreenPolicy.setSessionHeld(true);

    _mode = mode;
    _callId = callId;
    _getLocalStream = getLocalStream;
    _isVideoOn = isVideoOn;
    _isMuted = isMuted;
    _onReplaceAudioNeeded = onReplaceAudioNeeded;
    _onHangUp = onHangUp;
    _displayName = displayName;
    _videoPausedByLifecycle = false;
    _audioTrackEnded = false;
    _micFgsCovered = false;
    _cameraFgsCovered = false;
    _startedAtMs = 0;
    // Pas `false` en dur : un appel décroché depuis une notification acquiert la
    // session alors qu'Alanya n'est pas encore à l'écran, et la politique
    // caméra comme la relance du service se décident là-dessus.
    _appBackgrounded =
        WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;

    WidgetsBinding.instance.addObserver(this);
    _bindNative();

    await AudioHelper.configureCallAudio(isVideo: mode == SessionMode.video);

    await _startMediaForegroundService(
      isVideo: isVideo,
      displayName: displayName,
    );

    if (startCallKit) {
      await CallKitService.instance.startOutgoingCall(
        callId: callId,
        displayName: displayName,
        handle: handle,
        isVideo: isVideo,
      );
    }

    await _applyScreenPolicy();

    _watchAudioTrack();

    debugPrint('[CallSessionGuard] Session acquise mode=$mode callId=$callId');
    return true;
  }

  Future<void> markConnected() async {
    if (kIsWeb || _callId == null) return;
    await CallKitService.instance.setConnected(_callId!);
    // La notification est posée à l'acquisition, quand l'appel sonne encore.
    // On la réécrit ici pour y lancer le chronomètre : relancer le service ne
    // le duplique pas, il redessine sa notification sous le même identifiant.
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _startMediaForegroundService(
      isVideo: _mode == SessionMode.video,
      displayName: _displayName,
      startedAt: _startedAtMs,
    );
  }

  /// Ouvre l'oreille du pont natif, une fois pour toutes.
  ///
  /// Le canal ne descendait que dans un sens ; le bouton « Raccrocher » de la
  /// notification a besoin qu'il remonte, et le service de ce qu'il a obtenu.
  void _bindNative() {
    if (_nativeBound || !_isAndroid) return;
    _nativeBound = true;
    _callMediaChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onHangUpRequested':
          debugPrint(
            '[CallSessionGuard] raccrochage demandé depuis la notification',
          );
          await _onHangUp?.call();
        case 'onMediaTypes':
          final args = call.arguments as Map? ?? const {};
          _micFgsCovered = args['microphone'] == true;
          _cameraFgsCovered = args['camera'] == true;
          debugPrint(
            '[CallSessionGuard] FGS obtenu micro=$_micFgsCovered '
            'caméra=$_cameraFgsCovered',
          );
          // La caméra vient peut-être de gagner ou de perdre le droit de
          // tourner en arrière-plan : la politique se rejoue sur-le-champ.
          if (_refCount > 0) _applyLocalVideoPolicy();
      }
      return null;
    });
  }

  /// La session média est-elle tenue par [callId] ?
  ///
  /// À interroger avant de démonter quoi que ce soit de partagé — la fenêtre
  /// flottante et les rendus vidéo appartiennent eux aussi à celui qui tient la
  /// session, et les libérer depuis une session refusée vide l'écran du voisin.
  bool holdsSession(String? callId) {
    if (kIsWeb) return false;
    return shouldReleaseSession(
      refCount: _refCount,
      heldBy: _callId,
      releasedBy: callId,
    );
  }

  /// Rend la session — **si elle est bien à cet appel-ci**. Voir
  /// [shouldReleaseSession].
  Future<void> release({String? callId}) async {
    if (kIsWeb) return;
    if (!shouldReleaseSession(
      refCount: _refCount,
      heldBy: _callId,
      releasedBy: callId,
    )) {
      if (_refCount > 0) {
        debugPrint(
          '[CallSessionGuard] ⛔ release ignoré : session tenue par $_callId, '
          'rendue par $callId',
        );
      }
      return;
    }
    _refCount--;
    if (_refCount > 0) return;

    LockScreenPolicy.setSessionHeld(false);
    WidgetsBinding.instance.removeObserver(this);

    // Avant tout le reste : un écran resté noir parce que le verrou de
    // proximité a survécu à l'appel ne se distingue pas d'un téléphone en panne.
    await _applyScreenPolicy();

    await _stopMediaForegroundService();

    await AudioHelper.releaseCallAudio();

    final tenu = _callId;
    if (tenu != null && tenu.isNotEmpty) {
      try {
        await CallKitService.instance.endCall(tenu);
        debugPrint('[CallSessionGuard] CallKit fermé callId=$tenu');
      } catch (e) {
        debugPrint('[CallSessionGuard] endCall error: $e');
      }
    }

    _mode = null;
    _callId = null;
    _getLocalStream = null;
    _isVideoOn = null;
    _isMuted = null;
    _onReplaceAudioNeeded = null;
    _onHangUp = null;
    _displayName = '';
    _videoPausedByLifecycle = false;
    _audioTrackEnded = false;
    _systemPipActive = false;
    _appBackgrounded = false;
    _micFgsCovered = false;
    _cameraFgsCovered = false;
    _startedAtMs = 0;

    debugPrint('[CallSessionGuard] Session relâchée');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || _refCount == 0) return;

    // La couverture micro est journalisée ici parce que c'est à ce moment
    // qu'elle compte : un `paused` avec micro=false, c'est la conversation qui
    // devient muette pour le correspondant.
    debugPrint(
      '[CallSessionGuard] lifecycle=$state mode=$_mode micro=$_micFgsCovered',
    );

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Uniquement réactiver la track existante — jamais getUserMedia ici.
      _ensureAudioTrackActive();
      _appBackgrounded = true;
      _applyLocalVideoPolicy();
    } else if (state == AppLifecycleState.resumed) {
      _appBackgrounded = false;
      AudioHelper.reactivateCallAudio();
      _ensureAudioTrackActive();
      _maybeReplaceAudioIfNeeded();
      _promoteMediaServiceIfNeeded();
      _applyLocalVideoPolicy();
      // Rebranche ce qu'un passage par `detached` aurait coupé. Sans effet
      // quand rien n'a été détaché : `syncMain` ignore ce qui n'a pas changé.
      SessionVideoRenderers.instance.resync();
    } else if (state == AppLifecycleState.detached) {
      // L'activité est détruite — retour arrière, ou balayage depuis les
      // applications récentes. Le moteur Flutter se détache, mais les rendus
      // vidéo continuent d'être alimentés : la première image livrée après
      // coup tue le processus. On coupe l'alimentation tant que le canal
      // répond encore.
      //
      // Ce chemin ne devrait plus être emprunté pendant un appel vidéo, que le
      // Picture-in-Picture retient désormais au premier plan. Il reste pour ce
      // que le PiP ne couvre pas : l'appareil qui le refuse, et l'appel audio.
      SessionVideoRenderers.instance.detachStreams();
    }
  }

  /// Signale l'ouverture ou la fermeture du Picture-in-Picture système.
  ///
  /// Appelée par le pont natif. Elle rejoue la décision caméra : fermer le PiP
  /// alors que l'application reste en arrière-plan doit couper ce que son
  /// ouverture avait laissé passer.
  void setSystemPipActive(bool active) {
    if (_systemPipActive == active) return;
    _systemPipActive = active;
    debugPrint('[CallSessionGuard] PiP système=$active');
    if (_refCount == 0) return;
    _applyLocalVideoPolicy();
  }

  /// Relance le service au premier plan quand il n'a pas obtenu le micro.
  ///
  /// Le type `microphone` ne s'obtient pas depuis l'arrière-plan : Android y
  /// refuse `startForeground`, et c'est exactement le décrochage depuis une
  /// notification. Le service démarre alors en `phoneCall` seul — l'appel tient,
  /// mais la capture s'arrêterait au prochain passage en arrière-plan, sans que
  /// rien ne le signale sinon le silence du correspondant.
  ///
  /// Le relancer d'ici, Alanya à l'écran, repose la demande dans les conditions
  /// où le système l'accorde — et c'est le seul moment où il l'accorde. Rien
  /// n'est dupliqué : `onStartCommand` est simplement rappelé, et la
  /// notification se réécrit sous le même identifiant, chronomètre compris.
  void _promoteMediaServiceIfNeeded() {
    if (!_mediaFgsStarted || _micFgsCovered) return;
    debugPrint(
      '[CallSessionGuard] micro non couvert par le FGS — relance du service',
    );
    _startMediaForegroundService(
      isVideo: _mode == SessionMode.video,
      displayName: _displayName,
      startedAt: _startedAtMs,
    );
  }

  /// Coupe ou rétablit la caméra locale selon [localVideoShouldPause].
  ///
  /// La caméra ne se coupe plus par principe en arrière-plan : c'était le
  /// défaut à corriger. Elle continue d'émettre dès lors que la plateforme
  /// l'autorise, ou que le Picture-in-Picture est ouvert.
  void _applyLocalVideoPolicy() {
    final shouldPause = localVideoShouldPause(
      isVideo: _mode == SessionMode.video,
      appBackgrounded: _appBackgrounded,
      systemPipActive: _systemPipActive,
      cameraAllowedInBackground: _cameraAllowedInBackground,
    );

    if (shouldPause) {
      _pauseLocalVideo();
    } else if (_videoPausedByLifecycle) {
      _resumeLocalVideo();
    }
  }

  /// Réactive `enabled` sur la track audio locale. Ne capture pas de nouveau média.
  void _ensureAudioTrackActive() {
    if (_isMuted != null && _isMuted!()) return;
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) {
      _audioTrackEnded = true;
      return;
    }
    final track = tracks.first;
    if (!track.enabled) {
      debugPrint('[CallSessionGuard] Réactivation track audio');
      track.enabled = true;
    }
  }

  void _watchAudioTrack() {
    final stream = _getLocalStream?.call();
    final tracks = stream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    final track = tracks.first;
    track.onEnded = () {
      _audioTrackEnded = true;
      debugPrint('[CallSessionGuard] Track audio ended');
    };
  }

  Future<void> _maybeReplaceAudioIfNeeded() async {
    if (_refCount == 0) return;
    final stream = _getLocalStream?.call();
    final tracks = stream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    final ended = _audioTrackEnded || tracks.isEmpty;
    if (!ended) return;

    final cb = _onReplaceAudioNeeded;
    if (cb == null) {
      debugPrint(
        '[CallSessionGuard] Track audio morte, pas de onReplaceAudioNeeded',
      );
      return;
    }

    debugPrint('[CallSessionGuard] Track audio morte → replaceTrack');
    try {
      await cb();
      _audioTrackEnded = false;
      _watchAudioTrack();
    } catch (e) {
      debugPrint('[CallSessionGuard] ** onReplaceAudioNeeded: $e');
    }
  }

  void _pauseLocalVideo() {
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    final track = tracks.first;
    if (track.enabled) {
      track.enabled = false;
      _videoPausedByLifecycle = true;
      debugPrint('[CallSessionGuard] Vidéo locale suspendue (veille)');
    }
  }

  void _resumeLocalVideo() {
    if (_isVideoOn != null && !_isVideoOn!()) return;
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    tracks.first.enabled = true;
    _videoPausedByLifecycle = false;
    debugPrint('[CallSessionGuard] Vidéo locale reprise');
  }

  /// Signale la sortie audio courante — et donc si le téléphone est à l'oreille.
  ///
  /// Appelée par `setAudioRoute`, l'entonnoir unique par lequel passent le choix
  /// d'ouverture, le bouton de la barre de contrôle et les branchements de
  /// casque détectés en cours d'appel. La politique d'écran suit ainsi la sortie
  /// sans que rien d'autre n'ait à y penser.
  Future<void> updateAudioRoute(CallAudioRoute route) async {
    if (kIsWeb) return;
    if (_route == route) return;
    _route = route;
    await _applyScreenPolicy();
  }

  /// Applique les deux règles d'écran à partir de l'état courant.
  ///
  /// Un seul endroit décide, et il est rejoué à chaque changement : acquisition,
  /// changement de sortie audio, libération. Les règles elles-mêmes sont pures
  /// et testées — voir `proximityBlankingApplies` et `screenWakelockApplies`.
  Future<void> _applyScreenPolicy() async {
    final callActive = _refCount > 0;

    final wantProximity = proximityBlankingApplies(
      route: _route,
      callActive: callActive,
    );
    if (wantProximity != _proximityEnabled) {
      await _setProximityBlanking(wantProximity);
    }

    final wantWakelock = screenWakelockApplies(
      isVideo: _mode == SessionMode.video,
      route: _route,
      callActive: callActive,
    );
    if (wantWakelock != _wakelockEnabled) {
      try {
        wantWakelock
            ? await WakelockPlus.enable()
            : await WakelockPlus.disable();
        _wakelockEnabled = wantWakelock;
        debugPrint('[CallSessionGuard] Wakelock=$wantWakelock');
      } catch (e) {
        debugPrint('[CallSessionGuard] ** Wakelock: $e');
      }
    }
  }

  Future<void> _setProximityBlanking(bool enabled) async {
    try {
      if (enabled) {
        // Le natif répond false quand l'appareil n'a pas de capteur : ne pas
        // retenir un état actif qu'aucun verrou ne soutient, sinon la remise à
        // zéro suivante serait sautée.
        final ok = await _proximityChannel.invokeMethod<bool>('enable');
        _proximityEnabled = ok ?? false;
      } else {
        await _proximityChannel.invokeMethod('disable');
        _proximityEnabled = false;
      }
      debugPrint('[CallSessionGuard] Proximité=$_proximityEnabled');
    } on MissingPluginException {
      // Web, tests, ou build sans le pont natif : l'appel continue sans.
      _proximityEnabled = false;
    } catch (e) {
      debugPrint('[CallSessionGuard] ** Proximité: $e');
      _proximityEnabled = false;
    }
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pose la notification de l'appel, ou la réécrit.
  ///
  /// Elle est devenue la SEULE notification de l'appel — celle du plugin est
  /// masquée dans `CallKitService.startOutgoingCall`. Elle doit donc dire qui
  /// est au bout, depuis quand, et permettre de raccrocher : tout ce que
  /// l'autre portait et qu'elle ne portait pas.
  ///
  /// [startedAt] à zéro tant que l'appel sonne : voir `EXTRA_STARTED_AT`.
  Future<void> _startMediaForegroundService({
    required bool isVideo,
    required String displayName,
    int startedAt = 0,
  }) async {
    if (!_isAndroid) return;
    final l10n = resolveL10n();
    final chrono = callNotificationUsesChronometer(startedAt);
    try {
      await _callMediaChannel.invokeMethod('start', {
        'isVideo': isVideo,
        'title': callNotificationTitle(
          displayName: displayName,
          fallback: l10n.callInProgress,
        ),
        'body': isVideo ? l10n.videoCall : l10n.audioCall,
        'hangUpLabel': l10n.hangUp,
        'channelName': l10n.ongoingCallsChannel,
        'startedAt': startedAt,
        'usesChronometer': chrono,
      });
      _mediaFgsStarted = true;
      debugPrint(
        '[CallSessionGuard] CallMedia FGS start isVideo=$isVideo '
        'chrono=$chrono',
      );
    } catch (e) {
      debugPrint('[CallSessionGuard] ** CallMedia FGS start: $e');
    }
  }

  Future<void> _stopMediaForegroundService() async {
    if (!_isAndroid || !_mediaFgsStarted) return;
    try {
      await _callMediaChannel.invokeMethod('stop');
      debugPrint('[CallSessionGuard] CallMedia FGS stop');
    } catch (e) {
      debugPrint('[CallSessionGuard] ** CallMedia FGS stop: $e');
    } finally {
      _mediaFgsStarted = false;
    }
  }
}
