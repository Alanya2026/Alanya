import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/voice_waveform_store.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/voice_waveform_bar.dart';

/// Lecteur audio plein écran pour les statuts vocaux.
class StatusAudioView extends StatefulWidget {
  final AudioPlayer player;
  final String audioPath;
  final Duration totalDuration;
  final String displayName;
  final String? avatarUrl;
  final bool paused;
  final ValueChanged<double> onProgress;

  const StatusAudioView({
    super.key,
    required this.player,
    required this.audioPath,
    required this.totalDuration,
    required this.displayName,
    this.avatarUrl,
    this.paused = false,
    required this.onProgress,
  });

  @override
  State<StatusAudioView> createState() => _StatusAudioViewState();
}

class _StatusAudioViewState extends State<StatusAudioView> {
  List<double>? _samples;
  Duration _position = Duration.zero;
  bool _playing = false;
  final VoiceWaveformStore _waveforms = VoiceWaveformStore();

  @override
  void initState() {
    super.initState();
    _loadWaveform();
    widget.player.positionStream.listen((pos) {
      if (!mounted) return;
      final total = _total;
      if (total.inMilliseconds > 0) {
        widget.onProgress(
          (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
        );
      }
      setState(() => _position = pos);
    });
    widget.player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => _playing = st.playing);
    });
  }

  Duration get _total {
    final d = widget.player.duration;
    if (d != null && d.inMilliseconds > 0) return d;
    return widget.totalDuration;
  }

  Future<void> _loadWaveform() async {
    final data = await _waveforms.loadOrGenerate(
      localPath: widget.audioPath,
      durationSeconds: widget.totalDuration.inSeconds,
    );
    if (mounted) setState(() => _samples = data);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _seekRatio(double ratio) async {
    final ms = (_total.inMilliseconds * ratio.clamp(0.0, 1.0)).round();
    await widget.player.seek(Duration(milliseconds: ms));
    if (!widget.player.playing && !widget.paused) {
      await widget.player.play();
    }
  }

  Future<void> _skip(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _total ? _total : target);
    await widget.player.seek(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratio = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    final samples = _samples ??
        VoiceWaveformStore.generateDeterministicFallback(
          widget.audioPath,
          widget.totalDuration.inSeconds,
        );

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
            widget.paused ? 'En pause' : 'Message vocal',
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          VoiceWaveformBar(
            samples: samples,
            progress: ratio,
            foregroundColor: colors.primary,
            enabled: !widget.paused,
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
                onPressed: widget.paused ? null : () => _skip(-10),
              ),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 64,
                color: colors.primary,
                icon: Icon(
                  _playing && !widget.paused
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: widget.paused
                    ? null
                    : () async {
                        if (_playing) {
                          await widget.player.pause();
                        } else {
                          if (widget.player.processingState ==
                              ProcessingState.completed) {
                            await widget.player.seek(Duration.zero);
                          }
                          await widget.player.play();
                        }
                      },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Avancer 10 s',
                icon: const Icon(Icons.forward_10),
                color: colors.onSurface,
                iconSize: 32,
                onPressed: widget.paused ? null : () => _skip(10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
