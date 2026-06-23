// Détection locale du locuteur actif, via les stats WebRTC natives.
// Aucune donnée n'est envoyée au serveur ni aux autres participants :
// chaque client interroge périodiquement `getStats()` sur les
// RTCPeerConnection qu'il possède déjà (mesh 1-1 / groupe / meeting) et en
// déduit qui est en train de parler, parmi les flux qu'il reçoit, ainsi que
// pour son propre micro.
import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Détecteur de locuteur(s) actif(s), partagé par les écrans d'appel 1-1,
/// d'appel de groupe et de meeting.
///
/// Fonctionnement :
/// - toutes les [pollInterval], on lit `audioLevel` dans les rapports de
///   stats WebRTC de chaque PeerConnection du mesh ;
/// - `inbound-rtp` (kind=audio) donne le niveau du flux **reçu** d'un pair
///   distant → on l'associe à son userId ;
/// - `media-source`/`track` (kind=audio) donne le niveau du **micro local**
///   (la valeur est identique quel que soit le PeerConnection interrogé,
///   puisque c'est la même piste locale qui est envoyée à tous les pairs en
///   mesh) → on l'associe à [localKey].
/// - un système d'hystérésis (frames consécutives au-dessus/en-dessous du
///   seuil) évite que l'indicateur clignote sur chaque micro-pic de bruit.
class SpeakingDetector extends ChangeNotifier {
  SpeakingDetector({
    this.threshold = 0.04,
    this.pollInterval = const Duration(milliseconds: 350),
    this.framesToActivate = 2,
    this.framesToDeactivate = 3,
  });

  /// Niveau RMS WebRTC (échelle 0.0–1.0) au-delà duquel on considère que la
  /// personne parle. 0.04 filtre le bruit de fond / souffle du micro sans
  /// rater la voix.
  final double threshold;
  final Duration pollInterval;

  /// Nombre de mesures consécutives au-dessus du seuil avant d'allumer
  /// l'indicateur (anti-flicker).
  final int framesToActivate;

  /// Nombre de mesures consécutives en-dessous du seuil avant de l'éteindre
  /// (on relâche un peu plus lentement qu'on n'allume, plus naturel).
  final int framesToDeactivate;

  /// Clé conventionnelle représentant "mon" propre micro dans
  /// [activeSpeakers], puisqu'il n'y a pas d'userId associé côté local.
  static const String localKey = '__local__';

  Timer? _timer;
  final Set<String> _activeSpeakers = {};
  final Map<String, int> _aboveStreak = {};
  final Map<String, int> _belowStreak = {};

  Set<String> get activeSpeakers => Set.unmodifiable(_activeSpeakers);
  bool isSpeaking(String id) => _activeSpeakers.contains(id);
  bool get amISpeaking => isSpeaking(localKey);

  /// Démarre le polling. [peerConnectionsProvider] doit renvoyer la map
  /// courante userId→RTCPeerConnection à chaque appel (pas une copie figée),
  /// car des participants rejoignent/quittent en cours d'appel.
  void start(Map<String, RTCPeerConnection> Function() peerConnectionsProvider) {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll(peerConnectionsProvider()));
  }

  Future<void> _poll(Map<String, RTCPeerConnection> peerConnections) async {
    if (peerConnections.isEmpty) return;

    bool localCaptured = false;

    for (final entry in peerConnections.entries) {
      final userId = entry.key;
      final pc = entry.value;
      try {
        final reports = await pc.getStats();
        for (final r in reports) {
          final values = r.values;
          if (values['kind'] != 'audio') continue;

          // Flux distant reçu de ce pair.
          if (r.type == 'inbound-rtp') {
            final level = (values['audioLevel'] as num?)?.toDouble();
            if (level != null) _registerSample(userId, level);
          }

          // Mon propre micro : même valeur quel que soit le PC interrogé
          // (piste locale unique partagée par tous les pairs du mesh), donc
          // on ne la capture qu'une fois par cycle.
          if (!localCaptured &&
              (r.type == 'media-source' || r.type == 'track')) {
            final level = (values['audioLevel'] as num?)?.toDouble();
            if (level != null) {
              _registerSample(localKey, level);
              localCaptured = true;
            }
          }
        }
      } catch (e) {
        debugPrint('[SpeakingDetector] getStats échoué pour $userId: $e');
      }
    }
  }

  void _registerSample(String id, double level) {
    final aboveThreshold = level >= threshold;
    if (aboveThreshold) {
      _aboveStreak[id] = (_aboveStreak[id] ?? 0) + 1;
      _belowStreak[id] = 0;
      if (!_activeSpeakers.contains(id) &&
          _aboveStreak[id]! >= framesToActivate) {
        _activeSpeakers.add(id);
        notifyListeners();
      }
    } else {
      _belowStreak[id] = (_belowStreak[id] ?? 0) + 1;
      _aboveStreak[id] = 0;
      if (_activeSpeakers.contains(id) &&
          _belowStreak[id]! >= framesToDeactivate) {
        _activeSpeakers.remove(id);
        notifyListeners();
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_activeSpeakers.isNotEmpty) {
      _activeSpeakers.clear();
      notifyListeners();
    }
    _aboveStreak.clear();
    _belowStreak.clear();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}