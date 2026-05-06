import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

/// Service de gestion des sonneries et vibrations pour les appels
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  
  factory RingtoneService() {
    return _instance;
  }
  
  RingtoneService._internal();

  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  Future<void> init() async {
    if (kIsWeb) return;
    _audioPlayer = AudioPlayer();
  }

  /// Joue la sonnerie de RINGBACK (tonalité pour l'appelant en attente)
  /// Utilise le fichier MP3 des assets
  Future<void> playRingbackTone() async {
    if (kIsWeb) {
      debugPrint('[RingtoneService] Web - skip ringback');
      return;
    }

    if (_isPlaying) {
      debugPrint('[RingtoneService] ⚠️ Ringback déjà en cours');
      return;
    }

    try {
      debugPrint('[RingtoneService] 📞 Démarrage ringback tone (appelant)');
      _isPlaying = true;

      // ✅ Charger le son depuis les assets avec timeout
      try {
        await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3').timeout(const Duration(seconds: 2));
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play();
        debugPrint('[RingtoneService] ✅ Ringback tone lancée');
      } catch (e) {
        debugPrint('[RingtoneService] ⚠️ Asset ringback non disponible: $e');
        _isPlaying = false;
        // Continuer sans son plutôt que de bloquer
      }
    } catch (e) {
      debugPrint('[RingtoneService] ❌ Erreur ringback: $e');
      _isPlaying = false;
    }
  }

  /// Joue la sonnerie SYSTÈME du téléphone (pour appel entrant)
  /// Utilise la sonnerie configurée dans les paramètres Android
  Future<void> playSystemRingtone() async {
    if (kIsWeb) {
      debugPrint('[RingtoneService] Web - skip system ringtone');
      return;
    }

    if (_isPlaying) {
      debugPrint('[RingtoneService] ⚠️ Ringtone déjà en cours');
      return;
    }

    try {
      debugPrint('[RingtoneService] 🔔 Démarrage sonnerie système (appelé)');
      _isPlaying = true;

      // ✅ Essayer de charger la sonnerie système Android avec timeout
      if (Platform.isAndroid) {
        bool soundLoaded = false;
        
        // Essai 1 : sonnerie système
        try {
          const ringtoneUri = 'android.resource://com.android.systemui/raw/ringtone';
          await _audioPlayer.setUrl(ringtoneUri).timeout(const Duration(seconds: 2));
          await _audioPlayer.setLoopMode(LoopMode.one);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play();
          debugPrint('[RingtoneService] ✅ Sonnerie système lancée');
          soundLoaded = true;
        } catch (e) {
          debugPrint('[RingtoneService] ⚠️ Sonnerie système non disponible: $e');
          
          // Essai 2 : fichier asset en fallback
          if (!soundLoaded) {
            try {
              await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3').timeout(const Duration(seconds: 2));
              await _audioPlayer.setLoopMode(LoopMode.one);
              await _audioPlayer.setVolume(1.0);
              await _audioPlayer.play();
              debugPrint('[RingtoneService] ✅ Fallback asset lancé');
              soundLoaded = true;
            } catch (e2) {
              debugPrint('[RingtoneService] ⚠️ Fallback asset échoué: $e2');
              // Continuer sans son - au moins la vibration fonctionnera
            }
          }
        }
      } else {
        // Non-Android : utiliser le fichier asset
        try {
          await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3').timeout(const Duration(seconds: 2));
          await _audioPlayer.setLoopMode(LoopMode.one);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play();
          debugPrint('[RingtoneService] ✅ Asset ringtone lancé');
        } catch (e) {
          debugPrint('[RingtoneService] ⚠️ Asset non disponible: $e');
          // Continuer sans son
        }
      }

      // ✅ Vibration sur Android uniquement (en arrière-plan, ne pas attendre)
      if (Platform.isAndroid) {
        _startVibration().catchError((e) {
          debugPrint('[RingtoneService] ⚠️ Erreur vibration: $e');
        });
      }
    } catch (e) {
      debugPrint('[RingtoneService] ❌ Erreur system ringtone: $e');
      _isPlaying = false;
    }
  }

  /// Alias pour compatibilité - joue la sonnerie d'appel entrant
  Future<void> playIncomingCallRingtone() => playSystemRingtone();

  /// Lance une vibration continue (motif pour appel entrant)
  Future<void> _startVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) {
        debugPrint('[RingtoneService] ⚠️ Appareil sans vibreur');
        return;
      }

      // Motif de vibration : 500ms vibration, 500ms pause, répété
      // [duration ms, pause ms, duration ms, pause ms, ...]
      while (_isPlaying) {
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('[RingtoneService] ❌ Erreur vibration: $e');
    }
  }

  /// Arrête la sonnerie et vibration
  Future<void> stopRingtone() async {
    if (kIsWeb) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
        debugPrint('[RingtoneService] ⏹️ Sonnerie arrêtée');
      }
    } catch (e) {
      debugPrint('[RingtoneService] ❌ Erreur stop: $e');
    }
  }

  /// Nettoyer ressources
  Future<void> dispose() async {
    if (kIsWeb) return;
    
    try {
      await stopRingtone();
      await _audioPlayer.dispose();
      debugPrint('[RingtoneService] 🧹 Ressources disposées');
    } catch (e) {
      debugPrint('[RingtoneService] ⚠️ Erreur dispose: $e');
    }
  }
}
