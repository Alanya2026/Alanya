import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/call/call_audio_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Barre de contrôle flottante pour les appels.
///
/// Primaire : mute + (caméra | speaker) + overflow éventuel, puis raccrocher.
/// Add / transfer / switch cam → menu overflow pour limiter le nombre de boutons.
class CallControlBar extends StatelessWidget {
  const CallControlBar({
    super.key,
    required this.isVideo,
    required this.isMuted,
    required this.isVideoOn,
    required this.isSpeakerOn,
    required this.audioRoute,
    required this.audioRoutes,
    required this.useVideoChrome,
    this.showCameraInAudio = false,
    required this.onMute,
    required this.onSpeaker,
    required this.onCamera,
    required this.onSwitchCam,
    required this.onHangUp,
    this.canAddParticipant = false,
    this.onAddParticipant,
    this.onTransferParticipant,
  });

  final bool isVideo;
  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeakerOn;

  /// Sortie audio courante et sorties proposables. Le bouton ne disait
  /// « haut-parleur allumé / éteint » que parce qu'il n'en connaissait pas
  /// d'autres : avec un casque appairé, personne ne savait où sortait le son.
  final CallAudioRoute audioRoute;
  final List<CallAudioRoute> audioRoutes;

  /// Icône de la sortie courante.
  IconData get _routeIcon {
    switch (audioRoute) {
      case CallAudioRoute.speaker:
        return CupertinoIcons.speaker_3_fill;
      case CallAudioRoute.bluetooth:
        return Icons.bluetooth_audio;
      case CallAudioRoute.wired:
        return Icons.headset;
      case CallAudioRoute.earpiece:
        return CupertinoIcons.speaker_2;
    }
  }

  /// Nom de la sortie courante, pour l'accessibilité et le menu.
  String _routeLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (audioRoute) {
      case CallAudioRoute.speaker:
        return l10n.speaker;
      case CallAudioRoute.bluetooth:
        return l10n.audioOutputBluetooth;
      case CallAudioRoute.wired:
        return l10n.audioOutputWired;
      case CallAudioRoute.earpiece:
        return l10n.audioOutputEarpiece;
    }
  }

  /// Avec plus de deux sorties, l'appui ne bascule plus : il fait le tour. Le
  /// libellé doit le dire, sinon « Activer le haut-parleur » ment une fois sur
  /// deux.
  String _routeAction(BuildContext context) => audioRoutes.length > 2
      ? '${context.l10n.changeAudioOutput} · ${_routeLabel(context)}'
      : (audioRoute == CallAudioRoute.speaker
            ? context.l10n.turnOffSpeaker
            : context.l10n.turnOnSpeaker);
  final bool useVideoChrome;
  final bool showCameraInAudio;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCam;
  final VoidCallback onHangUp;

  final bool canAddParticipant;
  final VoidCallback? onAddParticipant;
  final VoidCallback? onTransferParticipant;

  bool get _hasOverflow =>
      isVideo ||
      showCameraInAudio ||
      (canAddParticipant &&
          (onAddParticipant != null || onTransferParticipant != null));

  Future<void> _openMore(BuildContext context) async {
    final callUi = context.callUi;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: callUi.controlSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: callUi.controlBorder,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
                if (isVideo || showCameraInAudio)
                  ListTile(
                    leading: Icon(
                      CupertinoIcons.switch_camera,
                      color: callUi.onControlSurface,
                    ),
                    title: Text(
                      l10n.switchCamera,
                      style: TextStyle(color: callUi.onControlSurface),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                      onSwitchCam();
                    },
                  ),
                // En vidéo, le bouton de la barre est la caméra : sans cette
                // entrée, la sortie audio — haut-parleur à l'init vidéo — ne
                // pouvait plus jamais être changée pendant l'appel.
                if (isVideo || showCameraInAudio)
                  ListTile(
                    leading: Icon(_routeIcon, color: callUi.onControlSurface),
                    title: Text(
                      _routeAction(ctx),
                      style: TextStyle(color: callUi.onControlSurface),
                    ),
                    subtitle: audioRoutes.length > 2
                        ? Text(
                            _routeLabel(ctx),
                            style: TextStyle(
                              color: callUi.onControlSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                      onSpeaker();
                    },
                  ),
                if (canAddParticipant && onAddParticipant != null)
                  ListTile(
                    leading: Icon(
                      Icons.person_add_alt_1,
                      color: callUi.onControlSurface,
                    ),
                    title: Text(
                      l10n.addToCall,
                      style: TextStyle(color: callUi.onControlSurface),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                      onAddParticipant!();
                    },
                  ),
                if (canAddParticipant && onTransferParticipant != null)
                  ListTile(
                    leading: Icon(
                      Icons.phone_forwarded,
                      color: callUi.onControlSurface,
                    ),
                    title: Text(
                      l10n.transferCall,
                      style: TextStyle(color: callUi.onControlSurface),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.selectionClick();
                      onTransferParticipant!();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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
              color: useVideoChrome
                  ? callUi.videoChromeSurface
                  : callUi.controlSurface,
              borderRadius: AppRadius.brPill,
              border: useVideoChrome
                  ? null
                  : Border.all(
                      color: callUi.controlBorder.withValues(alpha: 0.5),
                    ),
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
                  icon: isMuted
                      ? CupertinoIcons.mic_off
                      : CupertinoIcons.mic_solid,
                  active: isMuted,
                  useVideoChrome: useVideoChrome,
                  semanticsLabel: isMuted
                      ? context.l10n.unmuteMic
                      : context.l10n.muteMic,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onMute();
                  },
                ),
                AppSpacing.hGapMd,
                if (isVideo || showCameraInAudio)
                  _ControlButton(
                    icon: isVideo && !isVideoOn
                        ? Icons.videocam_off
                        : Icons.videocam,
                    active: isVideo && !isVideoOn,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: isVideo
                        ? (isVideoOn
                              ? context.l10n.turnOffCamera
                              : context.l10n.enableCamera)
                        : context.l10n.switchToVideoCall,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCamera();
                    },
                  )
                else
                  _ControlButton(
                    icon: _routeIcon,
                    // Mis en avant dès que le son ne sort plus par l'oreille —
                    // haut-parleur, casque filaire ou Bluetooth.
                    active: audioRoute != CallAudioRoute.earpiece,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: _routeAction(context),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSpeaker();
                    },
                  ),
                if (_hasOverflow) ...[
                  AppSpacing.hGapMd,
                  _ControlButton(
                    icon: Icons.more_horiz,
                    active: false,
                    useVideoChrome: useVideoChrome,
                    semanticsLabel: context.l10n.more,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _openMore(context);
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
        : callUi.onControlSurface;
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
