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
import '../../widgets/calls/call_participant_tile.dart';
import '../../widgets/calls/call_top_bar.dart';
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
    _remoteRenderer.srcObject = cs.remoteStream;
    _watchVideoTracks(cs.localStream);
    _watchVideoTracks(cs.remoteStream);
    cs.addListener(_onCallChanged);

    setState(() => _renderersReady = true);
  }

  void _onCallChanged() {
    if (_closing || !mounted) return;
    final cs = Provider.of<CallService>(context, listen: false);

    setState(() {
      if (_renderersReady) {
        if (_localRenderer.srcObject != cs.localStream) {
          _localRenderer.srcObject = cs.localStream;
        }
        if (_remoteRenderer.srcObject != cs.remoteStream) {
          _remoteRenderer.srcObject = cs.remoteStream;
        }
        _watchVideoTracks(cs.localStream);
        _watchVideoTracks(cs.remoteStream);
      }
    });

    if (cs.status == CallStatus.ended || cs.status == CallStatus.idle) {
      _closeAndPop();
    }
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
    if (cs.groupRoomId != null) {
      await cs.leaveGroupCall();
    } else {
      await cs.endCall();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
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
    bool isConnecting = false,
  }) {
    if (isGroup) {
      return CallGroupGrid(
        streams: cs.groupRemoteStreams,
        roster: cs.groupRoster,
        activeSpeakers: cs.activeSpeakers,
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
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _onFullscreenPop(didPop),
      child: Consumer<CallService>(
        builder: (_, cs, __) {
          final callUi = context.callUi;
          final isVideo = cs.isVideo;
          final isGroup = cs.groupRoomId != null;
          final useVideoChrome = CallUiScope.useVideoChrome(isVideo: isVideo);
          final hasRemoteVideo = _hasRemoteVideo(cs, isGroup);
          final isConnecting = _isConnecting(cs) && !isGroup;
          final localUser = context.watch<AuthProvider>().currentUser;
          final localName = localUser?.nom ?? context.l10n.meLabel;
          final localPhoto = localUser?.avatarUrl;
          final displayName =
              isGroup ? context.l10n.groupCall : (cs.remoteUserName ?? context.l10n.callNoun);
          final pipChild = _buildPipChild(
            cs,
            isGroup,
            localName: localName,
            localPhoto: localPhoto,
          );

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

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMainLayer(
                      cs,
                      isGroup,
                      hasRemoteVideo,
                      localName: localName,
                      localPhoto: localPhoto,
                      isConnecting: isConnecting,
                    ),

                    if (isConnecting)
                      CallConnectingOverlay(
                        name: cs.remoteUserName ?? context.l10n.callNoun,
                        photoUrl: cs.remoteUserPhoto,
                        message: _connectingMessage(cs),
                        animation: _pulse,
                      ),

                    if (isVideo)
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
                        onTap: isGroup ? null : _toggleSwap,
                        child: pipChild,
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
                              status: isGroup
                                  ? context.l10n.participantsCount(cs.groupRemoteStreams.length + 1)
                                  : _statusLabel(cs),
                              duration: cs.status == CallStatus.connected
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
