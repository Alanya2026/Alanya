import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, ChangeNotifier;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'call/speaking_detector.dart';

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

  // Timer de durée
  Timer? _durationTimer;
  int _meetingDuration = 0;

  // Messages in-meeting
  final List<ChatMessage> _chatMessages = [];

  // Détection locale du locuteur actif (mesh meeting).
  final SpeakingDetector speakingDetector = SpeakingDetector();

  // Getters 
  MeetingStatus get status => _status;
  Meeting? get currentMeeting => _currentMeeting;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  int get meetingDuration => _meetingDuration;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  Set<String> get activeSpeakers => speakingDetector.activeSpeakers;
  bool get amISpeaking => speakingDetector.amISpeaking;
  bool isUserSpeaking(String userId) => speakingDetector.isSpeaking(userId);

  MeetingService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _setupSocketListeners();
    // Le détecteur est un ChangeNotifier séparé : on relaie ses
    // changements pour que les écrans (Consumer<MeetingService>) se
    // reconstruisent quand le locuteur actif change.
    speakingDetector.addListener(notifyListeners);
  }


  void _setupSocketListeners() {
    // Confirmation que la room a été rejointe
    _apiClient.onSocketEvent(SocketEvents.meetingRoomJoined, (data) {
      debugPrint('[MeetingService] Room rejointe: $data');
    });

    // Un nouveau participant vient de rejoindre → initier l'échange WebRTC
    _apiClient.onSocketEvent(SocketEvents.meetingUserJoined, (data) async {
      if (data is! Map) return; 
      final userId = data['userID']?.toString();
      if (userId == null || _peerConnections.containsKey(userId)) return; 
      await _createPeerAndOffer(userId);
    });

    // Un participant quitte
    _apiClient.onSocketEvent(SocketEvents.meetingUserLeft, (data) {
      if (data is! Map) return;
      final userId = data['userID']?.toString();
      if (userId != null) _removePeer(userId);
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

  Future<void> createAndJoin({
    required String objet,
    required String startTime, 
    required String room,
    required int myId,
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
      await _apiClient.joinMeetingHttp(_currentMeeting!.idMeeting);
      await _joinRoom(myId: myId);
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

      // Rejoindre en DB
      await _apiClient.joinMeetingHttp(idMeeting);

      // Rejoindre la room socket
      await _joinRoom(myId: myId);
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

      await _apiClient.joinMeetingHttp(_currentMeeting!.idMeeting);
      await _joinRoom(myId: myId);
    } catch (e) {
      debugPrint('[MeetingService] Erreur joinByRoom: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinRoom({required int myId}) async {
    if (_localStream == null) {
      await _initLocalStream();
    }

    // !! Champs corrects : meetingID et userID (pas meetingId/userId)
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinRoom, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId,
    });

    _status = MeetingStatus.connected;
    _startDurationTimer();
    speakingDetector.start(() => _peerConnections);
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

    await _cleanup();
    _status = MeetingStatus.ended;
    notifyListeners();
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
    notifyListeners();
  }

  // MÉDIAS 

  Future<void> toggleMute() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final track = _localStream!.getAudioTracks().first;
      track.enabled = !track.enabled;
      _isMuted = !track.enabled;
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks().first;
      track.enabled = !track.enabled;
      _isVideoOff = !track.enabled;
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
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    _pendingIceByPeer.clear();
    _remoteDescSetForPeer.clear();
    _chatMessages.clear();
    await _localStream?.dispose();
    _localStream = null;
    _durationTimer?.cancel();
    _meetingDuration = 0;
    _currentMeeting = null;
    _isMuted = false;
    _isVideoOff = false;
  }

  @override
  void dispose() {
    _cleanup();
    speakingDetector.dispose();
    super.dispose();
  }
}