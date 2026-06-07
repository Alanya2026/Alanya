import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../core/services/local_cache_repository.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'meeting_lobby_screen.dart';
import 'participant_picker_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final int meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  Meeting? _meeting;
  bool _isLoading = true;
  int _myId = 0;
  String _myName = '';
  bool _isOrganiser = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      final results = await Future.wait([
        api.getMeeting(widget.meetingId),
        api.getMe(),
      ]);

      if (!mounted) return;
      final meeting = Meeting.fromJson(results[0]);
      final freshMe = results[1];
      final freshId = (freshMe['alanyaID'] as num?)?.toInt() ?? myId;
      final freshName = freshMe['nom'] as String? ??
          freshMe['pseudo'] as String? ??
          myName;

      setState(() {
        _meeting = meeting;
        _myId = freshId;
        _myName = freshName;
        _isOrganiser = meeting.idOrganiser == freshId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_meeting == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible de charger la réunion : $e')),
        );
      }
    }
  }

  Future<void> _inviteMore() async {
    final meeting = _meeting;
    if (meeting == null) return;

    final existing =
        meeting.participants.map((p) => p.participantID).toSet();

    final result = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: 'Inviter',
          maxSelectable:
              9 - meeting.participants.length.clamp(0, 9),
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
      await api.inviteParticipants(meeting.idMeeting, newIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newIds.length} participant(s) invité(s)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e, st) {
      AppLog.e('MeetingDetail', 'Invitation de participants échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'inviter les participants, réessayez')),
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
        title: const Text('Annuler la réunion'),
        content: const Text(
          'Cette action est irréversible. La réunion sera supprimée pour tous les participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Annuler la réunion',
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
        const SnackBar(content: Text('Impossible de supprimer la réunion, réessayez')),
      );
    }
  }

  void _openLobby() {
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
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Détail de la réunion'),
        actions: [
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: Icon(Icons.person_add_outlined,
                  color: context.colors.primary),
              tooltip: 'Inviter',
              onPressed: _inviteMore,
            ),
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: Icon(Icons.cancel_outlined,
                  color: context.colors.error),
              tooltip: 'Annuler',
              onPressed: _cancelMeeting,
            ),
        ],
      ),
      floatingActionButton: _meeting != null &&
              !_meeting!.isEnd &&
              _meeting!.endDateTime.isAfter(DateTime.now())
          ? FloatingActionButton.extended(
              heroTag: 'meeting_detail_join_fab',
              onPressed: _openLobby,
              icon: Icon(
                _meeting!.typeMedia == 0
                    ? Icons.videocam
                    : Icons.phone,
              ),
              label: const Text('Rejoindre',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      body: _isLoading
          ? const LoadingState()
          : _meeting == null
              ? const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Réunion introuvable',
                )
              : _MeetingDetailBody(
                  meeting: _meeting!,
                  myId: _myId,
                  isOrganiser: _isOrganiser,
                  onJoin: _openLobby,
                  onInvite: _inviteMore,
                  onCancel: _cancelMeeting,
                ),
    );
  }
}

// ─── Corps du détail ──────────────────────────────────────────────────────────

class _MeetingDetailBody extends StatelessWidget {
  const _MeetingDetailBody({
    required this.meeting,
    required this.myId,
    required this.isOrganiser,
    required this.onJoin,
    required this.onInvite,
    required this.onCancel,
  });

  final Meeting meeting;
  final int myId;
  final bool isOrganiser;
  final VoidCallback onJoin;
  final VoidCallback onInvite;
  final VoidCallback onCancel;

  _MeetingStatus _computeStatus() {
    if (meeting.isEnd) return _MeetingStatus.ended;
    final now = DateTime.now();
    if (meeting.startDateTime.isBefore(now) &&
        meeting.endDateTime.isAfter(now)) {
      return _MeetingStatus.inProgress;
    }
    final diff = meeting.startDateTime.difference(now);
    if (!diff.isNegative && diff.inMinutes <= 15) {
      return _MeetingStatus.soon;
    }
    if (diff.isNegative) return _MeetingStatus.ended;
    return _MeetingStatus.scheduled;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m}min';
  }

  String _formatDateTime() {
    final d = meeting.startDateTime;
    final e = meeting.endDateTime;
    const months = [
      '',
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'jun',
      'jul',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    final date = '${d.day} ${months[d.month]} ${d.year}';
    String hm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date · ${hm(d)} — ${hm(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _computeStatus();

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
            _statusChip(status),
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
              meeting.typeMedia == 0 ? 'Réunion vidéo' : 'Appel audio',
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
            text: 'Durée : ${_formatDuration(meeting.duree)}'),
        AppSpacing.vGapMd,
        _InfoRow(
          icon: Icons.person_outline,
          text:
              'Organisé par ${meeting.organiserNom ?? meeting.organiserPseudo ?? 'Inconnu'}',
        ),
        AppSpacing.vGapXxl,
        const Divider(),
        AppSpacing.vGapLg,

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Participants (${meeting.participants.length}/10)',
              style: context.text.titleSmall,
            ),
            if (isOrganiser && !meeting.isEnd)
              GestureDetector(
                onTap: onInvite,
                child: Row(
                  children: [
                    Icon(Icons.add,
                        size: AppIconSize.sm,
                        color: context.colors.primary),
                    AppSpacing.hGapXs,
                    Text(
                      'Inviter',
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
        if (meeting.participants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                'Aucun participant pour le moment',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...meeting.participants.map((p) => _ParticipantTile(
                participant: p,
                isMe: p.participantID == myId,
              )),

        AppSpacing.vGapXxl,
      ],
    );
  }

  Widget _statusChip(_MeetingStatus status) {
    switch (status) {
      case _MeetingStatus.inProgress:
        return const StatusChip(
            label: 'En cours', tone: StatusChipTone.success);
      case _MeetingStatus.soon:
        return const StatusChip(
            label: 'Bientôt', tone: StatusChipTone.warning);
      case _MeetingStatus.scheduled:
        return const StatusChip(
            label: 'Planifiée', tone: StatusChipTone.brand);
      case _MeetingStatus.ended:
        return const StatusChip(
            label: 'Terminée', tone: StatusChipTone.neutral);
    }
  }
}

enum _MeetingStatus { scheduled, soon, inProgress, ended }

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
      {required this.participant, required this.isMe});

  final MeetingParticipant participant;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name =
        participant.nom ?? participant.pseudo ?? 'Participant';
    final accepted = participant.status == 1;

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
                      color: AppColors.online,
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
                  isMe ? '$name (vous)' : name,
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
              color: accepted
                  ? AppColors.successContainer
                  : AppColors.warningContainer,
              borderRadius: AppRadius.brSm,
            ),
            child: Text(
              accepted ? 'Accepté' : 'En attente',
              style: TextStyle(
                color: accepted ? AppColors.success : AppColors.warning,
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
