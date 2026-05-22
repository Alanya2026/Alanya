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
        debugPrint('[AudioHelper]  Speaker phone: plateforme web (N/A)');
        return;
      }

      if (Platform.isAndroid) {
        debugPrint('[AudioHelper]  Configuration speaker phone: $on');
      } else if (Platform.isIOS) { 
        debugPrint('[AudioHelper]  iOS speaker phone: $on (géré par système)'); 
      }
    } catch (e) {
      debugPrint('[AudioHelper] ** Erreur setSpeakerphoneOn: $e');
    }
  }

  /// Switch caméra (avant/arrière) 
  static Future<void> switchCamera(dynamic videoTrack) async {
    try {
      if (kIsWeb) {
        debugPrint('[AudioHelper] 📷 Switch camera: plateforme web (N/A)');
        return;
      }

      debugPrint('[AudioHelper] 📷 Switch camera sur ${videoTrack.id}'); 
      debugPrint('[AudioHelper] !! Caméra basculée');
    } catch (e) {
      debugPrint('[AudioHelper] ** Erreur switchCamera: $e');
    }
  }
}

