import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/call_service.dart';
import '../../widgets/calls/speaking_indicator_border.dart';

/// Écran d'appel en cours (1-à-1, audio ou vidéo).
///
/// Trois sous-états gérés par le même widget :
/// - `connecting`  : "Connexion..." + spinner + ringback (déjà géré par CallService)
/// - `connected`   : timer + flux audio/vidéo
/// - `ended`/`idle`: pop automatique
class OngoingCallScreen extends StatefulWidget {
  const OngoingCallScreen({super.key});

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;

    final cs = Provider.of<CallService>(context, listen: false);

    // !! FIX: Assigner les streams immédiatement s'ils existent
    debugPrint('[OngoingCall] 📹 Init renderers');
    debugPrint('[OngoingCall] Local stream: ${cs.localStream != null ? "!!" : "**"}');
    debugPrint('[OngoingCall] Remote stream: ${cs.remoteStream != null ? "!!" : "**"}');

    _localRenderer.srcObject = cs.localStream;
    _remoteRenderer.srcObject = cs.remoteStream;

    // !! S'abonner aux changements de CallService
    cs.addListener(_onCallChanged);

    setState(() => _renderersReady = true);
  }

  void _onCallChanged() {
    if (_closing || !mounted) return;
    final cs = Provider.of<CallService>(context, listen: false);

    debugPrint('[OngoingCall] 📹 State changed: status=${cs.status}, local=${cs.localStream != null ? "!!" : "**"}, remote=${cs.remoteStream != null ? "!!" : "**"}');

    // !! FIX CRITIQUE: TOUJOURS mettre à jour les renderers
    // Ne pas vérifier si ça a "changé" - juste le faire
    // Parfois le stream arrive après le premier call, ou est réassigné
    setState(() {
      if (_renderersReady) {
        final localChanged = _localRenderer.srcObject != cs.localStream;
        final remoteChanged = _remoteRenderer.srcObject != cs.remoteStream;

        if (localChanged) {
          debugPrint('[OngoingCall] 📹 Update local renderer: ${cs.localStream != null ? "stream" : "null"}');
          _localRenderer.srcObject = cs.localStream;
        }
        if (remoteChanged) {
          debugPrint('[OngoingCall] 📹 Update remote renderer: ${cs.remoteStream != null ? "stream" : "null"}');
          _remoteRenderer.srcObject = cs.remoteStream;
        }
      }
    });

    if (cs.status == CallStatus.ended && !cs.callEndedByUs) {
      debugPrint('[OngoingCall] 📞 Appel terminé par l\'autre côté');
      _closeAndPop();
      return;
    }
    if (cs.status == CallStatus.idle) {
      debugPrint('[OngoingCall] 📞 Statut idle, fermeture');
      _closeAndPop();
      return;
    }
  }

  void _closeAndPop() {
    if (_closing) return;
    _closing = true;
    final cs = Provider.of<CallService>(context, listen: false);
    cs.removeListener(_onCallChanged);
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    if (mounted) Navigator.of(context).maybePop();
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
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    try {
      Provider.of<CallService>(context, listen: false).removeListener(_onCallChanged);
    } catch (_) { /* listener déjà retiré / provider absent — ignoré */ }
    if (_renderersReady) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (_, cs, __) {
        final isVideo = cs.isVideo;
        final isGroup = cs.groupRoomId != null;
        final hasRemoteVideo =
            !isGroup && isVideo && _remoteRenderer.srcObject != null;
        return Scaffold(
          backgroundColor: AppColors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background : grille groupe / remote vidéo plein écran / avatar
              if (isGroup)
                _GroupGrid(
                  streams: cs.groupRemoteStreams,
                  roster: cs.groupRoster,
                  activeSpeakers: cs.activeSpeakers,
                )
              else if (hasRemoteVideo)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _AudioBackdrop(
                  name: cs.remoteUserName ?? 'Inconnu',
                  photoUrl: cs.remoteUserPhoto,
                  isSpeaking: cs.isUserSpeaking(
                      cs.remoteUserId?.toString() ?? ''),
                  isRemoteMuted: cs.isRemoteMuted,
                ),

              // Local video PiP (vidéo uniquement)
              if (isVideo && _renderersReady && _localRenderer.srcObject != null)
                Positioned(
                  right: AppSpacing.lg,
                  top: MediaQuery.of(context).padding.top + AppSpacing.md,
                  child: _LocalPiP(renderer: _localRenderer),
                ),

              // Top bar : nom + statut + chronomètre
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).padding.top,
                child: _TopBar(
                  name: isGroup
                      ? 'Appel groupé'
                      : (cs.remoteUserName ?? 'Appel'),
                  status: isGroup
                      ? '${cs.groupRemoteStreams.length + 1} participants'
                      : _statusLabel(cs),
                  duration: cs.status == CallStatus.connected
                      ? cs.formattedDuration
                      : null,
                  onMinimize: () => Navigator.of(context).maybePop(),
                ),
              ),

              // Bottom controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomControls(
                  isVideo: isVideo,
                  isMuted: cs.isMuted,
                  isVideoOn: cs.isVideoOn,
                  isSpeakerOn: cs.isSpeakerOn,
                  onMute: () => cs.toggleMute(),
                  onSpeaker: () => cs.toggleSpeaker(),
                  onCamera: () => cs.toggleCamera(),
                  onSwitchCam: () => cs.switchCamera(),
                  onHangUp: _hangUp,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(CallService cs) {
    switch (cs.status) {
      case CallStatus.outgoing:
      case CallStatus.connecting:
        return 'Connexion…';
      case CallStatus.connected:
        return 'En cours';
      case CallStatus.ended:
        return 'Terminé';
      default:
        return '';
    }
  }
}

