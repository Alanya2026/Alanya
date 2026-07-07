import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/voice_chat_context.dart';
import '../../core/services/voice_message_coordinator.dart';
import '../../core/services/voice_playback_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/voice_waveform_bar.dart';

/// Bulle vocale : UI pure pilotée par [VoiceMessageCoordinator].
class VoiceMessageBubble extends StatefulWidget {
  final String messageId;
  final int serverMsgId;
  final bool isMe;
  final String? localPath;
  final String? pendingPath;
  final String? networkUrl;
  final int durationSeconds;
  final Color foregroundColor;
  final VoiceChatContext? chatContext;

  const VoiceMessageBubble({
    super.key,
    required this.messageId,
    required this.serverMsgId,
    required this.isMe,
    this.localPath,
    this.pendingPath,
    this.networkUrl,
    required this.durationSeconds,
    required this.foregroundColor,
    this.chatContext,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  VoiceMessageRef get _ref => VoiceMessageRef(
        clientId: widget.messageId,
        serverMsgId: widget.serverMsgId,
        isMe: widget.isMe,
        dbPath: widget.localPath,
        pendingPath: widget.pendingPath,
        mediaUrl: widget.networkUrl,
        durationSeconds: widget.durationSeconds,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.serverMsgId != widget.serverMsgId ||
        oldWidget.isMe != widget.isMe ||
        oldWidget.localPath != widget.localPath ||
        oldWidget.pendingPath != widget.pendingPath ||
        oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.durationSeconds != widget.durationSeconds) {
      _sync();
    }
  }

  void _sync() {
    if (!mounted) return;
    context.read<VoiceMessageCoordinator>().ensureReady(_ref);
  }

  Duration get _fallbackDuration => Duration(seconds: widget.durationSeconds);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canDownload =>
      !widget.isMe &&
      widget.serverMsgId != 0 &&
      widget.networkUrl != null &&
      widget.networkUrl!.isNotEmpty;

  Future<void> _onDownload(VoiceMessageCoordinator coordinator) async {
    await coordinator.download(_ref);
    if (!mounted) return;
    final snap = coordinator.snapshotFor(widget.messageId);
    if (snap?.phase == VoiceUiPhase.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snap!.error ?? 'Échec du téléchargement')),
      );
    }
  }

  Future<void> _toggle(
    VoicePlaybackService service,
    VoiceMessageSnapshot snap,
  ) async {
    final path = snap.localPath;
    if (snap.phase != VoiceUiPhase.ready || path == null) return;
    try {
      await service.toggle(
        messageId: widget.messageId,
        localPath: path,
        networkUrl: null,
        fallbackDuration: _fallbackDuration,
        chatContext: widget.chatContext,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio indisponible')),
      );
    }
  }

  Future<void> _seek(
    VoicePlaybackService service,
    VoiceMessageSnapshot snap,
    double ratio,
  ) async {
    final path = snap.localPath;
    if (snap.phase != VoiceUiPhase.ready || path == null) return;
    try {
      await service.seekToRatioForMessage(
        ratio,
        messageId: widget.messageId,
        localPath: path,
        networkUrl: null,
        fallbackDuration: _fallbackDuration,
        chatContext: widget.chatContext,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio indisponible')),
      );
    }
  }

  Widget _leadingButton(
    VoiceMessageCoordinator coordinator,
    VoicePlaybackService service,
    VoiceMessageSnapshot snap,
    bool playing,
    bool isPlaybackLoading,
  ) {
    switch (snap.phase) {
      case VoiceUiPhase.resolving:
      case VoiceUiPhase.extracting:
        return _smallSpinner(widget.foregroundColor);
      case VoiceUiPhase.needsDownload:
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.download_rounded,
            color: widget.foregroundColor,
            size: 30,
          ),
          onPressed: _canDownload ? () => _onDownload(coordinator) : null,
        );
      case VoiceUiPhase.downloading:
        return SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                value: snap.downloadProgress,
                strokeWidth: 2.5,
                color: widget.foregroundColor,
              ),
            ),
          ),
        );
      case VoiceUiPhase.ready:
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: isPlaybackLoading
              ? _smallSpinner(widget.foregroundColor, size: 22)
              : Icon(
                  playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: widget.foregroundColor,
                  size: 34,
                ),
          onPressed: isPlaybackLoading
              ? null
              : () => _toggle(service, snap),
        );
      case VoiceUiPhase.error:
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.refresh_rounded,
            color: widget.foregroundColor,
            size: 28,
          ),
          onPressed: () {
            coordinator.invalidate(widget.messageId);
            if (_canDownload &&
                snap.localPath == null &&
                widget.localPath == null) {
              _onDownload(coordinator);
            } else {
              _sync();
            }
          },
        );
    }
  }

  Widget _smallSpinner(Color color, {double size = 26}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VoiceMessageCoordinator, VoicePlaybackService>(
      builder: (context, coordinator, service, _) {
        final snap = coordinator.snapshotFor(widget.messageId) ??
            VoiceMessageSnapshot(phase: VoiceUiPhase.resolving, ref: _ref);

        final isActive = service.isActive(widget.messageId);
        final isPlaybackLoading = service.isMessageLoading(widget.messageId);
        final playing = isActive && service.isPlaying;
        final total = isActive && service.duration.inMilliseconds > 0
            ? service.duration
            : _fallbackDuration;
        final position = isActive ? service.position : Duration.zero;
        final ratio = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds)
                .clamp(0.0, 1.0);
        final hasStarted = isActive && (playing || position > Duration.zero);

        final String timeText;
        if (snap.phase == VoiceUiPhase.downloading) {
          timeText = 'Téléchargement…';
        } else if (hasStarted) {
          timeText = '${_fmt(position)} / ${_fmt(total)}';
        } else {
          timeText = _fmt(total);
        }

        final showWaveform =
            snap.phase == VoiceUiPhase.ready && snap.waveform != null;

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _leadingButton(
                coordinator,
                service,
                snap,
                playing,
                isPlaybackLoading,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showWaveform)
                      VoiceWaveformBar(
                        samples: snap.waveform!,
                        progress: ratio,
                        foregroundColor: widget.foregroundColor,
                        enabled: !isPlaybackLoading,
                        onSeek: (r) => _seek(service, snap, r),
                      )
                    else
                      const SizedBox(height: 28),
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: context.text.labelSmall?.copyWith(
                        color: widget.foregroundColor.withAlpha(180),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
