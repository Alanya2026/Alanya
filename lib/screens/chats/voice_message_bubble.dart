import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Bulle de lecture d'un message vocal : play/pause, barre de progression
/// et durée. Privilégie le fichier local (offline) puis l'URL réseau.
class VoiceMessageBubble extends StatefulWidget {
  final String? localPath;
  final String? networkUrl;
  final int durationSeconds;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    this.localPath,
    this.networkUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  bool _loading = false;

  Color get _fg => widget.isMe ? Colors.white : Colors.indigo;

  Future<void> _ensureLoaded() async {
    if (_ready) return;
    final hasLocal = widget.localPath != null && File(widget.localPath!).existsSync();
    if (hasLocal) {
      await _player.setFilePath(widget.localPath!);
    } else if (widget.networkUrl != null) {
      await _player.setUrl(widget.networkUrl!);
    } else {
      return;
    }
    _ready = true;
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      await _ensureLoaded();
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (_) {
      // lecture impossible (média non encore uploadé / hors-ligne sans cache)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: _loading
                    ? SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _fg),
                      )
                    : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: _fg, size: 34),
                onPressed: _toggle,
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snap) {
                final total = _player.duration ?? Duration(seconds: widget.durationSeconds);
                final pos = snap.data ?? Duration.zero;
                final ratio = total.inMilliseconds == 0
                    ? 0.0
                    : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: _fg.withAlpha(60),
                      valueColor: AlwaysStoppedAnimation(_fg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _player.playing || pos > Duration.zero
                          ? _fmt(pos)
                          : _fmt(Duration(seconds: widget.durationSeconds)),
                      style: TextStyle(color: _fg.withAlpha(200), fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
