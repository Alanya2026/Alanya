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

      // ✅ Charger le son depuis les assets (le MP3 de l'utilisateur)
      await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3');
      
      // ✅ Looper le son
      await _audioPlayer.setLoopMode(LoopMode.one);
      
      // ✅ Volume max
      await _audioPlayer.setVolume(1.0);
      
      // ✅ Démarrer la lecture
      await _audioPlayer.play();
      
      debugPrint('[RingtoneService] ✅ Ringback tone lancée');
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

      // ✅ Essayer de charger la sonnerie système Android
      if (Platform.isAndroid) {
        try {
          // URI de la sonnerie système Android par défaut
          const ringtoneUri = 'android.resource://com.android.systemui/raw/ringtone';
          
          await _audioPlayer.setUrl(ringtoneUri);
          await _audioPlayer.setLoopMode(LoopMode.one);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play();
          
          debugPrint('[RingtoneService] ✅ Sonnerie système lancée');
        } catch (e) {
          debugPrint('[RingtoneService] ⚠️ Sonnerie système non trouvée: $e');
          debugPrint('[RingtoneService] 📞 Fallback: Utilisation du ringback tone');
          // Fallback sur le MP3 des assets
          await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3');
          await _audioPlayer.setLoopMode(LoopMode.one);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play();
        }
      } else {
        // Fallback pour autres plateformes : utiliser le MP3
        await _audioPlayer.setAsset('assets/sounds/incoming_call.mp3');
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play();
      }

      // ✅ Vibration sur Android uniquement
      if (Platform.isAndroid) {
        _startVibration();
      }
    } catch (e) {
      debugPrint('[RingtoneService] ❌ Erreur system ringtone: $e');
      _isPlaying = false;
    }
  }

  /// Alias pour compatibilité - joue la sonnerie d'appel entrant
  Future<void> playIncomingCallRingtone() => playSystemRingtone();

  /// Lance une vibration continue (motif pour appel entrant)
  void _startVibration() async {
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
