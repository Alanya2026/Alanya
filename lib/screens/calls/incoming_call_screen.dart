import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/call_service.dart';
import 'ongoing_call_screen.dart';

/// Écran d'appel entrant.
///
/// Surveille `CallService.status` :
/// - `connecting` ou `connected` (auto-answer depuis CallKit) → push de
///   [OngoingCallScreen]
/// - `ended` ou `idle`  (raccroché côté appelant / refus / timeout) → pop
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    Provider.of<CallService>(context, listen: false).addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    Provider.of<CallService>(context, listen: false).removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted || _navigated) return;
    final cs = Provider.of<CallService>(context, listen: false);

    // Décrochage via CallKit pendant qu'on est sur cet écran → bascule vers
    // l'écran d'appel en cours.
    if (cs.status == CallStatus.connecting || cs.status == CallStatus.connected) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    if (cs.status == CallStatus.ended || cs.status == CallStatus.idle) {
      _navigated = true;
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reject() async {
    if (_navigated) return;
    _navigated = true;
    final cs = Provider.of<CallService>(context, listen: false);
    await cs.rejectCall();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _accept() async {
    if (_navigated) return;
    _navigated = true;
    
    final cs = Provider.of<CallService>(context, listen: false);
    await cs.answerCall();
    
    // Widget may be deactivated during await, check mounted before using context
    if (!mounted) return;

    if (cs.errorMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cs.errorMessage!),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    // Verify widget is still mounted before navigation
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (_, cs, __) {
        final caller = cs.currentCall?.caller;
        final isVideo = cs.isVideo;
        final name = caller?.nom.trim().isNotEmpty == true ? caller!.nom : 'Inconnu';
        final initial = name.substring(0, 1).toUpperCase();

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A237E), Color(0xFF000000)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    isVideo ? 'Appel vidéo entrant' : 'Appel vocal entrant',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _AvatarPulse(animation: _pulse, initial: initial, photoUrl: caller?.avatarUrl),
                  const SizedBox(height: 28),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Talky',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CallActionButton(
                          icon: CupertinoIcons.phone_down_fill,
                          label: 'Refuser',
                          color: const Color(0xFFE53935),
                          onTap: _reject,
                        ),
                        _CallActionButton(
                          icon: isVideo
                              ? CupertinoIcons.video_camera_solid
                              : CupertinoIcons.phone_fill,
                          label: 'Accepter',
                          color: const Color(0xFF43A047),
                          onTap: _accept,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPulse extends StatelessWidget {
  const _AvatarPulse({
    required this.animation,
    required this.initial,
    required this.photoUrl,
  });

  final Animation<double> animation;
  final String initial;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasPhoto = url != null &&
        url.isNotEmpty &&
        url.toUpperCase() != 'NON DEFINI' &&
        (url.startsWith('http://') || url.startsWith('https://'));
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: animation.value,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Transform.scale(
                scale: animation.value * 0.85,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 72,
                backgroundColor: const Color(0xFF3949AB),
                backgroundImage: hasPhoto ? NetworkImage(url) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
