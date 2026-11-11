import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permissions Android liées aux appels entrants (Phase 6.4).
class CallPermissionsHelper {
  CallPermissionsHelper._();

  static const _channel = MethodChannel('com.alanya/call_permissions');
  static const _askedFullScreenKey = 'asked_full_screen_intent_v1';

  /// Vérifie notifications + full-screen intent (Android 14+). Propose une fois
  /// l'écran système si l'intent plein écran est refusé.
  static Future<void> ensureCallDisplayPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final notif = await Permission.notification.status;
      if (!notif.isGranted) {
        await Permission.notification.request();
      }

      final canFullScreen = await _canUseFullScreenIntent();
      if (canFullScreen) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedFullScreenKey) == true) return;

      await _openFullScreenIntentSettings();
      await prefs.setBool(_askedFullScreenKey, true);
    } catch (e) {
      debugPrint('[CallPermissions] ensureCallDisplayPermissions: $e');
    }
  }

  /// Micro (et caméra en vidéo) pour un appel — hors du chemin critique.
  ///
  /// Lit d'abord le statut et ne `request()` que s'il le faut. C'est toute la
  /// différence : `webrtc_service` appelait `Permission.microphone.request()`
  /// entre le tap sur « Répondre » et l'ouverture de la capture, si bien que
  /// le tout premier appel ouvrait une boîte de dialogue système au milieu du
  /// décrochage. Appelée dès la sonnerie, la permission est déjà acquise quand
  /// le chemin critique la revérifie, et la vérification ne coûte plus rien.
  ///
  /// Appelable deux fois sans dommage : c'est le principe même.
  ///
  /// @return false si le MICRO est refusé — l'appel n'a alors pas lieu d'être.
  ///         Une caméra refusée n'est pas bloquante : l'appel se dégrade en
  ///         audio, comme il le faisait déjà.
  /// La caméra est-elle déjà autorisée ? Ne demande rien.
  static Future<bool> isCameraGranted() async {
    if (kIsWeb) return false;
    try {
      return await Permission.camera.isGranted;
    } catch (e) {
      debugPrint('[CallPermissions] ** lecture permission caméra: $e');
      return false;
    }
  }

  static Future<bool> ensureCallMediaPermissions({required bool isVideo}) async {
    if (kIsWeb) return true;

    try {
      var mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        mic = await Permission.microphone.request();
      }

      if (isVideo) {
        final cam = await Permission.camera.status;
        if (!cam.isGranted) {
          final asked = await Permission.camera.request();
          if (!asked.isGranted) {
            debugPrint('[CallPermissions] caméra refusée — appel en audio seul');
          }
        }
      }

      return mic.isGranted;
    } catch (e) {
      debugPrint('[CallPermissions] ensureCallMediaPermissions: $e');
      // Ne pas bloquer l'appel sur un échec de la couche permissions :
      // getUserMedia refusera de lui-même si l'accès n'est réellement pas là.
      return true;
    }
  }

  static Future<bool> _canUseFullScreenIntent() async {
    try {
      final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('[CallPermissions] canUseFullScreenIntent: $e');
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  static Future<void> _openFullScreenIntentSettings() async {
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } on PlatformException catch (e) {
      debugPrint('[CallPermissions] openFullScreenIntentSettings: $e');
    } on MissingPluginException {
      // iOS / tests unitaires
    }
  }
}
