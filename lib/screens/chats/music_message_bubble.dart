import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/voice_chat_context.dart';
import '../../core/services/voice_message_coordinator.dart';
import '../../core/services/voice_playback_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/audio_message_kind.dart';
import '../../core/utils/file_metadata.dart';
import '../../widgets/audio_seek_bar.dart';

/// Bulle musique : carte pochette + barre de scrub linéaire.
///
/// Volontairement distincte de la bulle vocale, qui garde son bouton rond et
/// sa waveform. Même moteur en dessous ([VoicePlaybackService]), donc lancer
/// un morceau coupe un vocal en cours, et inversement.
class MusicMessageBubble extends StatefulWidget {
  final String messageId;
  final int serverMsgId;
  final bool isMe;
  final String? localPath;
  final String? pendingPath;
  final String? networkUrl;
  final int durationSeconds;
  final String? mediaName;
  final int? mediaSize;

  /// Pochette JPEG/PNG en base64, extraite des tags à l'envoi.
  final String? coverThumb;

  /// Couleur des contrôles (bouton, barre).
  final Color foregroundColor;

  /// Couleur du titre et du sous-titre.
  final Color textColor;

  final VoiceChatContext? chatContext;

  const MusicMessageBubble({
    super.key,
    required this.messageId,
    required this.serverMsgId,
    required this.isMe,
    this.localPath,
    this.pendingPath,
    this.networkUrl,
    required this.durationSeconds,
    this.mediaName,
    this.mediaSize,
    this.coverThumb,
    required this.foregroundColor,
    required this.textColor,
    this.chatContext,
  });

  @override
  State<MusicMessageBubble> createState() => _MusicMessageBubbleState();
}

class _MusicMessageBubbleState extends State<MusicMessageBubble> {
  bool _syncScheduled = false;

  VoiceMessageRef get _ref => VoiceMessageRef(
        clientId: widget.messageId,
        serverMsgId: widget.serverMsgId,
        isMe: widget.isMe,
        dbPath: widget.localPath,
        pendingPath: widget.pendingPath,
        mediaUrl: widget.networkUrl,
        durationSeconds: widget.durationSeconds,
        kind: AudioMessageKind.music,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant MusicMessageBubble oldWidget) {
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
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.audioUnavailable)),
      );
    }
  }

  // ── Pochette ────────────────────────────────────────────────────────
  Widget _cover() {
    final thumb = widget.coverThumb;
    Widget child;
    if (thumb != null && thumb.isNotEmpty) {
      try {
        child = Image.memory(
          base64Decode(thumb),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _coverPlaceholder(),
        );
      } catch (_) {
        child = _coverPlaceholder();
      }
    } else {
      child = _coverPlaceholder();
    }

    return ClipRRect(
      borderRadius: AppRadius.brSm,
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }

  Widget _coverPlaceholder() {
    return ColoredBox(
      color: widget.foregroundColor.withAlpha(30),
      child: Icon(
        Icons.music_note,
        size: 26,
        color: widget.foregroundColor.withAlpha(200),
      ),
    );
  }

  String get _title => musicTitleFromName(
        widget.mediaName,
        fallback: context.l10n.music,
      );

  String get _subtitle {
    final parts = <String>[];
    final ext = musicExtensionOf(widget.mediaName);
    if (ext != null) parts.add(ext.toUpperCase());
    final size = widget.mediaSize;
    if (size != null && size > 0) parts.add(formatFileSize(size));
    return parts.join(' · ');
  }

  // ── Bouton de transport ─────────────────────────────────────────────
  Widget _transportButton(
    VoiceMessageCoordinator coordinator,
    VoicePlaybackService service,
    VoiceMessageSnapshot snap,
    bool playing,
    bool isPlaybackLoading,
  ) {
    switch (snap.phase) {
      case VoiceUiPhase.resolving:
        return _spinner();
      case VoiceUiPhase.needsDownload:
        return _iconButton(
          Icons.download_rounded,
          _canDownload ? () => _onDownload(coordinator) : null,
        );
      case VoiceUiPhase.downloading:
        return SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: snap.downloadProgress,
                strokeWidth: 2.5,
                color: widget.foregroundColor,
              ),
            ),
          ),
        );
      case VoiceUiPhase.ready:
        // Démarrage optimiste : pause dès le tap, bouton toujours actif,
        // un second tap annule le démarrage (cf. VoicePlaybackService).
        return _iconButton(
          playing || isPlaybackLoading
              ? Icons.pause_circle_filled
              : Icons.play_circle_fill,
          () => _toggle(service, snap),
        );
      case VoiceUiPhase.error:
        return _iconButton(Icons.refresh_rounded, () {
          coordinator.invalidate(widget.messageId);
          if (_canDownload && snap.localPath == null) {
            _onDownload(coordinator);
          } else {
            _sync();
          }
        });
    }
  }

  Widget _iconButton(IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: widget.foregroundColor, size: 34),
        onPressed: onPressed,
      ),
    );
  }

  Widget _spinner({double size = 26}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: widget.foregroundColor,
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

        final subtitle = _subtitle;

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cover(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title,
                          style: context.text.bodyMedium?.copyWith(
                            color: widget.textColor,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: context.text.labelSmall?.copyWith(
                              color: widget.textColor.withAlpha(170),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _transportButton(
                    coordinator,
                    service,
                    snap,
                    playing,
                    isPlaybackLoading,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AudioSeekBar(
                      value: ratio,
                      foregroundColor: widget.foregroundColor,
                      // Active dès que le fichier est prêt : un seek pendant
                      // le décodage est ignoré côté service, et garder la
                      // barre active évite un clignotement du curseur.
                      enabled: snap.phase == VoiceUiPhase.ready,
                      onSeek: (r) => _seek(service, snap, r),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    timeText,
                    style: context.text.labelSmall?.copyWith(
                      color: widget.textColor.withAlpha(180),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
