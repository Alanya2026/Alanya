import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OngoingMeetScreen extends StatefulWidget {
  const OngoingMeetScreen({super.key});

  @override
  State<OngoingMeetScreen> createState() => _OngoingMeetScreenState();
}

class _OngoingMeetScreenState extends State<OngoingMeetScreen> {
  bool isMicMuted = false;
  bool isVideoOff = false;
  bool isHandRaised = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124), // Google Meet dark background
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Team Sync',
                        style: TextStyle(
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
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.speaker_3, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  )
                ],
              ),
            ),
            // Video Grid Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                  children: [
                    _buildParticipantTile('Sarah (You)', Colors.blue, true),
                    _buildParticipantTile('Mike T.', Colors.orange, false),
                    _buildParticipantTile('Emma W.', Colors.green, false),
                    _buildParticipantTile('David L.', Colors.purple, false),
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
                    onTap: () => Navigator.pop(context),
                    isLarge: true,
                  ),
                  _buildControlBtn(
                    icon: isVideoOff ? CupertinoIcons.video_camera_solid : CupertinoIcons.video_camera,
                    color: isVideoOff ? Colors.white : Colors.white24,
                    iconColor: isVideoOff ? Colors.black : Colors.white,
                    onTap: () => setState(() => isVideoOff = !isVideoOff),
                  ),
                  _buildControlBtn(
                    icon: isMicMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic,
                    color: isMicMuted ? Colors.white : Colors.white24,
                    iconColor: isMicMuted ? Colors.black : Colors.white,
                    onTap: () => setState(() => isMicMuted = !isMicMuted),
                  ),
                  _buildControlBtn(
                    icon: isHandRaised ? Icons.back_hand : Icons.back_hand_outlined,
                    color: isHandRaised ? Colors.amber.shade100 : Colors.white24,
                    iconColor: isHandRaised ? Colors.amber.shade800 : Colors.white,
                    onTap: () => setState(() => isHandRaised = !isHandRaised),
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
  }

  Widget _buildParticipantTile(String name, Color color, bool isMe) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Placeholder for video feed
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: color,
              child: Text(
                name[0],
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
          ),
          // Name label
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
          // Mic status
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
                isMe && isMicMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 14,
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
