import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/voice_waveform_store.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/voice_waveform_bar.dart';

/// Lecteur audio plein écran pour les statuts vocaux.
class StatusAudioView extends StatefulWidget {
  final AudioPlayer? player;
  final bool isPreparing;
  final String? audioPath;
  final String fallbackKey;
  final Duration totalDuration;
  final String displayName;
  final String? avatarUrl;
  final bool paused;
  final ValueChanged<double>? onProgress;

  const StatusAudioView({
    super.key,
    this.player,
    this.isPreparing = false,
    this.audioPath,
    required this.fallbackKey,
    required this.totalDuration,
    required this.displayName,
    this.avatarUrl,
    this.paused = false,
    this.onProgress,
  });

  @override
  State<StatusAudioView> createState() => _StatusAudioViewState();
}

class _StatusAudioViewState extends State<StatusAudioView> {
  List<double>? _samples;
  Duration _position = Duration.zero;
  bool _playing = false;
  final VoiceWaveformStore _waveforms = VoiceWaveformStore();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadWaveform();
    _bindPlayer(widget.player);
  }

  @override
  void didUpdateWidget(covariant StatusAudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _bindPlayer(widget.player);
    }
    if (oldWidget.audioPath != widget.audioPath && widget.audioPath != null) {
      _loadWaveform();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _bindPlayer(AudioPlayer? player) {
    _positionSub?.cancel();
    _stateSub?.cancel();
    if (player == null) {
      _position = Duration.zero;
      _playing = false;
      return;
    }
    _positionSub = player.positionStream.listen((pos) {
      if (!mounted) return;
      final total = _total;
      if (total.inMilliseconds > 0) {
        widget.onProgress?.call(
          (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
        );
      }
      setState(() => _position = pos);
    });
    _stateSub = player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
    });
  }

  Duration get _total {
    final d = widget.player?.duration;
    if (d != null && d.inMilliseconds > 0) return d;
    return widget.totalDuration;
  }

  Future<void> _loadWaveform() async {
    final path = widget.audioPath;
    if (path == null || path.isEmpty) return;
    final data = await _waveforms.loadOrGenerate(
      localPath: path,
      durationSeconds: widget.totalDuration.inSeconds,
    );
    if (mounted) setState(() => _samples = data);
  }

  List<double> get _displaySamples {
    if (_samples != null && _samples!.isNotEmpty) return _samples!;
    final path = widget.audioPath;
    if (path != null && path.isNotEmpty) {
      return VoiceWaveformStore.generateDeterministicFallback(
        path,
        widget.totalDuration.inSeconds,
      );
    }
    return VoiceWaveformStore.generateDeterministicFallback(
      widget.fallbackKey,
      widget.totalDuration.inSeconds,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _seekRatio(double ratio) async {
    final player = widget.player;
    if (player == null || widget.isPreparing || widget.paused) return;
    final ms = (_total.inMilliseconds * ratio.clamp(0.0, 1.0)).round();
    await player.seek(Duration(milliseconds: ms));
    if (!player.playing) await player.play();
  }

  Future<void> _skip(int seconds) async {
    final player = widget.player;
    if (player == null || widget.isPreparing || widget.paused) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _total ? _total : target);
    await player.seek(clamped);
  }

  Future<void> _togglePlay() async {
    final player = widget.player;
    if (player == null || widget.isPreparing || widget.paused) return;
    if (_playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preparing = widget.isPreparing || widget.player == null;
    final ratio = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      color: colors.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: colors.primaryContainer,
            backgroundImage: widget.avatarUrl != null
                ? NetworkImage(widget.avatarUrl!)
                : null,
            child: widget.avatarUrl == null
                ? Icon(Icons.person, size: 56, color: colors.onPrimaryContainer)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            widget.displayName,
            style: context.text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            preparing
                ? 'Chargement…'
                : (widget.paused ? 'En pause' : 'Message vocal'),
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          VoiceWaveformBar(
            samples: _displaySamples,
            progress: ratio,
            foregroundColor: colors.primary,
            enabled: !widget.paused && !preparing,
            onSeek: _seekRatio,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_position), style: context.text.labelSmall),
              Text(_fmt(_total), style: context.text.labelSmall),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Reculer 10 s',
                icon: const Icon(Icons.replay_10),
                color: colors.onSurface,
                iconSize: 32,
                onPressed:
                    preparing || widget.paused ? null : () => _skip(-10),
              ),
              const SizedBox(width: 8),
              preparing
                  ? SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colors.primary,
                      ),
                    )
                  : IconButton(
                      iconSize: 64,
                      color: colors.primary,
                      icon: Icon(
                        _playing && !widget.paused
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      onPressed: widget.paused ? null : _togglePlay,
                    ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Avancer 10 s',
                icon: const Icon(Icons.forward_10),
                color: colors.onSurface,
                iconSize: 32,
                onPressed:
                    preparing || widget.paused ? null : () => _skip(10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
