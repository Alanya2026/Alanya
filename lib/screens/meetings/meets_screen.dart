import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/meeting_service.dart';
import 'join_meet_screen.dart';
import 'meeting_detail_screen.dart';
import 'ongoing_meet_screen.dart';
import 'participant_picker_screen.dart';
import '../shared/schedule_screen.dart';

class MeetsScreen extends StatefulWidget {
  const MeetsScreen({super.key});

  @override
  State<MeetsScreen> createState() => _MeetsScreenState();
}

class _MeetsScreenState extends State<MeetsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String _userInitial = 'U';
  int _myId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadMeetings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final userData = await apiClient.getMe();
      if (!mounted) return;
      final nom = userData['nom'] as String? ?? '';
      final pseudo = userData['pseudo'] as String? ?? '';
      final name = nom.isNotEmpty ? nom : pseudo;
      setState(() {
        _myId = (userData['alanyaID'] as num?)?.toInt() ?? 0;
        _userInitial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
      });
    } catch (_) {}
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    try {
      final meetingService = Provider.of<MeetingService>(context, listen: false);
      final data = await meetingService.getMeetings();
      setState(() {
        _meetings = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Meeting> get _todayMeetings {
    final now = DateTime.now();
    return _meetings.where((m) {
      return m.isToday && !m.isEnd && m.endDateTime.isAfter(now);
    }).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }

  List<Meeting> get _upcomingMeetings {
    final now = DateTime.now();
    return _meetings.where((m) {
      return !m.isToday && m.startDateTime.isAfter(now) && !m.isEnd;
    }).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }

  List<Meeting> get _pastMeetings {
    final now = DateTime.now();
    return _meetings.where((m) {
      return m.isEnd || m.endDateTime.isBefore(now);
    }).toList()
      ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
  }

  Future<void> _createNewMeeting() async {
    if (_myId == 0) await _loadCurrentUser();
    if (!mounted) return;

    // Sélection des participants avant de démarrer
    final participants = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ParticipantPickerScreen(confirmLabel: 'Démarrer'),
      ),
    );
    // null = l'utilisateur a annulé
    if (participants == null || !mounted) return;

    final meetingService = Provider.of<MeetingService>(context, listen: false);
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final now = DateTime.now();

    try {
      await meetingService.createAndJoin(
        objet: 'Réunion ${now.toString().substring(0, 16)}',
        startTime: now.toIso8601String(),
        room: 'mtg-${now.millisecondsSinceEpoch}',
        myId: _myId,
      );

      // Inviter les participants sélectionnés
      final meetingId = meetingService.currentMeeting?.idMeeting;
      if (participants.isNotEmpty && meetingId != null) {
        final ids = participants.map((u) => u.alanyaID).toList();
        await apiClient.inviteParticipants(meetingId, ids);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OngoingMeetScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de créer la réunion : $e')),
      );
    }
  }

  Future<void> _openSchedule() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
    );
    if (created == true) _loadMeetings();
  }

  void _openDetail(Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(meetingId: meeting.idMeeting),
      ),
    ).then((_) => _loadMeetings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Réunions',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.black),
            tooltip: 'Planifier',
            onPressed: _openSchedule,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _openSchedule,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                _userInitial,
                style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: "Aujourd'hui"),
            Tab(text: 'À venir'),
            Tab(text: 'Passés'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Boutons d'action rapide
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Nouvelle réunion',
                    icon: CupertinoIcons.video_camera_solid,
                    color: Colors.indigo,
                    onTap: _createNewMeeting,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActionCard(
                    title: 'Rejoindre',
                    icon: CupertinoIcons.keyboard,
                    color: Colors.black87,
                    isOutline: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinMeetScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Onglets
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MeetingList(
                        meetings: _todayMeetings,
                        emptyMessage: "Aucune réunion aujourd'hui",
                        emptyIcon: CupertinoIcons.calendar_badge_plus,
                        onRefresh: _loadMeetings,
                        showScheduleButton: true,
                        onSchedule: _openSchedule,
                        onOpenDetail: _openDetail,
                      ),
                      _MeetingList(
                        meetings: _upcomingMeetings,
                        emptyMessage: 'Aucune réunion à venir',
                        emptyIcon: CupertinoIcons.calendar,
                        onRefresh: _loadMeetings,
                        showScheduleButton: true,
                        onSchedule: _openSchedule,
                        onOpenDetail: _openDetail,
                      ),
                      _MeetingList(
                        meetings: _pastMeetings,
                        emptyMessage: 'Aucune réunion passée',
                        emptyIcon: CupertinoIcons.clock,
                        onRefresh: _loadMeetings,
                        showScheduleButton: false,
                        onSchedule: null,
                        onOpenDetail: _openDetail,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSchedule,
        backgroundColor: Colors.indigo,
        elevation: 4,
        tooltip: 'Planifier une réunion',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── Liste de meetings avec pull-to-refresh ───────────────────────────────────

class _MeetingList extends StatelessWidget {
  const _MeetingList({
    required this.meetings,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
    required this.showScheduleButton,
    required this.onSchedule,
    required this.onOpenDetail,
  });

  final List<Meeting> meetings;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final bool showScheduleButton;
  final VoidCallback? onSchedule;
  final void Function(Meeting) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: Colors.indigo,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 14),
                  Text(
                    emptyMessage,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                  if (showScheduleButton && onSchedule != null) ...[
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: onSchedule,
                      icon: const Icon(Icons.add, color: Colors.indigo),
                      label: const Text(
                        'Planifier une réunion',
                        style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.indigo,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: meetings.length,
        itemBuilder: (context, index) => _MeetingCard(
          meeting: meetings[index],
          onTap: () => onOpenDetail(meetings[index]),
        ),
      ),
    );
  }
}

// ─── Carte individuelle d'un meeting ─────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});

  final Meeting meeting;
  final VoidCallback onTap;

  String _formatDateTime(Meeting m) {
    final now = DateTime.now();
    final d = m.startDateTime;
    final e = m.endDateTime;
    String hm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final timeStr = '${hm(d)} — ${hm(e)}';
    if (m.isToday) return "Aujourd'hui · $timeStr";
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'Demain · $timeStr';
    }
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${d.day} ${months[d.month]} · $timeStr';
  }

  bool _isInProgress(Meeting m) {
    final now = DateTime.now();
    return m.startDateTime.isBefore(now) && m.endDateTime.isAfter(now) && !m.isEnd;
  }

  int? _minutesUntilStart(Meeting m) {
    final diff = m.startDateTime.difference(DateTime.now());
    if (!diff.isNegative && diff.inMinutes <= 15 && !m.isEnd) return diff.inMinutes;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[meeting.idMeeting % Colors.primaries.length];
    final inProgress = _isInProgress(meeting);
    final minsUntil = _minutesUntilStart(meeting);
    final organiser = meeting.organiserNom ?? meeting.organiserPseudo ?? 'Organisateur';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: inProgress ? Colors.indigo.shade200 : Colors.grey.shade200,
            width: inProgress ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: inProgress ? Colors.indigo.withAlpha(20) : Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: inProgress ? Colors.indigo : color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.objet,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (inProgress)
                          _StatusChip(label: 'En cours', color: Colors.green)
                        else if (minsUntil != null)
                          _StatusChip(
                            label: minsUntil == 0 ? 'Maintenant' : 'Dans ${minsUntil}min',
                            color: Colors.orange,
                          ),
                        if (meeting.typeMedia == 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(CupertinoIcons.phone_fill, size: 14, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(_formatDateTime(meeting), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            organiser,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (meeting.participants.isNotEmpty)
                          Text(
                            '· ${meeting.participants.length} participant${meeting.participants.length > 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Carte d'action rapide ────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isOutline = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOutline ? Colors.white : color,
          borderRadius: BorderRadius.circular(20),
          border: isOutline ? Border.all(color: Colors.grey.shade300, width: 1.5) : null,
          boxShadow: isOutline
              ? []
              : [
                  BoxShadow(
                    color: color.withAlpha(77),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isOutline ? Colors.grey.shade100 : Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isOutline ? Colors.black87 : Colors.white,
                size: 22,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: isOutline ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
