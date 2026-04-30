import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OngoingCallScreen extends StatefulWidget {
  final String callerName;
  final bool isVideoCall;

  const OngoingCallScreen({
    super.key,
    required this.callerName,
    this.isVideoCall = false,
  });

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen> {
  bool isMuted = false;
  bool isSpeakerOn = false;
  bool isVideoOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'End-to-end Encrypted',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 32), // Balance the flex
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Call Info
            if (!widget.isVideoCall || !isVideoOn) ...[
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.indigo.shade100,
                child: Text(
                  widget.callerName[0],
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '02:45', // Mock duration
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            if (widget.isVideoCall && isVideoOn)
              const Expanded(
                child: Center(
                  child: Icon(CupertinoIcons.video_camera, color: Colors.white24, size: 100),
                ),
              )
            else
              const Spacer(),
            // Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: isMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic,
                    isActive: isMuted,
                    onTap: () => setState(() => isMuted = !isMuted),
                  ),
                  if (widget.isVideoCall)
                    _buildControlButton(
                      icon: isVideoOn ? CupertinoIcons.video_camera_solid : CupertinoIcons.video_camera,
                      isActive: !isVideoOn,
                      onTap: () => setState(() => isVideoOn = !isVideoOn),
                    )
                  else
                    _buildControlButton(
                      icon: isSpeakerOn ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_2,
                      isActive: isSpeakerOn,
                      onTap: () => setState(() => isSpeakerOn = !isSpeakerOn),
                    ),
                  // End Call Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.phone_down_fill,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
