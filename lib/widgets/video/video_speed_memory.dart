import 'dart:async';

import 'package:video_player/video_player.dart';

import '../../core/services/playback_speed_preferences.dart';

/// Paliers proposés dans le menu de Chewie.
///
/// La liste par défaut du paquet en compte huit, dont 0,25× et 1,75× qui
/// n'apportent rien ici. On la resserre.
const List<double> kVideoPlaybackSpeeds = PlaybackSpeedPreferences.videoSpeeds;

/// Applique la vitesse vidéo mémorisée et persiste les changements.
///
/// Chewie règle la vitesse directement sur le [VideoPlayerController] sans
/// prévenir l'appelant : on observe donc le contrôleur plutôt que le menu.
///
/// À attacher **après** `initialize()` — régler la vitesse sur un contrôleur
/// non initialisé est sans effet.
class VideoSpeedMemory {
  VideoSpeedMemory._(this._controller, this._last);

  static VideoSpeedMemory attach(VideoPlayerController controller) {
    final stored = PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.video);
    final memory = VideoSpeedMemory._(controller, stored);
    unawaited(controller.setPlaybackSpeed(stored));
    controller.addListener(memory._onChanged);
    return memory;
  }

  final VideoPlayerController _controller;
  double _last;

  void _onChanged() {
    final current = _controller.value.playbackSpeed;
    if ((current - _last).abs() < 0.001) return;
    _last = current;
    unawaited(
      PlaybackSpeedPreferences.setSpeed(PlaybackSpeedKind.video, current),
    );
  }

  void dispose() => _controller.removeListener(_onChanged);
}
