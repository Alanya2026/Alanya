import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/services/call_service.dart';

class OngoingCallScreen extends StatefulWidget {
  const OngoingCallScreen({super.key});

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final callService = Provider.of<CallService>(context, listen: false);

    if (callService.localStream != null) {
      _localRenderer.srcObject = callService.localStream;
    }
    if (callService.remoteStream != null) {
      _remoteRenderer.srcObject = callService.remoteStream;
    }

    callService.addListener(_updateRenderers);
  }

  void _updateRenderers() {
    final callService = Provider.of<CallService>(context, listen: false);
    setState(() {
      _localRenderer.srcObject = callService.localStream;
      _remoteRenderer.srcObject = callService.remoteStream;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, _) {
        final isVideoCall = callService.isVideo;

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
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'End-to-end Encrypted',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Video/Audio Display
                Expanded(
                  child: Stack(
                    children: [
                      if (isVideoCall && _remoteRenderer.srcObject != null)
                        RTCVideoView(_remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      else
                        Center(
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(
                              callService.remoteUserName?.isNotEmpty == true
                                  ? callService.remoteUserName![0]
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (isVideoCall)
                        Positioned(
                          right: 20,
                          top: 20,
                          width: 100,
                          height: 150,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _localRenderer.srcObject != null
                                  ? RTCVideoView(_localRenderer,
                                      mirror: true,
                                      objectFit: RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitCover)
                                  : const SizedBox(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Call Info
                Text(
                  callService.formattedDuration,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 20),
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
                        icon: callService.isMuted
                            ? CupertinoIcons.mic_off
                            : CupertinoIcons.mic,
                        isActive: callService.isMuted,
                        onTap: () => callService.toggleMute(),
                      ),
                      if (isVideoCall)
                        _buildControlButton(
                          icon: callService.isVideoOn
                              ? CupertinoIcons.video_camera_solid
                              : CupertinoIcons.video_camera,
                          isActive: !callService.isVideoOn,
                          onTap: () => callService.toggleCamera(),
                        )
                      else
                        _buildControlButton(
                          icon: callService.isSpeakerOn
                              ? CupertinoIcons.speaker_3_fill
                              : CupertinoIcons.speaker_2,
                          isActive: callService.isSpeakerOn,
                          onTap: () {
                            setState(() {
                              callService.toggleMute();
                            });
                          },
                        ),
                      // End Call Button
                      GestureDetector(
                        onTap: () async {
                          await callService.endCall();
                          if (mounted) Navigator.pop(context);
                        },
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
      },
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
