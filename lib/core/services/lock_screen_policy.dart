import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_service.dart' show CallStatus;

/// Un appel dans cet état doit-il rester visible par-dessus l'écran de
/// verrouillage ?
///
/// `incoming` n'en fait pas partie : téléphone verrouillé, l'app passe en
/// arrière-plan et la sonnerie est confiée à l'écran plein de CallKit, qui a
/// sa propre activité. Afficher aussi Alanya doublerait l'écran d'appel.
bool appelVisibleSurLeVerrou(CallStatus status) {
  switch (status) {
    case CallStatus.outgoing:
    case CallStatus.joining:
    case CallStatus.connecting:
    case CallStatus.connected:
    case CallStatus.reconnecting:
      return true;
    case CallStatus.idle:
    case CallStatus.incoming:
    case CallStatus.ended:
      return false;
  }
}

/// Affichage d'Alanya par-dessus l'écran de verrouillage, accordé seulement
/// pendant un appel ou une réunion.
///
/// Le réglage était permanent (manifeste + `MainActivity`) : quiconque
/// rallumait un téléphone verrouillé pendant qu'Alanya était au premier plan
/// lisait les conversations sans code. Deux sources l'accordent désormais :
/// l'état de [CallService] et la session média tenue par `CallSessionGuard`
/// (qui couvre aussi les réunions). Il suffit d'une des deux.
///
/// Le natif l'accorde lui-même au décrochage depuis l'écran verrouillé, avant
/// que Flutter ne soit prêt. Pour ne pas le lui retirer au démarrage, on
/// n'envoie qu'aux changements : l'état initial (aucun appel) n'émet rien.
class LockScreenPolicy {
  LockScreenPolicy._();

  static const _channel = MethodChannel('com.alanya237.alanya/lock_screen');

  static bool _callActive = false;
  static bool _sessionHeld = false;
  static bool _applied = false;

  static void setCallActive(bool active) {
    if (_callActive == active) return;
    _callActive = active;
    _apply();
  }

  static void setSessionHeld(bool held) {
    if (_sessionHeld == held) return;
    _sessionHeld = held;
    _apply();
  }

  static void _apply() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final enabled = _callActive || _sessionHeld;
    if (enabled == _applied) return;
    _applied = enabled;
    _channel
        .invokeMethod('setShowWhenLocked', {'enabled': enabled})
        .catchError((Object e) {
      debugPrint('[LockScreenPolicy] setShowWhenLocked($enabled) échoué: $e');
    });
  }
}
