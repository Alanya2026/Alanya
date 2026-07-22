import '../../utils/app_log.dart';

/// Trace latence du parcours message (sender / receiver) en release.
///
/// Une entrée par [clientId] (ou clé synthétique destinataire), Stopwatch
/// monotone, purge LRU ~200 pour éviter les fuites mémoire.
class MessagePathTracer {
  MessagePathTracer._();

  static const int _maxEntries = 200;
  static const String _tag = 'MsgPath';

  static final Map<String, _Trace> _traces = {};

  /// Démarre (ou redémarre) une trace pour [clientId].
  static void start(String clientId, {String role = 'sender'}) {
    if (clientId.isEmpty) return;
    _evictIfNeeded();
    _traces[clientId] = _Trace(role: role)..sw.start();
    _log(clientId, 'click', role: role, ms: 0);
  }

  /// Enregistre une étape. Si [clientId] inconnu et [startIfMissing], démarre.
  static void mark(
    String clientId,
    String stage, {
    String? role,
    bool startIfMissing = false,
  }) {
    if (clientId.isEmpty) return;
    var t = _traces[clientId];
    if (t == null) {
      if (!startIfMissing) return;
      _evictIfNeeded();
      t = _Trace(role: role ?? 'receiver')..sw.start();
      _traces[clientId] = t;
    }
    final r = role ?? t.role;
    _log(clientId, stage, role: r, ms: t.sw.elapsedMilliseconds);
  }

  /// Fin de vie utile (ack reçu) — conserve l'entrée pour status_delivered/read.
  static void ackReceived(String clientId) {
    mark(clientId, 'ack_received');
  }

  static void status(String clientId, int status) {
    if (status == 2) {
      mark(clientId, 'status_delivered');
    } else if (status == 3) {
      mark(clientId, 'status_read');
      _traces.remove(clientId);
    }
  }

  static void clear(String clientId) => _traces.remove(clientId);

  static void _log(String clientId, String stage, {required String role, required int ms}) {
    AppLog.i(
      _tag,
      'clientId=$clientId stage=$stage ms_since_click=$ms role=$role',
    );
  }

  static void _evictIfNeeded() {
    while (_traces.length >= _maxEntries) {
      _traces.remove(_traces.keys.first);
    }
  }
}

class _Trace {
  _Trace({required this.role});
  final String role;
  final Stopwatch sw = Stopwatch();
}
