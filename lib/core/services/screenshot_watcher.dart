import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// Détecte une capture d'écran de l'écran affiché, le temps que l'appelant
/// écoute (entre [start] et [stop]).
///
/// - iOS : `screen_protector` (notification système de capture).
/// - Android : canal natif `com.alanya/screenshot` — callback officiel sur
///   Android 14+, observation de la galerie avant (si l'accès aux images est déjà
///   accordé ; l'app ne le demande pas pour cela). Voir `ScreenshotDetector.kt`.
///
/// Une plateforme sans détection (ou un échec natif) n'est pas une erreur : la
/// fonction est alors simplement inactive.
class ScreenshotWatcher {
  static const MethodChannel _channel = MethodChannel('com.alanya/screenshot');

  void Function()? _onShot;

  void start(void Function() onScreenshot) {
    stop();
    _onShot = onScreenshot;
    try {
      if (Platform.isAndroid) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onScreenshot') _onShot?.call();
        });
        _channel.invokeMethod<void>('start').catchError((Object e) {
          debugPrint('[ScreenshotWatcher] start: $e');
        });
      } else if (Platform.isIOS) {
        ScreenProtector.addListener(() => _onShot?.call(), null);
      }
    } catch (e) {
      debugPrint('[ScreenshotWatcher] start: $e');
    }
  }

  void stop() {
    if (_onShot == null) return;
    _onShot = null;
    try {
      if (Platform.isAndroid) {
        _channel.setMethodCallHandler(null);
        _channel.invokeMethod<void>('stop').catchError((Object e) {
          debugPrint('[ScreenshotWatcher] stop: $e');
        });
      } else if (Platform.isIOS) {
        ScreenProtector.removeListener();
      }
    } catch (e) {
      debugPrint('[ScreenshotWatcher] stop: $e');
    }
  }
}

/// Anti-rafale côté client : une rafale de captures n'envoie qu'UN signalement
/// par fenêtre. Le serveur applique sa propre limite (une ligne par minute et par
/// auteur) ; celle-ci évite surtout d'appeler pour rien.
class ScreenshotAlertGate {
  ScreenshotAlertGate({
    this.minInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration minInterval;
  final DateTime Function() _clock;
  DateTime? _last;

  /// Vrai (et mémorise l'instant) si un signalement peut partir maintenant.
  bool allow() {
    final now = _clock();
    final last = _last;
    if (last != null && now.difference(last) < minInterval) return false;
    _last = now;
    return true;
  }
}
