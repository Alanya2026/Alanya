import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'webrtc_service.dart';

enum CallStatus { idle, outgoing, incoming, connecting, connected, ended }

class CallService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final WebRTCService _webrtc = WebRTCService();

  CallStatus _status = CallStatus.idle;
  Call? _currentCall;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = true;
  Timer? _durationTimer;
  int _callDuration = 0;
  Map<String, dynamic>? _pendingOffer;

  CallStatus get status => _status;
  Call? get currentCall => _currentCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoOn => _isVideoOn;
  int get callDuration => _callDuration;
  MediaStream? get localStream => _webrtc.localStream;
  MediaStream? get remoteStream => _webrtc.remoteStream;

  CallService({TalkyApiClient? apiClient})
      : _apiClient = apiClient ?? TalkyApiClient() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _apiClient.onSocketEvent('call:incoming', (data) {
      _currentCall = Call.fromJson(data);
      _pendingOffer = data['offer'];
      _status = CallStatus.incoming;
      notifyListeners();
    });

    _apiClient.onSocketEvent('call:answer', (data) async {
      if (data['accepted'] == true && data['sdp'] != null) {
        await _webrtc.handleAnswer(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
        _status = CallStatus.connected;
        _startDurationTimer();
      } else {
        _status = CallStatus.ended;
      }
      notifyListeners();
    });

    _apiClient.onSocketEvent('ice:candidate', (data) {
      if (data['candidate'] != null) {
        _webrtc.addIceCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      }
    });

    _apiClient.onSocketEvent('call:end', (_) {
      endCall();
    });
  }

  Future<void> initiateCall({
    required int receiverId,
    required bool isVideo,
  }) async {
    _status = CallStatus.outgoing;
    notifyListeners();

    try {
      final callType = isVideo ? 'video' : 'audio';
      final data = await _apiClient.initiateCall(
        receiverId: receiverId,
        type: callType,
      );

      _currentCall = Call.fromJson(data);
      await _webrtc.init(isVideo ? CallType.video : CallType.audio);

      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent('ice:candidate', {
          'callId': _currentCall!.idAppel,
          'candidate': candidate.toMap(),
        });
      };

      final offer = await _webrtc.createOffer();
      _pendingOffer = offer.toMap();

      _apiClient.sendSocketEvent('call:user', {
        'receiverId': receiverId,
        'type': callType,
        'offer': _pendingOffer,
      });

      _status = CallStatus.connecting;
      notifyListeners();
    } catch (e) {
      _status = CallStatus.ended;
      notifyListeners();
    }
  }

  Future<void> answerCall() async {
    if (_currentCall == null) return;

    try {
      await _webrtc.init(
        _currentCall!.type == 'video' ? CallType.video : CallType.audio,
      );

      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent('ice:candidate', {
          'callId': _currentCall!.idAppel,
          'candidate': candidate.toMap(),
        });
      };

      if (_pendingOffer != null) {
        await _webrtc.handleOffer(
          RTCSessionDescription(_pendingOffer!['sdp'], 'offer'),
        );
      }

      final answer = await _webrtc.createAnswer();
      _apiClient.sendSocketEvent('call:answer', {
        'callId': _currentCall!.idAppel,
        'accepted': true,
        'sdp': answer.toMap()['sdp'],
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      _status = CallStatus.ended;
      notifyListeners();
    }
  }

  Future<void> rejectCall() async {
    if (_currentCall == null) return;
    _apiClient.sendSocketEvent('call:reject', {'callId': _currentCall!.idAppel});
    _status = CallStatus.ended;
    _currentCall = null;
    _pendingOffer = null;
    notifyListeners();
  }

  Future<void> endCall() async {
    if (_currentCall != null) {
      await _apiClient.endCall(_currentCall!.idAppel);
      _apiClient.sendSocketEvent('call:end', {'callId': _currentCall!.idAppel});
    }
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _status = CallStatus.ended;
    _currentCall = null;
    _pendingOffer = null;
    _callDuration = 0;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    await _webrtc.toggleMic();
    _isMuted = !_isMuted;
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    await _webrtc.toggleCamera();
    _isVideoOn = !_isVideoOn;
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  void _startDurationTimer() {
    _callDuration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  String get formattedDuration {
    final minutes = _callDuration ~/ 60;
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _webrtc.dispose();
    super.dispose();
  }
}
