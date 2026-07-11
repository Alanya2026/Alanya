import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, ChangeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../screens/meetings/ongoing_meet_screen.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'call/speaking_detector.dart';
import 'call_session_guard.dart';
import 'callkit_service.dart';
import '../navigation/app_navigator.dart';

enum MeetingStatus { idle, joining, connected, ended }

class ChatMessage {
  final String userId;
  final String message;
  final DateTime sendAt;

  ChatMessage({
    required this.userId,
    required this.message,
    required this.sendAt,
  });
}

class MeetingService extends ChangeNotifier {
  final TalkyApiClient _apiClient;

  // État de la réunion
  MeetingStatus _status = MeetingStatus.idle;
  Meeting? _currentMeeting;

  // Médias locaux & WebRTC peers 
  MediaStream? _localStream; 
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Streams distants 
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<RTCIceCandidate>> _pendingIceByPeer = {};
  final Set<String> _remoteDescSetForPeer = <String>{};

  // Contrôles
  bool _isMuted = false;
  bool _isVideoOff = false;

  // États mute des participants distants (userId → isMuted)
  final Map<String, bool> _remoteMutedStates = {};

  // États caméra des participants distants (userId → isVideoOff)
  final Map<String, bool> _remoteVideoStates = {};

  // ID local pendant la réunion + attente confirmation room_joined
  String? _myId;
  Completer<void>? _roomJoinCompleter;

  // Timer de durée
  Timer? _durationTimer;
  int _meetingDuration = 0;

  // Messages in-meeting
  final List<ChatMessage> _chatMessages = [];

  // Noms des participants connectés (alanyaID → nom affiché).
  final Map<String, String> _participantRoster = {};

  // UI minimisée (bannière flottante active).
  bool _isMeetingUiMinimized = false;
  bool _isMeetingUiRouteOpen = false;

  // Détection locale du locuteur actif (mesh meeting).
  final SpeakingDetector speakingDetector = SpeakingDetector();

  // Getters 
  MeetingStatus get status => _status;
  Meeting? get currentMeeting => _currentMeeting;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  Map<String, bool> get remoteMutedStates => Map.unmodifiable(_remoteMutedStates);
  bool isParticipantMuted(String userId) => _remoteMutedStates[userId] ?? false;
  Map<String, bool> get remoteVideoStates => Map.unmodifiable(_remoteVideoStates);
  bool isParticipantVideoOff(String userId) => _remoteVideoStates[userId] ?? false;
  int get meetingDuration => _meetingDuration;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  Map<String, String> get participantRoster => Map.unmodifiable(_participantRoster);

  /// Résout le nom affiché d'un participant (liste API + roster temps réel).
  String participantDisplayName(String userId) {
    final participant = _currentMeeting?.participants
        .where((p) => p.participantID.toString() == userId)
        .firstOrNull;
    final fromList = participant?.nom ?? participant?.pseudo;
    if (fromList != null && fromList.isNotEmpty) return fromList;
    final fromRoster = _participantRoster[userId];
    if (fromRoster != null && fromRoster.isNotEmpty) return fromRoster;
    return 'User $userId';
  }

  /// URL d'avatar d'un participant (liste API + organisateur).
  String? participantAvatarUrl(String userId) {
    final meeting = _currentMeeting;
    if (meeting == null) return null;
    if (meeting.idOrganiser.toString() == userId) {
      return meeting.organiserAvatar;
    }
    final participant = meeting.participants
        .where((p) => p.participantID.toString() == userId)
        .firstOrNull;
    return participant?.avatarUrl;
  }

  Set<String> get activeSpeakers => speakingDetector.activeSpeakers;
  bool get amISpeaking => speakingDetector.amISpeaking;
  bool isUserSpeaking(String userId) => speakingDetector.isSpeaking(userId);

  bool get isMeetingActive =>
      _status == MeetingStatus.joining || _status == MeetingStatus.connected;

  bool get isMeetingUiMinimized => _isMeetingUiMinimized;

  bool get isMeetingUiRouteOpen => _isMeetingUiRouteOpen;

  bool get shouldShowMeetingBanner =>
      isMeetingActive && _isMeetingUiMinimized;

  void markMeetingUiVisible() {
    _isMeetingUiRouteOpen = true;
    _isMeetingUiMinimized = false;
    notifyListeners();
  }

