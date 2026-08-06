import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/validators.dart';

/// Le code de récupération est recopié à la main depuis un papier, souvent des
/// mois après l'inscription. Le validateur doit donc accepter tout ce qu'une
/// recopie humaine produit — minuscules, tirets absents, espaces du
/// presse-papiers — et ne refuser que ce qui ne peut pas être un code.
void main() {
  group('Validators.recoveryCode', () {
    test('accepts the canonical form', () {
      expect(Validators.recoveryCode('TQMP-KX3C-P6P5'), isNull);
    });

    test('accepts lowercase, missing dashes and stray spaces', () {
      expect(Validators.recoveryCode('tqmpkx3cp6p5'), isNull);
      expect(Validators.recoveryCode('tqmp kx3c p6p5'), isNull);
      expect(Validators.recoveryCode('  TQMP-kx3c-P6P5  '), isNull);
    });

    test('rejects empty input', () {
      expect(Validators.recoveryCode(''), isNotNull);
      expect(Validators.recoveryCode(null), isNotNull);
      expect(Validators.recoveryCode('---'), isNotNull);
    });

    test('rejects wrong lengths', () {
      expect(Validators.recoveryCode('TQMP-KX3C'), isNotNull);
      expect(Validators.recoveryCode('TQMP-KX3C-P6P5-EXTRA'), isNotNull);
    });
  });
}
