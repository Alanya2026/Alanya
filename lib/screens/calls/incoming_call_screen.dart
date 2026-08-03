import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/calls/call_action_button.dart';
import '../../widgets/calls/call_connecting_overlay.dart';
import 'ongoing_call_screen.dart';

/// Écran d'appel entrant (app au premier plan uniquement).
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  /// Résolu dans initState : `Provider.of` lève dans `dispose()`, l'élément
  /// étant déjà démonté (Element.unmount vide `_widget` avant `state.dispose`).
  /// Le nettoyage qui suivait était donc silencieusement sauté.
  late final CallService _callService;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _callService = Provider.of<CallService>(context, listen: false);
    _callService.addListener(_onStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CallUiScope.applyOverlayStyle(context, isVideo: false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _callService.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted || _navigated) return;
    // Ne pas verrouiller la navigation si un écran/dialog est empilé au-dessus :
    // sinon un pop qui ne retire pas CET écran laisserait les deux boutons inertes.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final cs = Provider.of<CallService>(context, listen: false);

    if (cs.status == CallStatus.connecting || cs.status == CallStatus.connected) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    if (cs.status == CallStatus.ended || cs.status == CallStatus.idle) {
      _navigated = true;
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reject() async {
    if (_navigated) return;
    _navigated = true;
    final cs = Provider.of<CallService>(context, listen: false);
    if (cs.isConference) {
      await cs.rejectConferenceInvite();
    } else if (cs.groupRoomId != null) {
      await cs.rejectGroupCall();
    } else {
      await cs.rejectCall();
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _accept() async {
    if (_navigated) return;
    _navigated = true;

    final cs = Provider.of<CallService>(context, listen: false);

    // Invitation à rejoindre un appel en cours : ni un appel ordinaire (aucune
    // offre à répondre), ni un appel de groupe (aucune room à rejoindre).
    if (cs.isConference) {
      await cs.acceptConferenceInvite();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    if (cs.groupRoomId != null) {
      final me = context.read<AuthProvider>().currentUser;
      if (me == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final callerInfo = (cs.remoteUserId != null)
          ? GroupParticipantInfo(
              id: cs.remoteUserId.toString(),
              name: (cs.remoteUserName?.isNotEmpty == true)
                  ? cs.remoteUserName!
                  : context.l10n.participantFallback,
              photo: cs.remoteUserPhoto,
            )
          : null;
      await cs.joinGroupCall(
        roomId: cs.groupRoomId!,
        myId: me.alanyaID,
        myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
        myPhoto: me.avatarUrl,
        isVideo: cs.isVideo,
        callerInfo: callerInfo,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    await cs.answerCall();

    if (!mounted) return;

    if (cs.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cs.errorMessage!),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
      Navigator.of(context).maybePop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return Consumer<CallService>(
      builder: (_, cs, __) {
        final caller = cs.currentCall?.caller;
        final isVideo = cs.isVideo;
        final isGroup = cs.groupRoomId != null;
        final name = caller?.nom.trim().isNotEmpty == true ? caller!.nom : context.l10n.unknownSender;
        // Invitation à rejoindre un appel : le motif prime sur le type d'appel.
        // L'invité doit savoir qui l'ajoute, et à quelle conversation.
        final otherPeer = cs.isConference
            ? cs.groupRoster.values
                .where((p) => p.id != cs.confInvitedBy?.id)
                .map((p) => p.name)
                .where((n) => n.isNotEmpty)
                .join(', ')
            : '';
        final subtitle = cs.isConference
            ? (otherPeer.isNotEmpty
                ? context.l10n.confInviteSubtitle(otherPeer)
                : context.l10n.confCallOfThree)
            : isGroup
                ? (isVideo ? context.l10n.groupVideoCall : context.l10n.groupCall)
                : (isVideo ? context.l10n.videoCall : context.l10n.voiceCall);
        final subtitleIcon = isVideo
            ? CupertinoIcons.video_camera_solid
            : CupertinoIcons.phone_fill;

        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            unawaited(_reject());
          },
          child: Scaffold(
            backgroundColor: callUi.backgroundSolid,
            body: Container(
              decoration: BoxDecoration(
                gradient: callUi.backgroundGradientDecoration,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    AppSpacing.vGapXl,
                    CallIncomingHeaderPill(
                      icon: subtitleIcon,
                      label: context.l10n.callIncoming,
                      pulseAnimation: _pulse,
                    ),
                    const Spacer(),
                    CallIncomingAvatarPulse(
                      animation: _pulse,
                      name: name,
                      imageUrl: caller?.avatarUrl,
                    ),
                    AppSpacing.vGapXxl,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        name,
                        style: context.text.headlineMedium?.copyWith(
                          color: callUi.onBackground,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: callUi.chipBackground.withValues(alpha: 0.6),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            subtitleIcon,
                            color: callUi.onBackgroundMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: callUi.onBackgroundMuted,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CallActionButton(
                            icon: CupertinoIcons.phone_down_fill,
                            label: context.l10n.commonDecline,
                            color: callUi.actionReject,
                            onTap: _reject,
                          ),
                          const SizedBox(width: 64),
                          CallActionButton(
                            icon: subtitleIcon,
                            label: context.l10n.commonAccept,
                            color: callUi.actionAccept,
                            onTap: _accept,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
