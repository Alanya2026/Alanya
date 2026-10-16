import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

/// Détecte une capture d'écran — ou un enregistrement vidéo — de l'écran
/// affiché, le temps que l'appelant écoute (entre [start] et [stop]).
///
/// - iOS : `screen_protector` (notification système de capture ; pour la vidéo,
///   `UIScreen.isCaptured`, qui passe à vrai dès que l'écran est filmé — y
///   compris par une recopie AirPlay, que le système ne distingue pas).
/// - Android : canal natif `com.alanya/screenshot` — callbacks officiels
///   (capture : Android 14+, enregistrement : Android 15+), observation de la
///   galerie avant (si l'accès aux médias est déjà accordé ; l'app ne le demande
///   pas pour cela). Voir `ScreenshotDetector.kt`.
///
/// Une plateforme sans détection (ou un échec natif) n'est pas une erreur : la
/// fonction est alors simplement inactive.
class ScreenshotWatcher {
  static const MethodChannel _channel = MethodChannel('com.alanya/screenshot');

  void Function()? _onShot;
  void Function()? _onRecording;

  /// [onScreenRecording] est appelé quand l'écran se met à être filmé pendant
  /// l'écoute, ou l'était déjà au [start] : une discussion ouverte en cours
  /// d'enregistrement est filmée tout autant.
  void start(void Function() onScreenshot, {void Function()? onScreenRecording}) {
    stop();
    _onShot = onScreenshot;
    _onRecording = onScreenRecording;
    try {
      if (Platform.isAndroid) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onScreenshot') _onShot?.call();
          if (call.method == 'onScreenRecording') _onRecording?.call();
        });
        _channel.invokeMethod<void>('start').catchError((Object e) {
          debugPrint('[ScreenshotWatcher] start: $e');
        });
      } else if (Platform.isIOS) {
        ScreenProtector.addListener(
          () => _onShot?.call(),
          (isCaptured) {
            if (isCaptured) _onRecording?.call();
          },
        );
        // La notification ne part qu'au CHANGEMENT d'état : un enregistrement
        // lancé avant d'ouvrir la discussion ne la déclencherait jamais.
        if (onScreenRecording != null) {
          ScreenProtector.isRecording().then((recording) {
            if (recording) _onRecording?.call();
          }).catchError((Object e) {
            debugPrint('[ScreenshotWatcher] isRecording: $e');
          });
        }
      }
    } catch (e) {
      debugPrint('[ScreenshotWatcher] start: $e');
    }
  }

  void stop() {
    if (_onShot == null) return;
    _onShot = null;
    _onRecording = null;
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
/// par fenêtre (une barrière par type d'événement : capture, enregistrement).
/// Le serveur applique sa propre limite (une ligne par minute, par auteur et
/// par événement) ; celle-ci évite surtout d'appeler pour rien.
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
