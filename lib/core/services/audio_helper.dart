import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Routage audio WebRTC et session audio « appel » (voiceChat / videoChat).
class AudioHelper {
  static AudioSession? _session;
  static bool _callAudioActive = false;
  static bool _subscribed = false;

  /// Active la session audio pour un appel ou une réunion en cours.
  /// [isVideo] : mode iOS `videoChat` (sinon `voiceChat`).
  static Future<void> configureCallAudio({bool isVideo = false}) async {
    if (kIsWeb) return;
    try {
      _session ??= await AudioSession.instance;
      await _session!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: isVideo
            ? AVAudioSessionMode.videoChat
            : AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await _session!.setActive(true);
      _callAudioActive = true;
      _ensureEventSubscriptions();
      debugPrint(
        '[AudioHelper] Session audio appel activée '
        '(${isVideo ? "videoChat" : "voiceChat"})',
      );
    } catch (e) {
      debugPrint('[AudioHelper] ** configureCallAudio: $e');
    }
  }

  /// Relâche la session audio à la fin d'un appel/réunion.
  static Future<void> releaseCallAudio() async {
    if (kIsWeb) return;
    _callAudioActive = false;
    try {
      await _session?.setActive(false);
      debugPrint('[AudioHelper] Session audio appel relâchée');
    } catch (e) {
      debugPrint('[AudioHelper] ** releaseCallAudio: $e');
    }
  }

  /// Réactive la session après retour au premier plan.
  static Future<void> reactivateCallAudio() async {
    if (kIsWeb || _session == null || !_callAudioActive) return;
    try {
      await _session!.setActive(true);
    } catch (e) {
      debugPrint('[AudioHelper] ** reactivateCallAudio: $e');
    }
  }

  static void _ensureEventSubscriptions() {
    if (_subscribed || _session == null) return;
    _subscribed = true;

    _session!.interruptionEventStream.listen((event) {
      if (!_callAudioActive) return;
      if (event.begin) {
        debugPrint(
          '[AudioHelper] Interruption début type=${event.type}',
        );
        return;
      }
      // Fin d'interruption pendant un appel : reprendre le focus audio.
      debugPrint('[AudioHelper] Interruption fin → setActive(true)');
      _session?.setActive(true).then((_) {}, onError: (Object e) {
        debugPrint('[AudioHelper] ** setActive après interruption: $e');
      });
    });

    _session!.becomingNoisyEventStream.listen((_) {
      if (!_callAudioActive) return;
      // Appel : on ne coupe pas l'audio (contrairement à un lecteur média).
      debugPrint('[AudioHelper] becomingNoisy pendant appel (ignoré)');
    });

    _session!.devicesChangedEventStream.listen((event) {
      if (!_callAudioActive) return;
      debugPrint(
        '[AudioHelper] devicesChanged '
        '+${event.devicesAdded.length} -${event.devicesRemoved.length}',
      );
    });
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
