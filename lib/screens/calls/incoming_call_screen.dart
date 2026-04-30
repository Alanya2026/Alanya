import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'ongoing_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final bool isVideoCall;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    this.isVideoCall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Caller Info
            Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white24,
                  child: Text(
                    callerName[0],
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideoCall ? 'Incoming Video Call...' : 'Incoming Audio Call...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Call Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline Button
                  Column(
                    children: [
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
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  // Accept Button
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OngoingCallScreen(
                                callerName: callerName,
                                isVideoCall: isVideoCall,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideoCall ? CupertinoIcons.video_camera_solid : CupertinoIcons.phone_fill,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
