import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/call_limits.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/services/meeting/meeting_join_affordance.dart';
import '../../core/services/meeting/meeting_participant_view.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/meeting_service.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'meeting_lobby_screen.dart';
import 'participant_picker_screen.dart';
import 'package:intl/intl.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';

class MeetingDetailScreen extends StatefulWidget {
  final int meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen>
    with RouteAware {
  Meeting? _meeting;
  bool _isLoading = true;
  int _myId = 0;
  String _myName = '';
  bool _isOrganiser = false;

  /// La liste des participants a-t-elle été rendue par le réseau ?
  ///
  /// La première passe vient du cache local, qui ne peut pas la porter :
  /// `GET /meetings` ne joint pas `participant`, donc `participantsJson` y vaut
  /// toujours `[]`. Sans ce drapeau, l'écran affichait « Aucun participant »
  /// pendant l'aller-retour, y compris pour une réunion qui en a.
  bool _participantsCharges = false;

  ModalRoute<dynamic>? _observedRoute;
  MeetingService? _meetingService;
  Timer? _phaseTicker;

  @override
  void initState() {
    super.initState();
    _load();
    // Une réunion peut se terminer pendant qu'on regarde ce même écran : le
    // service le sait avant l'API.
    _meetingService = Provider.of<MeetingService>(context, listen: false)
      ..addListener(_onMeetingServiceChanged);
    // La phase dépend de l'heure, et l'heure n'émet rien. Sans ce battement, le
    // bouton « Rejoindre » restait affiché jusqu'à la prochaine reconstruction,
    // même une fois l'échéance passée.
    _phaseTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le retour depuis la réunion passe par ici et non par un `.then` : le lobby
    // se retire par `pushReplacement`, qui complète immédiatement le futur de la
    // route remplacée. Le `.then((_) => _load())` d'avant s'exécutait donc à
    // l'entrée en réunion, jamais au retour — d'où un écran figé sur l'état
    // d'avant, bouton « Rejoindre » compris.
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _observedRoute) {
      if (_observedRoute is PageRoute) appRouteObserver.unsubscribe(this);
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _load();

  @override
  void dispose() {
    _phaseTicker?.cancel();
    _meetingService?.removeListener(_onMeetingServiceChanged);
    if (_observedRoute is PageRoute) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _onMeetingServiceChanged() {
    if (!mounted) return;
    final service = _meetingService;
    if (service == null) return;
    // La réunion en cours vient de se terminer : recharger pour que la puce et
    // le bouton disent la vérité sans attendre un aller-retour d'écran.
    if (service.status == MeetingStatus.ended && _meeting?.isEnd == false) {
      _load();
    }
  }

  Future<void> _load() async {
    final me = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final cache =
        Provider.of<LocalCacheRepository>(context, listen: false);
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final myId = me?.alanyaID ?? 0;
    final myName =
        (me?.nom.isNotEmpty == true) ? me!.nom : (me?.pseudo ?? '');
    try {
      final local = await cache.watchMeetings().first;
      final found =
          local.where((m) => m.idMeeting == widget.meetingId).firstOrNull;
      if (found != null && mounted) {
        final cachedMeeting = Meeting(
          idMeeting: found.idMeeting,
          idOrganiser: found.organiserID,
          startTime: found.startTime.toIso8601String(),
          duree: found.duree,
          objet: found.objet,
          room: found.room,
          isEnd: found.statut == 2,
          typeMedia: found.typeMedia,
          reminderSent: false,
          organiserNom: found.organiserNom,
          participants: const [],
        );
        setState(() {
          _meeting = cachedMeeting;
          _myId = myId;
          _myName = myName;
          _isOrganiser = cachedMeeting.idOrganiser == myId;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } catch (e, st) {
      AppLog.e('MeetingDetail', 'Chargement réunion (cache) échoué', e, st);
    }

    try {
      final meeting = Meeting.fromJson(
        await api.getMeeting(widget.meetingId),
      );

      if (!mounted) return;

      setState(() {
        _meeting = meeting;
        _myId = myId;
        _myName = myName;
        _isOrganiser = meeting.idOrganiser == myId;
        _isLoading = false;
        _participantsCharges = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (_meeting == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(presenterErreur(context.l10n, e,
                  domaine: ErrorDomain.reunion))),
        );
      }
    }
  }

  Future<void> _inviteMore() async {
    final meeting = _meeting;
    if (meeting == null) return;

    final existing =
        meeting.participants.map((p) => p.participantID).toSet();

    final isVideoMeeting = meeting.typeMedia == 0;
    final maxTotal = CallLimits.maxParticipantsForMeeting(meeting.typeMedia);
    final remaining = maxTotal - meeting.participants.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CallLimits.limitReachedMessage(isVideo: isVideoMeeting),
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: context.l10n.invite,
          isVideo: isVideoMeeting,
          maxSelectable: remaining,
        ),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    final newIds = result
        .where((u) => !existing.contains(u.alanyaID))
        .map((u) => u.alanyaID)
        .toList();

    if (newIds.isEmpty) return;

    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final meetingService =
          Provider.of<MeetingService>(context, listen: false);
      await api.inviteParticipants(meeting.idMeeting, newIds);
      if (meetingService.currentMeeting?.idMeeting == meeting.idMeeting) {
        await meetingService.refreshCurrentMeeting();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.participantsInvited(newIds.length)),
          backgroundColor: context.semantic.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e, st) {
      AppLog.e('MeetingDetail', 'Invitation de participants échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToInviteParticipantsTryAgain)),
      );
    }
  }

  Future<void> _cancelMeeting() async {
    final meeting = _meeting;
    if (meeting == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.brMd),
        title: Text(context.l10n.cancelMeeting),
        content: Text(
          context.l10n.thisActionCannotBeUndoneThe,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.back),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.cancelMeeting,
                style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      await api.deleteMeeting(meeting.idMeeting);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      AppLog.e('MeetingDetail', 'Suppression de la réunion échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToDeleteTheMeetingTry)),
      );
    }
  }

  void _openLobby() {
    // Pas de `.then` : le rechargement au retour est fait par `didPopNext`.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingLobbyScreen(
          meetingId: widget.meetingId,
          myId: _myId,
          myName: _myName,
          isOrganiser: _isOrganiser,
          typeMedia: _meeting?.typeMedia ?? 0,
        ),
      ),
    );
  }

