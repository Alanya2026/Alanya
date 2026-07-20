import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/services/call_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';
import 'speaking_indicator_border.dart';

/// Tuile participant pour les appels de groupe.
class CallParticipantTile extends StatefulWidget {
  const CallParticipantTile({
    super.key,
    required this.userId,
    required this.stream,
    required this.name,
    required this.isSpeaking,
    this.photoUrl,
    this.isMuted = false,
    this.isVideoOn = true,
  });

  final String userId;
  final MediaStream stream;
  final String name;
  final String? photoUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool isVideoOn;

  @override
  State<CallParticipantTile> createState() => _CallParticipantTileState();
}

class _CallParticipantTileState extends State<CallParticipantTile> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant CallParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final initial = widget.name.isNotEmpty
        ? widget.name.substring(0, 1).toUpperCase()
        : '?';
    final url = widget.photoUrl;
    final hasPhoto = url != null &&
        url.isNotEmpty &&
        url.toUpperCase() != 'NON DEFINI' &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final showAvatar = !widget.isVideoOn || (_ready && _renderer.videoWidth == 0);

    return SpeakingIndicatorBorder(
      isSpeaking: widget.isSpeaking && !widget.isMuted,
      borderRadius: AppRadius.brMd,
      speakingColor: callUi.speakingRing,
      child: Container(
        decoration: BoxDecoration(
          color: callUi.groupTileBackground,
          borderRadius: AppRadius.brMd,
          boxShadow: [
            BoxShadow(
              color: callUi.groupTileShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && widget.isVideoOn)
              RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            if (showAvatar)
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.brandPrimary,
                  backgroundImage: hasPhoto ? NetworkImage(url) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: callUi.videoChromeSurface.withValues(alpha: 0.85),
                  borderRadius: AppRadius.brPill,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: callUi.onVideoChrome,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.isMuted)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          CupertinoIcons.mic_off,
                          color: callUi.actionReject,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille de participants pour appel groupé.
class CallGroupGrid extends StatelessWidget {
  const CallGroupGrid({
    super.key,
    required this.streams,
    required this.roster,
    required this.activeSpeakers,
  });

  final Map<String, MediaStream> streams;
  final Map<String, GroupParticipantInfo> roster;
  final Set<String> activeSpeakers;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final entries = streams.entries.toList();

    if (entries.isEmpty) {
      return Container(
        color: callUi.groupBackground,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.primary,
              ),
            ),
            AppSpacing.vGapLg,
            Text(
              context.l10n.waitingForParticipants,
              style: TextStyle(
                color: callUi.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            AppSpacing.vGapXl,
            _SkeletonTiles(callUi: callUi),
          ],
        ),
      );
    }

    return Container(
      color: callUi.groupBackground,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        80,
        AppSpacing.sm,
        160,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.75,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          final info = roster[e.key];
          return CallParticipantTile(
            key: ValueKey('remote_${e.key}'),
            userId: e.key,
            stream: e.value,
            name: info?.name ?? context.l10n.participantFallback,
            photoUrl: info?.photo,
            isSpeaking: activeSpeakers.contains(e.key),
            isMuted: info?.isMuted ?? false,
            isVideoOn: info?.isVideoOn ?? true,
          );
        },
      ),
    );
  }
}

class _SkeletonTiles extends StatelessWidget {
  const _SkeletonTiles({required this.callUi});

  final CallUiColors callUi;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 72,
          height: 96,
          margin: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm),
          decoration: BoxDecoration(
            color: callUi.groupTileBackground,
            borderRadius: AppRadius.brMd,
            boxShadow: [
              BoxShadow(
                color: callUi.groupTileShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      }),
    );
  }
}
