import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/meeting_service.dart';
import 'join_meet_screen.dart';
import 'ongoing_meet_screen.dart';
import '../shared/schedule_screen.dart';

class MeetsScreen extends StatefulWidget {
  const MeetsScreen({super.key});

  @override
  State<MeetsScreen> createState() => _MeetsScreenState();
}

class _MeetsScreenState extends State<MeetsScreen> {
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String _userInitial = 'U';

  @override
  void initState() {
    super.initState();
    _loadMeetings();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getMe();
      final userData = data is Map ? data : (data is List && data.isNotEmpty ? data[0] : null);
      if (userData != null) {
        final user = User.fromJson(userData as Map<String, dynamic>);
        setState(() {
          _userInitial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : 'U';
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);

    try {
      final meetingService = Provider.of<MeetingService>(context, listen: false);
      final data = await meetingService.getMeetings();
      setState(() {
        _meetings = data.cast<Meeting>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewMeeting() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);

    try {
      await meetingService.createAndJoinMeeting(
        titre: 'New Meeting ${DateTime.now().toString().substring(0, 16)}',
        dateDebut: DateTime.now(),
        dateFin: DateTime.now().add(const Duration(hours: 1)),
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OngoingMeetScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create meeting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Meetings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScheduleScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.indigo.shade100,
            child: Text(
              _userInitial,
              style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            title: 'New Meeting',
                            icon: CupertinoIcons.video_camera_solid,
                            color: Colors.indigo,
                            onTap: _createNewMeeting,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            title: 'Join with Code',
                            icon: CupertinoIcons.keyboard,
                            color: Colors.black87,
                            isOutline: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const JoinMeetScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Text(
                      'Upcoming Meetings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _meetings.length) return null;
                      return _buildMeetingItem(_meetings[index]);
                    },
                    childCount: _meetings.length,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewMeeting,
        backgroundColor: Colors.indigo,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isOutline ? Colors.white : color,
          borderRadius: BorderRadius.circular(20),
          border: isOutline ? Border.all(color: Colors.grey.shade300, width: 1.5) : null,
          boxShadow: isOutline
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOutline ? Colors.grey.shade100 : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isOutline ? Colors.black87 : Colors.white,
                size: 24,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: isOutline ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingItem(Meeting meeting) {
    final DateTime dateDebut = DateTime.parse(meeting.dateDebut);
    final DateTime dateFin = DateTime.parse(meeting.dateFin);
    final bool isToday = dateDebut.day == DateTime.now().day;

    final color = Colors.primaries[meeting.idMeeting % Colors.primaries.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.titre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${isToday ? "Today" : "Upcoming"} • ${dateDebut.hour}:${dateDebut.minute.toString().padLeft(2, '0')} - ${dateFin.hour}:${dateFin.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final meetingService = Provider.of<MeetingService>(context, listen: false);
              try {
                await meetingService.joinMeeting(meeting.idMeeting);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OngoingMeetScreen()),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to join: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade50,
              foregroundColor: Colors.indigo,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
