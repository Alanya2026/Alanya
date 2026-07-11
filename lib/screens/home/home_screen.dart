import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/services/call_service.dart';
import '../../core/services/notification_navigation.dart';
import '../../core/services/push_service.dart';
import '../chats/chats_screen.dart';
import '../calls/calls_screen.dart';
import '../meetings/meeting_detail_screen.dart';
import '../meetings/meets_screen.dart';
import '../profile/profile_screen.dart';
import '../status/statuses_screen.dart';
import '../calls/incoming_call_screen.dart';
import '../calls/ongoing_call_screen.dart';
import 'glass_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  // Garde unique : un seul écran d'appel (entrant OU actif) affiché à la fois.
  bool _callScreenShown = false;
  late final PageController _pageController;

  StreamSubscription<NotificationAction>? _notifActionSub;
  Timer? _resumeSyncDebounce;

  static const int _tabCalls = 1;
  static const int _tabStatuses = 2;
  static const int _tabMeetings = 3;

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
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final callService = Provider.of<CallService>(context, listen: false);
      callService.addListener(_onCallStatusChanged);
      _onCallStatusChanged();

      _notifActionSub =
          PushService.notificationActions.listen(_onNotificationAction);

      // Cold start : action reçue avant abonnement au stream
      final pending = PushService.consumePendingAction();
      if (pending != null) _onNotificationAction(pending);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeSyncDebounce?.cancel();
    _pageController.dispose();
    Provider.of<CallService>(context, listen: false)
        .removeListener(_onCallStatusChanged);
    _notifActionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleResumeCatchUp();
      Provider.of<ChatProvider>(context, listen: false)
          .repository
          .syncPushSuppressionForLifecycle(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      Provider.of<ChatProvider>(context, listen: false)
          .repository
          .syncPushSuppressionForLifecycle(false);
    }
  }

  void _scheduleResumeCatchUp() {
    _resumeSyncDebounce?.cancel();
    _resumeSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      unawaited(
        Provider.of<RealtimeSyncService>(context, listen: false).catchUp(),
      );
    });
  }

  // ── Appels entrants ─────────────────────────────────────────────────

  void _onCallStatusChanged() {
    if (!mounted) return;
    final callService = Provider.of<CallService>(context, listen: false);
    debugPrint('[HomeScreen] CallService status: ${callService.status}');

    if (callService.status == CallStatus.idle ||
        callService.status == CallStatus.ended) {
      _callScreenShown = false;
      return;
    }

    if (_callScreenShown) return;

    // Accepté depuis notification/CallKit : on saute l'écran entrant.
    if (callService.isAutoAnsweringFromPush) {
      if (callService.status == CallStatus.incoming ||
          callService.status == CallStatus.connecting ||
          callService.status == CallStatus.connected) {
        _showOngoingCall();
      }
      return;
    }

    if (callService.status == CallStatus.incoming) {
      _showIncomingCall();
      return;
    }

    if (callService.status == CallStatus.outgoing ||
        callService.status == CallStatus.connecting ||
        callService.status == CallStatus.connected) {
      _showOngoingCall();
    }
  }

  void _showIncomingCall() {
    _callScreenShown = true;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const IncomingCallScreen(),
      ),
    ).then((_) {
      if (mounted) _callScreenShown = false;
    });
  }

  void _showOngoingCall() {
    _callScreenShown = true;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const OngoingCallScreen(),
      ),
    ).then((_) {
      if (mounted) _callScreenShown = false;
    });
  }

  // ── Notifications ────────────────────────────────────────────────────

  void _onNotificationAction(NotificationAction action) {
    if (!mounted) return;
    debugPrint('[HomeScreen] notif action: type=${action.type} tap=${action.fromTap}');

    final type = action.type;
    if (type == 'message') {
      final convId = int.tryParse(action.data['conversationId'] ?? '') ?? 0;
      unawaited(
        Provider.of<RealtimeSyncService>(context, listen: false).catchUp(
          conversationId: convId > 0 ? convId : null,
        ),
      );
      if (action.fromTap) {
        NotificationNavigation.openConversation(context, action.data);
      }
    } else if (type == 'call' || type == 'group_call') {
      if (action.fromTap) _handleCallNotification(action.data);
    } else if (type == 'meeting_invite' || type == 'meeting_reminder') {
      _handleMeetingNotification(action);
    } else if (type == 'status_view') {
      if (action.fromTap) _switchToTab(_tabStatuses);
    }
  }

  void _handleCallNotification(Map<String, String> data) {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.prepareIncomingFromCallKit(
      callId: data['callId'] ?? data['roomId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? data['title'] ?? 'Appel',
      callerPhoto: data['photo'],
      isVideo: data['isVideo'] == 'true',
      roomId: data['roomId'],
    );
    _switchToTab(_tabCalls);
  }

  void _handleMeetingNotification(NotificationAction action) {
    final notif = MeetingNotifData(
      type: action.data['type'] ?? action.type,
      meetingId: int.tryParse(action.data['meetingId'] ?? '') ?? 0,
      meetingTitle: action.data['meetingTitle'] ?? '',
      organiserName: action.data['organiserName'] ?? '',
      meetingTime: action.data['meetingTime'] ?? '',
    );

    if (action.fromTap) {
      _switchToTab(_tabMeetings);
      if (notif.meetingId != 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingDetailScreen(meetingId: notif.meetingId),
          ),
        );
      }
      return;
    }

    _switchToTab(_tabMeetings);
    if (notif.type == 'meeting_reminder') {
      _showReminderDialog(notif);
    } else if (notif.type == 'meeting_invite') {
      _showInviteSnackBar(notif);
    }
  }

  void _switchToTab(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
