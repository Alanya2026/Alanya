import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import 'ongoing_call_screen.dart';
import 'keypad_screen.dart';
import 'select_contact_screen.dart';
import '../shared/schedule_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<dynamic> _recentCalls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentCalls();
  }

  Future<void> _loadRecentCalls() async {
    setState(() => _isLoading = true);

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final calls = await apiClient.getCallHistory();
      setState(() {
        _recentCalls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateCallFromHistory(dynamic callData, bool isVideo) async {
    final call = callData is Call ? callData : Call.fromJson(callData as Map<String, dynamic>);
    final currentUserId = await _getCurrentUserId();
    final otherUser = call.idCaller != currentUserId
        ? call.caller
        : call.receiver;

    if (otherUser == null) return;

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: otherUser.alanyaID,
      myId: currentUserId,
      myName: currentUserId.toString(),
      isVideo: isVideo,
    );
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OngoingCallScreen()),
      );
    }
  }

  Future<int> _getCurrentUserId() async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final userData = await apiClient.getMe();
    return userData['alanyaID'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calls',
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_call, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectContactScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentCalls.isEmpty
              ? const Center(
                  child: Text(
                    'No recent calls',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _recentCalls.length,
                  itemBuilder: (context, index) {
                    final callData = _recentCalls[index];
                    final call = callData is Call
                        ? callData
                        : Call.fromJson(callData as Map<String, dynamic>);

                    final isMissed = call.isMissed;
                    final isVideo = call.isVideo;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.indigo.shade50,
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.indigo,
                        ),
                      ),
                      title: FutureBuilder<int>(
                        future: _getCurrentUserId(),
                        builder: (context, snapshot) {
                          final otherUser = call.caller?.alanyaID != (snapshot.data ?? 0)
                              ? call.caller
                              : call.receiver;
                          return Text(
                            otherUser?.nom ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isMissed ? Colors.red : Colors.black87,
                            ),
                          );
                        },
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            isMissed ? Icons.call_missed : Icons.call_made,
                            size: 16,
                            color: isMissed ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDate(call.createdAt)} • ${isVideo ? "Video" : "Audio"}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isVideo ? Icons.videocam : Icons.call,
                          color: Colors.indigo,
                        ),
                        onPressed: () => _initiateCallFromHistory(callData, isVideo),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const KeypadScreen()));
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.dialpad, color: Colors.white),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month) {
        return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Recently';
    }
  }
}
