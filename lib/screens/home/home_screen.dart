import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.meetingTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Invitation de ${notif.organiserName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: notif.meetingId != 0
            ? SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingDetailScreen(meetingId: notif.meetingId),
                  ),
                ),
              )
            : null,
        backgroundColor: Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
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
            child: GlassNavBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_rounded, color: Colors.indigo, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Réunion dans moins de 10 minutes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.notif.meetingTitle,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Organisé par ${widget.notif.organiserName}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Plus tard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                        'Rejoindre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
