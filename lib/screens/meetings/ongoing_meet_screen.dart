import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/meeting_service.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/auth_provider.dart';

// Couleurs spécifiques à l'UI Google-Meet de la réunion (aucun token AppColors
// ne correspond exactement à ce gris-anthracite, distinct du bleu immersif).
const _kMeetBg = Color(0xFF202124);
const _kMeetTile = Color(0xFF3C4043);
const _kMeetSheet = Color(0xFF2D2D2D);
// Petit rayon pour les étiquettes de tuile vidéo.
const _kBrXs = BorderRadius.all(Radius.circular(4));

class OngoingMeetScreen extends StatefulWidget {
  const OngoingMeetScreen({super.key});

  @override
  State<OngoingMeetScreen> createState() => _OngoingMeetScreenState();
}

class _OngoingMeetScreenState extends State<OngoingMeetScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
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
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);
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
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);

    if (meetingService.status == MeetingStatus.ended) {
      meetingService.removeListener(_onMeetingServiceChanged);
      Navigator.of(context).pop();
      return;
    }

    if (_localRendererReady &&
        _localRenderer.srcObject != meetingService.localStream) {
      _localRenderer.srcObject = meetingService.localStream;
    }

    _syncRemoteRenderers(meetingService.remoteStreams);
  }

  Future<void> _syncRemoteRenderers(
      Map<String, dynamic> remoteStreams) async {
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
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);
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
      backgroundColor: _kMeetSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
      ),
      builder: (_) =>
          _ParticipantsSheet(meetingService: meetingService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, _) {
        final meeting = meetingService.currentMeeting;
        final myId = Provider.of<AuthProvider>(context, listen: false)
                .currentUser
                ?.alanyaID ??
            0;
        final isOrganiser = meeting?.idOrganiser == myId;

        return PopScope(
          canPop: meetingService.status != MeetingStatus.connected,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await meetingService.leaveMeeting();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: _kMeetBg,
            body: SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () async {
                                  await meetingService.leaveMeeting();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              AppSpacing.hGapSm,
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
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                            AppSpacing.hGapXs,
                            IconButton(
                              icon: const Icon(
                                  CupertinoIcons.switch_camera,
                                  color: Colors.white),
                              onPressed: () =>
                                  meetingService.switchCamera(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.people_outline,
                                  color: Colors.white),
                              onPressed: () =>
                                  _showParticipantsPanel(meetingService),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Grille vidéo ─────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: _remoteRenderers.isEmpty
                          ? _buildVideoTile(
                              label: 'Vous',
                              renderer: _localRenderer,
                              isVideoOff: meetingService.isVideoOff ||
                                  !_localRendererReady,
                              isMuted: meetingService.isMuted,
                              mirror: true,
                            )
                          : GridView.count(
                              crossAxisCount:
                                  _remoteRenderers.length < 2 ? 1 : 2,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.8,
                              children: [
                                _buildVideoTile(
                                  label: 'Vous',
                                  renderer: _localRenderer,
                                  isVideoOff: meetingService.isVideoOff ||
                                      !_localRendererReady,
                                  isMuted: meetingService.isMuted,
                                  mirror: true,
                                ),
                                ..._remoteRenderers.entries.map((entry) {
                                  final participant = meeting?.participants
                                      .where((p) =>
                                          p.participantID.toString() ==
                                          entry.key)
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

                  // ── Contrôles bas ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                        horizontal: AppSpacing.xxl),
                    color: _kMeetBg,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildControlBtn(
                          icon: Icons.call_end,
                          color: AppColors.error,
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
                          color: meetingService.isVideoOff
                              ? Colors.white
                              : Colors.white24,
                          iconColor: meetingService.isVideoOff
                              ? Colors.black
                              : Colors.white,
                          onTap: () => meetingService.toggleVideo(),
                        ),
                        _buildControlBtn(
                          icon: meetingService.isMuted
                              ? CupertinoIcons.mic_off
                              : CupertinoIcons.mic,
                          color: meetingService.isMuted
                              ? Colors.white
                              : Colors.white24,
                          iconColor: meetingService.isMuted
                              ? Colors.black
                              : Colors.white,
                          onTap: () => meetingService.toggleMute(),
                        ),
                        _buildControlBtn(
                          icon: Icons.chat_bubble_outline,
                          color: Colors.white24,
                          iconColor: Colors.white,
                          onTap: () =>
                              _showMeetingChat(context, meetingService),
                        ),
                        if (isOrganiser)
                          _buildControlBtn(
                            icon: Icons.stop_circle_outlined,
                            color: const Color(0xFFB71C1C),
                            iconColor: Colors.white,
                            onTap: () => _confirmEndForAll(
                                context, meetingService),
                          )
                        else
                          _buildControlBtn(
                            icon: Icons.more_vert,
                            color: Colors.white24,
                            iconColor: Colors.white,
                            onTap: () =>
                                _showParticipantsPanel(meetingService),
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

  Future<void> _confirmEndForAll(
      BuildContext context, MeetingService meetingService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kMeetSheet,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.brMd),
        title: const Text('Terminer pour tous',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous mettre fin à la réunion pour tous les participants ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer',
                style: TextStyle(color: AppColors.error)),
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
      decoration: const BoxDecoration(
        color: _kMeetTile,
        borderRadius: AppRadius.brMd,
      ),
      child: Stack(
        children: [
          if (!isVideoOff && renderer.srcObject != null)
            ClipRRect(
              borderRadius: AppRadius.brMd,
              child: RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.brandPrimary,
                child: Text(
                  label.isNotEmpty ? label[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 32, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: AppSpacing.md,
            left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: _kBrXs,
              ),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                color: isMuted ? AppColors.error : Colors.white,
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
        padding: EdgeInsets.all(isLarge ? AppSpacing.lg : AppSpacing.md),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon,
            color: iconColor, size: isLarge ? 32 : AppIconSize.md),
      ),
    );
  }

  void _showMeetingChat(
      BuildContext context, MeetingService meetingService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kMeetSheet,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop),
      builder: (ctx) =>
          _MeetingChatSheet(meetingService: meetingService),
    );
  }
}

// ─── Panel participants ───────────────────────────────────────────────────────

class _ParticipantsSheet extends StatelessWidget {
  final MeetingService meetingService;
  const _ParticipantsSheet({required this.meetingService});

  @override
  Widget build(BuildContext context) {
    final myId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.alanyaID ??
        0;
    final meeting = meetingService.currentMeeting;
    final connectedIds =
        Set<String>.from(meetingService.remoteStreams.keys);
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
                Container(
                  margin: const EdgeInsets.only(
                      top: AppSpacing.md, bottom: AppSpacing.sm),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
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
                      AppSpacing.hGapSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Text(
                          '${participants.length}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl),
                          itemCount: participants.length,
                          itemBuilder: (_, i) {
                            final p = participants[i];
                            final isConnected = p.connecte ||
                                connectedIds.contains(
                                    p.participantID.toString());
                            final name =
                                p.nom ?? p.pseudo ?? 'Participant';
                            final isMe = p.participantID == myId;
                            final isHost =
                                meeting?.idOrganiser == p.participantID;
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandPrimaryDark,
                backgroundImage: avatarImage(avatarUrl),
                child: hasValidAvatarUrl(avatarUrl)
                    ? null
                    : Text(initial,
                        style: const TextStyle(color: Colors.white)),
              ),
              if (isConnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _kMeetSheet, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14)),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withAlpha(60),
                borderRadius: AppRadius.brSm,
              ),
              child: const Text(
                'Hôte',
                style: TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: AppRadius.brSm,
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
    final myId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.alanyaID ??
        0;
    return ChangeNotifierProvider.value(
      value: widget.meetingService,
      child: Consumer<MeetingService>(
        builder: (context, svc, _) => Column(
          children: [
            AppSpacing.vGapSm,
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Chat',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      itemCount: svc.chatMessages.length,
                      itemBuilder: (_, i) {
                        final msg = svc.chatMessages[i];
                        final isMe = msg.userId == myId.toString();
                        final meeting = svc.currentMeeting;
                        final participant = meeting?.participants
                            .where((p) =>
                                p.participantID.toString() == msg.userId)
                            .firstOrNull;
                        final senderName = isMe
                            ? 'Vous'
                            : (participant?.nom ??
                                participant?.pseudo ??
                                'User ${msg.userId}');
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(senderName,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11)),
                              AppSpacing.vGapXs,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.brandPrimaryStrong
                                      : Colors.white12,
                                  borderRadius: AppRadius.brMd,
                                ),
                                child: Text(
                                  msg.message,
                                  style: const TextStyle(
                                      color: Colors.white),
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
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.brPill,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  IconButton(
                    icon: const Icon(Icons.send,
                        color: AppColors.brandPrimary),
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
