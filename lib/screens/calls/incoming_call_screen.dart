import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_avatar.dart';
import 'ongoing_call_screen.dart';

/// Écran d'appel entrant (app au premier plan uniquement).
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
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
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
    if (cs.groupRoomId != null) {
      await cs.rejectGroupCall();
    } else {
      await cs.rejectCall();
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _accept() async {
    if (_navigated) return;
    _navigated = true;

    final cs = Provider.of<CallService>(context, listen: false);

    if (cs.groupRoomId != null) {
      final me = context.read<AuthProvider>().currentUser;
      if (me == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final callerInfo = (cs.remoteUserId != null)
          ? GroupParticipantInfo(
              id: cs.remoteUserId.toString(),
              name: (cs.remoteUserName?.isNotEmpty == true)
                  ? cs.remoteUserName!
                  : 'Participant',
              photo: cs.remoteUserPhoto,
            )
          : null;
      await cs.joinGroupCall(
        roomId: cs.groupRoomId!,
        myId: me.alanyaID,
        myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
        myPhoto: me.avatarUrl,
        isVideo: cs.isVideo,
        callerInfo: callerInfo,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
      return;
    }

    await cs.answerCall();

    if (!mounted) return;

    if (cs.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cs.errorMessage!),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
      Navigator.of(context).maybePop();
      return;
    }

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
        final isGroup = cs.groupRoomId != null;
        final name = caller?.nom.trim().isNotEmpty == true ? caller!.nom : 'Inconnu';
        final subtitle = isGroup
            ? (isVideo ? 'Appel groupé vidéo' : 'Appel groupé')
            : (isVideo ? 'Appel vidéo' : 'Appel vocal');

        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) return;
            unawaited(_reject());
          },
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.brandPrimaryDark,
                    Color(0xFF0A1628),
                    AppColors.black,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    AppSpacing.vGapXl,
                    Text(
                      'Appel entrant',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    _IncomingAvatarPulse(
                      animation: _pulse,
                      name: name,
                      imageUrl: caller?.avatarUrl,
                    ),
                    AppSpacing.vGapXxl,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppSpacing.vGapMd,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVideo
                              ? CupertinoIcons.video_camera_solid
                              : CupertinoIcons.phone_fill,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _CallActionButton(
                            icon: CupertinoIcons.phone_down_fill,
                            label: 'Refuser',
                            color: AppColors.error,
                            onTap: _reject,
                          ),
                          _CallActionButton(
                            icon: isVideo
                                ? CupertinoIcons.video_camera_solid
                                : CupertinoIcons.phone_fill,
                            label: 'Accepter',
                            color: AppColors.success,
                            onTap: _accept,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IncomingAvatarPulse extends StatelessWidget {
  const _IncomingAvatarPulse({
    required this.animation,
    required this.name,
    required this.imageUrl,
  });

  final Animation<double> animation;
  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: animation.value,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: animation.value * 0.88,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  ),
                ),
              ),
              AppAvatar(
                imageUrl: imageUrl,
                name: name,
                size: 148,
                backgroundColor: AppColors.brandPrimary,
                showShadow: true,
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.40),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        AppSpacing.vGapMd,
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
