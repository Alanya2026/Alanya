// Gestion session audio / foreground service pendant appels (part of call_service.dart).
part of '../call_service.dart';

extension CallSession on CallService {
  String _ensureCallId() {
    if (_currentCallId == null || _currentCallId!.isEmpty) {
      _currentCallId = '${DateTime.now().millisecondsSinceEpoch}';
    }
    return _currentCallId!;
  }

  Future<void> _acquireCallSession({
    required bool isVideo,
    required String displayName,
    required String handle,
    bool startCallKit = true,
  }) async {
    if (kIsWeb) return;
    final callId = _ensureCallId();
    await CallSessionGuard.instance.acquire(
      mode: isVideo ? SessionMode.video : SessionMode.audio,
      callId: callId,
      displayName: displayName,
      handle: handle,
      isVideo: isVideo,
      startCallKit: startCallKit,
      getLocalStream: () => _webrtc.localStream,
      isVideoOn: () => _isVideoOn,
      isMuted: () => _isMuted,
    );
  }

  Future<void> _markCallSessionConnected() async {
    if (kIsWeb) return;
    await CallSessionGuard.instance.markConnected();
  }

  Future<void> _releaseCallSession() async {
    if (kIsWeb) return;
    await CallSessionGuard.instance.release();
  }
}
