import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../providers/auth_provider.dart';
import '../../talky_models.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/meeting_service.dart';
import '../../core/services/push_service.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/common/common.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'join_meet_screen.dart';
import 'meeting_detail_screen.dart';
import 'participant_picker_screen.dart';
import '../shared/schedule_screen.dart';
import '../../core/theme/locale_controller.dart';
import 'package:intl/intl.dart';

class MeetsScreen extends StatefulWidget {
  const MeetsScreen({super.key});

  @override
  State<MeetsScreen> createState() => _MeetsScreenState();
}

class _MeetsScreenState extends State<MeetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  int _myId = 0;
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  StreamSubscription<MeetingNotifData>? _meetingNotifSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final me = context.read<AuthProvider>().currentUser;
    _myId = me?.alanyaID ?? 0;
    _loadMeetings();
    _meetingNotifSub =
        PushService.meetingNotifications.listen((_) => _loadMeetings());
  }

  @override
  void dispose() {
    _meetingNotifSub?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _search = '';
      }
    });
  }

  List<Meeting> _filtered(List<Meeting> list) {
    if (_search.isEmpty) return list;
    return list
        .where((m) => m.objet.toLowerCase().contains(_search))
        .toList();
  }

  Future<void> _loadMeetings() async {
    try {
      final cache =
          Provider.of<LocalCacheRepository>(context, listen: false);
      final local = await cache.watchMeetings().first;
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _meetings = local.map(_localToMeeting).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = true);
      }
    } catch (e, st) {
      AppLog.e('MeetsScreen', 'Chargement réunions (cache) échoué', e, st);
    }

    try {
      final meetingService =
          Provider.of<MeetingService>(context, listen: false);
      final data = await meetingService.getMeetings();
      if (!mounted) return;
      setState(() {
        _meetings = data;
        _isLoading = false;
      });
      if (mounted) {
        final cache =
            Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncMeetings();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Meeting _localToMeeting(LocalMeeting m) {
    return Meeting(
      idMeeting: m.idMeeting,
      idOrganiser: m.organiserID,
      startTime: m.startTime.toIso8601String(),
      duree: m.duree,
      objet: m.objet,
      room: m.room,
      isEnd: m.statut == 2,
      typeMedia: m.typeMedia,
      reminderSent: false,
      organiserNom: m.organiserNom,
      participants: const [],
    );
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
    if (_myId == 0) {
      final me = context.read<AuthProvider>().currentUser;
      if (me != null) setState(() => _myId = me.alanyaID);
    }
    if (!mounted) return;

    final participants = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ParticipantPickerScreen(confirmLabel: context.l10n.startAction),
      ),
    );
    if (participants == null || !mounted) return;

    final meetingService =
        Provider.of<MeetingService>(context, listen: false);
    final now = DateTime.now();

    try {
      final me = context.read<AuthProvider>().currentUser;
      final myName = me != null
          ? (me.nom.isNotEmpty ? me.nom : me.pseudo)
          : '';

      await meetingService.createAndJoin(
        objet: context.l10n.meetingNamed(now.toString().substring(0, 16)),
        startTime: now.toUtc().toIso8601String(),
        room: 'mtg-${now.millisecondsSinceEpoch}',
        myId: _myId,
        myName: myName,
      );

      if (participants.isNotEmpty) {
        final ids = participants.map((u) => u.alanyaID).toList();
        await meetingService.inviteParticipants(ids);
      }

      if (!mounted) return;
      await meetingService.navigateToMeetingUi(context);
      if (mounted) _loadMeetings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotCreateMeeting('$e'))),
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
        builder: (_) =>
            MeetingDetailScreen(meetingId: meeting.idMeeting),
      ),
    ).then((_) => _loadMeetings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navMeetings, style: context.text.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            tooltip: _searchOpen ? context.l10n.closeSearch : context.l10n.commonSearch,
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: context.l10n.scheduleAction,
            onPressed: _openSchedule,
          ),
          AppSpacing.hGapLg,
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.today),
            Tab(text: context.l10n.upcoming),
            Tab(text: context.l10n.past),
          ],
        ),
      ),
      body: Column(
        children: [
          AnimatedSearchBar(
            open: _searchOpen,
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            onClose: _toggleSearch,
          ),
          // Boutons d'action rapide
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: context.l10n.newMeeting,
                    icon: CupertinoIcons.video_camera_solid,
                    onTap: _createNewMeeting,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: _ActionCard(
                    title: context.l10n.join,
                    icon: CupertinoIcons.keyboard,
                    isOutline: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const JoinMeetScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MeetingList(
                        meetings: _filtered(_todayMeetings),
                        emptyMessage: _search.isEmpty
                            ? context.l10n.noMeetingsToday
                            : context.l10n.noResults,
                        emptyIcon: CupertinoIcons.calendar_badge_plus,
                        onRefresh: _loadMeetings,
                        showScheduleButton: true,
                        onSchedule: _openSchedule,
                        onOpenDetail: _openDetail,
                      ),
                      _MeetingList(
                        meetings: _filtered(_upcomingMeetings),
                        emptyMessage: _search.isEmpty
                            ? context.l10n.noUpcomingMeetings
                            : context.l10n.noResults,
                        emptyIcon: CupertinoIcons.calendar,
                        onRefresh: _loadMeetings,
                        showScheduleButton: true,
                        onSchedule: _openSchedule,
                        onOpenDetail: _openDetail,
                      ),
                      _MeetingList(
                        meetings: _filtered(_pastMeetings),
                        emptyMessage: _search.isEmpty
                            ? context.l10n.noPastMeetings
                            : context.l10n.noResults,
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
        heroTag: 'meets_schedule_fab',
        onPressed: _openSchedule,
        elevation: 4,
        tooltip: context.l10n.scheduleAMeeting,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Liste de meetings avec pull-to-refresh ─────────────────────────���─────────

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
        color: context.colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(icon: emptyIcon, title: emptyMessage),
                if (showScheduleButton && onSchedule != null) ...[
                  AppSpacing.vGapXl,
                  TextButton.icon(
                    onPressed: onSchedule,
                    icon: const Icon(Icons.add),
                    label: Text(
                      context.l10n.scheduleAMeeting,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, kGlassNavBarSpace),
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

// ─── Carte individuelle d'un meeting ────────────────────────────���────────────

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
    if (m.isToday) return LocaleController.instance.l10n.todayAt(timeStr);
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day) {
      return LocaleController.instance.l10n.tomorrowAt(timeStr);
    }
    final locale = LocaleController.instance.resolvedLocale.toLanguageTag();
    final month = DateFormat.MMM(locale).format(d);
    return '${d.day} $month · $timeStr';
  }

  bool _isInProgress(Meeting m) {
    final now = DateTime.now();
    return m.startDateTime.isBefore(now) &&
        m.endDateTime.isAfter(now) &&
        !m.isEnd;
  }

  int? _minutesUntilStart(Meeting m) {
    final diff = m.startDateTime.difference(DateTime.now());
    if (!diff.isNegative && diff.inMinutes <= 15 && !m.isEnd) {
      return diff.inMinutes;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color =
        Colors.primaries[meeting.idMeeting % Colors.primaries.length];
    final inProgress = _isInProgress(meeting);
    final minsUntil = _minutesUntilStart(meeting);
    final organiser =
        meeting.organiserNom ?? meeting.organiserPseudo ?? context.l10n.organizer;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brLg,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: inProgress
                ? context.colors.primaryContainer
                : context.colors.outline,
            width: inProgress ? 1.5 : 1,
          ),
          boxShadow: inProgress ? AppShadows.subtle : null,
        ),
        child: Padding(
          padding: AppSpacing.card,
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: inProgress ? context.colors.primary : color,
                  borderRadius: AppRadius.brSm,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.objet,
                            style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (inProgress)
                          StatusChip(
                              label: context.l10n.inProgress,
                              tone: StatusChipTone.success)
                        else if (minsUntil != null)
                          StatusChip(
                            label: minsUntil == 0
                                ? context.l10n.nowLabel
                                : context.l10n.inMinutes(minsUntil),
                            tone: StatusChipTone.warning,
                          ),
                        if (meeting.typeMedia == 1)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: Icon(CupertinoIcons.phone_fill,
                                size: 14,
                                color: context.colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                    AppSpacing.vGapXs,
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 13,
                            color: context.colors.onSurfaceVariant),
                        AppSpacing.hGapXs,
                        Text(_formatDateTime(meeting),
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 13,
                            color: context.colors.onSurfaceVariant),
                        AppSpacing.hGapXs,
                        Expanded(
                          child: Text(
                            organiser,
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (meeting.participants.isNotEmpty)
                          Text(
                            context.l10n.dotParticipantsCount(meeting.participants.length),
                            style: context.text.labelSmall?.copyWith(
                                color: context.colors.outlineVariant),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.hGapSm,
              Icon(Icons.chevron_right,
                  color: context.colors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carte d'action rapide ─────────────────────────────��──────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isOutline = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: isOutline ? context.colors.surface : context.colors.primary,
          borderRadius: AppRadius.brLg,
          border: isOutline
              ? Border.all(color: context.colors.outline, width: 1.5)
              : null,
          boxShadow: isOutline ? null : AppShadows.brand,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm - 1),
              decoration: BoxDecoration(
                color: isOutline
                    ? context.semantic.surfaceMuted
                    : context.colors.onPrimary.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isOutline
                    ? context.colors.onSurface
                    : context.colors.onPrimary,
                size: AppIconSize.md - 2,
              ),
            ),
            Text(
              title,
              style: context.text.labelLarge?.copyWith(
                color: isOutline
                    ? context.colors.onSurface
                    : context.colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
