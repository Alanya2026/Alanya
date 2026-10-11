import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../screens/calls/ongoing_call_screen.dart';
import '../../core/call_limits.dart';
import '../errors/app_error.dart';
import '../errors/error_presenter.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'audio_helper.dart' as audio;
import 'callkit_service.dart';
import 'call_session_guard.dart';
import 'ringtone_service.dart';
import 'list_ringtone_preferences.dart';
import 'webrtc_service.dart';
import 'call/speaking_detector.dart'; // détection locale du locuteur actif
import '../navigation/app_navigator.dart';
import '../utils/backend_url.dart';
import 'connectivity_service.dart';
import 'meeting_service.dart';
import '../theme/locale_controller.dart';
import 'billing/entitlement_service.dart';
import 'chat/message_sound_service.dart';
import 'call/call_permissions_helper.dart';
import 'call/ended_call_registry.dart';
import 'call/session_video_renderers.dart';
import 'call/system_pip.dart';
import 'call/pending_call_reject_store.dart';
import 'call/pending_outgoing_call_store.dart';
import 'call/call_conf_routing.dart';
import 'call/call_audio_routes.dart';
import 'call/call_restart_policy.dart';
import 'call/call_restart_roles.dart';
import 'call/call_terminal_guards.dart';
import 'call/call_group_media_states.dart';
import 'call/call_ice_outbox.dart';
import 'call/call_ice_constraints.dart';
import 'call/incoming_presentation.dart';
import 'call/voicemail_greeting_player.dart';
import '../../widgets/calls/voicemail_recorder_sheet.dart';

// Endpoints répartis par domaine (mêmes librairie/membres privés) :
part 'call/call_incoming.dart';   // entrées push / CallKit
part 'call/call_signaling.dart';  // listeners socket.io
part 'call/call_one_to_one.dart'; // appels 1-à-1
part 'call/call_group.dart';      // appels de groupe
part 'call/call_conference.dart'; // « Ajouter à l'appel » (transfert assisté, 3 max)
part 'call/call_controls.dart';   // contrôles médias + timer
part 'call/call_session.dart';    // session audio / foreground en veille
part 'call/call_ui.dart';         // bannière / minimiser l'écran d'appel
part 'call/call_outgoing_restore.dart'; // restauration appel sortant après kill
part 'call/call_reconnect.dart'; // reconnexion mid-call 1-à-1 / ICE restart

/// Aligné sur TalkyFirebaseMessagingService (Android V2).
const bool _kAndroidNativeCallNotifications = bool.fromEnvironment(
  'TALKY_ANDROID_NATIVE_NOTIF_V2',
  defaultValue: true,
);

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, reconnecting, ended }

/// État UI informatif du transfert (le backend reste autoritaire).
enum CallTransferStatus {
  none,
  inviting,
  awaitingJoin,
  awaitingMediaReady,
  countdown,
  completed,
  cancelled,
}

/// Infos minimales d'un participant d'appel de groupe (pour l'UI grille).
class GroupParticipantInfo {
  final String id;
  final String name;
  final String? photo;
  bool isMuted;
  bool isVideoOn;
  GroupParticipantInfo({
    required this.id,
    required this.name,
    this.photo,
    this.isMuted = false,
    this.isVideoOn = true,
  });
}

