import 'package:talky_flutter/core/services/webrtc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebRTCService ICE generation', () {
    test('bump incrémente et invalide l’ancienne génération', () {
      final w = WebRTCService();
      expect(w.iceGeneration, 0);
      expect(w.acceptsIceGeneration(null), isTrue);
      expect(w.acceptsIceGeneration(0), isTrue);

      final g1 = w.bumpIceGeneration();
      expect(g1, 1);
      expect(w.iceGeneration, 1);
      expect(w.acceptsIceGeneration(0), isFalse);
      expect(w.acceptsIceGeneration(1), isTrue);
      expect(w.acceptsIceGeneration(null), isTrue);

      final g2 = w.bumpIceGeneration();
      expect(g2, 2);
      expect(w.acceptsIceGeneration(1), isFalse);
      expect(w.acceptsIceGeneration(2), isTrue);
    });

    test('clearPendingIce ne change pas la génération', () {
      final w = WebRTCService();
      w.bumpIceGeneration();
      w.clearPendingIce();
      expect(w.iceGeneration, 1);
      expect(w.acceptsIceGeneration(1), isTrue);
    });
  });
}
