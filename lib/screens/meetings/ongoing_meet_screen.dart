import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/call/session_video_renderers.dart';
import '../../core/services/meeting/meeting_exit_rules.dart';
import '../../core/services/meeting/meeting_focus_rules.dart';
import '../../core/services/meeting/meeting_join_affordance.dart';
import '../../core/services/meeting_service.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/calls/call_participant_focus_overlay.dart';
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
  /// Les rendus appartiennent à la **session**, pas à l'écran — même bascule
  /// que pour l'écran d'appel, et pour la même raison : la fenêtre flottante
  /// doit continuer à montrer la réunion une fois cet écran quitté. Voir
  /// [SessionVideoRenderers], qui porte aussi l'alignement des tuiles distantes
  /// et les notifications de première trame.
  SessionVideoRenderers get _renderers => SessionVideoRenderers.instance;
  RTCVideoRenderer? get _localRenderer => _renderers.local;
  Map<String, RTCVideoRenderer> get _remoteRenderers => _renderers.group;

  /// Résolu dans initState : `Provider.of` lève dans `dispose()`, l'élément
  /// étant déjà démonté (Element.unmount vide `_widget` avant `state.dispose`).
  /// Le nettoyage qui suivait était donc silencieusement sauté.
  late final MeetingService _meetingService;
  bool get _localRendererReady => _renderers.isReady;
  bool _closing = false;
  final Set<String> _watchedVideoTrackIds = {};

  /// Participant mis en avant par un tap sur sa tuile, ou null.
  String? _focusedParticipantId;

  @override
  void initState() {
    super.initState();
    _meetingService = Provider.of<MeetingService>(context, listen: false);
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

  /// Ferme l'écran — **une seule fois**, quel que soit celui qui arrive le
  /// premier.
  ///
  /// C'est le seul détenteur de `_closing`, et le seul chemin de fermeture avec
  /// `_minimize` (qui, lui, ne termine rien). Le listener et les deux boutons de
  /// sortie l'appellent sans se coordonner : le premier ferme, les suivants
  /// n'ont plus rien à faire. Avant ça, chacun popait de son côté et le second
  /// pop retirait la route du dessous — voir [shouldPopMeetingScreen].
  ///
  /// Le retrait du listener est fait ici et pas ailleurs : la notification
  /// suivante (`idle`, une fois F1 livré) ne doit pas rouvrir la question.
  void _closeOnce() {
    if (_closing || !mounted) return;
    _closing = true;
    _meetingService.removeListener(_onMeetingServiceChanged);
    Navigator.of(context).pop();
  }

  void _focusParticipant(String userId) {
    if (_closing || !mounted) return;
    setState(() => _focusedParticipantId = userId);
  }

  void _dismissFocus() {
    if (!mounted) return;
    setState(() => _focusedParticipantId = null);
  }

  void _onFullscreenPop(bool didPop) {
    if (!didPop || _closing || !mounted) return;
    Provider.of<MeetingService>(context, listen: false)
        .markMeetingUiMinimized();
  }

  Future<void> _setupRenderer() async {
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);
    // Idempotent : la session les a normalement déjà ouverts.
    await _renderers.ensureInitialized();
    if (!mounted) return;

    _renderers.syncMain(localStream: meetingService.localStream);
    _watchVideoTracks(meetingService.localStream);

    await _syncRemoteRenderers(meetingService.remoteStreams);
    if (!mounted) return;

    meetingService.addListener(_onMeetingServiceChanged);
    // L'inscription arrive après plusieurs `await` : une réunion terminée
    // pendant l'ouverture des rendus a déjà notifié, dans le vide. Sans cette
    // relecture, l'écran restait ouvert sur une réunion morte, et plus rien ne
    // viendrait le fermer.
    if (shouldPopMeetingScreen(
      alreadyClosing: _closing,
      meetingStatusName: meetingService.status.name,
    )) {
      _closeOnce();
      return;
    }
    // Première trame, changement de taille, arrivée d'une tuile : le porteur
    // notifie, l'écran se redessine.
    _renderers.addListener(_onRenderersChanged);
    setState(() {});
  }

  void _onRenderersChanged() {
    if (_closing || !mounted) return;
    setState(() {});
  }

  void _onMeetingServiceChanged() {
    if (!mounted) return;
    final meetingService =
        Provider.of<MeetingService>(context, listen: false);

    if (shouldPopMeetingScreen(
      alreadyClosing: _closing,
      meetingStatusName: meetingService.status.name,
    )) {
      _closeOnce();
      return;
    }

    // Le participant mis en avant peut partir pendant qu'on le regarde.
    final focusRetenu = focusEncoreValide(
      focusedId: _focusedParticipantId,
      localId: meetingService.myId,
      fluxDistants: meetingService.remoteStreams.keys.toSet(),
    );
    if (focusRetenu != _focusedParticipantId) {
      _focusedParticipantId = focusRetenu;
    }

    if (_localRendererReady &&
        _localRenderer?.srcObject != meetingService.localStream) {
      _renderers.syncMain(localStream: meetingService.localStream);
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
    return _localRenderer?.srcObject != null;
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

  /// Aligne les tuiles distantes sur les flux présents.
  ///
  /// La création, la libération et le rebranchement vivent désormais dans
  /// [SessionVideoRenderers] : le comptage des clés y est une fonction pure
  /// testée, et la course « quitter l'écran pendant qu'un participant arrive »
  /// disparaît d'elle-même — les rendus ne sont plus liés au montage de cet
  /// écran. Il ne reste ici que la surveillance des pistes, qui est de
  /// l'affichage.
  Future<void> _syncRemoteRenderers(
      Map<String, dynamic> remoteStreams) async {
    final streams = <String, MediaStream>{};
    remoteStreams.forEach((key, value) {
      if (value is MediaStream) streams[key] = value;
    });

    await _renderers.syncGroup(streams);
    if (!mounted) return;

    for (final stream in streams.values) {
      _watchVideoTracks(stream);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _meetingService.removeListener(_onMeetingServiceChanged);
    _renderers.removeListener(_onRenderersChanged);
    // Aucune libération ici : les rendus appartiennent à la session, qui
    // continue sans cet écran quand la réunion est minimisée.
    super.dispose();
  }

  void _showParticipantsPanel(MeetingService meetingService) {
    showModalBottomSheet(
      context: context,
      // Sans `isScrollControlled`, la feuille est plafonnée à 9/16 de l'écran :
      // le `maxChildSize: 0.85` du DraggableScrollableSheet qu'elle contient ne
      // voulait rien dire, et le geste de glissement vers le haut ne faisait
      // rien.
      isScrollControlled: true,
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
        // Pendant la création, la réunion n'est pas encore revenue du serveur —
        // mais on sait déjà que c'est la nôtre. Sans ça, le bouton « terminer
        // pour tous » apparaissait après coup, à la place d'un autre.
        final isOrganiser = meetingService.idOrganiseurEnCours == myId;

        final localId = meetingService.myId ?? myId.toString();
        final focusedId = _focusedParticipantId;
        final focusOverlay = _buildFocusOverlay(
          meetingService,
          localId: localId,
          myAvatar: myAvatar,
          youLabel: context.l10n.youLabel,
        );

        return PopScope(
          // Le retour arrière referme d'abord la mise en avant. `_closeOnce`
          // pope impérativement et n'est pas filtré par `canPop`, qui ne
          // s'applique qu'aux gestes système.
          canPop: focusedId == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop &&
                actionRetour(focusOuvert: _focusedParticipantId != null) ==
                    MeetingBackAction.fermerFocus) {
              _dismissFocus();
              return;
            }
            _onFullscreenPop(didPop);
          },
          child: Scaffold(
            backgroundColor: _kMeetBg,
            body: Stack(
              children: [
                SafeArea(
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
                                  // L'écran s'ouvre désormais dès le clic, la
                                  // salle n'est rejointe qu'ensuite : un
                                  // chronomètre figé à 00:00 laisserait croire
                                  // à un écran mort.
                                  meetingService.isJoining
                                      ? context.l10n.connecting2
                                      : meetingService.formattedDuration,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 13),
                                ),
                                AppSpacing.hGapXs,
                                // Réunion audio : pas de caméra à changer. Le
                                // bouton restait affiché et inerte — le lobby,
                                // lui, testait déjà `typeMedia`.
                                if (afficheCommandesCamera(
                                    meetingService.typeMediaEnCours))
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
                                  onTap: () => _focusParticipant(localId),
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
                                      onTap: () => _focusParticipant(localId),
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
                                        onTap: () => _focusParticipant(userId),
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
                                // Pas de `_closing` posé ici : `_terminateMeeting`
                                // notifie dans un `finally`, donc le listener ferme
                                // pendant l'attente. Cet appel n'est que le filet
                                // du cas où il ne l'aurait pas fait.
                                await meetingService.leaveMeeting();
                                if (mounted) _closeOnce();
                              },
                              isLarge: true,
                            ),
                            // Même raison qu'en haut de l'écran : sans piste
                            // vidéo, `toggleVideo` sort sans rien faire.
                            if (afficheCommandesCamera(
                                meetingService.typeMediaEnCours))
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
                // ── Mise en avant d'un participant ────────────────
                // Par-dessus la grille. L'overlay réserve lui-même la place de
                // la barre de contrôles, qui reste utilisable.
                if (focusOverlay != null) focusOverlay,
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construit l'overlay de mise en avant, ou null si aucune tuile n'est visée.
  ///
  /// La polarité de la caméra s'inverse ici : le service dit `isVideoOff`,
  /// l'overlay attend `isVideoOn`. C'est le genre d'inversion qui passe la
  /// relecture et ne se voit qu'à l'usage.
  Widget? _buildFocusOverlay(
    MeetingService meetingService, {
    required String localId,
    required String? myAvatar,
    required String youLabel,
  }) {
    final focusedId = _focusedParticipantId;
    if (focusedId == null) return null;
    final isLocal = focusedId == localId;
    return CallParticipantFocusOverlay(
      userId: focusedId,
      name: isLocal
          ? youLabel
          : meetingService.participantDisplayName(focusedId),
      stream: isLocal
          ? meetingService.localStream
          : meetingService.remoteStreams[focusedId],
      photoUrl:
          isLocal ? myAvatar : meetingService.participantAvatarUrl(focusedId),
      isMuted: isLocal
          ? meetingService.isMuted
          : meetingService.isParticipantMuted(focusedId),
      isVideoOn: isLocal
          ? !meetingService.isVideoOff
          : !meetingService.isParticipantVideoOff(focusedId),
      isSpeaking: isLocal
          ? meetingService.amISpeaking
          : meetingService.isUserSpeaking(focusedId),
      mirror: isLocal,
      onDismiss: _dismissFocus,
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
    if (confirm == true && mounted) {
      await meetingService.endMeetingForAll();
      if (mounted) _closeOnce();
    }
  }

  Widget _buildVideoTile({
    required String label,
    // Nullable depuis que les rendus appartiennent à la session : la tuile peut
    // être construite avant leur ouverture. Elle retombe alors sur l'avatar,
    // ce qu'elle sait déjà faire pour une caméra coupée.
    required RTCVideoRenderer? renderer,
    required bool showVideo,
    required bool isMuted,
    required bool isSpeaking,
    bool isVideoOff = false,
    String? photoUrl,
    bool mirror = false,
    VoidCallback? onTap,
  }) {
    final showVideoView =
        showVideo && !isVideoOff && renderer != null && renderer.srcObject != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SpeakingIndicatorBorder(
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
      // Sans `isScrollControlled`, la feuille garde une hauteur fixe de 9/16 :
      // le rembourrage `viewInsets` du champ de saisie poussait celui-ci hors
      // du cadre par le haut au lieu de faire monter la feuille, et le clavier
      // le recouvrait.
      isScrollControlled: true,
      useSafeArea: true,
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
    // Une seule source de vérité : la salle. `remoteStreams` disait « absent »
    // d'un arrivant dont le flux n'était pas encore négocié, et `p.connecte`
    // venait du dernier `getMeeting`, rechargé seulement à l'invitation.
    final connectedIds = meetingService.presentIds;
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
                          // Présents sur invités : le compteur n'affichait que
                          // le second, ce qui ne disait rien de la salle.
                          '${participants.where((p) => connectedIds.contains(p.participantID.toString())).length}'
                          '/${participants.length}',
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
                            final isConnected = connectedIds
                                .contains(p.participantID.toString());
                            final name = p.displayNom ??
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
        // La feuille est désormais libre de grandir (`isScrollControlled`) :
        // elle prendrait tout l'écran sans ce plafond, et le rembourrage du bas
        // suit maintenant le clavier au niveau de la feuille entière plutôt que
        // du seul champ de saisie.
        builder: (context, svc, _) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
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
              // Le décalage clavier est porté par la feuille entière, plus par
              // ce seul rembourrage : à hauteur fixe, il poussait le champ hors
              // du cadre au lieu de le remonter.
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
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
        ),
      ),
    );
  }
}