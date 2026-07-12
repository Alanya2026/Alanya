import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_avatar.dart';
import 'speaking_indicator_border.dart';

/// Fond thématisé + avatar central pour les appels audio.
class CallAudioBackdrop extends StatelessWidget {
  const CallAudioBackdrop({
    super.key,
    required this.name,
    required this.photoUrl,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isRemoteMuted = false,
  });

  final String name;
  final String? photoUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool isRemoteMuted;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return Container(
      decoration: BoxDecoration(
        gradient: callUi.audioBackdropGradient,
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SpeakingIndicatorBorder(
            isSpeaking: isSpeaking && !isMuted && !isRemoteMuted,
            shape: BoxShape.circle,
            borderWidth: 4,
            speakingColor: callUi.speakingRing,
            child: AppAvatar(
              imageUrl: photoUrl,
              name: name,
              size: 180,
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
            ),
          ),
          if (isRemoteMuted)
            Positioned(
              bottom: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: callUi.mutedBadgeBackground,
                  borderRadius: AppRadius.brPill,
                  boxShadow: [
                    BoxShadow(
                      color: callUi.groupTileShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.mic_off,
                      color: callUi.actionReject,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Micro coupé',
                      style: TextStyle(
                        color: callUi.mutedBadgeOnBackground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
