import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'audio_helper.dart' as audio;
import 'callkit_service.dart';
import 'ringtone_service.dart';
import 'webrtc_service.dart';
import 'call/speaking_detector.dart'; // détection locale du locuteur actif

// Endpoints répartis par domaine (mêmes librairie/membres privés) :
part 'call/call_incoming.dart';   // entrées push / CallKit
part 'call/call_signaling.dart';  // listeners socket.io
part 'call/call_one_to_one.dart'; // appels 1-à-1
part 'call/call_group.dart';      // appels de groupe
part 'call/call_controls.dart';   // contrôles médias + timer

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, ended }

/// Infos minimales d'un participant d'appel de groupe (pour l'UI grille).
class GroupParticipantInfo {
  final String id;
  final String name;
  final String? photo;
  const GroupParticipantInfo({required this.id, required this.name, this.photo});
}

class CallService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final WebRTCService _webrtc = WebRTCService();
  final RingtoneService _ringtone = RingtoneService.instance;
  final CallKitService _callKit = CallKitService.instance;

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