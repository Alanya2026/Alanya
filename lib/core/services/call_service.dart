import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../screens/calls/ongoing_call_screen.dart';
import '../../core/call_limits.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'audio_helper.dart' as audio;
import 'callkit_service.dart';
import 'call_session_guard.dart';
import 'ringtone_service.dart';
import 'webrtc_service.dart';
import 'call/speaking_detector.dart'; // détection locale du locuteur actif
import '../navigation/app_navigator.dart';
import '../utils/backend_url.dart';
import 'connectivity_service.dart';
import 'meeting_service.dart';
import '../theme/locale_controller.dart';
import 'chat/message_sound_service.dart';
import 'call/ended_call_registry.dart';
import 'call/pending_call_reject_store.dart';
import 'call/pending_outgoing_call_store.dart';
import 'call/call_conf_routing.dart';

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

/// Aligné sur TalkyFirebaseMessagingService (Android V2).
const bool _kAndroidNativeCallNotifications = bool.fromEnvironment(
  'TALKY_ANDROID_NATIVE_NOTIF_V2',
  defaultValue: true,
);

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, ended }

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

  bool _callEndedByUs = false;

  // Contrôles médias
  bool _isMuted = false;
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

  // Roster de l'appel de groupe (userId → infos d'affichage).
  final Map<String, GroupParticipantInfo> _groupRoster = {};

  //  « Ajouter à l'appel » — session à trois (join / transfer)
  //
  // Un appel 1-à-1 ordinaire n'a pas de session. Elle naît au premier ajout et
  // porte à elle seule le droit d'ajout : tant que _confSessionId est posé, le
  // bouton reste caché — y compris après un départ, le droit étant consommé
  // définitivement. Un échec d'invitation l'efface, ce qui rend le droit.
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
  /// demander pourquoi, et « quelqu'un a déjà utilisé l'ajout » n'a aucune action
  /// de rattrapage à proposer.
  bool get canAddParticipant =>
      _status == CallStatus.connected &&
      _confSessionId == null &&      // droit ni verrouillé ni consommé
      _groupRoomId == null &&        // pas un appel de groupe
      _remoteUserId != null &&       // bien à deux
      !_isMeetingActive();

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

  /// Vrai si l'app est au premier plan (ou état inconnu au tout début du boot).
  /// Sert à choisir la source de sonnerie entrante : RingtoneService en
  /// foreground, CallKit en background/app fermée (source unique).
  bool get _isAppForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  bool get isAppInForeground => _isAppForeground;

  /// Android V2 : CallKit entrant affiché côté natif en arrière-plan.
  bool get _nativeAndroidHandlesIncomingCallUi =>
      !kIsWeb &&
      Platform.isAndroid &&
      _kAndroidNativeCallNotifications;

  /// Retire l'UI CallKit sans refuser l'appel (migration premier plan).
  Future<void> dismissIncomingCallKitForForeground() async {
    if (kIsWeb || !_isAppForeground) return;
    final id = _currentCallId;
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

  /// Vrai si une session d'appel sortant/en cours correspond au [callId] CallKit.
  bool matchesActiveOutgoingSession(String callId) {
    if (callId.isEmpty || _currentCallId != callId) return false;
    return _status == CallStatus.outgoing ||
        _status == CallStatus.connecting ||
        _status == CallStatus.connected;
  }

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
    if (callId == null || callId.isEmpty) return;
    final now = DateTime.now();
    _handledTerminalCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 120);
    _handledTerminalCallIds[callId] = now;
    // Persisté pour l'isolate FCM background (course call vs call_ended).
    unawaited(EndedCallRegistry.markEnded(callId));
  }

  bool _isTerminalCallId(String? callId) {
    if (callId == null || callId.isEmpty) return false;
    final now = DateTime.now();
    _handledTerminalCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 120);
    return _handledTerminalCallIds.containsKey(callId);
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
      await notifyCallEndedFromExternal(callId: _currentCallId);
    });
  }

  /// App envoyée en arrière-plan pendant un entrant qui sonne au premier plan :
  /// on coupe la sonnerie Dart et on bascule sur CallKit pour que l'OS continue
  /// de sonner et que l'appel reste décrochable depuis la notification/lockscreen
  /// (comportement WhatsApp) — sinon la sonnerie tournerait sans UI.
  Future<void> handleForegroundIncomingBackgrounded() async {
    if (kIsWeb) return;
    if (_status != CallStatus.incoming || _isAutoAnsweringFromPush) return;
    await _ringtone.stop();
    final callerId = _remoteUserId?.toString() ?? '';
    final isGroup = _groupRoomId != null && _groupRoomId!.isNotEmpty;
    if (!isGroup && callerId.isEmpty) return;
    unawaited(
      _callKit
          .showIncoming(
            callId: isGroup ? _groupRoomId! : (_currentCallId ?? ''),
            callerId: callerId,
            callerName: _remoteUserName ??
                (isGroup ? resolveL10n().groupCall : resolveL10n().callNoun),
            callerPhoto: _remoteUserPhoto,
            isVideo: _isVideo,
            roomId: isGroup ? _groupRoomId : null,
          )
          .catchError((Object e) {
        debugPrint('[CallService] handoff CallKit (background) échoué: $e');
      }),
    );
  }

  /// Retour au premier plan pendant un entrant : retire l'UI CallKit et relance
  /// la sonnerie Dart (l'écran d'appel entrant Flutter reprend la main).
  Future<void> resumeForegroundIncoming() async {
    if (kIsWeb) return;
    if (_status != CallStatus.incoming || _isAutoAnsweringFromPush) return;
    await dismissIncomingCallKitForForeground();
    if (_status == CallStatus.incoming && !_isAutoAnsweringFromPush) {
      unawaited(_ringtone.startIncomingRingtone().catchError((Object e) {
        debugPrint('[CallService] reprise sonnerie (foreground) échouée: $e');
      }));
      _armIncomingRingSafety();
    }
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
    _durationTimer?.cancel();
    speakingDetector.dispose();
    _webrtc.dispose();
    _ringtone.stop();
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    super.dispose();
  }
}