  /// Où en est la réunion, maintenant. Une seule décision pour la puce d'état et
  /// pour le bouton, qui divergeaient.
  MeetingPhase? get _phase {
    final m = _meeting;
    if (m == null) return null;
    return phaseReunion(
      isEnd: m.isEnd,
      debut: m.startDateTime,
      dureeMinutes: m.duree,
      maintenant: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.l10n.meetingDetails),
        actions: [
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: Icon(Icons.person_add_outlined,
                  color: context.colors.primary),
              tooltip: context.l10n.invite,
              onPressed: _inviteMore,
            ),
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: Icon(Icons.cancel_outlined,
                  color: context.colors.error),
              tooltip: context.l10n.commonCancel,
              onPressed: _cancelMeeting,
            ),
        ],
      ),
      floatingActionButton: _phase != null && peutRejoindre(_phase!)
          ? FloatingActionButton.extended(
              heroTag: 'meeting_detail_join_fab',
              onPressed: _openLobby,
              icon: Icon(
                _meeting!.typeMedia == 0
                    ? Icons.videocam
                    : Icons.phone,
              ),
              label: Text(context.l10n.join,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      body: _isLoading
          ? const LoadingState()
          : _meeting == null
              ? EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: context.l10n.meetingNotFound,
                )
              : _MeetingDetailBody(
                  meeting: _meeting!,
                  phase: _phase!,
                  myId: _myId,
                  isOrganiser: _isOrganiser,
                  participantsCharges: _participantsCharges,
                  onInvite: _inviteMore,
                ),
    );
  }
}

// ─── Corps du détail ──────────────────────────────────────────────────────────

class _MeetingDetailBody extends StatelessWidget {
  const _MeetingDetailBody({
    required this.meeting,
    required this.phase,
    required this.myId,
    required this.isOrganiser,
    required this.participantsCharges,
    required this.onInvite,
  });

  final Meeting meeting;

  /// Calculée par l'écran, pas ici : la puce d'état et le bouton flottant
  /// doivent dire la même chose. `onJoin` et `onCancel` étaient déclarés et
  /// jamais appelés — un futur bouton les aurait utilisés en contournant
  /// l'affordance.
  final MeetingPhase phase;
  final int myId;
  final bool isOrganiser;

  /// Faux tant que la passe réseau n'a pas répondu — voir le champ homonyme
  /// de l'état.
  final bool participantsCharges;
  final VoidCallback onInvite;

  String _formatDuration(BuildContext context, int minutes) {
    final l10n = context.l10n;
    if (minutes < 60) return l10n.minutesShort(minutes);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? l10n.hoursShort(h) : l10n.hoursAndMinutesShort(h, m);
  }

