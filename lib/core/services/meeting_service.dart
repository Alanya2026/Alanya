import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

enum MeetingStatus { idle, joining, connected, ended }

class MeetingService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  MeetingStatus _status = MeetingStatus.idle;
  Meeting? _currentMeeting;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isHandRaised = false;
  Timer? _durationTimer;
  int _meetingDuration = 0;

  MeetingStatus get status => _status;
  Meeting? get currentMeeting => _currentMeeting;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isHandRaised => _isHandRaised;
  int get meetingDuration => _meetingDuration;

  MeetingService({TalkyApiClient? apiClient})
      : _apiClient = apiClient ?? TalkyApiClient() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _apiClient.onSocketEvent('meeting:user_joined', (data) {
      _handleUserJoined(data);
    });

    _apiClient.onSocketEvent('meeting:user_left', (data) {
      _handleUserLeft(data['userId'].toString());
    });

    _apiClient.onSocketEvent('meeting:offer', (data) async {
      await _handleOfferFromPeer(data);
    });

    _apiClient.onSocketEvent('meeting:answer', (data) async {
      await _handleAnswerFromPeer(data);
    });

    _apiClient.onSocketEvent('meeting:ice_candidate', (data) {
      _handleIceCandidate(data);
    });

    _apiClient.onSocketEvent('meeting:ended', (_) {
      endMeeting();
    });
  }

  Future<void> createAndJoinMeeting({
    required String titre,
    String? description,
    required DateTime dateDebut,
    required DateTime dateFin,
    List<int>? participants,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      final data = await _apiClient.createMeeting(
        titre: titre,
        description: description,
        dateDebut: dateDebut.toIso8601String(),
        dateFin: dateFin.toIso8601String(),
        participants: participants,
      );

      _currentMeeting = Meeting.fromJson(data);
      await _joinMeetingRoom(_currentMeeting!.idMeeting);
    } catch (e) {
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Meeting>> getMeetings() async {
    final data = await _apiClient.getMeetings();
    return data.map((item) {
      if (item is Meeting) return item;
      return Meeting.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  Future<void> joinMeeting(int meetingId) async {
    await _joinMeetingRoom(meetingId);
  }

  Future<void> joinMeetingByCode(String roomId) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      final meetings = await _apiClient.getMeetings();
      final meeting = meetings.firstWhere(
        (m) => m.roomId == roomId,
        orElse: () => throw Exception('Meeting not found'),
      );

      _currentMeeting = meeting is Meeting
          ? meeting
          : Meeting.fromJson(meeting as Map<String, dynamic>);
      await _joinMeetingRoom(_currentMeeting!.idMeeting);
    } catch (e) {
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinMeetingRoom(int meetingId) async {
    try {
      await _initLocalStream();

      _apiClient.sendSocketEvent('meeting:join_room', {
        'meetingId': meetingId,
      });

      _status = MeetingStatus.connected;
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _initLocalStream() async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': {'width': 1280, 'height': 720},
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    notifyListeners();
  }

  Future<void> _handleUserJoined(Map<String, dynamic> data) async {
    final userId = data['userId'].toString();
    if (_peerConnections.containsKey(userId)) return;

    final pc = await _createPeerConnection(userId);

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _apiClient.sendSocketEvent('meeting:offer', {
      'meetingId': _currentMeeting!.idMeeting,
      'targetUserId': userId,
      'offer': offer.toMap(),
    });
  }

  void _handleUserLeft(String userId) {
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _remoteStreams.remove(userId);
    notifyListeners();
  }

  Future<void> _handleOfferFromPeer(Map<String, dynamic> data) async {
    final userId = data['userId'].toString();
    if (_peerConnections.containsKey(userId)) return;

    final pc = await _createPeerConnection(userId);

    await pc.setRemoteDescription(
      RTCSessionDescription(data['offer']['sdp'], 'offer'),
    );

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _apiClient.sendSocketEvent('meeting:answer', {
      'meetingId': _currentMeeting!.idMeeting,
      'targetUserId': userId,
      'answer': answer.toMap(),
    });
  }

  Future<void> _handleAnswerFromPeer(Map<String, dynamic> data) async {
    final userId = data['userId'].toString();
    final pc = _peerConnections[userId];
    if (pc != null && data['answer'] != null) {
      await pc.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], 'answer'),
      );
    }
  }

  void _handleIceCandidate(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    if (userId == null) return;

    final pc = _peerConnections[userId];
    if (pc != null && data['candidate'] != null) {
      pc.addCandidate(
        RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    final pc = await createPeerConnection(configuration);

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams[0];
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
      _apiClient.sendSocketEvent('meeting:ice_candidate', {
        'meetingId': _currentMeeting!.idMeeting,
        'targetUserId': userId,
        'candidate': candidate.toMap(),
      });
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  Future<void> toggleMute() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      _isMuted = !audioTrack.enabled;
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      _isVideoOff = !videoTrack.enabled;
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> toggleHandRaised() async {
    _isHandRaised = !_isHandRaised;
    _apiClient.sendSocketEvent('meeting:hand_raised', {
      'meetingId': _currentMeeting!.idMeeting,
      'isRaised': _isHandRaised,
    });
    notifyListeners();
  }

  Future<void> endMeeting() async {
    if (_currentMeeting != null) {
      _apiClient.sendSocketEvent('meeting:leave', {
        'meetingId': _currentMeeting!.idMeeting,
      });
    }

    await _cleanup();
    _status = MeetingStatus.ended;
    notifyListeners();
  }

  Future<void> _cleanup() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    await _localStream?.dispose();
    _localStream = null;
    _durationTimer?.cancel();
    _meetingDuration = 0;
  }

  void _startDurationTimer() {
    _meetingDuration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _meetingDuration++;
      notifyListeners();
    });
  }

  String get formattedDuration {
    final minutes = _meetingDuration ~/ 60;
    final seconds = _meetingDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
