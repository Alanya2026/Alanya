import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/services/call_service.dart';
import '../../core/services/meeting_service.dart';
import '../../core/services/voice_playback_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../screens/chats/chat_detail_screen.dart';

/// Hauteur du bandeau compact (hors status bar / encoche).
const double kActiveSessionTopBarHeight = 44.0;

/// @deprecated Utiliser [kActiveSessionTopBarHeight].
const double kActiveSessionBannerHeight = kActiveSessionTopBarHeight;

/// Enveloppe globale : inset haut + bandeau de session minimisée.
class ActiveSessionChrome extends StatelessWidget {
  const ActiveSessionChrome({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Consumer3<CallService, MeetingService, VoicePlaybackService>(
      builder: (context, callService, meetingService, voiceService, _) {
        final topVisible = _isTopBannerVisible(
          callService,
          meetingService,
          voiceService,
        );
        final mq = MediaQuery.of(context);
        final topInset = topVisible ? kActiveSessionTopBarHeight : 0.0;

        return Stack(
          children: [
            if (child != null)
              MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(
                    top: mq.padding.top + topInset,
                  ),
                  viewPadding: mq.viewPadding.copyWith(
                    top: mq.viewPadding.top + topInset,
                  ),
                ),
                child: child!,
              ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ActiveSessionBannerHost(),
            ),
          ],
        );
      },
    );
  }
}

bool _isTopBannerVisible(
  CallService call,
  MeetingService meeting,
  VoicePlaybackService voice,
) {
  return _isBannerVisible(call, meeting) || voice.showMiniPlayer;
}

bool _isBannerVisible(CallService call, MeetingService meeting) {
  return call.shouldShowCallBanner ||
      (!call.isCallActive && meeting.shouldShowMeetingBanner);
}

/// Bandeau compact en haut (style iOS / Google Meet) : appel, réunion ou vocal.
class ActiveSessionBannerHost extends StatefulWidget {
  const ActiveSessionBannerHost({super.key});

  @override
  State<ActiveSessionBannerHost> createState() =>
      _ActiveSessionBannerHostState();
}

class _ActiveSessionBannerHostState extends State<ActiveSessionBannerHost>
    with SingleTickerProviderStateMixin {
  bool _wasCallBannerVisible = false;
  bool _wasMeetingBannerVisible = false;
  bool _wasVoiceBannerVisible = false;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _onSessionEnded({
    required bool callEnded,
    required bool meetingEnded,
    required bool voiceEnded,
    required bool wasMinimized,
  }) {
    if (!wasMinimized || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final message = callEnded
        ? 'Appel terminé'
        : meetingEnded
            ? 'Réunion terminée'
            : 'Message vocal terminé';
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),
    );
  }

  void _openVoiceChat(VoicePlaybackService service) {
    final ctx = service.chatContext;
    if (ctx == null) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: ctx.title,
          conversationId: ctx.conversationId,
          userId: ctx.userId,
          isGroup: ctx.isGroup,
          avatarUrl: ctx.avatarUrl,
        ),
      ),
    );
  }

  String _fmtVoiceDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _voiceDetail(VoicePlaybackService service) {
    if (service.isPlaying) {
      return '${_fmtVoiceDuration(service.position)} · Message vocal · Toucher pour revenir';
    }
    return 'En pause · Message vocal · Toucher pour revenir';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CallService, MeetingService, VoicePlaybackService>(
      builder: (context, callService, meetingService, voiceService, _) {
        final showCall = callService.shouldShowCallBanner;
        final showMeeting =
            !callService.isCallActive && meetingService.shouldShowMeetingBanner;
        final showVoice = !showCall && !showMeeting && voiceService.showMiniPlayer;
        final visible = showCall || showMeeting || showVoice;

        if (_wasCallBannerVisible &&
            !showCall &&
            callService.status == CallStatus.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSessionEnded(
              callEnded: true,
              meetingEnded: false,
              voiceEnded: false,
              wasMinimized: true,
            );
          });
        }
        if (_wasMeetingBannerVisible &&
            !showMeeting &&
            meetingService.status == MeetingStatus.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSessionEnded(
              callEnded: false,
              meetingEnded: true,
              voiceEnded: false,
              wasMinimized: true,
            );
          });
        }
        if (_wasVoiceBannerVisible &&
            !showVoice &&
            !voiceService.hasActivePlayback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSessionEnded(
              callEnded: false,
              meetingEnded: false,
              voiceEnded: true,
              wasMinimized: true,
            );
          });
        }
        _wasCallBannerVisible = showCall;
        _wasMeetingBannerVisible = showMeeting;
        _wasVoiceBannerVisible = showVoice;

        if (visible) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
          if (!_slideCtrl.isCompleted && !_slideCtrl.isAnimating) {
            _slideCtrl.forward(from: 0);
          }
        } else {
          if (_slideCtrl.isCompleted || _slideCtrl.isAnimating) {
            _slideCtrl.reverse();
          }
        }

        if (!visible && _slideCtrl.value == 0) {
          return const SizedBox.shrink();
        }

        final Widget bar;
        if (showCall) {
          bar = _SessionTopBar(
            label: _callLabel(callService),
            detail: _callDetail(callService),
            isConnected: callService.status == CallStatus.connected,
            isMuted: callService.isMuted,
            accent: AppColors.success,
            onExpand: () => callService.navigateToCallUi(),
            onHangUp: () async {
              if (callService.groupRoomId != null) {
                await callService.leaveGroupCall();
              } else {
                await callService.endCall();
              }
            },
          );
        } else if (showMeeting) {
          bar = _SessionTopBar(
            label: meetingService.currentMeeting?.objet ?? 'Réunion',
            detail:
                '${meetingService.formattedDuration} · Toucher pour revenir',
            isConnected: meetingService.status == MeetingStatus.connected,
            isMuted: meetingService.isMuted,
            accent: AppColors.brandPrimaryStrong,
            onExpand: () => meetingService.navigateToMeetingUi(),
            onHangUp: () => meetingService.leaveMeeting(),
          );
        } else {
          final title = voiceService.chatContext?.title ?? 'Message vocal';
          bar = _SessionTopBar(
            label: title,
            detail: _voiceDetail(voiceService),
            isConnected: voiceService.isPlaying,
            isMuted: false,
            accent: AppColors.brandPrimaryStrong,
            onExpand: () => _openVoiceChat(voiceService),
            onHangUp: voiceService.stop,
            leadingAction: _VoicePlayPauseButton(
              isPlaying: voiceService.isPlaying,
              onPressed: voiceService.togglePlayback,
            ),
            hangUpIcon: CupertinoIcons.xmark,
          );
        }

        return SlideTransition(
          position: _slideAnim,
          child: bar,
        );
      },
    );
  }

  String _callLabel(CallService cs) {
    if (cs.groupRoomId != null) return 'Appel groupé en cours';
    return cs.remoteUserName ?? 'Appel en cours';
  }

  String _callDetail(CallService cs) {
    if (cs.status == CallStatus.connecting) {
      return 'Connexion… · Toucher pour revenir';
    }
    final duration = cs.formattedDuration;
    if (cs.groupRoomId != null) {
      final count = cs.groupRemoteStreams.length + 1;
      return '$duration · $count participants';
    }
    final type = cs.isVideo ? 'Vidéo' : 'Audio';
    return '$duration · $type · Toucher pour revenir';
  }
}

