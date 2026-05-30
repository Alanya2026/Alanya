import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/call_service.dart';
import '../../core/services/push_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../chats/chats_screen.dart';
import '../calls/calls_screen.dart';
import '../meetings/meeting_detail_screen.dart';
import '../meetings/meets_screen.dart';
import '../profile/profile_screen.dart';
import '../status/statuses_screen.dart';
import '../calls/incoming_call_screen.dart';
import 'glass_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _incomingCallShown = false;
  late final PageController _pageController;

  StreamSubscription<MeetingNotifData>? _meetingNotifSub;

  final List<Widget> _screens = [
    const ChatsScreen(),
    const CallsScreen(),
    const StatusesScreen(),
    const MeetsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Appels entrants via CallService
      final callService = Provider.of<CallService>(context, listen: false);
      callService.addListener(_onCallStatusChanged);
      if (callService.status == CallStatus.incoming && !_incomingCallShown) {
        _showIncomingCall();
      }

      // Notifications meeting via PushService
      _meetingNotifSub = PushService.meetingNotifications.listen(_onMeetingNotif);

      // Lier le ChatProvider à l'utilisateur courant (couvre login frais ET
      // session restaurée) → active le temps réel et un senderID correct.
      final myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
      if (myId != null && myId != 0) {
        Provider.of<ChatProvider>(context, listen: false).bind(myId);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    Provider.of<CallService>(context, listen: false)
        .removeListener(_onCallStatusChanged);
    _meetingNotifSub?.cancel();
    super.dispose();
  }

  // ── Appels entrants ─────────────────────────────────────────────────

  void _onCallStatusChanged() {
    if (!mounted) return;
    final callService = Provider.of<CallService>(context, listen: false);
    debugPrint('[HomeScreen] CallService status: ${callService.status}');
    if (callService.status == CallStatus.incoming && !_incomingCallShown) {
      _showIncomingCall();
    }
  }

  void _showIncomingCall() {
    _incomingCallShown = true;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const IncomingCallScreen(),
      ),
    ).then((_) {
      if (mounted) _incomingCallShown = false;
    });
  }

  // ── Notifications meeting ────────────────────────────────────────────

  void _onMeetingNotif(MeetingNotifData notif) {
    if (!mounted) return;

    // Toujours switcher sur l'onglet Réunions
    setState(() => _selectedIndex = 2);

    if (notif.type == 'meeting_reminder') {
      _showReminderDialog(notif);
    } else if (notif.type == 'meeting_invite') {
      _showInviteSnackBar(notif);
    }
  }

  void _showInviteSnackBar(MeetingNotifData notif) {
    final onBrand = context.colors.onPrimary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.videocam_rounded, color: onBrand, size: AppIconSize.sm),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.meetingTitle,
                    style: context.text.titleSmall?.copyWith(color: onBrand),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Invitation de ${notif.organiserName}',
                    style: context.text.bodySmall?.copyWith(color: onBrand.withAlpha(220)),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: notif.meetingId != 0
            ? SnackBarAction(
                label: 'Voir',
                textColor: onBrand,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingDetailScreen(meetingId: notif.meetingId),
                  ),
                ),
              )
            : null,
        backgroundColor: context.colors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),
    );
  }

  void _showReminderDialog(MeetingNotifData notif) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ReminderDialog(notif: notif),
    );
  }

  // ── Navigation ───────────────────────────────────────────────────────

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // On injecte kGlassNavBarSpace dans viewPadding.bottom : ce canal n'est
    // pas consommé par SafeArea, donc le contenu scrolle plein écran et
    // passe derrière le glass. En revanche le Scaffold des onglets enfants
    // l'utilise pour positionner ses FAB → ils sont automatiquement remontés
    // au-dessus de la nav sans modif dans chaque écran.
    final injectedMq = mq.copyWith(
      viewPadding: mq.viewPadding.copyWith(
        bottom: mq.viewPadding.bottom + kGlassNavBarSpace,
      ),
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom + kGlassNavBarSpace,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          MediaQuery(
            data: injectedMq,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens.map((s) => KeepAliveWrapper(child: s)).toList(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: GlassNavBar(
                selectedIndex: _selectedIndex,
                onItemTapped: _onItemTapped,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog rappel 10 minutes ─────────────────────────────────────────────────

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.notif});

  final MeetingNotifData notif;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  void _join() {
    Navigator.pop(context);
    if (widget.notif.meetingId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(meetingId: widget.notif.meetingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        0,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.videocam_rounded, color: colors.primary, size: 32),
          ),
          AppSpacing.vGapLg,
          Text(
            'Réunion dans moins de 10 minutes',
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapSm,
          Text(
            widget.notif.meetingTitle,
            style: context.text.bodyLarge,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vGapXs,
          Text(
            'Organisé par ${widget.notif.organiserName}',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapXxl,
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: FilledButton(
                onPressed: _join,
                child: const Text('Rejoindre'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Garde les pages hors-écran en vie ────────────────────────────────

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
