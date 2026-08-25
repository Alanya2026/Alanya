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

  /// true si le verrouillage d'écran est affiché.
  ///
  /// Le service FCM natif n'affiche l'UI CallKit que lorsque le keyguard est
  /// verrouillé ou l'app en arrière-plan. Dart, lui, ne voyait que le cycle de
  /// vie Flutter : écran verrouillé mais activité encore résumée, les deux
  /// couches revendiquaient chacune leur écran d'appel entrant, avec chacune sa
  /// sonnerie. Cette méthode permet à Dart d'appliquer le même critère.
  ///
  /// Renvoie false en cas d'échec (canal absent au démarrage à froid, iOS,
  /// tests) : c'est le repli sûr, on conserve alors le comportement historique
  /// plutôt que de supprimer l'écran Flutter à tort.
  static Future<bool> isScreenLocked() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final locked = await _channel.invokeMethod<bool>('isKeyguardLocked');
      return locked ?? false;
    } on PlatformException catch (e) {
      debugPrint('[CallPermissions] isKeyguardLocked: $e');
      return false;
    } on MissingPluginException {
      return false;
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