class _SessionTopBar extends StatelessWidget {
  const _SessionTopBar({
    required this.label,
    required this.detail,
    required this.isConnected,
    required this.isMuted,
    required this.accent,
    required this.onExpand,
    required this.onHangUp,
    this.leadingAction,
    this.hangUpIcon = CupertinoIcons.phone_down_fill,
  });

  final String label;
  final String detail;
  final bool isConnected;
  final bool isMuted;
  final Color accent;
  final VoidCallback onExpand;
  final VoidCallback onHangUp;
  final Widget? leadingAction;
  final IconData hangUpIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kActiveSessionTopBarHeight,
          child: Row(
            children: [
              AppSpacing.hGapMd,
              _LiveDot(isConnected: isConnected),
              AppSpacing.hGapSm,
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onExpand,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        detail,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (leadingAction != null) leadingAction!,
              if (isMuted)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    CupertinoIcons.mic_slash_fill,
                    size: 16,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              _HangUpButton(
                onPressed: onHangUp,
                icon: hangUpIcon,
              ),
              AppSpacing.hGapMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _VoicePlayPauseButton extends StatelessWidget {
  const _VoicePlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        color: AppColors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.isConnected});

  final bool isConnected;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isConnected) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isConnected) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.isConnected
          ? Tween(begin: 0.45, end: 1.0).animate(_ctrl)
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: widget.isConnected
              ? [
                  BoxShadow(
                    color: AppColors.white.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _HangUpButton extends StatelessWidget {
  const _HangUpButton({
    required this.onPressed,
    this.icon = CupertinoIcons.phone_down_fill,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            color: AppColors.white,
            size: icon == CupertinoIcons.xmark ? 16 : 18,
          ),
        ),
      ),
    );
  }
}

/// Indique si le bandeau de session active est affiché.
bool isActiveSessionBannerVisible(BuildContext context) {
  final call = context.read<CallService>();
  final meeting = context.read<MeetingService>();
  final voice = context.read<VoicePlaybackService>();
  return _isTopBannerVisible(call, meeting, voice);
}

/// @deprecated Utiliser [isActiveSessionBannerVisible].
bool isVoiceMiniPlayerVisible(BuildContext context) {
  return context.read<VoicePlaybackService>().showMiniPlayer;
}