// ─── Sous-widgets ──────────────────────────────────────────────────────

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop({
    required this.name,
    required this.photoUrl,
    this.isSpeaking = false,
    this.isRemoteMuted = false,
  });

  final String name;
  final String? photoUrl;
  final bool isSpeaking;
  final bool isRemoteMuted;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasPhoto = url != null &&
        url.isNotEmpty &&
        url.toUpperCase() != 'NON DEFINI' &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandPrimaryDark, AppColors.black],
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SpeakingIndicatorBorder(
            isSpeaking: isSpeaking,
            shape: BoxShape.circle,
            borderWidth: 4,
            child: CircleAvatar(
              radius: 90,
              backgroundColor: AppColors.brandPrimary,
              backgroundImage: hasPhoto ? NetworkImage(url) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (isRemoteMuted)
            Positioned(
              bottom: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.mic_off, color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Micro coupé',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalPiP extends StatelessWidget {
  const _LocalPiP({required this.renderer});

  final RTCVideoRenderer renderer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 160,
      decoration: const BoxDecoration(
        borderRadius: AppRadius.brSm,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: RTCVideoView(
        renderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.status,
    required this.duration,
    required this.onMinimize,
  });

  final String name;
  final String status;
  final String? duration;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_down,
                color: Colors.white, size: 28),
            onPressed: onMinimize,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.vGapXs,
                Text(
                  duration ?? status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isVideo,
    required this.isMuted,
    required this.isVideoOn,
    required this.isSpeakerOn,
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
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onCamera;
  final VoidCallback onSwitchCam;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl,
          AppSpacing.xxl + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(
            icon: isMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic_solid,
            active: isMuted,
            onTap: onMute,
          ),
          if (isVideo)
            _RoundButton(
              icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
              active: !isVideoOn,
              onTap: onCamera,
            )
          else
            _RoundButton(
              icon: isSpeakerOn
                  ? CupertinoIcons.speaker_3_fill
                  : CupertinoIcons.speaker_2,
              active: isSpeakerOn,
              onTap: onSpeaker,
            ),
          if (isVideo)
            _RoundButton(
              icon: CupertinoIcons.switch_camera,
              active: false,
              onTap: onSwitchCam,
            ),
          _HangUpButton(onTap: onHangUp),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: active
              ? AppColors.white
              : Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Icon(
          icon,
          color: active ? AppColors.black : AppColors.white,
          size: 26,
        ),
      ),
    );
  }
}

// ─── Grille appel de groupe ────────────────────────────────────────────

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({
    required this.streams,
    required this.roster,
    required this.activeSpeakers,
  });

  final Map<String, MediaStream> streams;
  final Map<String, GroupParticipantInfo> roster;
  final Set<String> activeSpeakers;

  @override
  Widget build(BuildContext context) {
    final entries = streams.entries.toList();
    if (entries.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brandPrimaryDark, AppColors.black],
          ),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: AppSpacing.lg),
            Text(
              'En attente des participants…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Container(
      color: AppColors.black,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 80, AppSpacing.sm, 140),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.75,
        ),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final e = entries[i];
          final info = roster[e.key];
          return _RemoteTile(
            key: ValueKey('remote_${e.key}'),
            userId: e.key,
            stream: e.value,
            name: info?.name ?? 'Participant',
            isSpeaking: activeSpeakers.contains(e.key),
            isMuted: info?.isMuted ?? false,
          );
        },
      ),
    );
  }
}

class _RemoteTile extends StatefulWidget {
  const _RemoteTile({
    super.key,
    required this.userId,
    required this.stream,
    required this.name,
    required this.isSpeaking,
    this.isMuted = false,
  });

  final String userId;
  final MediaStream stream;
  final String name;
  final bool isSpeaking;
  final bool isMuted;

  @override
  State<_RemoteTile> createState() => _RemoteTileState();
}

class _RemoteTileState extends State<_RemoteTile> {
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
  void didUpdateWidget(covariant _RemoteTile oldWidget) {
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
    final initial = widget.name.isNotEmpty
        ? widget.name.substring(0, 1).toUpperCase()
        : '?';
    return SpeakingIndicatorBorder(
      isSpeaking: widget.isSpeaking,
      borderRadius: AppRadius.brMd,
      child: ClipRRect(
        borderRadius: AppRadius.brMd,
        child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.immersiveSurface),
          if (_ready)
            RTCVideoView(
              _renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          // Avatar fallback (visible si pas de track vidéo)
          if (_ready && _renderer.videoWidth == 0)
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.brandPrimary,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm - 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isMuted)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(CupertinoIcons.mic_off,
                          color: Colors.redAccent, size: 14),
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

class _HangUpButton extends StatelessWidget {
  const _HangUpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const SizedBox(
        width: 68,
        height: 68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(CupertinoIcons.phone_down_fill,
              color: Colors.white, size: 30),
        ),
      ),
    );
  }
}