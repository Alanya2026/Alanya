import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/services/meeting_service.dart';

class OngoingMeetScreen extends StatefulWidget {
  const OngoingMeetScreen({super.key});

  @override
  State<OngoingMeetScreen> createState() => _OngoingMeetScreenState();
}

class _OngoingMeetScreenState extends State<OngoingMeetScreen> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    if (meetingService.localStream != null) {
      _localRenderer.srcObject = meetingService.localStream;
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, _) {
        final meeting = meetingService.currentMeeting;
        final remoteStreams = meetingService.remoteStreams;

        return Scaffold(
          backgroundColor: const Color(0xFF202124),
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () async {
                              await meetingService.endMeeting();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            meeting?.titre ?? 'Meeting',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.switch_camera, color: Colors.white),
                            onPressed: () => meetingService.switchCamera(),
                          ),
                          IconButton(
                            icon: Icon(
                              meetingService.isVideoOff ? CupertinoIcons.speaker_3 : CupertinoIcons.speaker_3_fill,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                // Video Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.count(
                      crossAxisCount: remoteStreams.isEmpty ? 1 : 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.8,
                      children: [
                        // Local video
                        _buildVideoTile(
                          'You',
                          _localRenderer.srcObject != null
                              ? RTCVideoView(_localRenderer, mirror: true)
                              : null,
                          meetingService.isVideoOff,
                          meetingService.isMuted,
                        ),
                        // Remote videos
                        ...remoteStreams.entries.map((entry) {
                          return _buildRemoteVideoTile(entry.key, entry.value);
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                // Bottom Controls
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  color: const Color(0xFF202124),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildControlBtn(
                        icon: Icons.call_end,
                        color: Colors.red,
                        iconColor: Colors.white,
                        onTap: () async {
                          await meetingService.endMeeting();
                          if (context.mounted) Navigator.pop(context);
                        },
                        isLarge: true,
                      ),
                      _buildControlBtn(
                        icon: meetingService.isVideoOff ? CupertinoIcons.video_camera_solid : CupertinoIcons.video_camera,
                        color: meetingService.isVideoOff ? Colors.white : Colors.white24,
                        iconColor: meetingService.isVideoOff ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleVideo(),
                      ),
                      _buildControlBtn(
                        icon: meetingService.isMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic,
                        color: meetingService.isMuted ? Colors.white : Colors.white24,
                        iconColor: meetingService.isMuted ? Colors.black : Colors.white,
                        onTap: () => meetingService.toggleMute(),
                      ),
                      _buildControlBtn(
                        icon: meetingService.isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                        color: meetingService.isHandRaised ? Colors.amber.shade100 : Colors.white24,
                        iconColor: meetingService.isHandRaised ? Colors.amber.shade800 : Colors.white,
                        onTap: () => meetingService.toggleHandRaised(),
                      ),
                      _buildControlBtn(
                        icon: Icons.more_vert,
                        color: Colors.white24,
                        iconColor: Colors.white,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoTile(String name, Widget? videoView, bool isVideoOff, bool isMuted) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          if (videoView != null && !isVideoOff)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: videoView,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Text(
                  name[0],
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideoTile(String userId, MediaStream stream) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RTCVideoView(
              RTCVideoRenderer()..srcObject = stream,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'User $userId',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 16 : 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: isLarge ? 32 : 24,
        ),
      ),
    );
  }
}