class CallService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final ConnectivityService _connectivity = ConnectivityService();
  final WebRTCService _webrtc = WebRTCService();
  final RingtoneService _ringtone = RingtoneService.instance;
  final CallKitService _callKit = CallKitService.instance;

  static String get _offlineCallMessage =>
      LocaleController.instance.l10n.cannotPlaceCallCheckInternet;

  static String get _serverCallMessage =>
      LocaleController.instance.l10n.cannotPlaceCallServerFailed;

  CallStatus _status = CallStatus.idle;
  int? _remoteUserId;
  String? _remoteUserName;
  String? _remoteUserPhoto;
  int _remoteTypeCompte = 0;
  int _remoteAccountType = 0;
  int _remoteVerificationStatus = 0;
  bool _isVideo = false;
  Map<String, dynamic>? _pendingOffer; // offer reçu avant réponse
  String? _currentCallId;   // callId backend, utilisé pour synchroniser CallKit

  /// Identifiant sous lequel CallKit et `CallSessionGuard` ont été démarrés.
  ///
  /// Sur un appel sortant, la session CallKit est acquise avant que le serveur
  /// n'ait attribué son identifiant : `_ensureCallId()` en fabrique un à partir
  /// de l'horloge. `_currentCallId` adopte ensuite l'identifiant serveur reçu
  /// dans `call_answered` — sans quoi toutes les comparaisons de callId étaient
  /// fausses de ce côté, et `EndedCallRegistry` écrivait une clé que personne ne
  /// relisait, rendant inopérante la protection anti-appel-fantôme entre
  /// isolates. Mais CallKit, lui, ne connaît que l'identifiant fabriqué : il est
  /// donc conservé ici, et c'est lui qu'on lui présente pour fermer l'entrée.
  String? _callKitCallId;

  /// Vrai dès que `_currentCallId` porte l'identifiant attribué par le serveur.
  ///
  /// Faux tant que l'appel sortant n'a que l'horodatage de `_ensureCallId()`.
  /// Aucune comparaison de callId ne peut alors rien conclure — et les gardes
  /// terminales, qui en tiraient un refus, jetaient le refus du correspondant
  /// pendant toute la sonnerie. Elles s'en tiennent au statut dans ce cas.
  bool _serverCallIdKnown = false;

  /// Pose l'identifiant que le serveur a attribué à l'appel.
  ///
  /// `_callKitCallId` n'est pas touché : CallKit et la couche native ne
  /// connaissent que celui sous lequel l'entrée a été ouverte, et c'est lui
  /// qu'il faudra leur présenter pour la fermer.
  void _adoptServerCallId(String? id) {
    final identifiant = id?.trim() ?? '';
    _currentCallId = identifiant.isEmpty ? null : identifiant;
    _serverCallIdKnown = identifiant.isNotEmpty;
  }

  bool _callEndedByUs = false;

  /// Teardown en cours (endCall / terminate) — empêche un 2ᵉ `end_call`
  /// (ex. CallKit `ended` pendant `_callKit.endAll`).
  bool _isEndingCall = false;

  // Contrôles médias
  bool _isMuted = false;
  /// Sortie audio courante et sorties proposables. Le bouton de la barre de
  /// contrôle ne connaissait que « haut-parleur allumé / éteint » : avec un
  /// casque Bluetooth appairé, l'utilisateur ne savait pas où sortait le son.
  CallAudioRoute _audioRoute = CallAudioRoute.earpiece;
  List<CallAudioRoute> _audioRoutes = const [
    CallAudioRoute.earpiece,
    CallAudioRoute.speaker,
  ];
  StreamSubscription<void>? _audioOutputsSub;

  bool _isSpeakerOn = false;
  bool _isVideoOn = true;

  // État mute du distant (appel 1-à-1)
  bool _isRemoteMuted = false;
  bool _isRemoteVideoOn = true;

  // Erreurs
  String? _errorMessage;

  // Durée
  Timer? _durationTimer;
  int _callDuration = 0;

  //  Appels de groupe
  String? _groupRoomId;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};
  List<String> _groupParticipants = [];

  // ICE candidates bufferisés tant que la remote description n'est pas définie.
  final Map<String, List<RTCIceCandidate>> _groupPendingIce = {};
  final Set<String> _groupRemoteDescSet = <String>{};

  /// Grâce sur `Disconnected` mesh (état WebRTC souvent transitoire).
  final Map<String, Timer> _groupPeerDisconnectGrace = {};

  /// État reconnect par peer (mesh) — jamais leaveCallSession sur un seul lien.
  final Map<String, int> _groupPeerIceGeneration = {};
  final Map<String, int> _groupPeerRetryCount = {};
  final Map<String, bool> _groupPeerIsRestarting = {};
  static const int _maxGroupPeerIceRestarts = 3;

  // Roster de l'appel de groupe (userId → infos d'affichage).
  final Map<String, GroupParticipantInfo> _groupRoster = {};

  /// États micro/caméra reçus pour quelqu'un qui n'est pas encore au roster.
  ///
  /// Le serveur ne les réémet pas et l'émetteur ne sait pas qu'on les a jetés :
  /// sans ce report, un état arrivé une fraction de seconde trop tôt restait
  /// faux jusqu'à la prochaine bascule du micro d'en face.
  final PendingGroupMediaStates _pendingGroupMedia = PendingGroupMediaStates();

  //  « Ajouter à l'appel » — session à trois (join / transfer)
  //
  // Un appel 1-à-1 ordinaire n'a pas de session. Elle naît au premier ajout et
  // porte l'appel jusqu'au bout, même retombé à deux : le droit d'ajout est
  // alors rendu (canAddToCall) et l'invitation suivante s'y greffe. Un échec
  // d'invitation ne l'efface que si personne n'y est encore entré.
  String? _confSessionId;

  // Invité qui sonne encore : affiché en tuile « Sonnerie… » avant sa réponse.
  GroupParticipantInfo? _confPendingInvitee;

  // Côté invité : qui l'ajoute, pour l'écran d'appel entrant.
  GroupParticipantInfo? _confInvitedBy;

  // Vrai chez celui qui a lancé l'invitation : lui seul peut l'annuler.
  bool _confInviteIsMine = false;

  /// Mode d'invitation serveur : `join` (défaut) ou `transfer`.
  String _confMode = 'join';

  /// État UI informatif du transfert (backend = source de vérité).
  CallTransferStatus _transferStatus = CallTransferStatus.none;

  /// true si je suis l'initiateur à retirer après call_transfer_armed.
  bool _isTransferInitiator = false;

  /// Cible C du transfert en cours (id string). Ready média uniquement vers ce peer.
  String? _transferTargetId;

  /// Délai annoncé par le serveur pour le leave auto (ms).
  int? _transferLeaveInMs;

  /// Instant local où call_transfer_armed a été reçu.
  DateTime? _transferArmedAt;

  /// peerIds pour lesquels call_conf_ready a déjà été **émis** (sessionId|peerId).
  final Set<String> _confReadySent = {};

  /// Ready en attente de socket prêt (sessionId|peerId) — flush à authVerified.
  final Set<String> _pendingConfReady = {};

  /// call_conf_join en attente si le socket n'était pas prêt (cold-start).
  String? _pendingConfJoinSessionId;

  // Mon propre identifiant dans le roster, mémorisé à la bascule en maillage.
  String? _myRosterId;

  // Identité locale, poussée par AuthProvider. Les événements de session
  // arrivent par socket à n'importe quel moment, sans passer par un écran :
  // le service doit pouvoir se placer lui-même dans le roster.
  int? _localUserId;
  String _localUserName = '';
  String? _localUserPhoto;

  int? get localUserId => _localUserId;
  String? get myRosterId => _myRosterId;

  // Derniers faits marquants, consommés une fois par l'écran d'appel pour
  // afficher un bandeau (« Untel a refusé », « Untel a quitté l'appel »).
  String? _lastConfFailure;
  String? _lastConfDeparture;

  // Auto-réponse (CallKit pré-accepté)
  bool _autoAnswerOnNextIncoming = false;
  String? _autoAnswerCallerId;
  final Map<String, DateTime> _recentIncomingCallIds = {};

  // Auto-réponse depuis une notification/CallKit : on saute l'écran d'appel
  // entrant (IncomingCallScreen) et on ouvre directement l'écran d'appel actif.
  bool _isAutoAnsweringFromPush = false;
  bool _isRestoringOutgoing = false;
  Timer? _outgoingRestoreTimer;

  // Propriétaire de présentation UI entrante (lié au callId) — distinct de
  // CallStatus.incoming. Évite CallKit + IncomingCallScreen en même temps.
  IncomingPresentationState _incomingPresentation =
      IncomingPresentationState.empty;

  // Filet de sécurité local : si aucun état terminal serveur (call_answered,
  // call_busy, call_no_answer, call_rejected…) n'arrive, on abandonne l'appel.
  Timer? _outgoingTimeoutTimer;
  static const Duration _outgoingTimeout = Duration(seconds: 50);

  // Filet côté destinataire : attente BORNÉE de l'offre WebRTC après acceptation
  // (cold-start CallKit ou accept avant réception de l'offre). Sans ça, un écran
  // « connexion en cours » peut rester figé indéfiniment si l'offre n'arrive
  // jamais (appel périmé / rejeu fantôme).
  Timer? _awaitingOfferTimer;
  // Aligné sur la durée de sonnerie CallKit native (30 s) : au-delà, un entrant
  // sans offre socket est considéré périmé/terminé.
  static const Duration _awaitingOfferTimeout = Duration(seconds: 30);

  // Filet anti sonnerie infinie : borne la durée d'un entrant qui sonne au
  // premier plan (RingtoneService) si aucun événement terminal n'arrive
  // (secours au call_ended socket/FCM du serveur).
  Timer? _incomingRingSafetyTimer;
  static const Duration _incomingRingSafety = Duration(seconds: 55);

  // callId déjà traités (acceptés/refusés) — évite de re-sonner sur un
  // incoming_call rejoué par le backend (auth replay).
  final Map<String, DateTime> _handledTerminalCallIds = {};

  // File d'attente des end_call perdus quand le socket n'est pas prêt.
  // Rejoués à l'authentification du socket (comme les rejects).
  final List<Map<String, dynamic>> _pendingEndCalls = [];

  /// true si cet appareil a initié l'appel 1-à-1 (restart ICE = caller only).
  bool _isOutgoingCaller = false;

  Timer? _reconnectGraceTimer;
  Timer? _globalReconnectTimer;

  /// Audit du socket pendant une reconnexion — voir `_armSocketAudit`.
  Timer? _socketAuditTimer;
  bool _socketRebuiltForReconnect = false;
  Timer? _iceRestartRetryTimer;
  DateTime? _lastRestartOfferAt;
  /// Chaîne d'exécution des offres de reprise : elles se traitent une à une.
  Future<void> _rejoinOfferChain = Future<void>.value();

  /// Candidats ICE déjà émis pour l'appel sortant en cours, avec leur
  /// génération. Ils sont rejoués au décrochage : voir `_replayOutgoingIce`.
  final List<({int generation, Map<String, dynamic> payload})> _outgoingIceOutbox = [];
  bool _isIceRestarting = false;
  int _iceRestartCount = 0;
  static const Duration _reconnectGraceDuration = Duration(seconds: 4);
  static const Duration _globalReconnectTimeout = Duration(seconds: 45);
  static const int _maxIceRestarts = 3;
  /// Cadence de vérification pendant une reconnexion.
  /// Une offre peut se perdre sans que personne ne le sache : socket local à
  /// terre, ou appareil du pair absent. Le verdict reste au timeout global.
  static const Duration _iceRestartRetryInterval = Duration(seconds: 5);

  /// Borne l'ouverture du micro et de la caméra au décrochage.
  ///
  /// Entre le décrochage et l'envoi de la réponse, plus aucune horloge ne
  /// couvre l'appel. Vingt secondes laissent le temps à une boîte de dialogue
  /// de permission d'être acceptée, et restent en deçà des quarante-cinq
  /// secondes après lesquelles le serveur classe l'appel « sans réponse ».
  static const Duration _mediaAcquireTimeout = Duration(seconds: 20);

  /// Délai avant d'auditer le socket quand un appel entre en reconnexion, et
  /// silence au-delà duquel on le tient pour mort. Huit secondes laissent le
  /// temps à une reprise normale d'aboutir, et gardent trente-sept secondes
  /// avant le délai global pour qu'un socket neuf serve à quelque chose.
  static const Duration _socketAuditDelay = Duration(seconds: 8);
  static const Duration _socketSilenceThreshold = Duration(seconds: 8);

  /// Délai laissé à une offre de reprise déjà partie avant d'en réémettre une.
  /// Réémettre repart d'une génération neuve et purge les candidats ICE en
  /// cours de route : le faire trop tôt empêche la négociation d'aboutir, et
  /// l'appel se rétablit en apparence sans qu'aucun média ne passe.
  static const Duration _iceRestartOfferTimeout = Duration(seconds: 12);

  /// Plafond du rejeu des candidats ICE sortants. Un appel vidéo en rassemble
  /// quelques dizaines ; la borne protège d'un réseau qui en produirait sans fin.
  static const int _maxOutgoingIceReplay = 128;

  /// Hook optionnel après fin d'appel local (ex. resync historique).
  Future<void> Function()? onCallTerminatedHook;

  // UI minimisée (bannière flottante active).
  bool _isCallUiMinimized = false;
  bool _isCallUiRouteOpen = false;

  // Détection locale du locuteur actif (1-1 et groupe).
  final SpeakingDetector speakingDetector = SpeakingDetector();

  //  Getters
  CallStatus get status => _status;
  int? get remoteUserId => _remoteUserId;
  String? get remoteUserName => _remoteUserName;
  String? get remoteUserPhoto => _remoteUserPhoto;
  bool get isVideo => _isVideo;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Sortie audio courante — écouteur, haut-parleur, filaire ou Bluetooth.
  CallAudioRoute get audioRoute => _audioRoute;

  /// Sorties proposables, dans l'ordre du bouton.
  List<CallAudioRoute> get availableAudioRoutes =>
      List.unmodifiable(_audioRoutes);
  bool get isVideoOn => _isVideoOn;
  bool get isRemoteMuted => _isRemoteMuted;
  bool get isRemoteVideoOn => _isRemoteVideoOn;
  int get callDuration => _callDuration;
  String? get errorMessage => _errorMessage;
  bool get callEndedByUs => _callEndedByUs;
  MediaStream? get localStream => _webrtc.localStream;
  MediaStream? get remoteStream => _webrtc.remoteStream;

  String? get groupRoomId => _groupRoomId;
  Map<String, MediaStream> get groupRemoteStreams => _groupRemoteStreams;
  List<String> get groupParticipants => _groupParticipants;
  Map<String, GroupParticipantInfo> get groupRoster => _groupRoster;

  //  « Ajouter à l'appel »
  String? get confSessionId => _confSessionId;
  bool get isConference => _confSessionId != null;
  GroupParticipantInfo? get confPendingInvitee => _confPendingInvitee;
  GroupParticipantInfo? get confInvitedBy => _confInvitedBy;
  bool get confInviteIsMine => _confInviteIsMine;
  String get confMode => _confMode;
  bool get isTransferMode => _confMode == 'transfer';
  CallTransferStatus get transferStatus => _transferStatus;
  bool get isTransferInitiator => _isTransferInitiator;

  /// Secondes restantes du leave auto (null si pas en countdown).
  int? get transferCountdownRemainingSeconds {
    if (_transferStatus != CallTransferStatus.countdown) return null;
    final armedAt = _transferArmedAt;
    final leaveInMs = _transferLeaveInMs;
    if (armedAt == null || leaveInMs == null) return null;
    final elapsed = DateTime.now().difference(armedAt).inMilliseconds;
    final left = leaveInMs - elapsed;
    if (left <= 0) return 0;
    return (left / 1000).ceil();
  }

  /// Durée totale du countdown annoncée par le serveur (secondes).
  int get transferCountdownTotalSeconds {
    final ms = _transferLeaveInMs;
    if (ms == null || ms <= 0) return 10;
    return (ms / 1000).ceil();
  }

  /// Flux distant à afficher quand l'écran est en mode « à deux ».
  ///
  /// Après le départ d'un participant, le correspondant restant peut être celui
  /// qui était arrivé par le maillage : son flux n'est alors pas celui de
  /// `_webrtc`, mais une entrée de `_groupRemoteStreams`.
  MediaStream? get activeRemoteStream {
    final direct = _webrtc.remoteStream;
    if (_groupRoomId != null) return direct;
    final peerId = _remoteUserId?.toString();
    if (peerId != null && _groupRemoteStreams.containsKey(peerId)) {
      return _groupRemoteStreams[peerId];
    }
    return direct;
  }

  /// Renseigne l'identité locale (appelée par AuthProvider à chaque changement).
  void setLocalIdentity({required int id, required String name, String? photo}) {
    _localUserId = id;
    _localUserName = name;
    _localUserPhoto = photo;
  }

  /// Raison du dernier échec d'invitation, lue une seule fois par l'interface.
  String? takeConfFailure() {
    final v = _lastConfFailure;
    _lastConfFailure = null;
    return v;
  }

  /// Nom du dernier participant parti, lu une seule fois par l'interface.
  String? takeConfDeparture() {
    final v = _lastConfDeparture;
    _lastConfDeparture = null;
    return v;
  }

  /// Vrai quand le bouton « Ajouter à l'appel » doit être affiché.
  ///
  /// Absent plutôt que grisé dans tous les autres cas : un bouton grisé invite à
  /// demander pourquoi, et « l'appel est déjà à trois » n'a aucune action de
  /// rattrapage à proposer. La règle vit dans [canAddToCall].
  bool get canAddParticipant => canAddToCall(
        callStatusName: _status.name,
        hasConfSession: _confSessionId != null,
        showsGroupRoom: _groupRoomId != null,
        hasPendingInvitee: _confPendingInvitee != null,
        hasRemoteUser: _remoteUserId != null,
        meetingActive: _isMeetingActive(),
      );

  // Locuteur actif : Set des userId (groupe) ou {SpeakingDetector.localKey}
  // pour moi-même. Voir `speaking_detector.dart`.
  Set<String> get activeSpeakers => speakingDetector.activeSpeakers;
  bool get amISpeaking => speakingDetector.amISpeaking;
  bool isUserSpeaking(String userId) => speakingDetector.isSpeaking(userId);

  Call? get currentCall {
    if (_remoteUserId == null && _remoteUserName == null) return null;
    return Call(
      idCall: 0,
      idCaller: _remoteUserId ?? 0,
      idReceiver: 0,
      type: _isVideo ? 1 : 0,
      status: _status == CallStatus.incoming ? 0 : 1,
      createdAt: '',
      caller: _remoteUserId != null
          ? User(
              alanyaID: _remoteUserId!,
              nom: _remoteUserName ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 1,
              avatarUrl: _remoteUserPhoto ?? '',
              typeCompte: _remoteTypeCompte,
              accountType: _remoteAccountType,
              verificationStatus: _remoteVerificationStatus,
              isOnline: false,
              lastSeen: '',
            )
          : null,
    );
  }

  String get formattedDuration {
    final m = _callDuration ~/ 60;
    final s = _callDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  CallService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _initRingtone();
    _setupSocketListeners();
    // Le détecteur est un ChangeNotifier séparé : on relaie ses
    // changements pour que les écrans (Consumer<CallService>) se
    // reconstruisent quand le locuteur actif change.
    speakingDetector.addListener(notify);
  }

  /// Pont public vers `notifyListeners()` (lui-même `@protected`), afin que les
  /// extensions de cette librairie puissent déclencher un rebuild de l'UI.
  void notify() => notifyListeners();

  /// Démarre la détection du locuteur actif. [groupMode] détermine la
  /// source des PeerConnection : mesh de groupe (`_groupPeerConnections`)
  /// ou unique PeerConnection du 1-1 (clé = remoteUserId).
  void _startSpeakingDetection({required bool groupMode}) {
    speakingDetector.start(() {
      if (groupMode) return _groupPeerConnections;
      final pc = _webrtc.peerConnection;
      final remoteId = _remoteUserId?.toString();
      if (pc == null || remoteId == null) return <String, RTCPeerConnection>{};
      return {remoteId: pc};
    });
  }

  Future<void> _initRingtone() async {
    try {
      await _ringtone.init();
      debugPrint('[CallService] !! RingtoneService initialisé');
    } catch (e) {
      debugPrint('[CallService] ** Erreur init ringtone: $e');
    }
  }

  /// Vrai si l'app est au premier plan. Sert à choisir la source de sonnerie
  /// entrante : RingtoneService au premier plan, CallKit en arrière-plan ou
  /// application fermée — source unique.
  ///
  /// Voir `appIsForeground` : un état de cycle de vie encore inconnu compte
  /// désormais comme un arrière-plan, et non l'inverse.
  bool get _isAppForeground =>
      appIsForeground(WidgetsBinding.instance.lifecycleState?.name);

  bool get isAppInForeground => _isAppForeground;

  /// Android V2 : CallKit entrant affiché côté natif en arrière-plan.
  bool get _nativeAndroidHandlesIncomingCallUi =>
      !kIsWeb &&
      Platform.isAndroid &&
      _kAndroidNativeCallNotifications;

  /// Retire l'UI CallKit sans refuser l'appel (migration premier plan).
  ///
  /// Deux défauts corrigés ici, et ensemble ils faisaient les deux sonneries.
  ///
  /// L'identifiant était `_currentCallId` — **nul pour une invitation de
  /// groupe**, qui ne pose que `_groupRoomId`. Le retrait sortait donc à vide
  /// pendant que la sonnerie Flutter, elle, raisonnait bien sur le salon et
  /// partait. L'écran d'appel du plugin restait affiché, avec sa propre
  /// sonnerie : deux sonneries, sans qu'aucune trace ne le dise.
  ///
  /// Et la garde `!_isAppForeground` re-dérivait une décision que l'appelant
  /// venait de prendre. `resumeForegroundIncoming` est son unique appelant, et
  /// il n'agit qu'après que l'autorité de présentation a rendu
  /// `handoffToFlutter`. Au montage de l'accueil, l'état de cycle de vie peut
  /// encore être inconnu : la garde sortait, alors que le démarrage de la
  /// sonnerie douze lignes plus bas n'en avait pas. Deux moitiés d'un même
  /// geste, deux prédicats.
  Future<void> dismissIncomingCallKitForForeground() async {
    if (kIsWeb) return;
    final id = _activeIncomingPresentationCallId;
    if (id == null || id.isEmpty) return;
    await _callKit.dismissIncomingUiSilently(callId: id);
  }

  Future<void> _dismissStrayIncomingCallKit(String? callId) async {
    if (kIsWeb || callId == null || callId.isEmpty) return;
    await _callKit.dismissIncomingUiSilently(callId: callId);
  }

  bool _isMeetingActive() {
    final context = appNavigatorKey.currentContext;
    if (context == null) return false;
    try {
      return context.read<MeetingService>().isMeetingActive;
    } catch (_) {
      return false;
    }
  }

  bool get isAutoAnsweringFromPush => _isAutoAnsweringFromPush;

  String? get currentCallId => _currentCallId;

  IncomingPresentationOwner get incomingPresentationOwner =>
      _incomingPresentation.owner;

  /// callId utilisé pour l'ownership UI (1-1 = callId, groupe/conf = room/session).
  String? get _activeIncomingPresentationCallId => incomingPresentationId(
        callId: _currentCallId,
        groupRoomId: _groupRoomId,
      );

  /// HomeScreen : ouvrir IncomingCallScreen seulement si Flutter est owner.
  bool get shouldShowFlutterIncomingUi => evaluateShouldShowFlutterIncomingUi(
        statusIsIncoming: _status == CallStatus.incoming,
        isAutoAnsweringFromPush: _isAutoAnsweringFromPush,
        appForeground: _isAppForeground,
        owner: _incomingPresentation.owner,
        ownerCallId: _incomingPresentation.callId,
        currentCallId: _activeIncomingPresentationCallId,
      );

  bool _claimIncomingPresentation(
    String? callId,
    IncomingPresentationOwner owner, {
    bool explicitHandoff = false,
  }) {
    final id = callId?.trim() ?? '';
    final result = claimIncomingPresentation(
      current: _incomingPresentation,
      callId: id,
      owner: owner,
      explicitHandoff: explicitHandoff,
      isTerminal: _isTerminalCallId(id),
    );
    if (result.ignored && !result.changed) {
      if (id.isNotEmpty) {
        debugPrint(
          '[CallService] 🛡 claim presentation ignoré: callId=$id '
          'want=$owner have=${_incomingPresentation.owner}/'
          '${_incomingPresentation.callId} handoff=$explicitHandoff',
        );
      }
      return false;
    }
    if (result.changed) {
      _incomingPresentation = result.state;
      debugPrint(
        '[CallService] 🎯 presentation owner=${result.state.owner} '
        'callId=${result.state.callId}',
      );
    }
    return result.changed || !result.ignored;
  }

  /// Arbitre la présentation d'un entrant, l'applique, et **rend l'action**.
  ///
  /// Quatre sites recopiaient à la main `if (_isAppForeground) flutter else
  /// native`, puis un second `if (!_isAppForeground)` juste en dessous décidait
  /// l'affichage CallKit et la sonnerie. Deux aiguillages pour une seule
  /// question, qui pouvaient diverger — et qui divergeaient : ni le groupe ni
  /// la conférence n'avaient de branche « premier plan », donc ils ne sonnaient
  /// pas.
  ///
  /// `decideIncomingPresentation` prenait déjà exactement ces décisions, et
  /// n'était appelée que par son propre test. C'est elle qui tranche désormais,
  /// et l'action rendue pilote la suite chez l'appelant.
  ///
  /// [callKitActive] n'est à passer que si l'appelant sait mieux que le cache —
  /// le chemin `prepareFromCallKit`, par construction, est appelé alors que
  /// CallKit possède l'entrée.
  IncomingPresentationAction _resolveIncomingPresentation({
    required String? callId,
    required IncomingPresentationIntent intent,
    bool? callKitActive,
  }) {
    final id = callId?.trim() ?? '';
    final action = decideIncomingPresentation(
      callId: id,
      appForeground: _isAppForeground,
      currentOwner: _incomingPresentation.owner,
      currentOwnerCallId: _incomingPresentation.callId,
      isAutoAnsweringFromPush: _isAutoAnsweringFromPush,
      isTerminal: _isTerminalCallId(id),
      intent: intent,
      isCallKitActive: callKitActive ?? _callKit.isShowingIncoming(id),
    );
    switch (action) {
      case IncomingPresentationAction.showFlutterIncoming:
      case IncomingPresentationAction.handoffToFlutter:
        _claimIncomingPresentation(
          id,
          IncomingPresentationOwner.flutterScreen,
          explicitHandoff:
              action == IncomingPresentationAction.handoffToFlutter,
        );
      case IncomingPresentationAction.showNativeCallKit:
      case IncomingPresentationAction.handoffToNative:
        _claimIncomingPresentation(
          id,
          IncomingPresentationOwner.nativeCallKit,
          explicitHandoff: action == IncomingPresentationAction.handoffToNative,
        );
      case IncomingPresentationAction.mergeOnly:
        // Auto-réponse depuis un push : il n'y a aucun entrant à présenter,
        // seulement un appel à établir. On libère plutôt que de laisser un
        // propriétaire derrière soi — c'est ce que faisait déjà le site 1-à-1.
        if (_isAutoAnsweringFromPush) _clearIncomingPresentation(callId: id);
      case IncomingPresentationAction.ignore:
        break;
    }
    debugPrint('[CallService] 🎬 présentation $intent → $action (id=$id)');
    return action;
  }

  /// Sonnerie Flutter et retrait d'une entrée CallKit résiduelle, pour un
  /// entrant que Flutter présente — quel que soit le genre de session.
  ///
  /// Existait en clair sur le seul chemin 1-à-1 : `startIncomingRingtone` n'a
  /// jamais eu d'appelant côté groupe ni côté conférence. Une invitation de
  /// groupe reçue application ouverte affichait donc l'écran **en silence**.
  /// L'asymétrie le prouvait : passer en arrière-plan puis revenir *faisait*
  /// sonner la même invitation, parce que `resumeForegroundIncoming` ne fait
  /// pas cette distinction.
  void _startFlutterIncomingRinging(String presentationId) {
    unawaited(_dismissStrayIncomingCallKit(presentationId));
    _ringtone
        .startIncomingRingtone(
          override: _remoteUserId == null
              ? null
              : ListRingtonePreferences.resolveCall(_remoteUserId!),
        )
        .catchError((Object e) {
      debugPrint('[CallService] ** Erreur sonnerie (non-bloquante): $e');
    });
  }

  void _clearIncomingPresentation({String? callId}) {
    final next = clearIncomingPresentationState(
      current: _incomingPresentation,
      callId: callId,
    );
    if (next.owner == _incomingPresentation.owner &&
        next.callId == _incomingPresentation.callId) {
      return;
    }
    _incomingPresentation = next;
  }

  /// Vrai si une session d'appel sortant/en cours correspond au [callId] CallKit.
  /// True si [id] désigne l'appel en cours, quel que soit celui de ses deux
  /// identifiants qu'on lui présente.
  ///
  /// À utiliser dès que l'identifiant vient de CallKit ou de la couche native :
  /// eux ne connaissent que celui qui a ouvert la session, alors que le serveur
  /// et l'isolate FCM parlent du sien.
  bool _matchesCurrentCallId(String? id) => matchesCallIdentity(
        candidate: id,
        currentCallId: _currentCallId,
        callKitCallId: _callKitCallId,
      );

  bool matchesActiveOutgoingSession(String callId) => matchesActiveOutgoingCall(
        candidate: callId,
        callStatusName: _status.name,
        currentCallId: _currentCallId,
        callKitCallId: _callKitCallId,
      );

  bool _alreadyHandledIncomingCallId(String? callId) {
    if (callId == null || callId.isEmpty) return false;
    final now = DateTime.now();
    _recentIncomingCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 90);
    if (_recentIncomingCallIds.containsKey(callId)) return true;
    _recentIncomingCallIds[callId] = now;
    return false;
  }

  /// Mémorise un callId ayant atteint un état terminal (accepté/refusé/terminé)
  /// pour ignorer un `incoming_call` rejoué et un FCM `call` tardif.
  void _markTerminalCallId(String? callId) {
    _markOneTerminalCallId(callId);
    // Un appel sortant porte deux identifiants : celui du serveur, et celui
    // fabriqué avec lequel CallKit a été ouvert. L'isolate FCM et la couche
    // native peuvent parler de l'un ou de l'autre — marquer les deux, sinon la
    // protection anti-appel-fantôme rate la moitié des cas.
    if (_callKitCallId != null && _callKitCallId != callId) {
      _markOneTerminalCallId(_callKitCallId);
    }
  }

  void _markOneTerminalCallId(String? callId) {
    if (callId == null || callId.isEmpty) return;
    final now = DateTime.now();
    _handledTerminalCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 120);
    _handledTerminalCallIds[callId] = now;
    _clearIncomingPresentation(callId: callId);
    // Persisté pour l'isolate FCM background (course call vs call_ended).
    unawaited(EndedCallRegistry.markEnded(callId));
  }

  bool _isTerminalCallId(String? callId) {
    if (callId == null || callId.isEmpty) return false;
    final now = DateTime.now();
    _handledTerminalCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 120);
    return _handledTerminalCallIds.containsKey(callId);
  }

  /// Lève la marque « terminé » de [callId], ici et pour l'isolate FCM.
  ///
  /// Réservé à une session qu'on rejoint sur une invitation fraîche : l'avoir
  /// quittée plus tôt l'avait marquée, et la reprise d'appel comme la file du
  /// join auraient refusé ce retour pendant deux minutes.
  void _forgetTerminalCallId(String? callId) {
    if (callId == null || callId.isEmpty) return;
    _handledTerminalCallIds.remove(callId);
    unawaited(EndedCallRegistry.unmark(callId));
  }

  void _cancelOutgoingTimeout() {
    _outgoingTimeoutTimer?.cancel();
    _outgoingTimeoutTimer = null;
  }

  void _cancelAwaitingOfferTimeout() {
    _awaitingOfferTimer?.cancel();
    _awaitingOfferTimer = null;
  }

  void _cancelIncomingRingSafety() {
    _incomingRingSafetyTimer?.cancel();
    _incomingRingSafetyTimer = null;
  }

  /// Borne la durée d'un entrant qui sonne au premier plan : si aucun événement
  /// terminal n'arrête l'appel, on coupe la sonnerie et on refuse proprement
  /// (secours au call_ended serveur si socket/FCM ont échoué).
  void _armIncomingRingSafety() {
    _cancelIncomingRingSafety();
    _incomingRingSafetyTimer = Timer(_incomingRingSafety, () async {
      if (_status != CallStatus.incoming) return;
      debugPrint('[CallService] ⏰ Sonnerie entrante sans réponse → arrêt de sécurité');
      await _ringtone.stop();
      // `_currentCallId` est nul pour une invitation de groupe : le filet se
      // déclenchait alors sans rien débloquer. `_activeIncomingPresentationCallId`
      // retombe sur `_groupRoomId`, comme partout ailleurs.
      await notifyCallEndedFromExternal(
        callId: _activeIncomingPresentationCallId,
      );
    });
  }

  /// App envoyée en arrière-plan pendant un entrant qui sonne au premier plan :
  /// claim CallKit, coupe RingtoneService, affiche CallKit pour le même callId
  /// même si le FCM a déjà été consommé / est en retard — JAMAIS reject_call.
  Future<void> handleForegroundIncomingBackgrounded() async {
    if (kIsWeb) return;
    if (_status != CallStatus.incoming || _isAutoAnsweringFromPush) return;
    final presentationId = _activeIncomingPresentationCallId;
    if (presentationId == null || presentationId.isEmpty) return;

    // Couper la sonnerie Dart d'abord, et sans condition : quoi que décide
    // l'arbitrage, l'application part en arrière-plan et cette sonnerie-là ne
    // doit pas y continuer.
    await _ringtone.stop();

    if (_resolveIncomingPresentation(
          callId: presentationId,
          intent: IncomingPresentationIntent.handoffToNative,
        ) !=
        IncomingPresentationAction.handoffToNative) {
      debugPrint('[CallService] 🛡 bascule vers CallKit refusée: $presentationId');
      return;
    }

    final callerId = _remoteUserId?.toString() ?? '';
    final isGroup = _groupRoomId != null && _groupRoomId!.isNotEmpty;
    if (!isGroup && callerId.isEmpty) return;

    // Forcer CallKit pour ce callId (idempotent si déjà affiché via FCM).
    unawaited(
      _callKit
          .showIncoming(
            callId: presentationId,
            callerId: callerId,
            callerName: _remoteUserName ??
                (isGroup ? resolveL10n().groupCall : resolveL10n().callNoun),
            callerPhoto: _remoteUserPhoto,
            isVideo: _isVideo,
            roomId: isGroup ? _groupRoomId : null,
            sessionKind: _confSessionId != null ? 'conference' : null,
            mode: _confSessionId != null ? _confMode : null,
          )
          .catchError((Object e) {
        debugPrint('[CallService] handoff CallKit (background) échoué: $e');
      }),
    );
  }

  /// Retour au premier plan pendant un entrant : dismiss CallKit programmatique
  /// (pas un refus), claim Flutter, puis notify pour ouvrir IncomingCallScreen.
  Future<void> resumeForegroundIncoming() async {
    if (kIsWeb) return;
    if (_status != CallStatus.incoming || _isAutoAnsweringFromPush) return;
    final presentationId = _activeIncomingPresentationCallId;
    if (presentationId == null || presentationId.isEmpty) return;

    if (_resolveIncomingPresentation(
          callId: presentationId,
          intent: IncomingPresentationIntent.handoffToFlutter,
        ) !=
        IncomingPresentationAction.handoffToFlutter) {
      debugPrint('[CallService] 🛡 bascule vers Flutter refusée: $presentationId');
      return;
    }

    await dismissIncomingCallKitForForeground();
    if (_status == CallStatus.incoming && !_isAutoAnsweringFromPush) {
      unawaited(
        _ringtone
            .startIncomingRingtone(
              override: _remoteUserId == null
                  ? null
                  : ListRingtonePreferences.resolveCall(_remoteUserId!),
            )
            .catchError((Object e) {
          debugPrint('[CallService] reprise sonnerie (foreground) échouée: $e');
        }),
      );
      _armIncomingRingSafety();
    }
    notify();
  }

  /// Borne l'attente de l'offre WebRTC après acceptation d'un appel entrant : si
  /// aucune offre n'arrive (appel périmé / rejeu fantôme), on démonte proprement
  /// au lieu de laisser « connexion en cours » tourner indéfiniment.
  void _armAwaitingOfferTimeout() {
    _cancelAwaitingOfferTimeout();
    _awaitingOfferTimer = Timer(_awaitingOfferTimeout, () async {
      // Un entrant en status=incoming SANS offre bufferisée n'a jamais été
      // confirmé vivant par le socket (l'offre WebRTC arrive avec incoming_call).
      // Passé le délai, on démonte : soit l'appel est périmé/terminé (écran
      // fantôme « Inconnu » après un appel manqué), soit l'auto-réponse ne pourra
      // jamais aboutir. Couvre le cold-start CallKit (prepare/accept) et le rejeu.
      final stillWaiting =
          _status == CallStatus.incoming && _pendingOffer == null;
      if (!stillWaiting) return;
      final wasAnswering = _isAutoAnsweringFromPush || _autoAnswerOnNextIncoming;
      debugPrint(
        '[CallService] ⏰ Offre entrante jamais reçue → teardown (answering=$wasAnswering)',
      );
      if (wasAnswering) _errorMessage = LocaleController.instance.l10n.callFailed;
      await _terminateCall();
      if (wasAnswering) {
        _showTransientMessage(LocaleController.instance.l10n.callFailed);
      }
    });
  }

  /// Résout le nom (et la photo) du correspondant 1-à-1 quand le payload d'appel
  /// ne les fournit pas, pour éviter un écran « Inconnu » (miroir du fallback
  /// roster de groupe). No-op si le nom est déjà connu ou l'id absent.
  void _ensureRemoteIdentityResolved() {
    final id = _remoteUserId;
    if (id == null) return;
    if (_remoteUserName != null && _remoteUserName!.trim().isNotEmpty) return;
    _apiClient.getUserById(id).then((u) {
      if (_remoteUserId != id) return; // l'appel a changé entre-temps
      final nom = (u['nom'] as String?)?.trim() ?? '';
      final pseudo = (u['pseudo'] as String?)?.trim() ?? '';
      final resolved = nom.isNotEmpty ? nom : pseudo;
      if (resolved.isEmpty) return;
      _remoteUserName = resolved;
      _remoteUserPhoto ??= normalizeBackendUrl(u['avatar_url'] as String?);
      _remoteTypeCompte = (u['type_compte'] as num?)?.toInt() ?? 0;
      _remoteAccountType = (u['account_type'] as num?)?.toInt() ?? 0;
      _remoteVerificationStatus =
          (u['verification_status'] as num?)?.toInt() ?? 0;
      notify();
    }).catchError((Object e) {
      debugPrint('[CallService] _ensureRemoteIdentityResolved($id) échec: $e');
    });
  }

  /// Affiche un message transitoire (occupé / pas de réponse / échec) via le
  /// ScaffoldMessenger racine — indépendant de l'écran courant.
  void _showTransientMessage(String message) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('[CallService] ⚠ messenger indisponible: "$message"');
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  /// Vérifie réseau OS + socket avant un appel sortant.
  /// Affiche un popup si la connexion n'est pas complète et retourne `false`.
  Future<bool> _ensureFullyConnectedForOutgoingCall() async {
    bool hasNetwork = true;
    try {
      hasNetwork = await _connectivity.currentNetwork;
    } catch (e) {
      debugPrint('[CallService] Lecture réseau échouée: $e');
      hasNetwork = false;
    }
    if (!hasNetwork) {
      debugPrint('[CallService] Appel bloqué (pas de réseau OS)');
      await _showCallBlockedDialog(_offlineCallMessage);
      return false;
    }

    final socketReady = await _apiClient.ensureSocketReady();
    if (socketReady) return true;

    debugPrint(
      '[CallService] Appel bloqué (réseau=$hasNetwork '
      'socketReady=${_apiClient.isSocketReady})',
    );
    await _showCallBlockedDialog(_serverCallMessage);
    return false;
  }

  Future<void> _showCallBlockedDialog(String message) async {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _showTransientMessage(message);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleController.instance.l10n.connectionRequired),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(LocaleController.instance.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Seul `_durationTimer` était annulé : sept autres minuteries survivaient à
    // la destruction du service. Portée limitée en production — le service vit
    // aussi longtemps que l'application — mais toute réinstanciation, en test
    // ou au redémarrage à chaud, laissait derrière elle des rappels armés sur
    // un objet détruit.
    _durationTimer?.cancel();
    _cancelOutgoingTimeout();
    _cancelAwaitingOfferTimeout();
    _cancelIncomingRingSafety();
    _cancelOutgoingRestoreTimeout();
    _cancelAllReconnectTimers();
    _cancelAllGroupPeerDisconnectGrace();
    _clearTransferCountdown();
    _stopWatchingAudioOutputs();

    speakingDetector.dispose();
    unawaited(_webrtc.dispose());
    unawaited(_ringtone.stop());
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    super.dispose();
  }
}