import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../common/app_avatar.dart';

/// Overlay centré pour les états outgoing / connecting.
class CallConnectingOverlay extends StatelessWidget {
  const CallConnectingOverlay({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.message,
    this.animation,
  });

  final String name;
  final String? photoUrl;
  final String message;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final colors = context.colors;

    Widget avatar = AppAvatar(
      imageUrl: photoUrl,
      name: name,
      size: 148,
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: AppColors.white,
      showShadow: true,
    );

    if (animation != null) {
      avatar = AnimatedBuilder(
        animation: animation!,
        builder: (_, child) {
          return Transform.scale(scale: animation!.value, child: child);
        },
        child: avatar,
      );
    }

    return Container(
      color: callUi.backgroundSolid,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          AppSpacing.vGapXxl,
          Text(
            name,
            style: TextStyle(
              color: callUi.onBackground,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vGapMd,
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.primary,
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            message,
            style: TextStyle(
              color: callUi.onBackgroundMuted,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar pulsant pour l'écran d'appel entrant.
class CallIncomingAvatarPulse extends StatelessWidget {
  const CallIncomingAvatarPulse({
    super.key,
    required this.animation,
    required this.name,
    required this.imageUrl,
  });

  final Animation<double> animation;
  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

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
                      color: callUi.avatarHalo.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: animation.value * 0.92,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: callUi.avatarHaloInner.withValues(alpha: 0.5),
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

/// Pill animée « Appel entrant » avec icône.
class CallIncomingHeaderPill extends StatelessWidget {
  const CallIncomingHeaderPill({
    super.key,
    required this.icon,
    required this.label,
    required this.pulseAnimation,
  });

  final IconData icon;
  final String label;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, __) {
        final opacity = 0.55 + (pulseAnimation.value - 0.96) * 2.5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: callUi.chipBackground,
            borderRadius: AppRadius.brPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: callUi.chipOnBackground.withValues(alpha: opacity.clamp(0.4, 1.0)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: callUi.chipOnBackground.withValues(alpha: 0.85),
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
