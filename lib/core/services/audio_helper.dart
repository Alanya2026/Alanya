import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Routage audio WebRTC et session audio « appel » (voiceCommunication).
class AudioHelper {
  static AudioSession? _session;

  /// Active la session audio pour un appel ou une réunion en cours.
  static Future<void> configureCallAudio() async {
    if (kIsWeb) return;
    try {
      _session ??= await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await _session!.setActive(true);
      debugPrint('[AudioHelper] Session audio appel activée');
    } catch (e) {
      debugPrint('[AudioHelper] ** configureCallAudio: $e');
    }
  }

  /// Relâche la session audio à la fin d'un appel/réunion.
  static Future<void> releaseCallAudio() async {
    if (kIsWeb) return;
    try {
      await _session?.setActive(false);
      debugPrint('[AudioHelper] Session audio appel relâchée');
    } catch (e) {
      debugPrint('[AudioHelper] ** releaseCallAudio: $e');
    }
  }

  /// Réactive la session après retour au premier plan.
  static Future<void> reactivateCallAudio() async {
    if (kIsWeb || _session == null) return;
    try {
      await _session!.setActive(true);
    } catch (e) {
      debugPrint('[AudioHelper] ** reactivateCallAudio: $e');
    }
  }

  static Future<void> setSpeakerphoneOn(bool on) async {
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(on);
      debugPrint('[AudioHelper] Speaker phone: $on');
    } catch (e) {
      debugPrint('[AudioHelper] ** setSpeakerphoneOn: $e');
    }
  }

  static Future<void> switchCamera(MediaStreamTrack videoTrack) async {
    if (kIsWeb) return;
    try {
      await Helper.switchCamera(videoTrack);
    } catch (e) {
      debugPrint('[AudioHelper] ** switchCamera: $e');
    }
  }
}
