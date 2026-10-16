//  Service Android de premier plan pendant les envois vers le coffre-fort
//  (android/…/SafeboxTransferService.kt) : sans lui, Android suspend puis tue
//  l'application dès que l'inscrit passe à autre chose.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SafeboxForeground {
  SafeboxForeground({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('com.alanya/media_export');

  final MethodChannel _channel;
  bool _actif = false;
  String? _dernier;

  bool get _android => !kIsWeb && Platform.isAndroid;

  /// Démarre le service, ou met sa notification à jour. Les appels identiques
  /// au précédent ne repartent pas vers Android.
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required int percent,
  }) async {
    if (!_android) return;
    final cle = '$title|$text|$percent';
    if (_actif && cle == _dernier) return;
    _dernier = cle;
    _actif = true;
    try {
      await _channel.invokeMethod('safeboxServiceUpdate', {
        'channelName': channelName,
        'title': title,
        'text': text,
        'percent': percent,
      });
    } catch (e) {
      // Jamais bloquant : sans le service, l'envoi continue tant que
      // l'application reste ouverte, et reprend sinon au démarrage suivant.
      debugPrint('[Coffre] service de premier plan indisponible : $e');
    }
  }

  Future<void> stop() async {
    if (!_android || !_actif) return;
    _actif = false;
    _dernier = null;
    try {
      await _channel.invokeMethod('safeboxServiceStop');
    } catch (e) {
      debugPrint('[Coffre] arrêt du service : $e');
    }
  }
}
