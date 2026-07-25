import 'package:shared_preferences/shared_preferences.dart';

/// Type de média dont on mémorise la vitesse de lecture.
///
/// Les trois sont indépendants : régler un vocal sur 1,5× ne doit pas accélérer
/// les vidéos.
enum PlaybackSpeedKind { voice, music, video }

/// Vitesse de lecture mémorisée par type de média.
///
/// Même forme que [MediaDownloadPreferences] : valeurs mises en cache statiquement
/// et [preload] appelé dans `main()`, pour que la première lecture applique tout
/// de suite le choix persisté sans attendre un `load()` asynchrone.
class PlaybackSpeedPreferences {
  PlaybackSpeedPreferences._();

  /// Paliers proposés pour l'audio (pastille cyclique).
  static const List<double> audioSpeeds = [1.0, 1.5, 2.0];

  /// Paliers proposés pour la vidéo (menu Chewie).
  static const List<double> videoSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static const double defaultSpeed = 1.0;

  static const Map<PlaybackSpeedKind, String> _keys = {
    PlaybackSpeedKind.voice: 'playback_speed_voice',
    PlaybackSpeedKind.music: 'playback_speed_music',
    PlaybackSpeedKind.video: 'playback_speed_video',
  };

  static final Map<PlaybackSpeedKind, double> _cache = {
    PlaybackSpeedKind.voice: defaultSpeed,
    PlaybackSpeedKind.music: defaultSpeed,
    PlaybackSpeedKind.video: defaultSpeed,
  };

  static bool _loaded = false;

  /// Paliers valides pour un type donné.
  static List<double> speedsFor(PlaybackSpeedKind kind) =>
      kind == PlaybackSpeedKind.video ? videoSpeeds : audioSpeeds;

  /// À appeler dans `main()` avant `runApp`.
  static Future<void> preload() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _keys.entries) {
      _cache[entry.key] = _sanitize(entry.key, prefs.getDouble(entry.value));
    }
    _loaded = true;
  }

  static double speedOf(PlaybackSpeedKind kind) =>
      _cache[kind] ?? defaultSpeed;

  static Future<void> setSpeed(PlaybackSpeedKind kind, double speed) async {
    final value = _sanitize(kind, speed);
    if (_cache[kind] == value) return;
    _cache[kind] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keys[kind]!, value);
  }

  /// Palier suivant en boucle. Une valeur inconnue repart du début.
  static double nextSpeed(PlaybackSpeedKind kind, double current) {
    final speeds = speedsFor(kind);
    final index = speeds.indexWhere((s) => (s - current).abs() < 0.001);
    if (index < 0) return speeds.first;
    return speeds[(index + 1) % speeds.length];
  }

  /// Une préférence absente ou hors paliers ne doit jamais bloquer la lecture.
  static double _sanitize(PlaybackSpeedKind kind, double? speed) {
    if (speed == null) return defaultSpeed;
    final speeds = speedsFor(kind);
    for (final s in speeds) {
      if ((s - speed).abs() < 0.001) return s;
    }
    return defaultSpeed;
  }

  /// Réinitialise le cache — tests uniquement.
  static void resetForTesting() {
    _loaded = false;
    for (final kind in PlaybackSpeedKind.values) {
      _cache[kind] = defaultSpeed;
    }
  }
}

/// Formatage francophone d'un palier : `1×`, `1,5×`, `0,75×`.
String formatPlaybackSpeed(double speed) {
  if (speed == speed.roundToDouble()) return '${speed.toInt()}×';
  final text = speed.toString().replaceAll('.', ',');
  return '$text×';
}
