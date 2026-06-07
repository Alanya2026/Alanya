import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

/// Centralise les sons d'appel.

class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  static Future<void> stopAll() async {
    await instance.stop();
  }

  static const _ringbackAsset = 'assets/sounds/ringback.wav';

  final FlutterRingtonePlayer _systemRingtone = FlutterRingtonePlayer();
  AudioPlayer? _ringbackPlayer;
  AudioSession? _audioSession;

  _ActiveSound _active = _ActiveSound.none;
  Timer? _vibrationTimer;

  Future<void> init() async {
    if (kIsWeb) return;
    _ringbackPlayer ??= AudioPlayer();
    _audioSession ??= await AudioSession.instance;
  } 

  Future<void> startIncomingRingtone() async {
    if (kIsWeb || _active != _ActiveSound.none) return;
    _active = _ActiveSound.incoming;
    debugPrint('[RingtoneService] 🔔 Sonnerie système (appelé)');

    try {
      await _systemRingtone.playRingtone(looping: true, volume: 1.0, asAlarm: false);
      _startVibrationLoop();
    } catch (e) {
      debugPrint('[RingtoneService] ** Sonnerie système échouée: $e');
      _active = _ActiveSound.none;
    }
  }

  // Appelant : ringback custom 

  Future<void> startOutgoingRingback() async {
    if (kIsWeb || _active != _ActiveSound.none) return;
    _active = _ActiveSound.outgoing;
    debugPrint('[RingtoneService] 📞 Ringback (appelant)');

    try {
      await _configureCallAudioSession();
      final player = _ringbackPlayer!;
      await player.setAsset(_ringbackAsset);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(0.7);
      await player.play();
    } catch (e) {
      debugPrint('[RingtoneService] ** Ringback échoué: $e');
      _active = _ActiveSound.none;
    }
  } 

  Future<void> stop() async {
    if (kIsWeb) return;
    final wasActive = _active;
    _active = _ActiveSound.none;

    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      if (wasActive == _ActiveSound.incoming) {
        await _systemRingtone.stop();
        try { await Vibration.cancel(); } catch (_) { /* vibration non supportée — ignoré */ }
      } else if (wasActive == _ActiveSound.outgoing) {
        await _ringbackPlayer?.stop();
      }
    } catch (e) {
      debugPrint('[RingtoneService] ** Stop: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _ringbackPlayer?.dispose();
    _ringbackPlayer = null;
  }

  Future<void> _configureCallAudioSession() async {
    final session = _audioSession;
    if (session == null) return;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.voiceCommunicationSignalling,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      androidWillPauseWhenDucked: false,
    ));
    await session.setActive(true);
  }

  void _startVibrationLoop() {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try { Vibration.vibrate(duration: 700); } catch (_) { /* vibration non supportée — ignoré */ }
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_active != _ActiveSound.incoming) {
        _vibrationTimer?.cancel();
        return;
      }
      try { Vibration.vibrate(duration: 700); } catch (_) { /* vibration non supportée — ignoré */ }
    });
  }
}

enum _ActiveSound { none, incoming, outgoing }