  String _formatDateTime() {
    final d = meeting.startDateTime;
    final e = meeting.endDateTime;
    final locale = LocaleController.instance.resolvedLocale.toLanguageTag();
    final month = DateFormat.MMM(locale).format(d);
    final date = '${d.day} $month ${d.year}';
    String hm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date · ${hm(d)} — ${hm(e)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 100),
      children: [
        AppSpacing.vGapSm,
        Row(
          children: [
            Expanded(
              child: Text(
                meeting.objet,
                style: context.text.headlineSmall,
              ),
            ),
            AppSpacing.hGapMd,
            _statusChip(context, phase),
          ],
        ),
        AppSpacing.vGapSm,
        Row(
          children: [
            Icon(
              meeting.typeMedia == 0
                  ? Icons.videocam_outlined
                  : Icons.phone_outlined,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
            AppSpacing.hGapSm,
            Text(
              meeting.typeMedia == 0 ? context.l10n.videoMeeting : context.l10n.audioCall,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        AppSpacing.vGapXxl,
        const Divider(),
        AppSpacing.vGapLg,

        _InfoRow(icon: Icons.access_time, text: _formatDateTime()),
        AppSpacing.vGapMd,
        _InfoRow(
            icon: Icons.timelapse,
            text: context.l10n.durationLabel(_formatDuration(context, meeting.duree))),
        AppSpacing.vGapMd,
        _InfoRow(
          icon: Icons.person_outline,
          text:
              context.l10n.organizedBy(meeting.organiserNom ?? meeting.organiserPseudo ?? context.l10n.unknownSender),
        ),
        AppSpacing.vGapXxl,
        const Divider(),
        AppSpacing.vGapLg,

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.participantsRatio(meeting.participants.length, CallLimits.maxParticipantsForMeeting(meeting.typeMedia)),
              style: context.text.titleSmall,
            ),
            if (isOrganiser &&
                !meeting.isEnd &&
                meeting.participants.length <
                    CallLimits.maxParticipantsForMeeting(meeting.typeMedia))
              GestureDetector(
                onTap: onInvite,
                child: Row(
                  children: [
                    Icon(Icons.add,
                        size: AppIconSize.sm,
                        color: context.colors.primary),
                    AppSpacing.hGapXs,
                    Text(
                      context.l10n.invite,
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        AppSpacing.vGapMd,
        if (!participantsCharges)
          // Ni la liste, ni « aucun participant » : on ne sait pas encore. Le
          // cache ne porte pas les participants, et affirmer le vide était faux
          // une fois sur deux.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (meeting.participants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                context.l10n.noParticipantsYet,
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...meeting.participants.map((p) => _ParticipantTile(
                participant: p,
                isMe: p.participantID == myId,
                isHost: p.participantID == meeting.idOrganiser,
              )),

        AppSpacing.vGapXxl,
      ],
    );
  }

  Widget _statusChip(BuildContext context, MeetingPhase phase) {
    switch (phase) {
      case MeetingPhase.enCours:
        return StatusChip(
            label: context.l10n.inProgress, tone: StatusChipTone.success);
      case MeetingPhase.bientot:
        return StatusChip(
            label: context.l10n.comingSoon, tone: StatusChipTone.warning);
      case MeetingPhase.programmee:
        return StatusChip(
            label: context.l10n.scheduled, tone: StatusChipTone.brand);
      case MeetingPhase.echue:
        // Distincte de « Terminé » : personne n'a mis fin à cette réunion, son
        // heure est simplement passée. L'ancienne puce confondait les deux.
        return StatusChip(
            label: context.l10n.meetingExpired, tone: StatusChipTone.neutral);
      case MeetingPhase.terminee:
        return StatusChip(
            label: context.l10n.ended, tone: StatusChipTone.neutral);
    }
  }
}

// ─── Ligne d'info ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm, color: context.colors.primary),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(text, style: context.text.bodyMedium),
        ),
      ],
    );
  }
}

// ─── Tuile participant ─────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile(
      {required this.participant, required this.isMe, required this.isHost});

  final MeetingParticipant participant;
  final bool isMe;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final name =
        participant.displayNom ?? context.l10n.participantFallback;
    final aRejoint = badgeParticipant(
          status: participant.status,
          estOrganisateur: isHost,
        ) ==
        MeetingParticipantBadge.aRejoint;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Stack(
            children: [
              AppAvatar(
                imageUrl: participant.avatarUrl,
                name: name,
                size: AppSizes.avatarSm,
              ),
              if (participant.connecte)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.semantic.online,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.colors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? context.l10n.nameYouParen(name) : name,
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (participant.pseudo != null &&
                    participant.pseudo!.isNotEmpty)
                  Text(
                    '@${participant.pseudo}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: aRejoint
                  ? context.semantic.successContainer
                  : context.semantic.warningContainer,
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              aRejoint
                  ? context.l10n.meetingParticipantJoined
                  : context.l10n.meetingParticipantPending,
              style: TextStyle(
                color: aRejoint
                    ? context.semantic.success
                    : context.semantic.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
