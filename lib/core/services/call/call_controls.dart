// Contrôles médias (micro, caméra, haut-parleur) + timer de durée.
// part of call_service.dart.
part of '../call_service.dart';

extension CallControls on CallService {
  Future<void> toggleMute() async {
    await _webrtc.toggleMic();
    _isMuted = !_isMuted;
    notify();
  }

  Future<void> toggleCamera() async {
    await _webrtc.toggleCamera();
    _isVideoOn = !_isVideoOn;
    notify();
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await audio.AudioHelper.setSpeakerphoneOn(_isSpeakerOn);
    debugPrint('[CallService] Haut-parleur: ${_isSpeakerOn ? "ON" : "OFF"}');
    notify();
  }

  void _startDurationTimer() {
    _callDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notify();
    });
  }
}
