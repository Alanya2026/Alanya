import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/call/call_conf_routing.dart';
import '../../widgets/calls/call_action_button.dart';
import '../../widgets/calls/call_connecting_overlay.dart';
import '../../widgets/common/app_avatar.dart';
import 'ongoing_call_screen.dart';

/// Écran d'appel entrant (app au premier plan uniquement).
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _navigated = false;

  /// Aperçu de sa propre caméra pendant que l'appel sonne.
  final RTCVideoRenderer _previewRenderer = RTCVideoRenderer();
  Future<void>? _previewInit;
  bool _previewReady = false;

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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_callService.openRingCamera());
  }

  /// Android retire la caméra à une application en arrière-plan : on la rend
  /// avant qu'il ne la prenne, et on la rouvre au retour si l'appel sonne encore.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_callService.closeRingCamera());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_callService.openRingCamera());
    }
  }

  /// Branche l'aperçu sur la caméra dès qu'elle est ouverte.
  Future<void> _syncPreview() async {
    if (_callService.ringPreviewStream == null && !_previewReady) return;
    _previewInit ??= _previewRenderer.initialize();
    await _previewInit;
    if (!mounted || _navigated) return;
    _previewReady = true;
    final stream = _callService.ringPreviewStream;
    if (_previewRenderer.srcObject == stream) return;
    _previewRenderer.srcObject = stream;
    setState(() {});
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
    WidgetsBinding.instance.removeObserver(this);
    // Décroché, la caméra appartient désormais à l'appel. Sinon, elle se ferme
    // avec cet écran.
    final status = _callService.status;
    if (status != CallStatus.connecting && status != CallStatus.connected) {
      unawaited(_callService.closeRingCamera());
    }
    if (_previewInit != null) {
      if (_previewReady) _previewRenderer.srcObject = null;
      unawaited(_previewRenderer.dispose());
    }
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted || _navigated) return;
    unawaited(_syncPreview());
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
      _openOngoingOrReport(cs);
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
      _openOngoingOrReport(cs);
      return;
    }

    await cs.answerCall();

    if (!mounted) return;
    _openOngoingOrReport(cs);
  }

  /// Ouvre l'écran d'appel, ou referme en expliquant.
  ///
  /// `joinGroupCall` et `acceptConferenceInvite` avalent leurs erreurs et
  /// repassent en `idle` : pousser l'écran sans vérifier donnait un « appel en
  /// cours » à 00:00, sans média, sans message et sans fermeture automatique.
  /// La branche 1-à-1 vérifiait déjà `errorMessage` ; les trois le font
  /// maintenant, et le statut est vérifié en plus.
  void _openOngoingOrReport(CallService cs) {
    if (shouldOpenOngoingScreen(
      callStatusName: cs.status.name,
      errorMessage: cs.errorMessage,
    )) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    final message = cs.errorMessage ?? context.l10n.errorAcceptingCall;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 4),
    ));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return Consumer<CallService>(
      builder: (_, cs, __) {
        final caller = cs.currentCall?.caller;
        final isVideo = cs.isVideo;
        final isGroup = cs.groupRoomId != null;
        final showPreview =
            isVideo && _previewReady && cs.ringPreviewStream != null;
        final name = caller?.displayName.trim().isNotEmpty == true
            ? caller!.displayName
            : context.l10n.unknownSender;
        // Invitation à rejoindre un appel : le motif prime sur le type d'appel.
        // L'invité doit savoir qui l'ajoute, et à quelle conversation.
        final otherPeers = cs.isConference
            ? cs.groupRoster.values
                .where((p) => p.id != cs.confInvitedBy?.id)
                .toList()
            : const <GroupParticipantInfo>[];
        final otherPeerNames = otherPeers
            .map((p) => p.name)
            .where((n) => n.isNotEmpty)
            .join(', ');
        final isTransferInvite = cs.isConference && cs.isTransferMode;
        final subtitle = cs.isConference
            ? (isTransferInvite
                ? (otherPeerNames.isNotEmpty
                    ? '${context.l10n.conferenceTransferInviteBody} · $otherPeerNames'
                    : context.l10n.conferenceTransferInviteBody)
                : (otherPeerNames.isNotEmpty
                    ? context.l10n.confInviteSubtitle(otherPeerNames)
                    : context.l10n.confCallOfThree))
            : isGroup
                ? (isVideo ? context.l10n.groupVideoCall : context.l10n.groupCall)
                : (isVideo ? context.l10n.videoCall : context.l10n.voiceCall);
        final subtitleIcon = isTransferInvite
            ? Icons.phone_forwarded
            : isVideo
                ? CupertinoIcons.video_camera_solid
                : CupertinoIcons.phone_fill;

        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            unawaited(_reject());
          },
          child: Scaffold(
            backgroundColor: callUi.backgroundSolid,
            body: _RingCameraBackdrop(
              renderer: showPreview ? _previewRenderer : null,
              child: Container(
                decoration: showPreview
                    ? null
                    : BoxDecoration(
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
                            color: showPreview
                                ? AppColors.white
                                : callUi.onBackground,
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
                            Flexible(
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  color: callUi.onBackgroundMuted,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cs.isConference && otherPeers.isNotEmpty) ...[
                        AppSpacing.vGapLg,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (cs.confInvitedBy != null) ...[
                              AppAvatar(
                                imageUrl: cs.confInvitedBy!.photo,
                                name: cs.confInvitedBy!.name,
                                size: 40,
                              ),
                              const SizedBox(width: 8),
                            ],
                            ...otherPeers.take(3).map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: AppAvatar(
                                  imageUrl: p.photo,
                                  name: p.name,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isVideo && !isGroup && !cs.isConference) ...[
                        AppSpacing.vGapXl,
                        _RingCameraButton(
                          cameraOff: cs.isRingCameraOff,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            unawaited(cs.toggleRingCamera());
                          },
                        ),
                      ],
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
          ),
        );
      },
    );
  }
}

/// Sa propre caméra en fond d'écran, assombrie pour garder le texte lisible.
class _RingCameraBackdrop extends StatelessWidget {
  const _RingCameraBackdrop({required this.renderer, required this.child});

  final RTCVideoRenderer? renderer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final preview = renderer;
    if (preview == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        RTCVideoView(
          preview,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
        ColoredBox(color: AppColors.black.withValues(alpha: 0.35)),
        child,
      ],
    );
  }
}

/// Coupe ou rallume sa caméra avant de décrocher.
class _RingCameraButton extends StatelessWidget {
  const _RingCameraButton({required this.cameraOff, required this.onTap});

  final bool cameraOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        cameraOff ? context.l10n.enableCamera : context.l10n.turnOffCamera;
    return Material(
      color: AppColors.black.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cameraOff ? Icons.videocam : Icons.videocam_off,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(color: AppColors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
