import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../talky_api_client.dart';

/// Ce que CE téléphone sait faire en HEVC 720p, par une puce dédiée.
@immutable
class VideoCodecSupport {
  const VideoCodecSupport({required this.hevcEncoder, required this.hevcDecoder});

  final bool hevcEncoder;
  final bool hevcDecoder;

  static const none = VideoCodecSupport(hevcEncoder: false, hevcDecoder: false);

  static Future<VideoCodecSupport>? _detected;

  /// Android : le pont natif inspecte les codecs du téléphone. iOS : l'app
  /// exige iOS 15.5, et tous les iPhone qui le font tourner lisent le HEVC par
  /// leur puce ; l'envoi, lui, reste en H.264. Ailleurs : rien.
  static Future<VideoCodecSupport> detect() => _detected ??= _detect();

  static Future<VideoCodecSupport> _detect() async {
    try {
      if (Platform.isIOS) {
        return const VideoCodecSupport(hevcEncoder: false, hevcDecoder: true);
      }
      if (!Platform.isAndroid) return none;
      final raw = await const MethodChannel('com.alanya237.alanya/video_transcode')
          .invokeMethod<Map<dynamic, dynamic>>('capabilities');
      return VideoCodecSupport(
        hevcEncoder: raw?['hevcEncoder'] == true,
        hevcDecoder: raw?['hevcDecoder'] == true,
      );
    } catch (e) {
      debugPrint('[VideoCodec] capacités illisibles: $e');
      return none;
    }
  }
}

/// `true` si une vidéo destinée à [conversationID] peut partir en HEVC, d'après
/// l'instance créée au démarrage ; `false` sans elle.
Future<bool> hevcAllowedFor(int conversationID) =>
    VideoCodecPolicy.maybeInstance?.allowsHevc(conversationID) ??
    Future.value(false);

/// Décide, discussion par discussion, si une vidéo peut partir en HEVC.
///
/// Le HEVC pèse un tiers de moins que le H.264 à qualité égale, mais certains
/// téléphones ne le lisent pas. Il faut donc deux choses :
///
/// - ce téléphone l'encode par une puce dédiée ([VideoCodecSupport]) ;
/// - le serveur confirme que tous les appareils actifs des membres de la
///   discussion le lisent. Chaque téléphone le déclare une fois par session
///   ([reportCapabilities]) ; une ancienne version de l'app ne déclare rien et
///   compte comme incapable.
///
/// Dans le doute — réseau absent, serveur antérieur, réponse illisible — c'est
/// non : la vidéo part en H.264, que tout le monde lit.
class VideoCodecPolicy {
  VideoCodecPolicy({
    required Future<bool> Function(int conversationID) fetchAllowsHevc,
    required Future<void> Function({required bool hevcDecode}) sendCapabilities,
    Future<VideoCodecSupport> Function()? support,
    this.cacheFor = const Duration(minutes: 10),
    DateTime Function()? clock,
  })  : _fetchAllowsHevc = fetchAllowsHevc,
        _sendCapabilities = sendCapabilities,
        _support = support ?? VideoCodecSupport.detect,
        _clock = clock ?? DateTime.now {
    _instance = this;
  }

  /// Branché sur l'API de l'app.
  factory VideoCodecPolicy.forApi(TalkyApiClient api) => VideoCodecPolicy(
        fetchAllowsHevc: api.conversationAllowsHevc,
        sendCapabilities: api.reportVideoCapabilities,
      );

  static VideoCodecPolicy? _instance;

  /// L'instance créée au démarrage, pour les services sans contexte.
  static VideoCodecPolicy? get maybeInstance => _instance;

  /// Durée pendant laquelle la réponse du serveur est réutilisée : un nouveau
  /// membre, ou un nouvel appareil, est pris en compte au plus tard après.
  final Duration cacheFor;

  final Future<bool> Function(int conversationID) _fetchAllowsHevc;
  final Future<void> Function({required bool hevcDecode}) _sendCapabilities;
  final Future<VideoCodecSupport> Function() _support;
  final DateTime Function() _clock;

  final Map<int, ({bool hevc, DateTime at})> _cache = {};
  bool _reported = false;

  /// `true` si une vidéo destinée à [conversationID] peut partir en HEVC.
  /// Ne lève jamais.
  Future<bool> allowsHevc(int conversationID) async {
    try {
      if (!(await _support()).hevcEncoder) return false;
      return await _membresLisentHevc(conversationID);
    } catch (e) {
      debugPrint('[VideoCodec] autorisation HEVC inconnue pour $conversationID, H.264: $e');
      return false;
    }
  }

  /// `true` si tous les appareils actifs des membres de [conversationID]
  /// lisent le HEVC, quel que soit ce téléphone : pour une vidéo déjà en HEVC
  /// (coffre-fort), qui n'a pas à être encodée ici. `null` si on ne sait pas.
  Future<bool?> membersReadHevc(int conversationID) async {
    try {
      return await _membresLisentHevc(conversationID);
    } catch (e) {
      debugPrint('[VideoCodec] lecture HEVC inconnue pour $conversationID: $e');
      return null;
    }
  }

  Future<bool> _membresLisentHevc(int conversationID) async {
    final now = _clock();
    final hit = _cache[conversationID];
    if (hit != null && now.difference(hit.at) < cacheFor) return hit.hevc;
    final hevc = await _fetchAllowsHevc(conversationID);
    _cache[conversationID] = (hevc: hevc, at: now);
    return hevc;
  }

  /// Déclare au serveur si ce téléphone lit le HEVC. Une fois par session ;
  /// un échec sera retenté au prochain appel. Ne lève jamais.
  Future<void> reportCapabilities() async {
    if (_reported) return;
    try {
      final support = await _support();
      await _sendCapabilities(hevcDecode: support.hevcDecoder);
      _reported = true;
    } catch (e) {
      debugPrint('[VideoCodec] capacités non déclarées: $e');
    }
  }

  /// À la déconnexion : le compte suivant redéclare, et ses discussions sont
  /// redemandées.
  void reset() {
    _cache.clear();
    _reported = false;
  }
}
