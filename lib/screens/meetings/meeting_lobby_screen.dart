import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/meeting_service.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'ongoing_meet_screen.dart';

class MeetingLobbyScreen extends StatefulWidget {
  final int meetingId;
  final int myId;
  final String myName;
  final bool isOrganiser;
  final int typeMedia; // 0 = vidéo+audio, 1 = audio seul

  const MeetingLobbyScreen({
    super.key,
    required this.meetingId,
    required this.myId,
    required this.myName,
    required this.isOrganiser,
    this.typeMedia = 0,
  });

  @override
  State<MeetingLobbyScreen> createState() => _MeetingLobbyScreenState();
}

class _MeetingLobbyScreenState extends State<MeetingLobbyScreen> {
  final RTCVideoRenderer _previewRenderer = RTCVideoRenderer();
  MediaStream? _previewStream;
  late final MeetingService _meetingService;

  Meeting? _meeting;
  bool _loadingMeeting = true;

  bool _isMicOn = true;
  bool _isCamOn = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _meetingService = Provider.of<MeetingService>(context, listen: false);
    _initPreview();
    _loadMeeting();
  }

  @override
  void dispose() {
    _previewRenderer.srcObject = null;
    _previewRenderer.dispose();
    _meetingService.releaseLocalMediaIfNotJoined();
    super.dispose();
  }

  Future<void> _initPreview() async {
    await _previewRenderer.initialize();
    final stream = await _meetingService.prepareLocalMedia(
      video: widget.typeMedia == 0,
    );
    if (!mounted) return;
    setState(() {
      _previewStream = stream;
      _previewRenderer.srcObject = widget.typeMedia == 0 ? stream : null;
    });
  }

  Future<void> _loadMeeting() async {
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await api.getMeeting(widget.meetingId);
      if (!mounted) return;
      final meeting = Meeting.fromJson(data);
      setState(() {
        _meeting = meeting;
        _loadingMeeting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMeeting = false);
    }
  }

  void _toggleMic() {
    _previewStream?.getAudioTracks().forEach((t) => t.enabled = !_isMicOn);
    setState(() => _isMicOn = !_isMicOn);
  }

  void _toggleCam() {
    _previewStream?.getVideoTracks().forEach((t) => t.enabled = !_isCamOn);
    setState(() => _isCamOn = !_isCamOn);
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    _previewRenderer.srcObject = null;

    try {
      await _meetingService.joinMeeting(
        idMeeting: widget.meetingId,
        myId: widget.myId,
        myName: widget.myName,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OngoingMeetScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de rejoindre : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.immersiveBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _loadingMeeting ? 'Réunion' : (_meeting?.objet ?? 'Réunion'),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Prévisualisation caméra ───────────────────────────��────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
              child: ClipRRect(
                borderRadius: AppRadius.brLg,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppColors.immersiveSurface),
                    if (_previewStream != null && _isCamOn)
                      RTCVideoView(
                        _previewRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.brandPrimaryStrong,
                              child: Text(
                                widget.myName.isNotEmpty
                                    ? widget.myName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 36, color: Colors.white),
                              ),
                            ),
                            if (!_isCamOn) ...[
                              AppSpacing.vGapMd,
                              const Text(
                                'Caméra désactivée',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: AppSpacing.lg,
                      left: AppSpacing.lg,
                      child: Text(
                        widget.myName.isNotEmpty ? widget.myName : 'Vous',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contrôles + bouton rejoindre ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LobbyToggle(
                        icon: _isMicOn ? Icons.mic : Icons.mic_off,
                        label: _isMicOn ? 'Micro actif' : 'Micro coupé',
                        active: _isMicOn,
                        onTap: _toggleMic,
                      ),
                      if (widget.typeMedia == 0) ...[
                        const SizedBox(width: AppSpacing.xxl),
                        _LobbyToggle(
                          icon: _isCamOn ? Icons.videocam : Icons.videocam_off,
                          label:
                              _isCamOn ? 'Caméra active' : 'Caméra coupée',
                          active: _isCamOn,
                          onTap: _toggleCam,
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.vGapXl,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _joining ? null : _join,
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSizes.buttonHeight + 6),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.brMd),
                        elevation: 0,
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Rejoindre',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                    ),
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

// ─── Bouton toggle lobby ──────────────────────────────────────────────────────

class _LobbyToggle extends StatelessWidget {
  const _LobbyToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            decoration: BoxDecoration(
              color: active ? Colors.white24 : AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          AppSpacing.vGapSm,
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
