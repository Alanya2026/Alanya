import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stall = Duration(milliseconds: 200);

  test('aucun morceau pendant le délai : l’envoi est jugé bloqué', () async {
    final guard = UploadStallGuard(stallTimeout: stall);
    await guard.abortTrigger.timeout(const Duration(seconds: 5));
    expect(guard.stalled, isTrue);
  });

  test('des morceaux réguliers le gardent en vie bien au-delà du délai', () async {
    final guard = UploadStallGuard(stallTimeout: stall);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      guard.tick();
    }
    // Deux fois le délai écoulé : c'est l'inactivité qui compte, pas la durée.
    expect(guard.stalled, isFalse);
    guard.stop();
  });

  test('arrêté, il ne se déclenche plus', () async {
    final guard = UploadStallGuard(stallTimeout: stall)..stop();
    await Future<void>.delayed(stall * 2);
    expect(guard.stalled, isFalse);
  });
}
