import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio_helper.dart';
import 'callkit_service.dart';

enum SessionMode { audio, video }

/// Maintient micro + foreground service actifs pendant appels/réunions (Android).
/// Vidéo : wakelock écran + pause caméra en veille.
class CallSessionGuard with WidgetsBindingObserver {
  CallSessionGuard._();
  static final CallSessionGuard instance = CallSessionGuard._();

  int _refCount = 0;
  SessionMode? _mode;
  String? _callId;
  bool _wakelockEnabled = false;
  bool _videoPausedByLifecycle = false;

  MediaStream? Function()? _getLocalStream;
  bool Function()? _isVideoOn;
  bool Function()? _isMuted;

  bool get isActive => _refCount > 0;

  Future<void> acquire({
    required SessionMode mode,
    required String callId,
    required String displayName,
    required String handle,
    required bool isVideo,
    bool startCallKit = true,
    MediaStream? Function()? getLocalStream,
    bool Function()? isVideoOn,
    bool Function()? isMuted,
  }) async {
    if (kIsWeb) return;

    _refCount++;
    if (_refCount > 1) {
      debugPrint('[CallSessionGuard] Déjà actif (ref=$_refCount)');
      return;
    }

    _mode = mode;
    _callId = callId;
    _getLocalStream = getLocalStream;
    _isVideoOn = isVideoOn;
    _isMuted = isMuted;
    _videoPausedByLifecycle = false;

    WidgetsBinding.instance.addObserver(this);

    await AudioHelper.configureCallAudio();

    if (startCallKit) {
      await CallKitService.instance.startOutgoingCall(
        callId: callId,
        displayName: displayName,
        handle: handle,
        isVideo: isVideo,
      );
    }

    if (mode == SessionMode.video) {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
      debugPrint('[CallSessionGuard] Wakelock activé (vidéo)');
    }

    debugPrint('[CallSessionGuard] Session acquise mode=$mode callId=$callId');
  }

  Future<void> markConnected() async {
    if (kIsWeb || _callId == null) return;
    await CallKitService.instance.setConnected(_callId!);
  }

  Future<void> release() async {
    if (kIsWeb) return;
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount > 0) return;

    WidgetsBinding.instance.removeObserver(this);

    if (_wakelockEnabled) {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    }

    await AudioHelper.releaseCallAudio();

    _mode = null;
    _callId = null;
    _getLocalStream = null;
    _isVideoOn = null;
    _isMuted = null;
    _videoPausedByLifecycle = false;

    debugPrint('[CallSessionGuard] Session relâchée');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || _refCount == 0) return;

    debugPrint('[CallSessionGuard] lifecycle=$state mode=$_mode');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ensureAudioTrackActive();
      if (_mode == SessionMode.video) {
        _pauseLocalVideo();
      }
    } else if (state == AppLifecycleState.resumed) {
      AudioHelper.reactivateCallAudio();
      _ensureAudioTrackActive();
      if (_mode == SessionMode.video && _videoPausedByLifecycle) {
        _resumeLocalVideo();
      }
    }
  }

  void _ensureAudioTrackActive() {
    if (_isMuted != null && _isMuted!()) return;
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) return;
    final track = tracks.first;
    if (!track.enabled) {
      debugPrint('[CallSessionGuard] Réactivation track audio');
      track.enabled = true;
    }
  }

  void _pauseLocalVideo() {
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    final track = tracks.first;
    if (track.enabled) {
      track.enabled = false;
      _videoPausedByLifecycle = true;
      debugPrint('[CallSessionGuard] Vidéo locale suspendue (veille)');
    }
  }

  void _resumeLocalVideo() {
    if (_isVideoOn != null && !_isVideoOn!()) return;
    final stream = _getLocalStream?.call();
    if (stream == null) return;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return;
    tracks.first.enabled = true;
    _videoPausedByLifecycle = false;
    debugPrint('[CallSessionGuard] Vidéo locale reprise');
  }
}
