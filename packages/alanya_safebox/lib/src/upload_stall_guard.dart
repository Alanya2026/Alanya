import 'dart:async';

/// Délai au-delà duquel un envoi qui n'avance plus est abandonné.
///
/// Un délai d'*inactivité*, pas une durée totale : 100 Mo sur une connexion
/// mobile à 1 Mbit/s prennent près de 14 minutes, et c'est normal. Ce qui ne
/// l'est pas, c'est qu'aucun octet ne parte pendant une minute.
const Duration kUploadStallTimeout = Duration(seconds: 60);

/// Coupe un envoi qui n'avance plus.
///
/// Chaque morceau qui part réarme le compte à rebours ([tick]). Sans morceau
/// pendant [stallTimeout], [abortTrigger] se complète : le client HTTP
/// interrompt la requête. Après le dernier morceau, le même délai couvre
/// l'attente de la réponse du serveur.
class UploadStallGuard {
  UploadStallGuard({this.stallTimeout = kUploadStallTimeout}) {
    _arm();
  }

  final Duration stallTimeout;
  final Completer<void> _abort = Completer<void>();
  Timer? _timer;

  /// Se complète quand l'envoi est jugé bloqué.
  Future<void> get abortTrigger => _abort.future;

  /// `true` une fois l'envoi jugé bloqué.
  bool get stalled => _abort.isCompleted;

  /// Un morceau vient de partir.
  void tick() => _arm();

  /// L'envoi est terminé (réussi ou non) : plus rien à surveiller.
  void stop() => _timer?.cancel();

  /// Coupe l'envoi tout de suite (pause ou annulation demandée).
  void abortNow() {
    _timer?.cancel();
    if (!_abort.isCompleted) _abort.complete();
  }

  void _arm() {
    _timer?.cancel();
    if (_abort.isCompleted) return;
    _timer = Timer(stallTimeout, () {
      if (!_abort.isCompleted) _abort.complete();
    });
  }
}
