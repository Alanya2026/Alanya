import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/services/meeting_service.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/auth_provider.dart';

class OngoingMeetScreen extends StatefulWidget {
  const OngoingMeetScreen({super.key});

  @override
  State<OngoingMeetScreen> createState() => _OngoingMeetScreenState();
}

class _OngoingMeetScreenState extends State<OngoingMeetScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  // Signature (id du stream + nb de pistes) par pair. Sert à détecter qu'une
  // piste vidéo s'est ajoutée à un stream déjà rendu (les pistes audio/vidéo
  // arrivent via deux onTrack successifs) afin de réassigner le srcObject —
  // sinon le renderer reste figé sur l'audio seul et la vidéo est noire.
  final Map<String, String> _remoteStreamSignatures = {};
  bool _localRendererReady = false;

  String _streamSignature(dynamic stream) {
    if (stream is! MediaStream) return '';
    return '${stream.id}:v${stream.getVideoTracks().length}:a${stream.getAudioTracks().length}';
  }

  @override
  void initState() {
    super.initState();
    _setupRenderer();
  }

  Future<void> _setupRenderer() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    await _localRenderer.initialize();
    if (!mounted) return;

    setState(() {
      _localRendererReady = true;
      _localRenderer.srcObject = meetingService.localStream;
    });

    await _syncRemoteRenderers(meetingService.remoteStreams);
    if (!mounted) return;

    meetingService.addListener(_onMeetingServiceChanged);
  }

  void _onMeetingServiceChanged() {
    if (!mounted) return;
    final meetingService = Provider.of<MeetingService>(context, listen: false);

    if (meetingService.status == MeetingStatus.ended) {
      meetingService.removeListener(_onMeetingServiceChanged);
      Navigator.of(context).pop();
      return;
    }

    if (_localRendererReady &&
        _localRenderer.srcObject != meetingService.localStream) {
      _localRenderer.srcObject = meetingService.localStream;
    }

    // _syncRemoteRenderers déclenche déjà son propre setState une fois terminé.
    _syncRemoteRenderers(meetingService.remoteStreams);
  }

  Future<void> _syncRemoteRenderers(Map<String, dynamic> remoteStreams) async {
    final currentKeys = Set<String>.from(_remoteRenderers.keys);
    final newKeys = Set<String>.from(remoteStreams.keys);

    for (final key in currentKeys.difference(newKeys)) {
      await _remoteRenderers[key]?.dispose();
      _remoteRenderers.remove(key);
      _remoteStreamSignatures.remove(key);
    }

    for (final key in newKeys.difference(currentKeys)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = remoteStreams[key];
      _remoteRenderers[key] = renderer;
      _remoteStreamSignatures[key] = _streamSignature(remoteStreams[key]);
    }

    // Pairs déjà rendus : si la composition du stream a changé (piste vidéo
    // ajoutée après l'audio), réassigner le srcObject pour forcer le rendu.
    for (final key in newKeys.intersection(currentKeys)) {
      final sig = _streamSignature(remoteStreams[key]);
      if (_remoteStreamSignatures[key] != sig) {
        _remoteRenderers[key]?.srcObject = remoteStreams[key];
        _remoteStreamSignatures[key] = sig;
      }
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

  void _showParticipantsPanel(MeetingService meetingService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ParticipantsSheet(meetingService: meetingService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, _) {
        final meeting = meetingService.currentMeeting;
        final myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID ?? 0;
        final isOrganiser = meeting?.idOrganiser == myId;

        return PopScope(
          canPop: meetingService.status != MeetingStatus.connected,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await meetingService.leaveMeeting();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
          backgroundColor: const Color(0xFF202124),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () async {
                                await meetingService.leaveMeeting();
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                meeting?.objet ?? 'Meeting',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            meetingService.formattedDuration,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(CupertinoIcons.switch_camera, color: Colors.white),
                            onPressed: () => meetingService.switchCamera(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people_outline, color: Colors.white),
                            onPressed: () => _showParticipantsPanel(meetingService),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Grille vidéo ─────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _remoteRenderers.isEmpty
                        ? _buildVideoTile(
                            label: 'Vous',
                            renderer: _localRenderer,
                            isVideoOff: meetingService.isVideoOff || !_localRendererReady,
                            isMuted: meetingService.isMuted,
                            mirror: true,
                          )
                        : GridView.count(
                            crossAxisCount: _remoteRenderers.length < 2 ? 1 : 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.8,
                            children: [
                              _buildVideoTile(
                                label: 'Vous',
                                renderer: _localRenderer,
                                isVideoOff: meetingService.isVideoOff || !_localRendererReady,
                                isMuted: meetingService.isMuted,
                                mirror: true,
                              ),
                              ..._remoteRenderers.entries.map((entry) {
                                final participant = meeting?.participants
                                    .where((p) => p.participantID.toString() == entry.key)
                                    .firstOrNull;
                                final label = participant?.nom ??
                                    participant?.pseudo ??
                                    'User ${entry.key}';
                                return _buildVideoTile(
                                  label: label,
                                  renderer: entry.value,
                                  isVideoOff: false,
                                  isMuted: false,
                                );
                              }),
                            ],
                          ),
                  ),
                ),

                // ── Contrôles bas ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  color: const Color(0xFF202124),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
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
                      _buildControlBtn(
                        icon: meetingService.isVideoOff
                            ? CupertinoIcons.video_camera
                            : CupertinoIcons.video_camera_solid,
                        color: meetingService.isVideoOff ? Colors.white : Colors.white24,
                        iconColor: meetingService.isVideoOff ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleVideo(),
                      ),
                      _buildControlBtn(
                        icon: meetingService.isMuted
                            ? CupertinoIcons.mic_off
                            : CupertinoIcons.mic,
                        color: meetingService.isMuted ? Colors.white : Colors.white24,
                        iconColor: meetingService.isMuted ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleMute(),
                      ),
                      _buildControlBtn(
                        icon: Icons.chat_bubble_outline,
                        color: Colors.white24,
                        iconColor: Colors.white,
                        onTap: () => _showMeetingChat(context, meetingService),
                      ),
                      if (isOrganiser)
                        _buildControlBtn(
                          icon: Icons.stop_circle_outlined,
                          color: Colors.red.shade900,
                          iconColor: Colors.white,
                          onTap: () => _confirmEndForAll(context, meetingService),
                        )
                      else
                        _buildControlBtn(
                          icon: Icons.more_vert,
                          color: Colors.white24,
                          iconColor: Colors.white,
                          onTap: () => _showParticipantsPanel(meetingService),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Future<void> _confirmEndForAll(BuildContext context, MeetingService meetingService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer pour tous', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous mettre fin à la réunion pour tous les participants ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await meetingService.endMeetingForAll();
      if (context.mounted) Navigator.pop(context);
    }
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
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

// ─── Panel participants ───────────────────────────────────────────────────────

class _ParticipantsSheet extends StatelessWidget {
  final MeetingService meetingService;
  const _ParticipantsSheet({required this.meetingService});

  @override
  Widget build(BuildContext context) {
    final myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID ?? 0;
    final meeting = meetingService.currentMeeting;
    final connectedIds = Set<String>.from(meetingService.remoteStreams.keys);
    final participants = meeting?.participants ?? [];

    return ChangeNotifierProvider.value(
      value: meetingService,
      child: Consumer<MeetingService>(
        builder: (_, svc, __) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Participants',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${participants.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des participants
                Expanded(
                  child: participants.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun participant connecté',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: participants.length,
                          itemBuilder: (_, i) {
                            final p = participants[i];
                            final isConnected = p.connecte ||
                                connectedIds.contains(p.participantID.toString());
                            final name = p.nom ?? p.pseudo ?? 'Participant';
                            final isMe = p.participantID == myId;
                            final isHost = meeting?.idOrganiser == p.participantID;
                            return _ParticipantRow(
                              name: isMe ? '$name (vous)' : name,
                              avatarUrl: p.avatarUrl,
                              isConnected: isConnected,
                              isHost: isHost,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.isConnected,
    required this.isHost,
    this.avatarUrl,
  });
  final String name;
  final String? avatarUrl;
  final bool isConnected;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.indigo.shade800,
                backgroundImage: avatarImage(avatarUrl),
                child: hasValidAvatarUrl(avatarUrl)
                    ? null
                    : Text(initial, style: const TextStyle(color: Colors.white)),
              ),
              if (isConnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2D2D2D), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.indigo.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Hôte',
                style: TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Invité',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Chat in-meeting ──────────────────────────────────────────────────────────

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
    final myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID ?? 0;
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
              child: Text(
                'Chat',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: svc.chatMessages.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun message pour le moment',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: svc.chatMessages.length,
                      itemBuilder: (_, i) {
                        final msg = svc.chatMessages[i];
                        final isMe = msg.userId == myId.toString();
                        final meeting = svc.currentMeeting;
                        final participant = meeting?.participants
                            .where((p) => p.participantID.toString() == msg.userId)
                            .firstOrNull;
                        final senderName = isMe
                            ? 'Vous'
                            : (participant?.nom ?? participant?.pseudo ?? 'User ${msg.userId}');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.indigo.shade700 : Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg.message,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                      svc.sendChatMessage(text, myId);
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