  void markMeetingUiMinimized() {
    _isMeetingUiRouteOpen = false;
    _isMeetingUiMinimized = true;
    notifyListeners();
  }

  void markMeetingUiClosed() {
    _isMeetingUiRouteOpen = false;
    notifyListeners();
  }

  Future<void> showMeetingScreen() async {
    if (!isMeetingActive || _isMeetingUiRouteOpen) return;

    final navigator = appNavigator;
    if (navigator == null) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => const OngoingMeetScreen()),
    );

    markMeetingUiClosed();
    if (isMeetingActive && !_isMeetingUiMinimized) {
      markMeetingUiMinimized();
    }
  }

  Future<void> navigateToMeetingUi([BuildContext? context]) async {
    if (context != null && !context.mounted) return;
    if (!isMeetingActive || _isMeetingUiRouteOpen) return;
    await showMeetingScreen();
  }

  MeetingService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _setupSocketListeners();
    // Le détecteur est un ChangeNotifier séparé : on relaie ses
    // changements pour que les écrans (Consumer<MeetingService>) se
    // reconstruisent quand le locuteur actif change.
    speakingDetector.addListener(notifyListeners);
  }


  void _setupSocketListeners() {
    // Confirmation que la room a été rejointe (inclut snapshot muteStates)
    _apiClient.onSocketEvent(SocketEvents.meetingRoomJoined, (data) {
      debugPrint('[MeetingService] Room rejointe: $data');
      if (data is Map) {
        _applyMuteStatesSnapshot(data['muteStates']);
        _applyVideoStatesSnapshot(data['videoStates']);
        notifyListeners();
      }
      if (_roomJoinCompleter != null && !_roomJoinCompleter!.isCompleted) {
        _roomJoinCompleter!.complete();
      }
    });

    // Un nouveau participant vient de rejoindre → enrichir le roster + WebRTC
    _apiClient.onSocketEvent(SocketEvents.meetingUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userID']?.toString();
      if (userId == null) return;

      var changed = false;
      final displayName = data['userName']?.toString() ??
          data['nom']?.toString() ??
          data['pseudo']?.toString();
      if (displayName != null && displayName.isNotEmpty) {
        _participantRoster[userId] = displayName;
        changed = true;
      }

      if (data.containsKey('isMuted')) {
        _applyRemoteMuteState(userId, data['isMuted'] == true);
        changed = true;
      }

      if (data.containsKey('isVideoOff')) {
        _remoteVideoStates[userId] = data['isVideoOff'] == true;
        changed = true;
      }

      if (changed) notifyListeners();

      // Informer le nouvel arrivant de nos états micro/caméra actuels
      _broadcastMuteState();
      _broadcastVideoState();

      if (_peerConnections.containsKey(userId)) return;
      await _createPeerAndOffer(userId);
    });

    // Un participant quitte
    _apiClient.onSocketEvent(SocketEvents.meetingUserLeft, (data) {
      if (data is! Map) return;
      final userId = data['userID']?.toString();
      if (userId != null) {
        _participantRoster.remove(userId);
        _removePeer(userId);
      }
    });

    // Réunion terminée par l'organisateur
    _apiClient.onSocketEvent(SocketEvents.meetingEnded, (_) {
      _terminateMeeting(emitLeave: false);
    });

    // Message chat in-meeting
    _apiClient.onSocketEvent(SocketEvents.meetingMessage, (data) {
      if (data is! Map) return;
      _chatMessages.add(ChatMessage(
        userId: data['userID']?.toString() ?? '',
        message: data['message']?.toString() ?? '',
        sendAt: DateTime.tryParse(data['sendAt']?.toString() ?? '') ?? DateTime.now(),
      ));
      notifyListeners();
    });

    // WebRTC : offer reçue d'un pair
    _apiClient.onSocketEvent(SocketEvents.meetingOffer, (data) async {
      if (data is! Map) return;
      // !! Champ correct du backend : fromUserID
      final fromUserId = data['fromUserID']?.toString();
      final offer = data['offer'] as Map?;
      if (fromUserId == null || offer == null) return;
      await _handleOffer(fromUserId, offer);
    });

    // WebRTC : answer reçue d'un pair
    _apiClient.onSocketEvent(SocketEvents.meetingAnswer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserID']?.toString();
      final answer = data['answer'] as Map?;
      if (fromUserId == null || answer == null) return;
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        _remoteDescSetForPeer.add(fromUserId);
        await _flushPendingIce(fromUserId);
      }
    });

    // WebRTC : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.meetingIceCandidate, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserID']?.toString();
      final c = data['candidate'] as Map?;
      if (fromUserId == null || c == null) return;
      final candidate = RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      final pc = _peerConnections[fromUserId];
      if (pc == null || !_remoteDescSetForPeer.contains(fromUserId)) { 
        _pendingIceByPeer.putIfAbsent(fromUserId, () => []).add(candidate);
        return;
      }
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[MeetingService] addCandidate échoué pour $fromUserId: $e');
      }
    });

    // Mute state : un participant a coupé/réactivé son micro
    _apiClient.onSocketEvent(SocketEvents.meetingMuteState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isMuted = data['isMuted'] == true;
      if (userId == null) return;
      debugPrint('[MeetingService] 🎙 Mute state: userId=$userId isMuted=$isMuted');
      _applyRemoteMuteState(userId, isMuted);
      notifyListeners();
    });

    // Video state : un participant a coupé/réactivé sa caméra
    _apiClient.onSocketEvent(SocketEvents.meetingVideoState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isVideoOff = data['isVideoOff'] == true;
      if (userId == null) return;
      debugPrint('[MeetingService] 📷 Video state: userId=$userId isVideoOff=$isVideoOff');
      _remoteVideoStates[userId] = isVideoOff;
      notifyListeners();
    });
  }

  void _applyRemoteMuteState(String userId, bool isMuted) {
    _remoteMutedStates[userId] = isMuted;
    speakingDetector.setSpeakerMuted(userId, isMuted);
  }

  void _applyMuteStatesSnapshot(dynamic muteStates) {
    if (muteStates is! Map) return;
    muteStates.forEach((key, value) {
      _applyRemoteMuteState(key.toString(), value == true);
    });
  }

  void _applyVideoStatesSnapshot(dynamic videoStates) {
    if (videoStates is! Map) return;
    videoStates.forEach((key, value) {
      _remoteVideoStates[key.toString()] = value == true;
    });
  }

  void _syncLocalMediaFromTracks() {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      _isMuted = !audioTracks.first.enabled;
      speakingDetector.setSpeakerMuted(SpeakingDetector.localKey, _isMuted);
    }
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      _isVideoOff = !videoTracks.first.enabled;
    }
  }

  void _broadcastMuteState() {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingMuteState, {
      'meetingId': _currentMeeting!.idMeeting,
      'isMuted': _isMuted,
    });
  }

  void _broadcastVideoState() {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingVideoState, {
      'meetingId': _currentMeeting!.idMeeting,
      'isVideoOff': _isVideoOff,
    });
  }

  Future<void> _flushPendingIce(String userId) async {
    final pc = _peerConnections[userId];
    final pending = _pendingIceByPeer.remove(userId);
    if (pc == null || pending == null || pending.isEmpty) return;
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('[MeetingService] addCandidate (flush) échoué pour $userId: $e');
      }
    }
  }

  Future<List<Meeting>> getMeetings() async {
    final data = await _apiClient.getMeetings();
    return data
        .whereType<Map<String, dynamic>>()
        .map(Meeting.fromJson)
        .toList();
  }

  /// Recharge les détails de la réunion en cours (participants avec noms).
  Future<void> refreshCurrentMeeting() async {
    final id = _currentMeeting?.idMeeting;
    if (id == null) return;
    await _reloadCurrentMeeting(id);
  }

  /// Invite des participants puis rafraîchit la liste locale.
  Future<void> inviteParticipants(List<int> participantIds) async {
    final id = _currentMeeting?.idMeeting;
    if (id == null || participantIds.isEmpty) return;
    await _apiClient.inviteParticipants(id, participantIds);
    await _reloadCurrentMeeting(id);
  }

  Future<void> _reloadCurrentMeeting(int idMeeting) async {
    try {
      final data = await _apiClient.getMeeting(idMeeting);
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();
      notifyListeners();
    } catch (e) {
      debugPrint('[MeetingService] Erreur reload meeting: $e');
    }
  }

  void _seedRosterFromMeeting() {
    final meeting = _currentMeeting;
    if (meeting == null) return;

    final organiserName = meeting.organiserNom ?? meeting.organiserPseudo;
    if (organiserName != null && organiserName.isNotEmpty) {
      _participantRoster[meeting.idOrganiser.toString()] = organiserName;
    }

    for (final p in meeting.participants) {
      final name = p.nom ?? p.pseudo;
      if (name != null && name.isNotEmpty) {
        _participantRoster[p.participantID.toString()] = name;
      }
    }
  }

  Future<void> createAndJoin({
    required String objet,
    required String startTime, 
    required String room,
    required int myId,
    required String myName,
    int duree = 60,
    int typeMedia = 0,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      final data = await _apiClient.createMeeting(
        objet: objet,
        startTime: startTime,
        room: room,
        duree: duree,
        typeMedia: typeMedia,
      );
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();
      await _apiClient.joinMeetingHttp(_currentMeeting!.idMeeting);
      await _reloadCurrentMeeting(_currentMeeting!.idMeeting);
      await _joinRoom(myId: myId, myName: myName);
    } catch (e) {
      debugPrint('[MeetingService] Erreur createAndJoin: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  /// Prépare le stream local (caméra/micro) avant de rejoindre
  Future<MediaStream?> prepareLocalMedia({required bool video}) async {
    if (_localStream != null) return _localStream;
    try {
      if (!kIsWeb) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          throw Exception('Permission microphone refusée');
        }
        if (video) {
          await Permission.camera.request();
        }
      }

      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        if (video)
          'video': {
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
            'frameRate': {'ideal': 30},
          },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isVideoOff = !video;
      debugPrint('[MeetingService] !! prepareLocalMedia: ${_localStream?.getTracks().length} tracks');
      notifyListeners();
      return _localStream;
    } catch (e) {
      debugPrint('[MeetingService] ** prepareLocalMedia: $e');
      return null;
    }
  }

  /// Libère le stream préparé si l'utilisateur quitte le lobby sans rejoindre.
  Future<void> releaseLocalMediaIfNotJoined() async {
    if (_status == MeetingStatus.connected || _status == MeetingStatus.joining) {
      return; 
    }
    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) {
        await t.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    _isVideoOff = false;
    notifyListeners();
  }

  /// Rejoint une réunion existante par son [idMeeting].
  /// [myId] est le alanyaID de l'utilisateur connecté.
  /// Si [prepareLocalMedia] a déjà été appelé, le stream existant est réutilisé.
  Future<void> joinMeeting({
    required int idMeeting,
    required int myId,
    required String myName,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      // Récupérer les détails de la réunion
      final data = await _apiClient.getMeeting(idMeeting);
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();

      // Rejoindre en DB
      await _apiClient.joinMeetingHttp(idMeeting);

      // Rejoindre la room socket
      await _joinRoom(myId: myId, myName: myName);
    } catch (e) {
      debugPrint('[MeetingService] Erreur joinMeeting: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  /// Rejoindre par code de room (cherche dans la liste des réunions).
  Future<void> joinByRoom({
    required String roomCode,
    required int myId,
    required String myName,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      // Résolution par code côté serveur : fonctionne même si on n'est pas
      // encore participant (contrairement à getMeetings qui filtre).
      final data = await _apiClient.getMeetingByRoom(roomCode);
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();

      await _apiClient.joinMeetingHttp(_currentMeeting!.idMeeting);
      await _joinRoom(myId: myId, myName: myName);
    } catch (e) {
      debugPrint('[MeetingService] Erreur joinByRoom: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinRoom({required int myId, required String myName}) async {
    if (_localStream == null) {
      await _initLocalStream();
    }

    _myId = myId.toString();
    _syncLocalMediaFromTracks();

    if (myName.isNotEmpty) {
      _participantRoster[_myId!] = myName;
    }

    _roomJoinCompleter = Completer<void>();
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinRoom, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId,
      'userName': myName,
      'isMuted': _isMuted,
      'isVideoOff': _isVideoOff,
    });

    try {
      await _roomJoinCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      debugPrint('[MeetingService] Timeout attente room_joined');
    } finally {
      _roomJoinCompleter = null;
    }

    _broadcastMuteState();
    _broadcastVideoState();

    _status = MeetingStatus.connected;
    _startDurationTimer();
    speakingDetector.start(() => _peerConnections);

    if (!kIsWeb && _currentMeeting != null) {
      final isVideo = _currentMeeting!.typeMedia == 0;
      await CallSessionGuard.instance.acquire(
        mode: isVideo ? SessionMode.video : SessionMode.audio,
        callId: 'meeting_${_currentMeeting!.idMeeting}',
        displayName: _currentMeeting!.objet,
        handle: _currentMeeting!.room,
        isVideo: isVideo,
        getLocalStream: () => _localStream,
        isVideoOn: () => !_isVideoOff,
        isMuted: () => _isMuted,
      );
      await CallSessionGuard.instance.markConnected();
    }

    notifyListeners();
  }
 

  /// Envoie un message chat dans la réunion.
  void sendChatMessage(String message, int myId) {
    if (_currentMeeting == null) return;

    // !! Champs corrects : meetingID, userID
    _apiClient.sendSocketEvent(SocketEvents.meetingChat, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId.toString(),
      'message': message,
    });
  }

  /// Termine la réunion pour tout le monde (organisateur seulement).
  Future<void> endMeetingForAll() async {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingEnd, {
      'meetingID': _currentMeeting!.idMeeting,
    });
    await _terminateMeeting(emitLeave: false);
  }

  /// Quitte la réunion (côté participant).
  Future<void> leaveMeeting() async {
    await _terminateMeeting(emitLeave: true);
  }

  Future<void> _terminateMeeting({required bool emitLeave}) async {
    if (emitLeave && _currentMeeting != null) {
      // !! Payload exact : meetingID
      _apiClient.sendSocketEvent(SocketEvents.meetingLeave, {
        'meetingID': _currentMeeting!.idMeeting,
      });
      // Mettre à jour l'état en DB
      try {
        await _apiClient.leaveMeetingHttp(_currentMeeting!.idMeeting);
      } catch (e) {
        debugPrint('[MeetingService] leaveMeetingHttp error: $e');
      }
    }

    // Le statut DOIT passer à `ended` même si un imprévu survient dans le
    // cleanup, sinon l'écran de réunion ne se referme jamais (le listener et le
    // bouton dépendent de MeetingStatus.ended pour faire le pop()).
    try {
      await _cleanup();
    } catch (e) {
      debugPrint('[MeetingService] _cleanup error: $e');
    } finally {
      _status = MeetingStatus.ended;
      notifyListeners();
    }
  }

  // WEBRTC
  
  Future<void> _initLocalStream() async {
    try {
      debugPrint('[MeetingService] Initialisation du stream local...');
      debugPrint('[MeetingService] isWeb: $kIsWeb');

      final isVideoMeeting = _currentMeeting?.typeMedia == 0;

      // Demander les permissions si mobile
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          throw Exception('Permission microphone refusée');
        }

        if (isVideoMeeting) {
          final cameraStatus = await Permission.camera.request();
          if (!cameraStatus.isGranted) {
            debugPrint('[MeetingService] ** Permission caméra refusée');
          }
        }
      }

      // Obtenir le media stream avec constraints
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
      };

      if (isVideoMeeting) {
        constraints['video'] = {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
        };
      }

      debugPrint('[MeetingService] Appel getUserMedia avec contraintes: $constraints');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      if (!isVideoMeeting) _isVideoOff = true;
      debugPrint('[MeetingService] !! Stream local obtenu: ${_localStream?.getTracks().length} tracks');
      notifyListeners();
    } catch (e) {
      debugPrint('[MeetingService] ** Erreur _initLocalStream: $e');
      debugPrint('[MeetingService] Type: ${e.runtimeType}');

      String errorMsg = 'Erreur d\'accès aux médias';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission')) {
        errorMsg = 'Permission refusée pour le microphone/caméra';
      } else if (errorStr.contains('navigator') || errorStr.contains('getusermedia')) {
        errorMsg = 'Erreur d\'accès aux médias. Vérifiez HTTPS ou localhost.';
      } else if (errorStr.contains('notfounderror')) {
        errorMsg = 'Aucun appareil audio/vidéo trouvé';
      } else if (errorStr.contains('notreadableerror')) {
        errorMsg = 'Impossible d\'accéder aux appareils. Vérifiez les permissions.';
      }

      debugPrint('[MeetingService] Message d\'erreur: $errorMsg');
      rethrow;
    }
  }

  Future<void> _createPeerAndOffer(String userId) async {
    final pc = await _createPeerConnection(userId);

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // !! Champs corrects : meetingID, toUserID
    _apiClient.sendSocketEvent(SocketEvents.meetingOffer, {
      'meetingID': _currentMeeting!.idMeeting,
      'toUserID': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> _handleOffer(String fromUserId, Map offer) async {
    final pc = await _createPeerConnection(fromUserId);

    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, 'offer'),
    );
    _remoteDescSetForPeer.add(fromUserId);
    await _flushPendingIce(fromUserId);

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // !! Champs corrects : meetingID, toUserID
    _apiClient.sendSocketEvent(SocketEvents.meetingAnswer, {
      'meetingID': _currentMeeting!.idMeeting,
      'toUserID': fromUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    if (_peerConnections.containsKey(userId)) {
      return _peerConnections[userId]!;
    }

    final iceServers = await _apiClient.fetchIceServers();
    final pc = await createPeerConnection({'iceServers': iceServers});

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams[0];
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
      // !! Champs corrects : meetingID, toUserID
      _apiClient.sendSocketEvent(SocketEvents.meetingIceCandidate, {
        'meetingID': _currentMeeting!.idMeeting,
        'toUserID': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onConnectionState = (state) {
      debugPrint('[MeetingService] Peer $userId connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _removePeer(userId);
      }
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  void _removePeer(String userId) {
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteStreams.remove(userId);
    _pendingIceByPeer.remove(userId);
    _remoteDescSetForPeer.remove(userId);
    _remoteMutedStates.remove(userId);
    _remoteVideoStates.remove(userId);
    notifyListeners();
  }

  // MÉDIAS 

  Future<void> toggleMute() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final track = _localStream!.getAudioTracks().first;
      track.enabled = !track.enabled;
      _isMuted = !track.enabled;
      speakingDetector.setSpeakerMuted(SpeakingDetector.localKey, _isMuted);
      // Notifier les autres participants
      if (_currentMeeting != null) {
        _broadcastMuteState();
      }
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks().first;
      track.enabled = !track.enabled;
      _isVideoOff = !track.enabled;
      if (_currentMeeting != null) {
        _broadcastVideoState();
      }
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(track);
    }
  }

  // TIMER 
  void _startDurationTimer() {
    _meetingDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _meetingDuration++;
      notifyListeners();
    });
  }

  String get formattedDuration {
    final m = _meetingDuration ~/ 60;
    final s = _meetingDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // CLEANUP
  Future<void> _cleanup() async {
    speakingDetector.stop();
    final meetingCallId = _currentMeeting != null ? 'meeting_${_currentMeeting!.idMeeting}' : null;
    if (!kIsWeb) {
      await CallSessionGuard.instance.release();
      if (meetingCallId != null) {
        try {
          await CallKitService.instance.endCall(meetingCallId);
          debugPrint('[MeetingService] CallKit meeting fermé: $meetingCallId');
        } catch (e) {
          debugPrint('[MeetingService] endCall meeting error: $e');
        }
      }
    }
    // On copie puis on vide la map AVANT de fermer les connexions : pc.close()
    // déclenche onConnectionState -> _removePeer() qui modifie _peerConnections.
    // Itérer directement sur la map lèverait une ConcurrentModificationError et
    // interromprait le cleanup (d'où l'ancien bug du double-appui pour sortir).
    final peers = _peerConnections.values.toList();
    _peerConnections.clear();
    for (final pc in peers) {
      try {
        await pc.close();
      } catch (e) {
        debugPrint('[MeetingService] pc.close error: $e');
      }
    }
    _remoteStreams.clear();
    _pendingIceByPeer.clear();
    _remoteDescSetForPeer.clear();
    _chatMessages.clear();
    await _localStream?.dispose();
    _localStream = null;
    _durationTimer?.cancel();
    _meetingDuration = 0;
    _currentMeeting = null;
    _participantRoster.clear();
    _myId = null;
    _roomJoinCompleter = null;
    _isMuted = false;
    _isVideoOff = false;
    _remoteMutedStates.clear();
    _remoteVideoStates.clear();
    _isMeetingUiMinimized = false;
    _isMeetingUiRouteOpen = false;
  }

  @override
  void dispose() {
    _cleanup();
    speakingDetector.dispose();
    super.dispose();
  }
}