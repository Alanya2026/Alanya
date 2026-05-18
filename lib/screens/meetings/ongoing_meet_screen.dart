import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/services/meeting_service.dart';

class OngoingMeetScreen extends StatefulWidget {
  const OngoingMeetScreen({super.key});

  @override
  State<OngoingMeetScreen> createState() => _OngoingMeetScreenState();
}

class _OngoingMeetScreenState extends State<OngoingMeetScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  // ✅ Map de renderers pour les participants distants — correctement initialisés
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _initLocalRenderer();
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    meetingService.addListener(_onMeetingServiceChanged);
  }

  Future<void> _initLocalRenderer() async {
    await _localRenderer.initialize();
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    if (meetingService.localStream != null) {
      setState(() => _localRenderer.srcObject = meetingService.localStream);
    }
  }

  void _onMeetingServiceChanged() {
    if (!mounted) return;
    final meetingService = Provider.of<MeetingService>(context, listen: false);

    // ✅ Navigation automatique si la réunion se termine
    if (meetingService.status == MeetingStatus.ended) {
      meetingService.removeListener(_onMeetingServiceChanged);
      Navigator.of(context).pop();
      return;
    }

    // Mettre à jour le renderer local
    if (_localRenderer.srcObject != meetingService.localStream) {
      setState(() => _localRenderer.srcObject = meetingService.localStream);
    }

    // Synchroniser les renderers distants avec les streams reçus
    _syncRemoteRenderers(meetingService.remoteStreams).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _syncRemoteRenderers(Map<String, dynamic> remoteStreams) async {
    final currentKeys = Set<String>.from(_remoteRenderers.keys);
    final newKeys = Set<String>.from(remoteStreams.keys);

    // Supprimer les renderers pour les participants partis
    for (final key in currentKeys.difference(newKeys)) {
      await _remoteRenderers[key]?.dispose();
      _remoteRenderers.remove(key);
    }

    // Créer les renderers pour les nouveaux participants
    for (final key in newKeys.difference(currentKeys)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = remoteStreams[key];
      _remoteRenderers[key] = renderer;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    meetingService.removeListener(_onMeetingServiceChanged);
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, _) {
        final meeting = meetingService.currentMeeting;

        return Scaffold(
          backgroundColor: const Color(0xFF202124),
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () async {
                              await meetingService.leaveMeeting();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            meeting?.objet ?? 'Meeting',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Durée
                          Text(
                            meetingService.formattedDuration,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(CupertinoIcons.switch_camera, color: Colors.white),
                            onPressed: () => meetingService.switchCamera(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Grille vidéo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _remoteRenderers.isEmpty
                        // Seul dans la réunion — afficher en plein écran
                        ? _buildVideoTile(
                            label: 'Vous',
                            renderer: _localRenderer,
                            isVideoOff: meetingService.isVideoOff,
                            isMuted: meetingService.isMuted,
                            mirror: true,
                          )
                        : GridView.count(
                            crossAxisCount: _remoteRenderers.length < 2 ? 1 : 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.8,
                            children: [
                              // Tuile locale
                              _buildVideoTile(
                                label: 'Vous',
                                renderer: _localRenderer,
                                isVideoOff: meetingService.isVideoOff,
                                isMuted: meetingService.isMuted,
                                mirror: true,
                              ),
                              // Tuiles distantes — ✅ renderers correctement initialisés
                              ..._remoteRenderers.entries.map((entry) {
                                return _buildVideoTile(
                                  label: 'User ${entry.key}',
                                  renderer: entry.value,
                                  isVideoOff: false,
                                  isMuted: false,
                                );
                              }),
                            ],
                          ),
                  ),
                ),

                // Contrôles bas
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  color: const Color(0xFF202124),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Raccrocher
                      _buildControlBtn(
                        icon: Icons.call_end,
                        color: Colors.red,
                        iconColor: Colors.white,
                        onTap: () async {
                          await meetingService.leaveMeeting();
                          if (context.mounted) Navigator.pop(context);
                        },
                        isLarge: true,
                      ),
                      // Caméra
                      _buildControlBtn(
                        icon: meetingService.isVideoOff
                            ? CupertinoIcons.video_camera
                            : CupertinoIcons.video_camera_solid,
                        color: meetingService.isVideoOff ? Colors.white : Colors.white24,
                        iconColor: meetingService.isVideoOff ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleVideo(),
                      ),
                      // Micro
                      _buildControlBtn(
                        icon: meetingService.isMuted
                            ? CupertinoIcons.mic_off
                            : CupertinoIcons.mic,
                        color: meetingService.isMuted ? Colors.white : Colors.white24,
                        iconColor: meetingService.isMuted ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleMute(),
                      ),
                      // Chat in-meeting
                      _buildControlBtn(
                        icon: Icons.chat_bubble_outline,
                        color: Colors.white24,
                        iconColor: Colors.white,
                        onTap: () => _showMeetingChat(context, meetingService),
                      ),
                      // Plus d'options
                      _buildControlBtn(
                        icon: Icons.more_vert,
                        color: Colors.white24,
                        iconColor: Colors.white,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoTile({
    required String label,
    required RTCVideoRenderer renderer,
    required bool isVideoOff,
    required bool isMuted,
    bool mirror = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Vidéo ou avatar
          if (!isVideoOff && renderer.srcObject != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.indigo,
                child: Text(
                  label[0].toUpperCase(),
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
            ),
          // Label
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          // Indicateur micro
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                color: isMuted ? Colors.red : Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 16 : 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: isLarge ? 32 : 24),
      ),
    );
  }

  void _showMeetingChat(BuildContext context, MeetingService meetingService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MeetingChatSheet(meetingService: meetingService),
    );
  }
}

class _MeetingChatSheet extends StatefulWidget {
  final MeetingService meetingService;
  const _MeetingChatSheet({required this.meetingService});

  @override
  State<_MeetingChatSheet> createState() => _MeetingChatSheetState();
}

class _MeetingChatSheetState extends State<_MeetingChatSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.meetingService,
      child: Consumer<MeetingService>(
        builder: (context, svc, _) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chat', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: svc.chatMessages.length,
                itemBuilder: (_, i) {
                  final msg = svc.chatMessages[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User ${msg.userId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(msg.message, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.indigo),
                    onPressed: () {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      // myId récupéré depuis AuthProvider en production
                      svc.sendChatMessage(text, 0);
                      _ctrl.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}