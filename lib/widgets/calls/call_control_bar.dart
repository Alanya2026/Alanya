import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Barre de contrôle flottante pour les appels (mute, speaker/caméra, raccrocher).
class CallControlBar extends StatelessWidget {
  const CallControlBar({
    super.key,
    required this.isVideo,
    required this.isMuted,
    required this.isVideoOn,
    required this.isSpeakerOn,
    required this.useVideoChrome,
    required this.onMute,
    required this.onSpeaker,
    required this.onCamera,
    required this.onSwitchCam,
    required this.onHangUp,
  });

  final bool isVideo;
  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeakerOn;
  final bool useVideoChrome;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCam;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl + bottomPadding,
      ),
      decoration: useVideoChrome
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: callUi.chromeScrimBottom,
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: useVideoChrome ? callUi.videoChromeSurface : callUi.controlSurface,
              borderRadius: AppRadius.brPill,
              border: useVideoChrome
                  ? null
                  : Border.all(color: callUi.controlBorder.withValues(alpha: 0.5)),
              boxShadow: useVideoChrome
                  ? null
                  : [
                      BoxShadow(
                        color: callUi.groupTileShadow,
                        blurRadius: callUi.controlElevation * 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlButton(
                  icon: isMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic_solid,
                  active: isMuted,
                  useVideoChrome: useVideoChrome,
                  semanticsLabel: isMuted ? context.l10n.unmuteMic : context.l10n.muteMic,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onMute();
                  },
                ),
                AppSpacing.hGapMd,
                if (isVideo)
                  _ControlButton(
                    icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
                    active: !isVideoOn,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: isVideoOn ? context.l10n.turnOffCamera : context.l10n.enableCamera,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCamera();
                    },
                  )
                else
                  _ControlButton(
                    icon: isSpeakerOn
                        ? CupertinoIcons.speaker_3_fill
                        : CupertinoIcons.speaker_2,
                    active: isSpeakerOn,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: isSpeakerOn ? context.l10n.turnOffSpeaker : context.l10n.turnOnSpeaker,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSpeaker();
                    },
                  ),
                if (isVideo) ...[
                  AppSpacing.hGapMd,
                  _ControlButton(
                    icon: CupertinoIcons.switch_camera,
                    active: false,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: context.l10n.switchCamera,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSwitchCam();
                    },
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.vGapLg,
          Semantics(
            button: true,
            label: context.l10n.hangUp,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onHangUp();
              },
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: callUi.actionReject,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: callUi.actionReject.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.phone_down_fill,
                  color: AppColors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.active,
    required this.useVideoChrome,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final bool useVideoChrome;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    final bg = useVideoChrome
        ? (active ? callUi.videoControlActive : callUi.videoControlSurface)
        : (active ? callUi.controlSurfaceActive : callUi.controlSurface);
    final fg = useVideoChrome
        ? (active ? AppColors.black : callUi.onVideoControlSurface)
        : (active ? callUi.onControlSurface : callUi.onControlSurface);
    final borderColor = useVideoChrome
        ? Colors.white.withValues(alpha: 0.2)
        : callUi.controlBorder.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}
