// Alanya ne passe par-dessus l'écran de verrouillage que pendant un appel.
//
// Le réglage était permanent : téléphone verrouillé avec Alanya au premier
// plan, l'app réapparaissait à l'allumage de l'écran sans code (signalement
// du groupe 3GI 2029, bug A1).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call_service.dart';
import 'package:talky_flutter/core/services/lock_screen_policy.dart';

void main() {
  test('hors appel : jamais par-dessus le verrou', () {
    expect(appelVisibleSurLeVerrou(CallStatus.idle), isFalse);
    expect(appelVisibleSurLeVerrou(CallStatus.ended), isFalse);
  });

  test('sonnerie entrante : CallKit présente, pas Alanya', () {
    expect(appelVisibleSurLeVerrou(CallStatus.incoming), isFalse);
  });

  test('appel émis, décroché ou en cours : visible', () {
    for (final s in [
      CallStatus.outgoing,
      CallStatus.joining,
      CallStatus.connecting,
      CallStatus.connected,
      CallStatus.reconnecting,
    ]) {
      expect(appelVisibleSurLeVerrou(s), isTrue, reason: '$s');
    }
  });
}
