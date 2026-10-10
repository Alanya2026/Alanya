// L'empreinte n'est redemandée qu'après une vraie absence.
//
// Elle l'était à chaque perte de focus — volet des notifications, galerie,
// appareil photo — et des utilisateurs désactivaient le verrou (signalement du
// groupe 3GI 2029, bug A4).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/widgets/session/biometric_lock_overlay.dart';

void main() {
  final t0 = DateTime(2026, 10, 10, 12);

  test('jamais passée en arrière-plan (volet, dialogue) : pas d\'empreinte', () {
    expect(biometrieExigeeAuRetour(quitteeA: null, maintenant: t0), isFalse);
  });

  test('aller-retour rapide (galerie, appareil photo) : pas d\'empreinte', () {
    expect(
      biometrieExigeeAuRetour(
        quitteeA: t0,
        maintenant: t0.add(const Duration(seconds: 12)),
      ),
      isFalse,
    );
  });

  test('absence au-delà du délai de grâce : empreinte', () {
    expect(
      biometrieExigeeAuRetour(
        quitteeA: t0,
        maintenant: t0.add(kBiometricRelockGrace),
      ),
      isTrue,
    );
    expect(
      biometrieExigeeAuRetour(
        quitteeA: t0,
        maintenant: t0.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });
}
