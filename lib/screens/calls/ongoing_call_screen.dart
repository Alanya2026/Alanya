import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/calls/call_audio_backdrop.dart';
import '../../widgets/calls/call_connecting_overlay.dart';
import '../../widgets/calls/call_control_bar.dart';
import '../../widgets/calls/call_participant_focus_overlay.dart';
import '../../widgets/calls/call_participant_tile.dart';
import '../../widgets/calls/call_top_bar.dart';
import '../../widgets/calls/call_transfer_countdown_overlay.dart';
import '../../widgets/calls/add_to_call_sheet.dart';
import '../../widgets/calls/draggable_video_pip.dart';
import '../../widgets/common/app_avatar.dart';

/// Écran d'appel en cours (1-à-1, audio ou vidéo, groupe).
class OngoingCallScreen extends StatefulWidget {
  const OngoingCallScreen({super.key});

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen>
    with SingleTickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  /// Résolu dans initState : `Provider.of` lève dans `dispose()`, l'élément
  /// étant déjà démonté (Element.unmount vide `_widget` avant `state.dispose`).
  /// Le nettoyage qui suivait était donc silencieusement sauté.
  late final CallService _callService;
  bool _renderersReady = false;
  bool _closing = false;
  bool _localIsMainView = false;
  Offset? _pipOffset;
  bool _controlsVisible = true;
  final Set<String> _watchedVideoTrackIds = {};
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  String? _focusedParticipantId;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _callService = Provider.of<CallService>(context, listen: false);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CallService>(context, listen: false).markCallUiVisible();
      }
    });
    _initRenderers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cs = Provider.of<CallService>(context, listen: false);
    CallUiScope.applyOverlayStyle(context, isVideo: cs.isVideo);
  }

  void _minimize() {
    if (_closing || !mounted) return;
    Navigator.of(context).pop();
  }

  void _onFullscreenPop(bool didPop) {
    if (!didPop || _closing || !mounted) return;
    Provider.of<CallService>(context, listen: false).markCallUiMinimized();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;

    final cs = Provider.of<CallService>(context, listen: false);

    _localRenderer.srcObject = cs.localStream;
    _remoteRenderer.srcObject = cs.activeRemoteStream;
    _watchVideoTracks(cs.localStream);
    _watchVideoTracks(cs.activeRemoteStream);
    cs.addListener(_onCallChanged);

    setState(() => _renderersReady = true);
  }

  /// Ouvre la feuille de sélection et lance l'invitation sur le contact choisi.
  Future<void> _openAddSheet({required bool transfer}) async {
    debugPrint('[AddToCall] 👆 bouton pressé transfer=$transfer');
    try {
      final cs = Provider.of<CallService>(context, listen: false);
      if (!cs.canAddParticipant) {
        debugPrint('[AddToCall] ⛔ canAddParticipant=false, ouverture annulée');
        return;
      }

      final l10n = context.l10n;
      if (transfer) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.transferCallConfirmationTitle),
            content: Text(l10n.transferCallConfirmationBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.transferCall),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.confAddSheetTitle),
            content: Text(l10n.addToCallConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.invite),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }

      final me = context.read<AuthProvider>().currentUser;
      final excluded = <int>{
        if (me != null) me.alanyaID,
        if (cs.remoteUserId != null) cs.remoteUserId!,
      };
      debugPrint('[AddToCall] ▶ ouverture de la feuille (exclus=$excluded)');

      final chosen = await AddToCallSheet.show(
        context,
        excludedIds: excluded,
        transfer: transfer,
      );
      debugPrint('[AddToCall] ◀ feuille fermée, choix=${chosen?.alanyaID}');
      if (chosen == null || !mounted) return;

      cs.addParticipant(
        chosen.alanyaID,
        myName: me == null
            ? null
            : (me.nom.isNotEmpty ? me.nom : me.pseudo),
        myPhoto: me?.avatarUrl,
        transfer: transfer,
      );
    } catch (e, st) {
      debugPrint('[AddToCall] ** échec ouverture: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  /// Bandeaux d'information : arrivée, départ, échec d'invitation.
  ///
  /// Chaque fait n'est lu qu'une fois, sinon le message se rejouerait à chaque
  /// notification du service.
  void _drainConferenceNotices(CallService cs) {
    final l10n = context.l10n;

    final departed = cs.takeConfDeparture();
    if (departed != null) {
      _showNotice(l10n.confLeftCall(departed));
    }

    final failure = cs.takeConfFailure();
    if (failure == null) return;

    final who = cs.confPendingInvitee?.name ?? l10n.participantFallback;
    final message = switch (failure) {
      'declined' => l10n.confDeclined(who),
      'busy' => l10n.confBusy(who),
      'no_answer' => l10n.confNoAnswer(who),
      'offline' => l10n.confNotJoined(who),
      'media_not_ready' => l10n.mediaConnectionFailed,
      'cancelled' => null,
      'caller_left' => null,
      'already_used' => l10n.confAddAlreadyUsed,
      'blocked' => l10n.confCannotAdd(who),
      _ => l10n.confAddFailed,
    };
    if (message != null) _showNotice(message);
  }

  void _showNotice(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
    });
  }

  void _onCallChanged() {
    if (_closing || !mounted) return;
    final cs = Provider.of<CallService>(context, listen: false);
    _drainConferenceNotices(cs);
    _syncCountdownTicker(cs);

    setState(() {
      if (_renderersReady) {
        if (_localRenderer.srcObject != cs.localStream) {
          _localRenderer.srcObject = cs.localStream;
        }
        if (_remoteRenderer.srcObject != cs.activeRemoteStream) {
          _remoteRenderer.srcObject = cs.activeRemoteStream;
        }
        _watchVideoTracks(cs.localStream);
        _watchVideoTracks(cs.activeRemoteStream);
      }
      // Si le focus pointe un participant parti, le fermer.
      final focused = _focusedParticipantId;
      if (focused != null) {
        final localId = (cs.localUserId ??
                Provider.of<AuthProvider>(context, listen: false)
                    .currentUser
                    ?.alanyaID)
            ?.toString();
        final stillThere =
            focused == localId || cs.groupRemoteStreams.containsKey(focused);
        if (!stillThere) _focusedParticipantId = null;
      }
    });

    if (cs.status == CallStatus.ended || cs.status == CallStatus.idle) {
      _closeAndPop();
    }
  }

  void _syncCountdownTicker(CallService cs) {
    final need = cs.isTransferInitiator &&
        cs.transferStatus == CallTransferStatus.countdown;
    if (need && _countdownTicker == null) {
      _countdownTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {});
      });
    } else if (!need && _countdownTicker != null) {
      _countdownTicker?.cancel();
      _countdownTicker = null;
    }
  }

  void _focusParticipant(String userId) {
    setState(() => _focusedParticipantId = userId);
  }

  void _dismissFocus() {
    setState(() => _focusedParticipantId = null);
  }

  void _closeAndPop() {
    if (_closing) return;
    _closing = true;
    final cs = Provider.of<CallService>(context, listen: false);
    cs.removeListener(_onCallChanged);
    cs.markCallUiClosed();
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hangUp() async {
    if (_closing) return;
    _closing = true;
    final cs = Provider.of<CallService>(context, listen: false);
    cs.removeListener(_onCallChanged);
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    // Session à trois : raccrocher ne fait que me retirer, l'appel continue
    // sans moi. Le serveur interprète end_call en ce sens — surtout pas
    // leaveGroupCall, qui viserait une room d'appel de groupe inexistante.
    if (cs.isConference) {
      await cs.endCall();
    } else if (cs.groupRoomId != null) {
      await cs.leaveGroupCall();
    } else {
      await cs.endCall();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _pulseCtrl.dispose();
    _callService.removeListener(_onCallChanged);
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _toggleSwap() {
    setState(() => _localIsMainView = !_localIsMainView);
  }

  void _onPipPositionChanged(Offset offset) {
    setState(() => _pipOffset = offset);
  }

  bool _streamHasActiveVideo(MediaStream? stream) {
    if (stream == null) return false;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return false;
    return tracks.any((track) => track.enabled);
  }

  void _watchVideoTracks(MediaStream? stream) {
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      final trackId = track.id ?? track.label ?? '';
      if (trackId.isEmpty || _watchedVideoTrackIds.contains(trackId)) continue;
      _watchedVideoTrackIds.add(trackId);
      void refresh() {
        if (mounted) setState(() {});
      }
      track.onMute = refresh;
      track.onUnMute = refresh;
    }
  }

  bool _rendererShowsVideo(RTCVideoRenderer renderer, MediaStream? stream) {
    if (!_streamHasActiveVideo(stream)) return false;
    if (!_renderersReady) return true;
    return renderer.videoWidth > 0;
  }

  bool _hasRemoteVideo(CallService cs, bool isGroup) {
    if (isGroup || !cs.isVideo || !cs.isRemoteVideoOn) return false;
    final stream = _remoteRenderer.srcObject;
    if (stream == null) return false;
    return _rendererShowsVideo(_remoteRenderer, stream);
  }

  bool _hasLocalVideo(CallService cs) {
    if (!cs.isVideoOn) return false;
    final stream = _localRenderer.srcObject;
    if (stream == null) return false;
    return _rendererShowsVideo(_localRenderer, stream);
  }

  bool _isConnecting(CallService cs) {
    if (cs.status == CallStatus.outgoing || cs.status == CallStatus.connecting) {
      return true;
    }
    // Cold-start : accepté depuis CallKit, en attente de l'offre SDP.
    return cs.status == CallStatus.incoming && cs.isAutoAnsweringFromPush;
  }

  Widget? _buildPipChild(
    CallService cs,
    bool isGroup, {
    required String localName,
    required String? localPhoto,
  }) {
    if (!cs.isVideo || !_renderersReady) return null;

    if (isGroup) {
      if (_hasLocalVideo(cs)) {
        return _PipVideo(renderer: _localRenderer, mirror: true);
      }
      return _PipAvatar(name: localName, photoUrl: localPhoto);
    }

    if (_localIsMainView) {
      if (_hasRemoteVideo(cs, false)) {
        return _PipVideo(renderer: _remoteRenderer);
      }
      return _PipAvatar(
        name: cs.remoteUserName ?? context.l10n.unknownSender,
        photoUrl: cs.remoteUserPhoto,
      );
    }

    if (_hasLocalVideo(cs)) {
      return _PipVideo(renderer: _localRenderer, mirror: true);
    }
    return _PipAvatar(name: localName, photoUrl: localPhoto);
  }

  Widget _buildMainLayer(
    CallService cs,
    bool isGroup,
    bool hasRemoteVideo, {
    required String localName,
    required String? localPhoto,
    required String localUserId,
    bool isConnecting = false,
  }) {
    if (isGroup) {
      return CallGroupGrid(
        streams: cs.groupRemoteStreams,
        roster: cs.groupRoster,
        activeSpeakers: cs.activeSpeakers,
        pendingInvitee: cs.confPendingInvitee,
        onCancelPending:
            cs.confInviteIsMine ? () => cs.cancelAddParticipant() : null,
        localUserId: localUserId,
        localStream: cs.localStream,
        localName: localName,
        localPhoto: localPhoto,
        localMuted: cs.isMuted,
        localVideoOn: cs.isVideo && cs.isVideoOn,
        localSpeaking: cs.amISpeaking,
        onParticipantTap: _focusParticipant,
      );
    }

    // Pendant outgoing/connecting l'overlay affiche déjà l'avatar : pas de
    // second portrait en dessous (sinon effet « double photo » floutée).
    if (isConnecting && !cs.isVideo) {
      return Container(
        decoration: BoxDecoration(
          gradient: context.callUi.audioBackdropGradient,
        ),
      );
    }

    if (!cs.isVideo) {
      return CallAudioBackdrop(
        name: cs.remoteUserName ?? context.l10n.unknownSender,
        photoUrl: cs.remoteUserPhoto,
        isSpeaking: cs.isUserSpeaking(cs.remoteUserId?.toString() ?? ''),
        isRemoteMuted: cs.isRemoteMuted,
      );
    }

    if (_localIsMainView) {
      if (_hasLocalVideo(cs)) {
        return RTCVideoView(
          _localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      }
      return CallAudioBackdrop(
        name: localName,
        photoUrl: localPhoto,
        isSpeaking: cs.amISpeaking,
        isMuted: cs.isMuted,
      );
    }

    if (hasRemoteVideo) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    return CallAudioBackdrop(
      name: cs.remoteUserName ?? context.l10n.unknownSender,
      photoUrl: cs.remoteUserPhoto,
      isSpeaking: cs.isUserSpeaking(cs.remoteUserId?.toString() ?? ''),
      isRemoteMuted: cs.isRemoteMuted,
    );
  }

  String _statusLabel(CallService cs) {
    if (cs.isTransferInitiator) {
      switch (cs.transferStatus) {
        case CallTransferStatus.awaitingJoin:
          return context.l10n.transferWaitingForParticipant;
        case CallTransferStatus.awaitingMediaReady:
          return context.l10n.transferWaitingForConnection;
        case CallTransferStatus.countdown:
          final secs = cs.transferCountdownRemainingSeconds;
          if (secs != null) {
            return context.l10n.transferCountdownSeconds(secs);
          }
          return context.l10n.transferCountdown;
        case CallTransferStatus.completed:
          return context.l10n.transferCompleted;
        default:
          break;
      }
    }
    switch (cs.status) {
      case CallStatus.outgoing:
        return context.l10n.callInProgress;
      case CallStatus.connecting:
        return context.l10n.connecting2;
      case CallStatus.incoming:
        if (cs.isAutoAnsweringFromPush) return context.l10n.connecting2;
        return '';
      case CallStatus.connected:
        return context.l10n.inProgress;
      case CallStatus.reconnecting:
        return context.l10n.callReconnecting;
      case CallStatus.ended:
        return context.l10n.ended2;
      default:
        return '';
    }
  }

  String _connectingMessage(CallService cs) {
    if (cs.status == CallStatus.outgoing) {
      return context.l10n.callFrom(cs.remoteUserName ?? context.l10n.contact2);
    }
    return context.l10n.connecting;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _focusedParticipantId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _focusedParticipantId != null) {
          _dismissFocus();
          return;
        }
        _onFullscreenPop(didPop);
      },
      child: Consumer<CallService>(
        builder: (_, cs, __) {
          _syncCountdownTicker(cs);
          final callUi = context.callUi;
          final isVideo = cs.isVideo;
          final isGroup = cs.groupRoomId != null;
          final useVideoChrome = CallUiScope.useVideoChrome(isVideo: isVideo);
          final hasRemoteVideo = _hasRemoteVideo(cs, isGroup);
          final isConnecting = _isConnecting(cs) && !isGroup;
          final localUser = context.watch<AuthProvider>().currentUser;
          final localName = localUser?.nom ?? context.l10n.meLabel;
          final localPhoto = localUser?.avatarUrl;
          final localUserId = (cs.localUserId ?? localUser?.alanyaID)?.toString() ?? '';
          final transferStatusLabel = _statusLabel(cs);
          final displayName = isGroup
              ? (cs.isConference
                  ? context.l10n.confCallOfThree
                  : context.l10n.groupCall)
              : (cs.remoteUserName ?? context.l10n.callNoun);
          // PiP 1-à-1 uniquement — en conf la tuile locale est dans la grille.
          final pipChild = isGroup
              ? null
              : _buildPipChild(
                  cs,
                  isGroup,
                  localName: localName,
                  localPhoto: localPhoto,
                );
          final countdownSecs = cs.transferCountdownRemainingSeconds;
          final showCountdown = cs.isTransferInitiator &&
              cs.transferStatus == CallTransferStatus.countdown &&
              countdownSecs != null;

          CallUiScope.applyOverlayStyle(context, isVideo: isVideo);

          return Scaffold(
            backgroundColor: useVideoChrome ? AppColors.black : callUi.backgroundSolid,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final screenSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final safeArea = MediaQuery.paddingOf(context);
                final pipBounds = computePipBounds(
                  screenSize: screenSize,
                  safeArea: safeArea,
                  controlsVisible: _controlsVisible,
                );

                final reclamped = reclampPipOffset(_pipOffset, pipBounds);
                if (reclamped != _pipOffset) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && reclamped != _pipOffset) {
                      setState(() => _pipOffset = reclamped);
                    }
                  });
                }

                Widget? focusOverlay;
                final focusedId = _focusedParticipantId;
                if (isGroup && focusedId != null) {
                  final isLocal = focusedId == localUserId;
                  final rosterInfo = cs.groupRoster[focusedId];
                  focusOverlay = CallParticipantFocusOverlay(
                    userId: focusedId,
                    name: isLocal
                        ? localName
                        : (rosterInfo?.name ?? context.l10n.participantFallback),
                    stream: isLocal
                        ? cs.localStream
                        : cs.groupRemoteStreams[focusedId],
                    photoUrl: isLocal ? localPhoto : rosterInfo?.photo,
                    isMuted: isLocal
                        ? cs.isMuted
                        : (rosterInfo?.isMuted ?? false),
                    isVideoOn: isLocal
                        ? (cs.isVideo && cs.isVideoOn)
                        : (rosterInfo?.isVideoOn ?? true),
                    isSpeaking: isLocal
                        ? cs.amISpeaking
                        : cs.activeSpeakers.contains(focusedId),
                    mirror: isLocal,
                    onDismiss: _dismissFocus,
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMainLayer(
                      cs,
                      isGroup,
                      hasRemoteVideo,
                      localName: localName,
                      localPhoto: localPhoto,
                      localUserId: localUserId,
                      isConnecting: isConnecting,
                    ),

                    if (isConnecting)
                      CallConnectingOverlay(
                        name: cs.remoteUserName ?? context.l10n.callNoun,
                        photoUrl: cs.remoteUserPhoto,
                        message: _connectingMessage(cs),
                        animation: _pulse,
                      ),

                    if (isVideo && !isGroup)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleControls,
                          child: const SizedBox.expand(),
                        ),
                      ),

                    if (pipChild != null)
                      DraggableVideoPiP(
                        bounds: pipBounds,
                        position: _pipOffset,
                        onPositionChanged: _onPipPositionChanged,
                        onTap: _toggleSwap,
                        child: pipChild,
                      ),

                    if (focusOverlay != null) focusOverlay,

                    if (showCountdown)
                      CallTransferCountdownOverlay(
                        remainingSeconds: countdownSecs,
                        totalSeconds: cs.transferCountdownTotalSeconds,
                      ),

                    Positioned(
                      left: 0,
                      right: 0,
                      top: MediaQuery.of(context).padding.top,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: AnimatedSlide(
                          offset: _controlsVisible ? Offset.zero : const Offset(0, -0.5),
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: AppDurations.normal,
                            child: CallTopBar(
                              name: displayName,
                              status: transferStatusLabel.isNotEmpty
                                  ? transferStatusLabel
                                  : (isGroup
                                      ? context.l10n.participantsCount(
                                          cs.groupRemoteStreams.length + 1,
                                        )
                                      : ''),
                              duration: (cs.status == CallStatus.connected ||
                                      cs.status == CallStatus.reconnecting)
                                  ? cs.formattedDuration
                                  : null,
                              onMinimize: _minimize,
                              useVideoChrome: useVideoChrome,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: AnimatedSlide(
                          offset: _controlsVisible ? Offset.zero : const Offset(0, 0.5),
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1 : 0,
                            duration: AppDurations.normal,
                            child: CallControlBar(
                              isVideo: isVideo,
                              isMuted: cs.isMuted,
                              isVideoOn: cs.isVideoOn,
                              isSpeakerOn: cs.isSpeakerOn,
                              useVideoChrome: useVideoChrome,
                              onMute: () => cs.toggleMute(),
                              onSpeaker: () => cs.toggleSpeaker(),
                              onCamera: () => cs.toggleCamera(),
                              onSwitchCam: () => cs.switchCamera(),
                              onHangUp: _hangUp,
                              canAddParticipant: cs.canAddParticipant,
                              onAddParticipant: () => _openAddSheet(transfer: false),
                              onTransferParticipant: cs.canAddParticipant
                                  ? () => _openAddSheet(transfer: true)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PipVideo extends StatelessWidget {
  const _PipVideo({required this.renderer, this.mirror = false});

  final RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

class _PipAvatar extends StatelessWidget {
  const _PipAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return ColoredBox(
      color: callUi.groupTileBackground,
      child: Center(
        child: AppAvatar(
          imageUrl: photoUrl,
          name: name,
          size: 72,
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.white,
        ),
      ),
    );
  }
}
