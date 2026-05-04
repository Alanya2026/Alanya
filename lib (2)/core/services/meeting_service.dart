// meeting_service.dart — aligné sur le backend Node.js
//
// Événements corrects (backend/src/socket/handlers/meetings.js) :
//
// Flutter → Backend
//   meeting:join_room    { meetingID, userID }
//   meeting:join_request { meetingID, userID, userName }
//   meeting:join_accept  { meetingID, userID }
//   meeting:join_decline { meetingID, userID }
//   meeting:start        { meetingID }
//   meeting:end          { meetingID }
//   meeting:leave        { meetingID }
//   meeting:chat         { meetingID, userID, message }
//   meeting:offer        { meetingID, toUserID, offer:{sdp,type} }
//   meeting:answer       { meetingID, toUserID, answer:{sdp,type} }
//   meeting:ice_candidate{ meetingID, toUserID, candidate:{...} }
//
// Backend → Flutter
//   meeting:room_joined  { meetingID, userID }
//   meeting:user_joined  { meetingID, userID }
//   meeting:user_left    { meetingID, userID }
//   meeting:accepted     { meetingID }
//   meeting:declined     { meetingID }
//   meeting:started      { meetingID }
//   meeting:ended        { meetingID }
//   meeting:message      { meetingID, userID, message, sendAt }
//   meeting:offer        { fromUserID, offer, meetingID }
//   meeting:answer       { fromUserID, answer, meetingID }
//   meeting:ice_candidate{ fromUserID, candidate, meetingID }
//
// Champs DB corrects :
//   Meeting : idMeeting, idOrganiser, start_time, duree, objet, room, isEnd, type_media
//   Participant : IDparticipant, status, connecte
//   Payload join_room : meetingID (pas meetingId), toUserID (pas targetUserId)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

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

  // Médias locaux
  MediaStream? _localStream;

  // WebRTC peers : userId → PeerConnection
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Streams distants : userId → MediaStream
  final Map<String, MediaStream> _remoteStreams = {};

  // Contrôles
  bool _isMuted = false;
  bool _isVideoOff = false;

  // Timer de durée
  Timer? _durationTimer;
  int _meetingDuration = 0;

  // Messages in-meeting
  final List<ChatMessage> _chatMessages = [];

  // Config ICE (STUN + TURN)
  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': [
          'turn:global.relay.metered.ca:80',
          'turn:global.relay.metered.ca:80?transport=tcp',
          'turn:global.relay.metered.ca:443',
          'turns:global.relay.metered.ca:443?transport=tcp',
        ],
        'username': '4ccd30e6211751522c93c044',
        'credential': 'iB+/hPI3lLayZAKn',
      },
    ],
  };

  // ── Getters ────────────────────────────────────────────────────────
  MeetingStatus get status => _status;
  Meeting? get currentMeeting => _currentMeeting;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  int get meetingDuration => _meetingDuration;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  MeetingService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _setupSocketListeners();
  }

  // ── SOCKET LISTENERS ───────────────────────────────────────────────

  void _setupSocketListeners() {
    // Confirmation que la room a été rejointe
    _apiClient.onSocketEvent(SocketEvents.meetingRoomJoined, (data) {
      debugPrint('[MeetingService] Room rejointe: $data');
    });

    // Un nouveau participant vient de rejoindre → initier l'échange WebRTC
    _apiClient.onSocketEvent(SocketEvents.meetingUserJoined, (data) async {
      if (data is! Map) return;
      // ✅ Champ correct du backend : userID (string)
      final userId = data['userID']?.toString();
      if (userId == null || _peerConnections.containsKey(userId)) return;
      // C'est nous qui créons l'offer (on est arrivé en premier)
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

    // Notre demande de join a été acceptée
    _apiClient.onSocketEvent(SocketEvents.meetingAccepted, (data) {
      debugPrint('[MeetingService] Demande acceptée: $data');
    });

    // Notre demande de join a été refusée
    _apiClient.onSocketEvent(SocketEvents.meetingDeclined, (data) {
      debugPrint('[MeetingService] Demande refusée: $data');
      _status = MeetingStatus.ended;
      notifyListeners();
    });

    // Réunion démarrée
    _apiClient.onSocketEvent(SocketEvents.meetingStarted, (data) {
      debugPrint('[MeetingService] Réunion démarrée: $data');
      notifyListeners();
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
      // ✅ Champ correct du backend : fromUserID
      final fromUserId = data['fromUserID']?.toString();
      final offer = data['offer'] as Map?;
      if (fromUserId == null || offer == null) return;
      await _handleOffer(fromUserId, offer);
    });

    // WebRTC : answer reçue d'un pair
    _apiClient.onSocketEvent(SocketEvents.meetingAnswer, (data) async {
      if (data is! Map) return;
      // ✅ Champ correct du backend : fromUserID
      final fromUserId = data['fromUserID']?.toString();
      final answer = data['answer'] as Map?;
      if (fromUserId == null || answer == null) return;
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
      }
    });

    // WebRTC : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.meetingIceCandidate, (data) {
      if (data is! Map) return;
      // ✅ Champ correct du backend : fromUserID
      final fromUserId = data['fromUserID']?.toString();
      final c = data['candidate'] as Map?;
      if (fromUserId == null || c == null) return;
      _peerConnections[fromUserId]?.addCandidate(RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    });
  }

  // ── API REST ───────────────────────────────────────────────────────

  /// Récupère la liste des réunions depuis le serveur.
  Future<List<Meeting>> getMeetings() async {
    final data = await _apiClient.getMeetings();
    return data
        .whereType<Map<String, dynamic>>()
        .map(Meeting.fromJson)
        .toList();
  }

  /// Crée une réunion ET rejoint la room socket.
  /// [myId] est le alanyaID de l'utilisateur connecté.
  Future<void> createAndJoin({
    required String objet,
    required String startTime, // ISO8601
    required String room,
    required int myId,
    int duree = 60,
    int typeMedia = 0,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      // 1. Créer la réunion en DB via REST
      final data = await _apiClient.createMeeting(
        objet: objet,
        startTime: startTime,
        room: room,
        duree: duree,
        typeMedia: typeMedia,
      );
      _currentMeeting = Meeting.fromJson(data);

      // 2. Rejoindre en DB (marque connecte=1)
      await _apiClient.joinMeetingHttp(_currentMeeting!.idMeeting);

      // 3. Rejoindre la room socket
      await _joinRoom(myId: myId);
    } catch (e) {
      debugPrint('[MeetingService] Erreur createAndJoin: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  /// Rejoint une réunion existante par son [idMeeting].
  /// [myId] est le alanyaID de l'utilisateur connecté.
  Future<void> joinMeeting({
    required int idMeeting,
    required int myId,
    required String myName,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      // 1. Récupérer les détails de la réunion
      final data = await _apiClient.getMeeting(idMeeting);
      _currentMeeting = Meeting.fromJson(data);

      // 2. Rejoindre en DB
      await _apiClient.joinMeetingHttp(idMeeting);

      // 3. Rejoindre la room socket
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
      final meetings = await getMeetings();
      // ✅ Champ correct : room (pas roomId)
      final meeting = meetings.firstWhere(
        (m) => m.room == roomCode,
        orElse: () => throw Exception('Réunion introuvable'),
      );

      _currentMeeting = meeting;
      await _apiClient.joinMeetingHttp(meeting.idMeeting);
      await _joinRoom(myId: myId);
    } catch (e) {
      debugPrint('[MeetingService] Erreur joinByRoom: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinRoom({required int myId}) async {
    // Initialiser le stream local
    await _initLocalStream();

    // ✅ Champs corrects : meetingID et userID (pas meetingId/userId)
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinRoom, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId,
    });

    _status = MeetingStatus.connected;
    _startDurationTimer();
    notifyListeners();
  }

  // ── CONTRÔLES DE RÉUNION ──────────────────────────────────────────

  /// Envoie un message chat dans la réunion.
  void sendChatMessage(String message, int myId) {
    if (_currentMeeting == null) return;

    // ✅ Champs corrects : meetingID, userID
    _apiClient.sendSocketEvent(SocketEvents.meetingChat, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId.toString(),
      'message': message,
    });
  }

  /// Accepte la demande de join d'un participant (organisateur seulement).
  void acceptJoinRequest(int userId) {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinAccept, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': userId.toString(),
    });
  }

  /// Refuse la demande de join.
  void declineJoinRequest(int userId) {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinDecline, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': userId.toString(),
    });
  }

  /// Démarre la réunion (organisateur seulement).
  void startMeeting() {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingStart, {
      'meetingID': _currentMeeting!.idMeeting,
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
      // ✅ Payload exact : meetingID
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

  // ── WEBRTC ────────────────────────────────────────────────────────

  Future<void> _initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'width': 1280, 'height': 720},
    });
    notifyListeners();
  }

  Future<void> _createPeerAndOffer(String userId) async {
    final pc = await _createPeerConnection(userId);

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // ✅ Champs corrects : meetingID, toUserID
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

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // ✅ Champs corrects : meetingID, toUserID
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

    final pc = await createPeerConnection(_iceConfig);

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams[0];
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
      // ✅ Champs corrects : meetingID, toUserID
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

    _peerConnections[userId] = pc;
    return pc;
  }

  void _removePeer(String userId) {
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteStreams.remove(userId);
    notifyListeners();
  }

  // ── MÉDIAS ────────────────────────────────────────────────────────

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

  // ── TIMER ─────────────────────────────────────────────────────────

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

  // ── CLEANUP ───────────────────────────────────────────────────────

  Future<void> _cleanup() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
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
    super.dispose();
  }
}