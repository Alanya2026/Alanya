import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/meeting_service.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/calls/speaking_indicator_border.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_badge.dart';
import '../../core/theme/app_theme.dart';

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
  bool _closing = false;
  final Set<String> _watchedVideoTrackIds = {};

  String _streamSignature(dynamic stream) {
    if (stream is! MediaStream) return '';
    return '${stream.id}:v${stream.getVideoTracks().length}:a${stream.getAudioTracks().length}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<MeetingService>(context, listen: false)
            .markMeetingUiVisible();
      }
    });
    _setupRenderer();
  }

  void _minimize() {
    if (_closing || !mounted) return;
    Navigator.of(context).pop();
  }

  void _onFullscreenPop(bool didPop) {
    if (!didPop || _closing || !mounted) return;
    Provider.of<MeetingService>(context, listen: false)
        .markMeetingUiMinimized();
  }

  Future<void> _setupRenderer() async {
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);
    await _localRenderer.initialize();
    if (!mounted) return;

    _localRenderer.onResize = () {
      if (mounted) setState(() {});
    };
    setState(() {
      _localRendererReady = true;
      _localRenderer.srcObject = meetingService.localStream;
    });
    _watchVideoTracks(meetingService.localStream);

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
      _closing = true;
      Navigator.of(context).pop();
      return;
    }

    if (_localRendererReady &&
        _localRenderer.srcObject != meetingService.localStream) {
      _localRenderer.srcObject = meetingService.localStream;
      _watchVideoTracks(meetingService.localStream);
    }

    _syncRemoteRenderers(meetingService.remoteStreams);
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

  bool _localTileShowsVideo(MeetingService meetingService) {
    if (meetingService.isVideoOff || !_localRendererReady) return false;
    final stream = meetingService.localStream;
    if (stream == null || stream.getVideoTracks().isEmpty) return false;
    return _localRenderer.srcObject != null;
  }

  bool _remoteTileShowsVideo(
    RTCVideoRenderer renderer,
    MediaStream? stream, {
    required bool isVideoOff,
  }) {
    // Comme les appels de groupe : on se fie UNIQUEMENT à l'état caméra
    // synchronisé par socket, pas à `videoWidth`. Le RTCVideoView se
    // rafraîchit tout seul quand les trames (re)arrivent — sinon la tuile
    // restait bloquée sur l'avatar après une réactivation.
    if (isVideoOff) return false;
    if (stream == null || stream.getVideoTracks().isEmpty) return false;
    return renderer.srcObject != null;
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
      final stream = remoteStreams[key] as MediaStream?;
      renderer.srcObject = stream;
      // Rebuild quand la 1re trame / la taille change (reprise caméra),
      // sinon la tuile pouvait rester figée sur l'avatar.
      renderer.onResize = () {
        if (mounted) setState(() {});
      };
      _remoteRenderers[key] = renderer;
      _remoteStreamSignatures[key] = _streamSignature(stream);
      _watchVideoTracks(stream);
    }

    for (final key in newKeys.intersection(currentKeys)) {
      final sig = _streamSignature(remoteStreams[key]);
      if (_remoteStreamSignatures[key] != sig) {
        final stream = remoteStreams[key] as MediaStream?;
        _remoteRenderers[key]?.srcObject = stream;
        _remoteStreamSignatures[key] = sig;
        _watchVideoTracks(stream);
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
        final myAvatar =
            Provider.of<AuthProvider>(context, listen: false).currentUser?.avatarUrl;
        final isOrganiser = meeting?.idOrganiser == myId;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) => _onFullscreenPop(didPop),
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
                                icon: const Icon(
                                  CupertinoIcons.chevron_down,
                                  color: AppColors.white,
                                  size: 28,
                                ),
                                onPressed: _minimize,
                              ),
                              AppSpacing.hGapSm,
                              Flexible(
                                child: Text(
                                  meeting?.objet ?? context.l10n.meeting,
                                  style: const TextStyle(
                                    color: AppColors.white,
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
                                  color: AppColors.white),
                              onPressed: () =>
                                  meetingService.switchCamera(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.people_outline,
                                  color: AppColors.white),
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
                              label: context.l10n.youLabel,
                              renderer: _localRenderer,
                              photoUrl: myAvatar,
                              showVideo: _localTileShowsVideo(meetingService),
                              isVideoOff: meetingService.isVideoOff,
                              isMuted: meetingService.isMuted,
                              isSpeaking: meetingService.amISpeaking,
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
                                  label: context.l10n.youLabel,
                                  renderer: _localRenderer,
                                  photoUrl: myAvatar,
                                  showVideo:
                                      _localTileShowsVideo(meetingService),
                                  isVideoOff: meetingService.isVideoOff,
                                  isMuted: meetingService.isMuted,
                                  isSpeaking: meetingService.amISpeaking,
                                  mirror: true,
                                ),
                                ..._remoteRenderers.entries.map((entry) {
                                  final userId = entry.key;
                                  final label = meetingService
                                      .participantDisplayName(userId);
                                  final stream =
                                      meetingService.remoteStreams[userId];
                                  return _buildVideoTile(
                                    label: label,
                                    renderer: entry.value,
                                    photoUrl: meetingService
                                        .participantAvatarUrl(userId),
                                    showVideo: _remoteTileShowsVideo(
                                      entry.value,
                                      stream,
                                      isVideoOff: meetingService
                                          .isParticipantVideoOff(userId),
                                    ),
                                    isVideoOff: meetingService
                                        .isParticipantVideoOff(userId),
                                    isMuted: meetingService
                                        .isParticipantMuted(userId),
                                    isSpeaking: meetingService
                                        .isUserSpeaking(userId),
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
                          iconColor: AppColors.white,
                          onTap: () async {
                            _closing = true;
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
                              ? AppColors.white
                              : Colors.white24,
                          iconColor: meetingService.isVideoOff
                              ? AppColors.black
                              : AppColors.white,
                          onTap: () => meetingService.toggleVideo(),
                        ),
                        _buildControlBtn(
                          icon: meetingService.isMuted
                              ? CupertinoIcons.mic_off
                              : CupertinoIcons.mic,
                          color: meetingService.isMuted
                              ? AppColors.white
                              : Colors.white24,
                          iconColor: meetingService.isMuted
                              ? AppColors.black
                              : AppColors.white,
                          onTap: () => meetingService.toggleMute(),
                        ),
                        _buildControlBtn(
                          icon: Icons.chat_bubble_outline,
                          color: Colors.white24,
                          iconColor: AppColors.white,
                          badgeCount: meetingService.unreadChatCount,
                          onTap: () =>
                              _showMeetingChat(context, meetingService),
                        ),
                        if (isOrganiser)
                          _buildControlBtn(
                            icon: Icons.stop_circle_outlined,
                            color: AppColors.error,
                            iconColor: AppColors.white,
                            onTap: () => _confirmEndForAll(
                                context, meetingService),
                          )
                        else
                          _buildControlBtn(
                            icon: Icons.more_vert,
                            color: Colors.white24,
                            iconColor: AppColors.white,
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
        title: Text(context.l10n.endForEveryone,
            style: TextStyle(color: AppColors.white)),
        content: Text(
          context.l10n.doYouWantToEndThe,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel,
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.endMeetingAction,
                style: const TextStyle(color: AppColors.error)),
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
    required bool showVideo,
    required bool isMuted,
    required bool isSpeaking,
    bool isVideoOff = false,
    String? photoUrl,
    bool mirror = false,
  }) {
    final showVideoView =
        showVideo && !isVideoOff && renderer.srcObject != null;

    return SpeakingIndicatorBorder(
      isSpeaking: isSpeaking && !isMuted,
      borderRadius: AppRadius.brMd,
      child: Container(
      decoration: const BoxDecoration(
        color: _kMeetTile,
        borderRadius: AppRadius.brMd,
      ),
      child: Stack(
        children: [
          if (showVideoView)
            ClipRRect(
              borderRadius: AppRadius.brMd,
              child: RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          if (!showVideoView)
            Center(
              child: AppAvatar(
                imageUrl: photoUrl,
                name: label,
                size: 80,
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
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
                      color: AppColors.white, fontSize: 12)),
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
                color: isMuted ? AppColors.error : AppColors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLarge = false,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(isLarge ? AppSpacing.lg : AppSpacing.md),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon,
                color: iconColor, size: isLarge ? 32 : AppIconSize.md),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: CountBadge(
                count: badgeCount,
                borderColor: _kMeetBg,
              ),
            ),
        ],
      ),
    );
  }

  void _showMeetingChat(
      BuildContext context, MeetingService meetingService) {
    meetingService.markMeetingChatOpen();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kMeetSheet,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop),
      builder: (ctx) =>
          _MeetingChatSheet(meetingService: meetingService),
    ).whenComplete(meetingService.markMeetingChatClosed);
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
                      Text(
                        context.l10n.participants,
                        style: TextStyle(
                          color: AppColors.white,
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
                      ? Center(
                          child: Text(
                            context.l10n.noParticipantsConnected,
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
                            final name = p.nom ??
                                p.pseudo ??
                                context.l10n.participantFallback;
                            final isMe = p.participantID == myId;
                            final isHost =
                                meeting?.idOrganiser == p.participantID;
                            return _ParticipantRow(
                              name: isMe
                                  ? context.l10n.nameYouParen(name)
                                  : name,
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
                        style: const TextStyle(color: AppColors.white)),
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
                    color: AppColors.white, fontSize: 14)),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withAlpha(60),
                borderRadius: AppRadius.brSm,
              ),
              child: Text(
                context.l10n.hostLabel,
                style: const TextStyle(
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
              child: Text(
                context.l10n.guestLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                context.l10n.chatLabel,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: svc.chatMessages.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.noMessagesYet,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      itemCount: svc.chatMessages.length,
                      itemBuilder: (_, i) {
                        final msg = svc.chatMessages[i];
                        final isMe = msg.userId == myId.toString();
                        final senderName = isMe
                            ? context.l10n.youLabel
                            : svc.participantDisplayName(msg.userId);
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
                                      color: AppColors.white),
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
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: context.l10n.message,
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