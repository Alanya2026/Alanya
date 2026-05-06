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
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  bool _initialized = false;
  bool _isScreenClosing = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    try {
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      
      debugPrint('[OngoingCallScreen] ✅ Renderers initialisés');

      final callService = Provider.of<CallService>(context, listen: false);

      if (callService.localStream != null) {
        _localRenderer.srcObject = callService.localStream;
      }
      if (callService.remoteStream != null) {
        _remoteRenderer.srcObject = callService.remoteStream;
      }

      // ✅ Stocker le listener pour pouvoir le supprimer dans dispose
      callService.addListener(_onCallServiceChanged);
      
      setState(() => _initialized = true);
    } catch (e) {
      debugPrint('[OngoingCallScreen] ❌ Erreur init renderers: $e');
    }
  }

  void _onCallServiceChanged() {
    // ✅ Ignorer si l'écran est en cours de fermeture
    if (_isScreenClosing) {
      debugPrint('[OngoingCallScreen] ⚠️ _onCallServiceChanged: screen is closing, ignoring');
      return;
    }
    
    if (!mounted) {
      debugPrint('[OngoingCallScreen] ⚠️ _onCallServiceChanged: widget not mounted, ignoring');
      return;
    }
    
    final callService = Provider.of<CallService>(context, listen: false);
    debugPrint('[OngoingCallScreen] 📊 CallService changed: ${callService.status}');

    // ✅ Navigation automatique quand l'appel se termine côté distant
    // Ne pas pop si on a volontairement terminé l'appel (le bouton RED l'a déjà fait)
    if (callService.status == CallStatus.ended && !callService.callEndedByUs) {
      debugPrint('[OngoingCallScreen] ❌ Appel terminé par l\'autre - dépilage...');
      _isScreenClosing = true;
      callService.removeListener(_onCallServiceChanged);
      
      // ✅ Vider les renderers avant de pop
      if (_initialized) {
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // ✅ Mettre à jour les renderers quand les streams changent
    if (!_initialized) return;
    
    debugPrint('[OngoingCallScreen] 🎥 Mise à jour renderers - Local: ${callService.localStream != null}, Remote: ${callService.remoteStream != null}');
    try {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = callService.localStream;
          _remoteRenderer.srcObject = callService.remoteStream;
        });
      }
    } catch (e) {
      debugPrint('[OngoingCallScreen] ⚠️ Erreur setState renderers: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('[OngoingCallScreen] 🧹 Nettoyage OngoingCallScreen...');
    
    try {
      // ✅ Supprimer le listener
      try {
        final callService = Provider.of<CallService>(context, listen: false);
        callService.removeListener(_onCallServiceChanged);
      } catch (e) {
        debugPrint('[OngoingCallScreen] ⚠️ Erreur suppression listener: $e');
      }
      
      if (_initialized) {
        // ✅ Vider les sources avant dispose
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        
        // ✅ Disposer les renderers
        _localRenderer.dispose();
        _remoteRenderer.dispose();
        
        debugPrint('[OngoingCallScreen] ✅ Renderers disposés');
      }
    } catch (e) {
      debugPrint('[OngoingCallScreen] ❌ Erreur dispose: $e');
    }
    
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
                      Column(
                        children: [
                          Text(
                            callService.remoteUserName ?? 'Appel en cours',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Chiffré de bout en bout',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Video/Audio Display
                Expanded(
                  child: Stack(
                    children: [
                      if (isVideoCall && _remoteRenderer.srcObject != null)
                        RTCVideoView(_remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.indigo.shade100,
                                child: Text(
                                  callService.remoteUserName?.isNotEmpty == true
                                      ? callService.remoteUserName![0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                callService.remoteUserName ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                // Durée de l'appel
                Text(
                  callService.formattedDuration,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 20),
                // Contrôles
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
                      // Micro
                      _buildControlButton(
                        icon: callService.isMuted
                            ? CupertinoIcons.mic_off
                            : CupertinoIcons.mic,
                        isActive: callService.isMuted,
                        onTap: () => callService.toggleMute(),
                      ),
                      // Caméra (vidéo) ou Speaker (audio)
                      if (isVideoCall)
                        _buildControlButton(
                          icon: callService.isVideoOn
                              ? CupertinoIcons.video_camera_solid
                              : CupertinoIcons.video_camera,
                          isActive: !callService.isVideoOn,
                          onTap: () => callService.toggleCamera(),
                        )
                      else
                        // ✅ Appelle toggleSpeaker (pas toggleMute)
                        _buildControlButton(
                          icon: callService.isSpeakerOn
                              ? CupertinoIcons.speaker_3_fill
                              : CupertinoIcons.speaker_2,
                          isActive: callService.isSpeakerOn,
                          onTap: () async {
                            await callService.toggleSpeaker();
                          },
                        ),
                      // Bouton raccrocher
                      GestureDetector(
                        onTap: () async {
                          debugPrint('[OngoingCallScreen] 🔴 Bouton rouge appuyé');
                          _isScreenClosing = true;
                          
                          // ✅ Supprimer le listener AVANT d'endcall
                          final callService = Provider.of<CallService>(context, listen: false);
                          callService.removeListener(_onCallServiceChanged);
                          
                          // ✅ Arrêter les renderers AVANT de quitter
                          if (_initialized) {
                            _localRenderer.srcObject = null;
                            _remoteRenderer.srcObject = null;
                            debugPrint('[OngoingCallScreen] 🛑 Renderers arrêtés');
                          }
                          
                          // ✅ Terminer l'appel et attendre la fin complète
                          await callService.endCall();
                          debugPrint('[OngoingCallScreen] ✅ endCall() complété');
                          
                          // ✅ Pop seulement après que tout soit fini
                          if (mounted) {
                            Navigator.pop(context);
                          }
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
                      // Changer de caméra (video uniquement)
                      if (isVideoCall)
                        _buildControlButton(
                          icon: CupertinoIcons.switch_camera,
                          isActive: false,
                          onTap: () => callService.switchCamera(),
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