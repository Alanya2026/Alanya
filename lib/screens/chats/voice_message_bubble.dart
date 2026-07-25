import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/playback_speed_preferences.dart';
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
  bool _syncScheduled = false;

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
    _syncScheduled = false;
    context.read<VoiceMessageCoordinator>().ensureReady(_ref);
  }

  void _scheduleSyncIfNeeded() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Duration get _fallbackDuration => Duration(seconds: widget.durationSeconds);

  /// Libellé du mini-lecteur : le nom du contact seul ne dit pas ce qui joue.
  String get _miniPlayerTitle {
    final label = context.l10n.voiceMessage;
    final chat = widget.chatContext?.title;
    return (chat == null || chat.isEmpty) ? label : '$label · $chat';
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canDownload =>
      widget.serverMsgId != 0 &&
      widget.networkUrl != null &&
      widget.networkUrl!.isNotEmpty;

  Future<void> _onDownload(VoiceMessageCoordinator coordinator) async {
    await coordinator.download(_ref);
    if (!mounted) return;
    final snap = coordinator.snapshotFor(widget.messageId);
    if (snap?.phase == VoiceUiPhase.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snap!.error ?? context.l10n.downloadFailed)),
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
        serverMsgId: widget.serverMsgId,
        title: _miniPlayerTitle,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.audioUnavailable)),
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
        serverMsgId: widget.serverMsgId,
        title: _miniPlayerTitle,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.audioUnavailable)),
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
        // Démarrage optimiste : on affiche pause dès le tap plutôt qu'un
        // spinner, et le bouton reste actif — un second tap annule le
        // démarrage au lieu d'être avalé pendant le décodage.
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            playing || isPlaybackLoading
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
            color: widget.foregroundColor,
            size: 34,
          ),
          onPressed: () => _toggle(service, snap),
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
                snap.localPath == null) {
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
        final existing = coordinator.snapshotFor(widget.messageId);
        if (existing == null) {
          _scheduleSyncIfNeeded();
        }
        final snap = existing ??
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
          timeText = context.l10n.downloading;
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
                        enabled: true,
                        onSeek: (r) => _seek(service, snap, r),
                      )
                    else
                      const SizedBox(height: 28),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          timeText,
                          style: context.text.labelSmall?.copyWith(
                            color: widget.foregroundColor.withAlpha(180),
                          ),
                        ),
                        const Spacer(),
                        // Vitesse réservée aux vocaux : c'est là qu'accélérer
                        // a du sens, et l'endroit où on la cherche.
                        if (snap.phase == VoiceUiPhase.ready)
                          _SpeedPill(
                            speed: service.speed,
                            color: widget.foregroundColor,
                            onPressed: service.cycleSpeed,
                          ),
                      ],
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

/// Pastille cyclique 1× → 1,5× → 2×, alignée sur celle du mini-lecteur.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.speed,
    required this.color,
    required this.onPressed,
  });

  final double speed;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(38),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: context.l10n.playbackSpeed,
          child: Container(
            height: 20,
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              formatPlaybackSpeed(speed),
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
