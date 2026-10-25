import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/stickers/sticker_video_check.dart';

/// Lecteur minimal de l'écran « Sticker depuis une vidéo » : durée, position,
/// lecture, saut. Une **interface mince**, pour que l'écran se teste sans moteur
/// vidéo (la vraie lecture de `video_player` ne tourne pas en `flutter test`).
///
/// Le lecteur est **muet** : le sticker n'a pas de son (contrat §4d).
abstract class VideoWindowPlayer implements Listenable {
  /// Prépare la lecture. Lève une exception si la vidéo est illisible.
  Future<void> initialize();

  int get durationMs;
  int get positionMs;
  bool get isPlaying;

  /// Dimensions de l'image vidéo (après rotation), pour le recadrage `cover`.
  Size get videoSize;

  Future<void> seekTo(int ms);
  Future<void> play();
  Future<void> pause();

  /// La surface vidéo, à placer dans un cadre recadré.
  Widget buildView();

  /// Libère le lecteur et tout fichier temporaire. Idempotent.
  Future<void> dispose();
}

/// Fabrique d'un [VideoWindowPlayer] pour des octets de vidéo déjà en mémoire.
typedef VideoWindowPlayerFactory =
    Future<VideoWindowPlayer> Function(Uint8List bytes, StickerVideoKind kind);

/// Production : écrit la vidéo dans un fichier temporaire (le lecteur natif lit
/// un fichier), la joue en `video_player`, supprime le fichier à la fermeture.
Future<VideoWindowPlayer> createVideoWindowPlayer(
  Uint8List bytes,
  StickerVideoKind kind,
) async {
  final dir = await getTemporaryDirectory();
  final name = 'sticker_video_${DateTime.now().microsecondsSinceEpoch}'
      '_${math.Random().nextInt(1 << 32)}${kind.extension}';
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return _FileVideoWindowPlayer(file);
}

class _FileVideoWindowPlayer extends ChangeNotifier
    implements VideoWindowPlayer {
  _FileVideoWindowPlayer(this._file) : _controller = VideoPlayerController.file(_file);

  final File _file;
  final VideoPlayerController _controller;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setVolume(0);
    await _controller.setLooping(false);
    _controller.addListener(notifyListeners);
  }

  @override
  int get durationMs => _controller.value.duration.inMilliseconds;

  @override
  int get positionMs => _controller.value.position.inMilliseconds;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  Size get videoSize => _controller.value.size;

  @override
  Future<void> seekTo(int ms) => _controller.seekTo(Duration(milliseconds: ms));

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(notifyListeners);
    await _controller.dispose();
    try {
      if (await _file.exists()) await _file.delete();
    } catch (_) {
      // Fichier temporaire : le système le nettoiera.
    }
    super.dispose();
  }
}
