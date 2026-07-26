import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/presence_service.dart';

/// Harnais : capture les émissions de présence et le résolveur installé sur la
/// couche socket, sans toucher au réseau.
class _Harness {
  final List<bool> emitted = [];
  bool Function()? resolver;
  bool sessionActive = false;

  late final PresenceService service;

  _Harness({Duration debounce = const Duration(milliseconds: 50)}) {
    service = PresenceService(
      sendPresence: ({required bool online}) => emitted.add(online),
      registerResolver: (r) => resolver = r,
      isSessionActive: () => sessionActive,
      offlineDebounce: debounce,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const debounce = Duration(milliseconds: 50);
  final afterDebounce = debounce + const Duration(milliseconds: 20);

  test('attach installe le résolveur et déclare la présence courante', () {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);

    expect(h.resolver, isNotNull);
    // Le handshake `auth:verified` consulte le résolveur.
    expect(h.resolver!(), isTrue);
    expect(h.service.declared, isTrue);
  });

  test('passage en arrière-plan → hors ligne après le debounce', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    h.service.handleLifecycleState(AppLifecycleState.paused);
    // Rien tout de suite : la transition est différée.
    expect(h.emitted, isEmpty);
    expect(h.service.hasPendingOfflineTransition, isTrue);

    await Future<void>.delayed(afterDebounce);
    expect(h.emitted, [false]);
    expect(h.service.declared, isFalse);
  });

  test('retour au premier plan → en ligne immédiatement', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    h.service.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(afterDebounce);
    h.emitted.clear();

    h.service.handleLifecycleState(AppLifecycleState.resumed);
    expect(h.emitted, [true]);
  });

  test('aller-retour rapide : aucune bascule (debounce)', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    // Sélecteur de fichiers, dialogue de permission : l'app ressort aussitôt.
    h.service.handleLifecycleState(AppLifecycleState.paused);
    h.service.handleLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(afterDebounce);

    expect(h.emitted, isEmpty);
    expect(h.service.declared, isTrue);
  });

  test('inactive n\'est pas traité comme un arrière-plan', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    h.service.handleLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(afterDebounce);

    expect(h.emitted, isEmpty);
    expect(h.service.declared, isTrue);
  });

  test('hidden et detached comptent comme arrière-plan', () async {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      final h = _Harness()..service.attach();
      h.resolver!();
      h.service.handleLifecycleState(state);
      await Future<void>.delayed(afterDebounce);
      expect(h.emitted, [false], reason: '$state doit passer hors ligne');
      h.service.dispose();
    }
  });

  test('appel en cours : reste en ligne en arrière-plan', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    h.sessionActive = true;
    h.service.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(afterDebounce);

    expect(h.emitted, isEmpty);
    expect(h.service.shouldBeOnline, isTrue);
  });

  test('fin d\'appel alors que l\'app est déjà en arrière-plan → hors ligne',
      () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    final source = ChangeNotifier();
    h.service.bindSessionSource(source);

    h.sessionActive = true;
    h.service.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(afterDebounce);
    expect(h.emitted, isEmpty);

    // L'appel se termine : CallService notifie, la présence est réévaluée.
    h.sessionActive = false;
    source.notifyListeners();
    await Future<void>.delayed(afterDebounce);

    expect(h.emitted, [false]);
  });

  test('le résolveur reflète l\'état courant à la reconnexion', () async {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();

    h.service.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(afterDebounce);

    // Reconnexion socket alors que l'app est toujours en arrière-plan :
    // on doit se ré-annoncer hors ligne, pas en ligne.
    expect(h.resolver!(), isFalse);
  });

  test('detach coupe toute émission ultérieure', () async {
    final h = _Harness()..service.attach();
    h.resolver!();
    h.service.detach();

    expect(h.resolver, isNull);
    h.service.handleLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(afterDebounce);
    expect(h.emitted, isEmpty);

    h.service.dispose();
  });

  test('attach après detach repart proprement', () {
    final h = _Harness()..service.attach();
    addTearDown(h.service.dispose);
    h.resolver!();
    h.service.detach();

    h.service.attach();
    expect(h.resolver, isNotNull);
    expect(h.resolver!(), isTrue);
  });
}
