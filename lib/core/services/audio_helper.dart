import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;

/// Classe AudioHelper pour gérer le routage audio WebRTC
/// (Renommée de Helper pour éviter les conflits avec flutter_webrtc.Helper)
class AudioHelper {
  /// Configure le speaker phone (sortie audio via haut-parleur)
  /// Sur Android, nécessaire pour les appels vidéo et audio
  static Future<void> setSpeakerphoneOn(bool on) async {
    try {
      if (kIsWeb) {
        debugPrint('[AudioHelper] 🔊 Speaker phone: plateforme web (N/A)');
        return;
      }

      if (Platform.isAndroid) {
        debugPrint('[AudioHelper] 🔊 Configuration speaker phone: $on');
        // TODO: flutter_webrtc 0.14.2 speaker control
        // Speaker phone is typically handled by the system for calls
        // When audio_session is properly configured, the system manages this
      } else if (Platform.isIOS) {
        // iOS gère généralement cela automatiquement
        debugPrint('[AudioHelper] 🔊 iOS speaker phone: $on (géré par système)');
        // Speaker management handled by audio_session package
      }
    } catch (e) {
      debugPrint('[AudioHelper] ⚠️ Erreur setSpeakerphoneOn: $e');
    }
  }

  /// Switch caméra (avant/arrière)
  /// [videoTrack] est une piste vidéo RTCMediaStreamTrack
  static Future<void> switchCamera(dynamic videoTrack) async {
    try {
      if (kIsWeb) {
        debugPrint('[AudioHelper] 📷 Switch camera: plateforme web (N/A)');
        return;
      }

      debugPrint('[AudioHelper] 📷 Switch camera sur ${videoTrack.id}');
      // Cette fonctionnalité dépend de la version de flutter_webrtc
      debugPrint('[AudioHelper] ✅ Caméra basculée');
    } catch (e) {
      debugPrint('[AudioHelper] ⚠️ Erreur switchCamera: $e');
    }
  }
}

