import 'dart:async';
import 'dart:io' show Platform;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'ringtone_preferences.dart';

/// Service pour jouer les sonneries personnalisées.
/// Gère la lecture de fichiers audio locaux (MP3, WAV, M4A, OGG).
class CustomRingtoneService {
  CustomRingtoneService._();
  static final CustomRingtoneService instance = CustomRingtoneService._();

  static Future<void> stopAll() async {
    await instance.stop();
  }

  final AudioPlayer _incomingPlayer = AudioPlayer();
  AudioSession? _audioSession;
  Timer? _vibrationTimer;

  _ActiveSound _active = _ActiveSound.none;

  Future<void> init() async {
    _audioSession ??= await AudioSession.instance;
  }

  /// Joue la sonnerie d'appel entrant
  Future<void> startIncomingRingtone(RingtonePreferences prefs) async {
    if (_active == _ActiveSound.incoming) return;
    if (_active != _ActiveSound.none) await stop();

    _active = _ActiveSound.incoming;

    try {
      await _configureAudioSession();
      await _playRingtone(prefs);
      _startVibrationLoop();
    } catch (e) {
      debugPrint('[CustomRingtoneService] ** Sonnerie échouée: $e');
      _active = _ActiveSound.none;
    }
  }

  Future<void> _configureAudioSession() async {
    final session = _audioSession;
    if (session == null) return;

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.notification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));

    await session.setActive(true);
  }

  Future<void> _playRingtone(RingtonePreferences prefs) async {
    final path = prefs.currentRingtonePath;

    if (path == null) return;

    // Vérifier si c'est un fichier d'assets ou un fichier local
    if (path.startsWith('assets/')) {
      debugPrint('[CustomRingtoneService] Lecture asset: $path');
      await _incomingPlayer.setAsset(path);
    } else {
      debugPrint('[CustomRingtoneService] Lecture fichier local: $path');
      await _incomingPlayer.setFilePath(path);
    }

    await _incomingPlayer.setLoopMode(LoopMode.one);
    await _incomingPlayer.setVolume(1.0);
    await _incomingPlayer.play();
  }

  /// Joue un aperçu (preview) d'une sonnerie spécifique
  Future<bool> playPreview(String? assetPath, String? customPath) async {
    if (assetPath != null && assetPath.startsWith('assets/')) {
      try {
        await _incomingPlayer.setAsset(assetPath);
        await _incomingPlayer.setVolume(0.8);
        await _incomingPlayer.setLoopMode(LoopMode.off);
        await _incomingPlayer.play();
        
        // Arrêter après 3 secondes
        Future.delayed(const Duration(seconds: 3), () {
          if (_active == _ActiveSound.none) {
            _incomingPlayer.stop();
          }
        });
        return true;
      } catch (e) {
        debugPrint('[CustomRingtoneService] Preview asset échoué: $e');
        return false;
      }
    } else if (customPath != null) {
      try {
        await _incomingPlayer.setFilePath(customPath);
        await _incomingPlayer.setVolume(0.8);
        await _incomingPlayer.setLoopMode(LoopMode.off);
        await _incomingPlayer.play();
        
        Future.delayed(const Duration(seconds: 3), () {
          if (_active == _ActiveSound.none) {
            _incomingPlayer.stop();
          }
        });
        return true;
      } catch (e) {
        debugPrint('[CustomRingtoneService] Preview custom échoué: $e');
        return false;
      }
    }
    return false;
  }

  /// Arrête la lecture
  Future<void> stop() async {
    final wasActive = _active;
    _active = _ActiveSound.none;

    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _incomingPlayer.stop();
      if (wasActive == _ActiveSound.incoming) {
        try {
          await Vibration.cancel();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CustomRingtoneService] ** Stop: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _incomingPlayer.dispose();
  }

  void _startVibrationLoop() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      Vibration.vibrate(duration: 700);
    } catch (_) {}
    
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_active != _ActiveSound.incoming) {
        _vibrationTimer?.cancel();
        return;
      }
      try {
        Vibration.vibrate(duration: 700);
      } catch (_) {}
    });
  }

  /// Demande les permissions nécessaires pour accéder aux fichiers audio
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (status.isGranted) return true;
      
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }
}

enum _ActiveSound { none, incoming }
