import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../chats/chats_screen.dart';
import '../calls/calls_screen.dart';
import '../meetings/meets_screen.dart';
import '../profile/profile_screen.dart';
import '../calls/incoming_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatsScreen(),
    const CallsScreen(),
    const MeetsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Écouter les rappels entrants
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callService = Provider.of<CallService>(context, listen: false);
      callService.addListener(_onCallStatusChanged);
    });
  }

  @override
  void dispose() {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.removeListener(_onCallStatusChanged);
    super.dispose();
  }

  void _onCallStatusChanged() {
    if (!mounted) return;
    final callService = Provider.of<CallService>(context, listen: false);
    
    debugPrint('[HomeScreen] 🎯 CallService status changed: ${callService.status}');
    
    // ✅ NE naviguer que si UNIQUEMENT appel entrant (pas pendant un appel en cours)
    // Si status == connecting/outgoing/connected, l'appareil est déjà en appel
    if (callService.status == CallStatus.incoming) {
      debugPrint('[HomeScreen] 📱 Navigation vers IncomingCallScreen...');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const IncomingCallScreen(),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chat_bubble_2),
              activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.phone),
              activeIcon: Icon(CupertinoIcons.phone_fill),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.video_camera),
              activeIcon: Icon(CupertinoIcons.video_camera_solid),
              label: 'Meets',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person),
              activeIcon: Icon(CupertinoIcons.person_fill),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}