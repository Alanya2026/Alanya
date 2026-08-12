import 'package:flutter/foundation.dart';

/// Chronomètre du chemin critique « notification d'appel → média établi ».
///
/// Uniquement de l'instrumentation : chaque étape imprime le temps écoulé
/// depuis le premier `mark` de la trace (t0 = plus tôt possible dans `main()`)
/// et le delta avec l'étape précédente. Permet de savoir en une lecture de
/// `adb logcat -s flutter` quelle phase du démarrage à froid coûte du temps.
///
/// ```
/// [CallBoot] +0ms      (+0ms)    main:start
/// [CallBoot] +412ms    (+412ms)  main:firebase-ready
/// [CallBoot] +690ms    (+278ms)  bootstrap:auth-restored
/// [CallBoot] +702ms    (+12ms)   fastpath:callkit-accept
/// [CallBoot] +705ms    (+3ms)    socket:connect-requested
/// [CallBoot] +1180ms   (+475ms)  socket:auth-verified
/// [CallBoot] +1290ms   (+110ms)  signaling:incoming-call-offer
/// [CallBoot] +1291ms   (+1ms)    answer:begin
/// [CallBoot] +1305ms   (+14ms)   answer:ice-servers        ← préchauffé
/// [CallBoot] +1720ms   (+415ms)  answer:webrtc-init
/// [CallBoot] +1810ms   (+90ms)   answer:answer-sent
/// [CallBoot] +1812ms   (+2ms)    answer:connected
/// ```
class CallBootTrace {
  CallBootTrace._();

  static final Stopwatch _watch = Stopwatch();
  static int _lastMs = 0;
  static bool _enabled = true;

  /// Désactive la trace (tests, ou si le bruit de log gêne en production).
  static void setEnabled(bool value) => _enabled = value;

  /// Repart de zéro. Appelé au tout début de `main()` puis à chaque nouvel
  /// appel entrant, pour que les temps restent lisibles d'un appel à l'autre.
  static void reset([String? label]) {
    if (!_enabled) return;
    _watch
      ..reset()
      ..start();
    _lastMs = 0;
    if (label != null) mark(label);
  }

  /// Horodate une étape du chemin critique.
  static void mark(String step) {
    if (!_enabled) return;
    if (!_watch.isRunning) {
      _watch.start();
      _lastMs = 0;
    }
    final now = _watch.elapsedMilliseconds;
    final delta = now - _lastMs;
    _lastMs = now;
    debugPrint('[CallBoot] +${now}ms (+${delta}ms) $step');
  }
}
