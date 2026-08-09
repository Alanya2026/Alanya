import 'package:talky_flutter/core/services/call/call_restart_roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('restart roles', () {
    test('1-1 : seul le caller initie', () {
      expect(isOneToOneRestartInitiator(isOutgoingCaller: true), isTrue);
      expect(isOneToOneRestartInitiator(isOutgoingCaller: false), isFalse);
    });

    test('groupe : userId min du pair initie', () {
      expect(isGroupRestartInitiator(me: '10', peerId: '77'), isTrue);
      expect(isGroupRestartInitiator(me: '77', peerId: '10'), isFalse);
      expect(isGroupRestartInitiator(me: '5', peerId: '5'), isTrue);
    });
  });

  // E2E manuelle (hors CI) — Wi‑Fi↔4G, lockscreen micro, resume owner-only,
  // mesh A↔C sans leave C, FGS MICROPHONE vs CAMERA, transfert 10s/25s.
}
