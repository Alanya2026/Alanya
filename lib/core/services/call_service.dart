import 'dart:async';
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

// Endpoints répartis par domaine (mêmes librairie/membres privés) :
part 'call/call_incoming.dart';   // entrées push / CallKit
part 'call/call_signaling.dart';  // listeners socket.io
part 'call/call_one_to_one.dart'; // appels 1-à-1
part 'call/call_group.dart';      // appels de groupe
part 'call/call_controls.dart';   // contrôles médias + timer
part 'call/call_session.dart';    // session audio / foreground en veille
part 'call/call_ui.dart';         // bannière / minimiser l'écran d'appel

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, ended }

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

  static const String _offlineCallMessage =
      'Impossible de passer un appel, vérifiez votre connexion à internet et réessayez.';

  CallStatus _status = CallStatus.idle;
  int? _remoteUserId;
  String? _remoteUserName;
  String? _remoteUserPhoto;
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

  // Auto-réponse (CallKit pré-accepté)
  bool _autoAnswerOnNextIncoming = false;
  String? _autoAnswerCallerId;
  final Map<String, DateTime> _recentIncomingCallIds = {};

  // Auto-réponse depuis une notification/CallKit : on saute l'écran d'appel
  // entrant (IncomingCallScreen) et on ouvre directement l'écran d'appel actif.
  bool _isAutoAnsweringFromPush = false;

  // Filet de sécurité local : si aucun état terminal serveur (call_answered,
  // call_busy, call_no_answer, call_rejected…) n'arrive, on abandonne l'appel.
  Timer? _outgoingTimeoutTimer;
  static const Duration _outgoingTimeout = Duration(seconds: 50);

  // callId déjà traités (acceptés/refusés) — évite de re-sonner sur un
  // incoming_call rejoué par le backend (auth replay).
  final Map<String, DateTime> _handledTerminalCallIds = {};

  // File d'attente des refus émis avant que le socket soit prêt (cold start /
  // decline depuis la notification). Rejoués à l'authentification du socket.
  final Set<String> _pendingRejectCallerIds = {};

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
              typeCompte: 0,
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

  bool _alreadyHandledIncomingCallId(String? callId) {
    if (callId == null || callId.isEmpty) return false;
    final now = DateTime.now();
    _recentIncomingCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 90);
    if (_recentIncomingCallIds.containsKey(callId)) return true;
    _recentIncomingCallIds[callId] = now;
    return false;
  }

  /// Mémorise un callId ayant atteint un état terminal (accepté/refusé) pour
  /// ignorer un `incoming_call` rejoué par le backend.
  void _markTerminalCallId(String? callId) {
    if (callId == null || callId.isEmpty) return;
    final now = DateTime.now();
    _handledTerminalCallIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 120);
    _handledTerminalCallIds[callId] = now;
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
    final fullyConnected = hasNetwork && _apiClient.isSocketConnected;
    if (fullyConnected) return true;

    debugPrint(
      '[CallService] Appel bloqué (réseau=$hasNetwork '
      'socket=${_apiClient.isSocketConnected})',
    );
    await _showOfflineCallDialog();
    return false;
  }

  Future<void> _showOfflineCallDialog() async {
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _showTransientMessage(_offlineCallMessage);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text(_offlineCallMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
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