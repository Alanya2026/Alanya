import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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

  Meeting? _meeting;
  bool _loadingMeeting = true;

  // Statut du participant dans ce meeting
  int _participantStatus = 1; // 0=pending, 1=accepted
  bool _isMicOn = true;
  bool _isCamOn = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
    _loadMeeting();
  }

  @override
  void dispose() {
    _previewRenderer.dispose();
    _previewStream?.getTracks().forEach((t) => t.stop());
    _previewStream?.dispose();
    super.dispose();
  }

  Future<void> _initPreview() async {
    // Les réunions audio n'ont pas besoin de la caméra
    if (widget.typeMedia != 0) return;

    await _previewRenderer.initialize();
    try {
      if (!kIsWeb) {
        await Permission.camera.request();
        await Permission.microphone.request();
      }
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      if (!mounted) return;
      setState(() {
        _previewStream = stream;
        _previewRenderer.srcObject = stream;
      });
    } catch (_) {
      // Camera non disponible — on continue sans prévisualisation
    }
  }

  Future<void> _loadMeeting() async {
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await api.getMeeting(widget.meetingId);
      if (!mounted) return;
      final meeting = Meeting.fromJson(data);

      // Trouver le statut du participant courant
      final myParticipant = meeting.participants
          .where((p) => p.participantID == widget.myId)
          .firstOrNull;

      setState(() {
        _meeting = meeting;
        _participantStatus = widget.isOrganiser ? 1 : (myParticipant?.status ?? 1);
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
    final meetingService = Provider.of<MeetingService>(context, listen: false);

    // Transférer la propriété du stream à MeetingService :
    // on ne le stoppe PAS pour éviter que la caméra ne renvoie des frames
    // noires lors d'un nouveau getUserMedia immédiat.
    final adoptedStream = _previewStream;
    setState(() {
      _joining = true;
      _previewStream = null; // empêche dispose() de toucher au stream adopté
    });
    _previewRenderer.srcObject = null;

    try {
      await meetingService.joinMeeting(
        idMeeting: widget.meetingId,
        myId: widget.myId,
        myName: widget.myName,
        initialStream: adoptedStream,
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
    final isPending = _participantStatus == 0 && !widget.isOrganiser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _loadingMeeting
              ? 'Réunion'
              : (_meeting?.objet ?? 'Réunion'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Prévisualisation caméra ────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fond sombre
                    Container(color: const Color(0xFF2D2D44)),

                    // Vidéo ou avatar
                    if (_previewStream != null && _isCamOn)
                      RTCVideoView(
                        _previewRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.indigo.shade700,
                              child: Text(
                                widget.myName.isNotEmpty
                                    ? widget.myName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 36, color: Colors.white),
                              ),
                            ),
                            if (!_isCamOn) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Caméra désactivée',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Nom en bas
                    Positioned(
                      bottom: 16,
                      left: 16,
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

          // ── Bannière "En attente d'approbation" ─────────────────────
          if (isPending) _PendingBanner(),

          // ── Contrôles + bouton rejoindre ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  // Toggles micro / caméra
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
                        const SizedBox(width: 24),
                        _LobbyToggle(
                          icon: _isCamOn ? Icons.videocam : Icons.videocam_off,
                          label: _isCamOn ? 'Caméra active' : 'Caméra coupée',
                          active: _isCamOn,
                          onTap: _toggleCam,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bouton Rejoindre
                  if (!isPending)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _joining ? null : _join,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
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

// ─── Bannière "En attente d'approbation" ─────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.orange),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'En attente d\'approbation de l\'organisateur…',
              style: TextStyle(color: Colors.white, fontSize: 13),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active ? Colors.white24 : Colors.red.shade700,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
