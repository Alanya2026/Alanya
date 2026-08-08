import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/services/call_service.dart';
import '../../core/services/meeting_service.dart';
import '../../core/services/playback_speed_preferences.dart';
import '../../core/utils/audio_message_kind.dart';
import '../../core/services/voice_playback_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
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

  /// Type du dernier audio affiché. À la fin de la lecture la source est déjà
  /// vidée : sans ça le message de fin parlerait de vocal pour un morceau.
  AudioMessageKind _lastAudioKind = AudioMessageKind.voiceNote;
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
        ? context.l10n.callEnded
        : meetingEnded
            ? context.l10n.meetingEnded
            : (_lastAudioKind == AudioMessageKind.music
                ? context.l10n.musicEnded
                : context.l10n.voiceMessageEnded);
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

  Future<void> _openVoiceChat(VoicePlaybackService service) async {
    final ctx = service.chatContext;
    if (ctx == null) return;
    // Même garde-fou que `_isCallUiRouteOpen` côté appel : sans lui, chaque tap
    // empilait une nouvelle instance de la conversation.
    if (service.isChatRouteOpen) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    service.markChatRouteOpen();
    try {
      await nav.push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: ctx.title,
            conversationId: ctx.conversationId,
            userId: ctx.userId,
            isGroup: ctx.isGroup,
            avatarUrl: ctx.avatarUrl,
            focusMessageId: service.source?.serverMsgId,
          ),
        ),
      );
    } finally {
      service.markChatRouteClosed();
    }
  }

  String _fmtVoiceDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _voiceDetail(VoicePlaybackService service) {
    // Le sous-titre nomme ce qui joue : « Message vocal » était codé en dur
    // dans les deux libellés, y compris pour un morceau.
    final kindLabel = service.source?.kind == AudioMessageKind.music
        ? context.l10n.music
        : context.l10n.voiceMessage;

    if (!service.isPlaying) return context.l10n.pausedTapToReturn(kindLabel);

    // `position / durée` : la position seule ne dit pas où on en est.
    final total = service.duration;
    final position = _fmtVoiceDuration(service.position);
    final elapsed = total.inMilliseconds > 0
        ? '$position / ${_fmtVoiceDuration(total)}'
        : position;
    return context.l10n.sessionBannerTapToReturn(elapsed, kindLabel);
  }

  double? _voiceProgress(VoicePlaybackService service) {
    final total = service.duration.inMilliseconds;
    if (total <= 0) return null;
    return (service.position.inMilliseconds / total).clamp(0.0, 1.0);
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
        if (showVoice) {
          _lastAudioKind =
              voiceService.source?.kind ?? AudioMessageKind.voiceNote;
        }
        _wasCallBannerVisible = showCall;
        _wasMeetingBannerVisible = showMeeting;
        _wasVoiceBannerVisible = showVoice;

        if (visible) {
          final brightness = Theme.of(context).brightness;
          SystemChrome.setSystemUIOverlayStyle(
            brightness == Brightness.light
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
          );
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
            accent: context.semantic.success,
            onExpand: () => callService.navigateToCallUi(),
            onHangUp: () async {
              // Conf / transfert : end_call → leaveCallSession (je pars seul).
              // leaveGroupCall vise les rooms groupe classiques, pas callSessions.
              if (callService.isConference) {
                await callService.endCall();
              } else if (callService.groupRoomId != null) {
                await callService.leaveGroupCall();
              } else {
                await callService.endCall();
              }
            },
          );
        } else if (showMeeting) {
          bar = _SessionTopBar(
            label: meetingService.currentMeeting?.objet ?? context.l10n.meeting,
            detail:
                context.l10n.durationTapToReturn(meetingService.formattedDuration),
            isConnected: meetingService.status == MeetingStatus.connected,
            isMuted: meetingService.isMuted,
            accent: AppColors.brandPrimaryStrong,
            onExpand: () => meetingService.navigateToMeetingUi(),
            onHangUp: () => meetingService.leaveMeeting(),
          );
        } else {
          // Titre du média joué, pas de la conversation : le nom du contact
          // seul ne dit pas ce qu'on écoute.
          final title = voiceService.source?.title ??
              voiceService.chatContext?.title ??
              context.l10n.voiceMessage;
          bar = _SessionTopBar(
            label: title,
            detail: _voiceDetail(voiceService),
            isConnected: voiceService.isPlaying,
            isMuted: false,
            accent: AppColors.brandPrimaryStrong,
            onExpand: () => _openVoiceChat(voiceService),
            onHangUp: voiceService.stop,
            actions: [
              _SpeedPill(
                speed: voiceService.speed,
                onPressed: voiceService.cycleSpeed,
                color: _contrastColor(AppColors.brandPrimaryStrong),
              ),
              AppSpacing.hGapXs,
              _VoicePlayPauseButton(
                isPlaying: voiceService.isPlaying,
                onPressed: voiceService.togglePlayback,
              ),
            ],
            progress: _voiceProgress(voiceService),
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
    if (cs.groupRoomId != null) return context.l10n.groupCallInProgress;
    return cs.remoteUserName ?? context.l10n.callInProgress;
  }

  String _callDetail(CallService cs) {
    if (cs.status == CallStatus.connecting) {
      return context.l10n.connectingTapToReturn;
    }
    final duration = cs.formattedDuration;
    if (cs.groupRoomId != null) {
      final count = cs.groupRemoteStreams.length + 1;
      return context.l10n.durationParticipants(duration, count);
    }
    final type = cs.isVideo ? context.l10n.video2 : context.l10n.audio2;
    return context.l10n.sessionBannerTapToReturn(duration, type);
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
    this.actions = const [],
    this.hangUpIcon = CupertinoIcons.phone_down_fill,
    this.progress,
  });

  final String label;
  final String detail;
  final bool isConnected;
  final bool isMuted;
  final Color accent;
  final VoidCallback onExpand;
  final VoidCallback onHangUp;
  /// Contrôles insérés avant le bouton de fin. Vide pour l'appel et la réunion.
  final List<Widget> actions;
  final IconData hangUpIcon;

  /// Avancement 0..1 dessiné sur l'arête basse. `null` = pas de barre.
  ///
  /// Volontairement rendue À L'INTÉRIEUR des 44 px : sortir de cette hauteur
  /// obligerait à recalculer [kActiveSessionTopBarHeight] et le décalage
  /// injecté à tous les écrans.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final onAccent = _contrastColor(accent);

    return Material(
      color: accent,
      elevation: Theme.of(context).brightness == Brightness.light ? 2 : 0,
      shadowColor: AppColors.black.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kActiveSessionTopBarHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  AppSpacing.hGapMd,
              _LiveDot(isConnected: isConnected, color: onAccent),
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
                        style: TextStyle(
                          color: onAccent,
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
                          color: onAccent.withValues(alpha: 0.88),
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
              ...actions,
              if (isMuted)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    CupertinoIcons.mic_slash_fill,
                    size: 16,
                    color: onAccent.withValues(alpha: 0.85),
                  ),
                ),
              _HangUpButton(
                onPressed: onHangUp,
                icon: hangUpIcon,
              ),
              AppSpacing.hGapMd,
            ],
              ),
              if (progress != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BannerProgress(
                    value: progress!,
                    color: onAccent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avancement de lecture, non interactif : 3 px n'atteignent pas la cible
/// tactile, un scrub y serait imprécis.
class _BannerProgress extends StatelessWidget {
  const _BannerProgress({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * value.clamp(0.0, 1.0);
          return Stack(
            children: [
              Container(color: color.withValues(alpha: 0.28)),
              Container(width: width, color: color),
            ],
          );
        },
      ),
    );
  }
}

Color _contrastColor(Color background) {
  return background.computeLuminance() > 0.5 ? AppColors.textPrimary : AppColors.white;
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

/// Pastille cyclique 1× → 1,5× → 2×.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.speed,
    required this.onPressed,
    required this.color,
  });

  final double speed;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: context.l10n.playbackSpeed,
          child: Container(
            height: 24,
            constraints: const BoxConstraints(minWidth: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              formatPlaybackSpeed(speed),
              style: TextStyle(
                color: color,
                fontSize: 11,
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

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.isConnected, required this.color});

  final bool isConnected;
  final Color color;

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
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: widget.isConnected
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
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
