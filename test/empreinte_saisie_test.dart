import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/documents_sensibles/empreinte_saisie.dart';
// Compilé ici : l'écran « Vérifier une empreinte » et son entrée.
// ignore: unused_import
import 'package:talky_flutter/screens/profile/account_security_screen.dart';

/// L'empreinte telle qu'on la saisit : huit blocs de quatre, en majuscules.
void main() {
  TextEditingValue taper(String avant, String apres, int curseur) =>
      FormateurEmpreinte().formatEditUpdate(
        TextEditingValue(text: avant),
        TextEditingValue(
          text: apres,
          selection: TextSelection.collapsed(offset: curseur),
        ),
      );

  test('nettoyer : seuls 0-9 et A-F restent, en majuscules', () {
    expect(Empreinte.nettoyer(' 3f9a-0c1e\nzz5b'), '3F9A0C1E5B');
  });

  test('en blocs, et la forme du serveur', () {
    const c = '3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f';
    expect(Empreinte.enBlocs(c), '3F9A 0C1E 5B7D 2A4C 6E8F 0A1B 2C3D 4E5F');
    expect(Empreinte.pourServeur(Empreinte.enBlocs(c)), c);
    expect(Empreinte.pourServeur('3F9A'), isNull);
  });

  test('la frappe est regroupée, le curseur suit', () {
    final v = taper('3F9', '3F9a', 4);
    expect(v.text, '3F9A');
    final w = taper('3F9A', '3F9A0', 5);
    expect(w.text, '3F9A 0');
    expect(w.selection.end, 6);
  });

  test('un collage trop long est borné à 32 caractères', () {
    final v = taper('', 'a' * 40, 40);
    expect(Empreinte.nettoyer(v.text).length, 32);
  });
}
