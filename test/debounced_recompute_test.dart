import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/chat/debounced_recompute.dart';

void main() {
  test('3 schedule rapides → 1 seul recompute', () async {
    var calls = 0;
    final d = DebouncedRecompute(
      (_) async {
        calls++;
      },
      window: const Duration(milliseconds: 30),
    );

    d.schedule(10);
    d.schedule(10);
    d.schedule(10);
    expect(calls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
    d.dispose();
  });

  test('flushNow exécute immédiatement et annule le debounce', () async {
    var calls = 0;
    final d = DebouncedRecompute(
      (_) async {
        calls++;
      },
      window: const Duration(milliseconds: 200),
    );

    d.schedule(7);
    await d.flushNow(7);
    expect(calls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(calls, 1);
    d.dispose();
  });

  test('conversations distinctes ne se coalescent pas', () async {
    final seen = <int>[];
    final d = DebouncedRecompute(
      (id) async {
        seen.add(id);
      },
      window: const Duration(milliseconds: 20),
    );

    d.schedule(1);
    d.schedule(2);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(seen.toSet(), {1, 2});
    d.dispose();
  });
}
