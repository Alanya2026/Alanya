import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
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
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final results = await Future.wait([
        api.getMeeting(widget.meetingId),
        api.getMe(),
      ]);

      if (!mounted) return;
      final meeting = Meeting.fromJson(results[0]);
      final me = results[1];
      final myId = (me['alanyaID'] as num?)?.toInt() ?? 0;
      final myName = me['nom'] as String? ?? me['pseudo'] as String? ?? '';

      setState(() {
        _meeting = meeting;
        _myId = myId;
        _myName = myName;
        _isOrganiser = meeting.idOrganiser == myId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la réunion : $e')),
      );
    }
  }

  Future<void> _inviteMore() async {
    final meeting = _meeting;
    if (meeting == null) return;

    final existing = meeting.participants
        .map((p) => p.participantID)
        .toSet();

    final result = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: 'Inviter',
          maxSelectable: 9 - meeting.participants.length.clamp(0, 9),
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
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _cancelMeeting() async {
    final meeting = _meeting;
    if (meeting == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Annuler la réunion', style: TextStyle(color: Colors.red)),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Détail de la réunion',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: Colors.indigo),
              tooltip: 'Inviter',
              onPressed: _inviteMore,
            ),
          if (_isOrganiser && _meeting != null && !_meeting!.isEnd)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: 'Annuler',
              onPressed: _cancelMeeting,
            ),
        ],
      ),
      floatingActionButton: _meeting != null && !_meeting!.isEnd
          ? FloatingActionButton.extended(
              onPressed: _openLobby,
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: Icon(
                _meeting!.typeMedia == 0 ? Icons.videocam : Icons.phone,
              ),
              label: const Text('Rejoindre',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : _meeting == null
              ? const Center(child: Text('Réunion introuvable'))
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
    if (meeting.startDateTime.isBefore(now) && meeting.endDateTime.isAfter(now)) {
      return _MeetingStatus.inProgress;
    }
    final diff = meeting.startDateTime.difference(now);
    if (!diff.isNegative && diff.inMinutes <= 15) return _MeetingStatus.soon;
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
    const months = [
      '', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc',
    ];
    final date = '${d.day} ${months[d.month]} ${d.year}';
    final time =
        '${d.hour}:${d.minute.toString().padLeft(2, '0')} — ${meeting.endDateTime.hour}:${meeting.endDateTime.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final status = _computeStatus();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // ── Header ───────────────────────────────────────────────────
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                meeting.objet,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              meeting.typeMedia == 0 ? Icons.videocam_outlined : Icons.phone_outlined,
              size: 16,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              meeting.typeMedia == 0 ? 'Réunion vidéo' : 'Appel audio',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // ── Infos date/heure ─────────────────────────────────────────
        _InfoRow(icon: Icons.access_time, text: _formatDateTime()),
        const SizedBox(height: 12),
        _InfoRow(icon: Icons.timelapse, text: 'Durée : ${_formatDuration(meeting.duree)}'),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.person_outline,
          text: 'Organisé par ${meeting.organiserNom ?? meeting.organiserPseudo ?? 'Inconnu'}',
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // ── Participants ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Participants (${meeting.participants.length}/10)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (isOrganiser && !meeting.isEnd)
              GestureDetector(
                onTap: onInvite,
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.indigo),
                    SizedBox(width: 4),
                    Text('Inviter', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (meeting.participants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Aucun participant pour le moment',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ...meeting.participants.map((p) => _ParticipantTile(
                participant: p,
                isMe: p.participantID == myId,
              )),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Badge de statut ──────────────────────────────────────────────────────────

enum _MeetingStatus { scheduled, soon, inProgress, ended }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _MeetingStatus status;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color bg;
    late Color fg;

    switch (status) {
      case _MeetingStatus.inProgress:
        label = 'En cours';
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
      case _MeetingStatus.soon:
        label = 'Bientôt';
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
      case _MeetingStatus.scheduled:
        label = 'Planifiée';
        bg = Colors.indigo.shade50;
        fg = Colors.indigo;
      case _MeetingStatus.ended:
        label = 'Terminée';
        bg = Colors.grey.shade100;
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == _MeetingStatus.inProgress)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
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
        Icon(icon, size: 18, color: Colors.indigo.shade300),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
        ),
      ],
    );
  }
}

// ─── Tuile participant ─────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.isMe});

  final MeetingParticipant participant;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = participant.nom ?? participant.pseudo ?? 'Participant';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final accepted = participant.status == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.indigo.shade50,
                backgroundImage: participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty
                    ? NetworkImage(participant.avatarUrl!)
                    : null,
                child: participant.avatarUrl == null || participant.avatarUrl!.isEmpty
                    ? Text(initial,
                        style: const TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.bold))
                    : null,
              ),
              if (participant.connecte)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (vous)' : name,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                if (participant.pseudo != null && participant.pseudo!.isNotEmpty)
                  Text(
                    '@${participant.pseudo}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
              ],
            ),
          ),
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accepted ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              accepted ? 'Accepté' : 'En attente',
              style: TextStyle(
                color: accepted ? Colors.green.shade700 : Colors.orange.shade700,
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

