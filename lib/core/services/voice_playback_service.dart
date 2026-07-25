import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'playback_speed_preferences.dart';
import 'voice_chat_context.dart';
import '../utils/audio_message_kind.dart';

/// Lecteur audio singleton pour les messages vocaux du chat.
/// Un seul vocal peut jouer à la fois ; le changement de message arrête le précédent.
class VoicePlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String? _activeMessageId;
  String? _loadedMessageId;
  String? _loadingMessageId;

  /// Message dont le démarrage a été annulé par un tap pendant le chargement.
  String? _cancelledLoadId;
  VoicePlaybackSource? _source;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  VoiceChatContext? _chatContext;
  bool _backgroundPlayback = false;
  double _speed = PlaybackSpeedPreferences.defaultSpeed;

  /// Écran de conversation ouvert depuis le mini-lecteur : évite d'en empiler
  /// deux instances si l'utilisateur tape plusieurs fois le bandeau.
  bool _isChatRouteOpen = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  String? get activeMessageId => _activeMessageId;
  bool isMessageLoading(String messageId) => _loadingMessageId == messageId;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _playing;
  VoiceChatContext? get chatContext => _chatContext;
  VoicePlaybackSource? get source => _source;

  bool get hasActivePlayback =>
      _source != null &&
      _loadedMessageId != null &&
      _player.processingState != ProcessingState.idle;

  /// Mini-lecteur visible quand on a quitté le chat mais qu'un vocal est chargé.
  bool get showMiniPlayer =>
      _backgroundPlayback && _chatContext != null && hasActivePlayback;

  bool isActive(String messageId) => _activeMessageId == messageId;

  VoicePlaybackService() {
    _stateSub = _player.playerStateStream.listen((state) {
      _playing = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _playing = false;
        _position = _duration;
        _clearPlayback();
        _backgroundPlayback = false;
      }
      notifyListeners();
    });
    _positionSub = _player.positionStream.listen((pos) {
      if (_loadedMessageId != null) {
        _position = pos;
        notifyListeners();
      }
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && dur.inMilliseconds > 0) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  // Le contexte n'est plus posé à l'ouverture d'un chat : il vient de la bulle
  // au moment de la lecture, via `toggle`. Le fixer ailleurs écrasait celui de
  // la conversation en cours d'écoute.

  void enterChat(int conversationId) {
    // Entrer dans une AUTRE conversation ne doit pas masquer le mini-lecteur :
    // seul le retour dans celle qui joue rend la main à la bulle.
    if (_chatContext == null || _chatContext!.conversationId == conversationId) {
      _backgroundPlayback = false;
    }
    notifyListeners();
  }

  void leaveChat() {
    if (hasActivePlayback || _playing) {
      _backgroundPlayback = true;
    }
    notifyListeners();
  }

  Future<void> toggle({
    required String messageId,
    String? localPath,
    String? networkUrl,
    Duration fallbackDuration = Duration.zero,
    VoiceChatContext? chatContext,
    String? title,
    AudioMessageKind kind = AudioMessageKind.voiceNote,
    int serverMsgId = 0,
  }) async {
    if (chatContext != null) _chatContext = chatContext;
    // Chargement en cours : le tap annule le démarrage au lieu d'être ignoré.
    // Sans ça le bouton reste bloqué jusqu'à la fin du décodage.
    if (_loadingMessageId == messageId) {
      cancelPendingStart(messageId);
      return;
    }
    if (_activeMessageId == messageId && _playing) {
      await pause();
      return;
    }
    await play(
      messageId: messageId,
      localPath: localPath,
      networkUrl: networkUrl,
      fallbackDuration: fallbackDuration,
      chatContext: chatContext,
      title: title,
      kind: kind,
      serverMsgId: serverMsgId,
    );
  }

  Future<void> togglePlayback() async {
    if (_playing) {
      await pause();
      return;
    }
    await resume();
  }

  Future<void> resume() async {
    final src = _source;
    if (src == null) return;
    if (_loadedMessageId == src.messageId &&
        _player.processingState != ProcessingState.idle) {
      _activeMessageId = src.messageId;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        _position = Duration.zero;
      }
      _playing = true;
      _startPlayback();
      notifyListeners();
      return;
    }
    await play(
      messageId: src.messageId,
      localPath: src.localPath,
      networkUrl: src.networkUrl,
      fallbackDuration: src.fallbackDuration,
      title: src.title,
      kind: src.kind,
      serverMsgId: src.serverMsgId,
    );
  }

  Future<void> play({
    required String messageId,
    String? localPath,
    String? networkUrl,
    Duration fallbackDuration = Duration.zero,
    VoiceChatContext? chatContext,
    String? title,
    AudioMessageKind kind = AudioMessageKind.voiceNote,
    int serverMsgId = 0,
  }) async {
    if (chatContext != null) _chatContext = chatContext;

    if (_loadedMessageId == messageId &&
        _player.processingState != ProcessingState.idle) {
      _activeMessageId = messageId;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        _position = Duration.zero;
      }
      _playing = true;
      _startPlayback();
      notifyListeners();
      return;
    }

    _loadingMessageId = messageId;
    _cancelledLoadId = null;
    notifyListeners();

    try {
      await _loadSource(
        messageId,
        localPath,
        networkUrl,
        fallbackDuration,
        title,
        kind,
        serverMsgId,
      );
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        _position = Duration.zero;
      }
      // Annulé pendant le décodage : la source reste chargée et prête, on
      // s'abstient simplement de démarrer. Aucun await entre ce test et le
      // démarrage, pour ne pas rouvrir la fenêtre de course.
      if (_cancelledLoadId == messageId) {
        _cancelledLoadId = null;
        _playing = false;
        return;
      }
      _activeMessageId = messageId;
      _playing = true;
      _startPlayback();
    } catch (e) {
      if (_activeMessageId == messageId) _activeMessageId = null;
      rethrow;
    } finally {
      if (_loadingMessageId == messageId) _loadingMessageId = null;
      notifyListeners();
    }
  }

  // ── Navigation depuis le mini-lecteur ───────────────────────────────

  /// Vrai tant que la conversation ouverte depuis le bandeau est dans la pile.
  /// Même garde-fou que `_isCallUiRouteOpen` côté appel, qui manquait ici.
  bool get isChatRouteOpen => _isChatRouteOpen;

  void markChatRouteOpen() => _isChatRouteOpen = true;

  void markChatRouteClosed() => _isChatRouteOpen = false;

  // ── Vitesse de lecture ──────────────────────────────────────────────

  /// Vitesse courante du player. `1.0` tant que rien n'a été chargé.
  double get speed => _speed;

  /// Type de préférence correspondant à ce qui joue.
  PlaybackSpeedKind get _speedKind =>
      (_source?.kind ?? AudioMessageKind.voiceNote) == AudioMessageKind.music
          ? PlaybackSpeedKind.music
          : PlaybackSpeedKind.voice;

  Future<void> setSpeed(double value) async {
    if (_speed == value) return;
    _speed = value;
    notifyListeners();
    try {
      await _player.setSpeed(value);
    } catch (e) {
      debugPrint('[VoicePlayback] setSpeed échoué: $e');
    }
    await PlaybackSpeedPreferences.setSpeed(_speedKind, value);
  }

  /// Palier suivant en boucle : 1× → 1,5× → 2× → 1×.
  Future<void> cycleSpeed() =>
      setSpeed(PlaybackSpeedPreferences.nextSpeed(_speedKind, _speed));

  Future<void> _applyStoredSpeed(AudioMessageKind kind) async {
    final prefKind = kind == AudioMessageKind.music
        ? PlaybackSpeedKind.music
        : PlaybackSpeedKind.voice;
    final stored = PlaybackSpeedPreferences.speedOf(prefKind);
    _speed = stored;
    try {
      await _player.setSpeed(stored);
    } catch (e) {
      debugPrint('[VoicePlayback] setSpeed initial échoué: $e');
    }
  }

  /// Démarre la lecture sans l'attendre.
  ///
  /// `AudioPlayer.play()` ne complète qu'à la fin de la lecture (ou à la pause,
  /// ou à l'arrêt) — c'est documenté dans just_audio. L'attendre laissait
  /// `_loadingMessageId` armé pendant tout le morceau : bouton figé en
  /// chargement, et tap de pause détourné vers l'annulation de démarrage.
  void _startPlayback() {
    unawaited(_player.play().catchError((Object e) {
      debugPrint('[VoicePlayback] play() échoué: $e');
    }));
  }

  Future<void> pause() async {
    await _player.pause();
    _playing = false;
    notifyListeners();
  }

  /// Annule un démarrage en cours de chargement. On ne touche pas au player :
  /// le décodage va au bout (il est court), mais la lecture ne démarrera pas.
  /// Éviter un `stop()` concurrent au `setFilePath` évite une exception qui
  /// remonterait à l'UI en « audio indisponible ».
  void cancelPendingStart(String messageId) {
    if (_loadingMessageId != messageId) return;
    _cancelledLoadId = messageId;
    _loadingMessageId = null;
    _playing = false;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> seekToRatio(double ratio) async {
    final src = _source;
    if (src == null) return;
    await seekToRatioForMessage(
      ratio,
      messageId: src.messageId,
      localPath: src.localPath,
      networkUrl: src.networkUrl,
      fallbackDuration: src.fallbackDuration,
      title: src.title,
      kind: src.kind,
      serverMsgId: src.serverMsgId,
    );
  }

  Future<void> seekToRatioForMessage(
    double ratio, {
    required String messageId,
    String? localPath,
    String? networkUrl,
    Duration fallbackDuration = Duration.zero,
    VoiceChatContext? chatContext,
    String? title,
    AudioMessageKind kind = AudioMessageKind.voiceNote,
    int serverMsgId = 0,
  }) async {
    if (chatContext != null) _chatContext = chatContext;
    if (_loadingMessageId == messageId) return;

    final clamped = ratio.clamp(0.0, 1.0);
    final totalMs = _effectiveDuration(fallbackDuration).inMilliseconds;
    final target = Duration(
      milliseconds: totalMs == 0 ? 0 : (totalMs * clamped).round(),
    );

    _source = VoicePlaybackSource(
      messageId: messageId,
      localPath: localPath,
      networkUrl: networkUrl,
      fallbackDuration: fallbackDuration,
      title: title,
      kind: kind,
      serverMsgId: serverMsgId,
    );

    if (_loadedMessageId != messageId) {
      _loadingMessageId = messageId;
      notifyListeners();
      try {
        await _loadSource(
        messageId,
        localPath,
        networkUrl,
        fallbackDuration,
        title,
        kind,
        serverMsgId,
      );
        _activeMessageId = messageId;
      } catch (e) {
        _clearPlayback();
        rethrow;
      } finally {
        if (_loadingMessageId == messageId) _loadingMessageId = null;
        notifyListeners();
      }
    } else {
      _activeMessageId = messageId;
    }

    await _player.seek(target);
    _position = target;
    if (!_playing) {
      _playing = true;
      _startPlayback();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _loadingMessageId = null;
    _clearPlayback();
    _backgroundPlayback = false;
    _chatContext = null;
    notifyListeners();
  }

  void _clearPlayback() {
    _activeMessageId = null;
    _loadedMessageId = null;
    _source = null;
    _playing = false;
    _position = Duration.zero;
  }

  Duration _effectiveDuration(Duration fallback) {
    if (_duration.inMilliseconds > 0) return _duration;
    if (fallback.inMilliseconds > 0) return fallback;
    return Duration.zero;
  }

  Future<String?> _resolvePlaybackPath(String? localPath) async {
    if (localPath != null && File(localPath).existsSync()) return localPath;
    return null;
  }

  Future<void> _loadSource(
    String messageId,
    String? localPath,
    String? networkUrl,
    Duration fallbackDuration,
    String? title,
    AudioMessageKind kind,
    int serverMsgId,
  ) async {
    if (_loadedMessageId != null && _loadedMessageId != messageId) {
      await _player.stop();
    }
    final path = await _resolvePlaybackPath(localPath);
    if (path == null) {
      throw StateError('Audio not downloaded');
    }
    await _player.setFilePath(path);
    _loadedMessageId = messageId;
    _source = VoicePlaybackSource(
      messageId: messageId,
      localPath: localPath ?? path,
      networkUrl: networkUrl,
      fallbackDuration: fallbackDuration,
      title: title,
      kind: kind,
      serverMsgId: serverMsgId,
    );
    _duration = _player.duration ?? fallbackDuration;
    _position = Duration.zero;
    // Vitesse mémorisée pour ce type de média : appliquée après setFilePath,
    // sinon just_audio repart au défaut du player.
    await _applyStoredSpeed(kind);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
