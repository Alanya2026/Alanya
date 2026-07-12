import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Couleurs dédiées aux écrans d'appel actifs (entrant, en cours).
///
/// Accessible via `context.callUi` ou `Theme.of(context).extension<CallUiColors>()`.
@immutable
class CallUiColors extends ThemeExtension<CallUiColors> {
  const CallUiColors({
    required this.backgroundSolid,
    required this.backgroundGradient,
    required this.onBackground,
    required this.onBackgroundMuted,
    required this.controlSurface,
    required this.onControlSurface,
    required this.controlSurfaceActive,
    required this.controlBorder,
    required this.videoChromeSurface,
    required this.onVideoChrome,
    required this.videoControlSurface,
    required this.onVideoControlSurface,
    required this.videoControlActive,
    required this.chromeScrimTop,
    required this.chromeScrimBottom,
    required this.actionAccept,
    required this.actionReject,
    required this.avatarHalo,
    required this.avatarHaloInner,
    required this.speakingRing,
    required this.pipBorder,
    required this.pipShadow,
    required this.chipBackground,
    required this.chipOnBackground,
    required this.mutedBadgeBackground,
    required this.mutedBadgeOnBackground,
    required this.groupBackground,
    required this.groupTileBackground,
    required this.groupTileShadow,
    required this.controlElevation,
  });

  final Color backgroundSolid;
  final List<Color> backgroundGradient;
  final Color onBackground;
  final Color onBackgroundMuted;
  final Color controlSurface;
  final Color onControlSurface;
  final Color controlSurfaceActive;
  final Color controlBorder;
  final Color videoChromeSurface;
  final Color onVideoChrome;
  final Color videoControlSurface;
  final Color onVideoControlSurface;
  final Color videoControlActive;
  final List<Color> chromeScrimTop;
  final List<Color> chromeScrimBottom;
  final Color actionAccept;
  final Color actionReject;
  final Color avatarHalo;
  final Color avatarHaloInner;
  final Color speakingRing;
  final Color pipBorder;
  final Color pipShadow;
  final Color chipBackground;
  final Color chipOnBackground;
  final Color mutedBadgeBackground;
  final Color mutedBadgeOnBackground;
  final Color groupBackground;
  final Color groupTileBackground;
  final Color groupTileShadow;
  final double controlElevation;

  static const CallUiColors light = CallUiColors(
    backgroundSolid: AppColors.background,
    backgroundGradient: [
      AppColors.brandSurfaceTint,
      AppColors.brandContainer,
      AppColors.background,
    ],
    onBackground: AppColors.textPrimary,
    onBackgroundMuted: AppColors.textSecondary,
    controlSurface: AppColors.surface,
    onControlSurface: AppColors.textPrimary,
    controlSurfaceActive: AppColors.surfaceSubtle,
    controlBorder: AppColors.outline,
    videoChromeSurface: AppColors.callChromeDark,
    onVideoChrome: AppColors.white,
    videoControlSurface: Color(0x33FFFFFF),
    onVideoControlSurface: AppColors.white,
    videoControlActive: AppColors.white,
    chromeScrimTop: [Color(0x99000000), Colors.transparent],
    chromeScrimBottom: [Color(0xCC000000), Colors.transparent],
    actionAccept: AppColors.success,
    actionReject: AppColors.error,
    avatarHalo: AppColors.brandPrimary,
    avatarHaloInner: AppColors.brandContainer,
    speakingRing: AppColors.brandPrimary,
    pipBorder: Color(0x3DFFFFFF),
    pipShadow: Color(0x66000000),
    chipBackground: AppColors.brandContainer,
    chipOnBackground: AppColors.brandPrimary,
    mutedBadgeBackground: AppColors.surface,
    mutedBadgeOnBackground: AppColors.textSecondary,
    groupBackground: AppColors.background,
    groupTileBackground: AppColors.surface,
    groupTileShadow: Color(0x1A1A1D23),
    controlElevation: 8,
  );

  static const CallUiColors dark = CallUiColors(
    backgroundSolid: AppColors.immersiveBackground,
    backgroundGradient: [
      AppColors.brandPrimaryDarker,
      AppColors.immersiveBackground,
      AppColors.black,
    ],
    onBackground: AppColors.white,
    onBackgroundMuted: Color(0x8FFFFFFF),
    controlSurface: Color(0xCC1B2147),
    onControlSurface: AppColors.white,
    controlSurfaceActive: Color(0x33FFFFFF),
    controlBorder: Color(0x33FFFFFF),
    videoChromeSurface: AppColors.callChromeDark,
    onVideoChrome: AppColors.white,
    videoControlSurface: Color(0x2EFFFFFF),
    onVideoControlSurface: AppColors.white,
    videoControlActive: AppColors.white,
    chromeScrimTop: [Color(0x99000000), Colors.transparent],
    chromeScrimBottom: [Color(0xDE000000), Colors.transparent],
    actionAccept: AppColors.success,
    actionReject: AppColors.error,
    avatarHalo: AppColors.brandPrimary,
    avatarHaloInner: Color(0x1F3F51B5),
    speakingRing: Color(0xFF7C5CFC),
    pipBorder: Color(0x3DFFFFFF),
    pipShadow: Color(0x99000000),
    chipBackground: Color(0x331B2147),
    chipOnBackground: Color(0xCCFFFFFF),
    mutedBadgeBackground: Color(0xA6000000),
    mutedBadgeOnBackground: Color(0xB3FFFFFF),
    groupBackground: AppColors.black,
    groupTileBackground: AppColors.immersiveSurface,
    groupTileShadow: Color(0x66000000),
    controlElevation: 0,
  );

  LinearGradient get backgroundGradientDecoration => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: backgroundGradient,
      );

  LinearGradient get audioBackdropGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: backgroundGradient.length >= 2
            ? [backgroundGradient.first, backgroundGradient.last]
            : [backgroundSolid, backgroundSolid],
      );

  @override
  CallUiColors copyWith({
    Color? backgroundSolid,
    List<Color>? backgroundGradient,
    Color? onBackground,
    Color? onBackgroundMuted,
    Color? controlSurface,
    Color? onControlSurface,
    Color? controlSurfaceActive,
    Color? controlBorder,
    Color? videoChromeSurface,
    Color? onVideoChrome,
    Color? videoControlSurface,
    Color? onVideoControlSurface,
    Color? videoControlActive,
    List<Color>? chromeScrimTop,
    List<Color>? chromeScrimBottom,
    Color? actionAccept,
    Color? actionReject,
    Color? avatarHalo,
    Color? avatarHaloInner,
    Color? speakingRing,
    Color? pipBorder,
    Color? pipShadow,
    Color? chipBackground,
    Color? chipOnBackground,
    Color? mutedBadgeBackground,
    Color? mutedBadgeOnBackground,
    Color? groupBackground,
    Color? groupTileBackground,
    Color? groupTileShadow,
    double? controlElevation,
  }) {
    return CallUiColors(
      backgroundSolid: backgroundSolid ?? this.backgroundSolid,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      onBackground: onBackground ?? this.onBackground,
      onBackgroundMuted: onBackgroundMuted ?? this.onBackgroundMuted,
      controlSurface: controlSurface ?? this.controlSurface,
      onControlSurface: onControlSurface ?? this.onControlSurface,
      controlSurfaceActive: controlSurfaceActive ?? this.controlSurfaceActive,
      controlBorder: controlBorder ?? this.controlBorder,
      videoChromeSurface: videoChromeSurface ?? this.videoChromeSurface,
      onVideoChrome: onVideoChrome ?? this.onVideoChrome,
      videoControlSurface: videoControlSurface ?? this.videoControlSurface,
      onVideoControlSurface: onVideoControlSurface ?? this.onVideoControlSurface,
      videoControlActive: videoControlActive ?? this.videoControlActive,
      chromeScrimTop: chromeScrimTop ?? this.chromeScrimTop,
      chromeScrimBottom: chromeScrimBottom ?? this.chromeScrimBottom,
      actionAccept: actionAccept ?? this.actionAccept,
      actionReject: actionReject ?? this.actionReject,
      avatarHalo: avatarHalo ?? this.avatarHalo,
      avatarHaloInner: avatarHaloInner ?? this.avatarHaloInner,
      speakingRing: speakingRing ?? this.speakingRing,
      pipBorder: pipBorder ?? this.pipBorder,
      pipShadow: pipShadow ?? this.pipShadow,
      chipBackground: chipBackground ?? this.chipBackground,
      chipOnBackground: chipOnBackground ?? this.chipOnBackground,
      mutedBadgeBackground: mutedBadgeBackground ?? this.mutedBadgeBackground,
      mutedBadgeOnBackground: mutedBadgeOnBackground ?? this.mutedBadgeOnBackground,
      groupBackground: groupBackground ?? this.groupBackground,
      groupTileBackground: groupTileBackground ?? this.groupTileBackground,
      groupTileShadow: groupTileShadow ?? this.groupTileShadow,
      controlElevation: controlElevation ?? this.controlElevation,
    );
  }

  @override
  CallUiColors lerp(ThemeExtension<CallUiColors>? other, double t) {
    if (other is! CallUiColors) return this;
    return CallUiColors(
      backgroundSolid: Color.lerp(backgroundSolid, other.backgroundSolid, t)!,
      backgroundGradient: [
        Color.lerp(backgroundGradient[0], other.backgroundGradient[0], t)!,
        Color.lerp(backgroundGradient[1], other.backgroundGradient[1], t)!,
        Color.lerp(backgroundGradient[2], other.backgroundGradient[2], t)!,
      ],
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onBackgroundMuted: Color.lerp(onBackgroundMuted, other.onBackgroundMuted, t)!,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      onControlSurface: Color.lerp(onControlSurface, other.onControlSurface, t)!,
      controlSurfaceActive:
          Color.lerp(controlSurfaceActive, other.controlSurfaceActive, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      videoChromeSurface: Color.lerp(videoChromeSurface, other.videoChromeSurface, t)!,
      onVideoChrome: Color.lerp(onVideoChrome, other.onVideoChrome, t)!,
      videoControlSurface:
          Color.lerp(videoControlSurface, other.videoControlSurface, t)!,
      onVideoControlSurface:
          Color.lerp(onVideoControlSurface, other.onVideoControlSurface, t)!,
      videoControlActive: Color.lerp(videoControlActive, other.videoControlActive, t)!,
      chromeScrimTop: [
        Color.lerp(chromeScrimTop[0], other.chromeScrimTop[0], t)!,
        Color.lerp(chromeScrimTop[1], other.chromeScrimTop[1], t)!,
      ],
      chromeScrimBottom: [
        Color.lerp(chromeScrimBottom[0], other.chromeScrimBottom[0], t)!,
        Color.lerp(chromeScrimBottom[1], other.chromeScrimBottom[1], t)!,
      ],
      actionAccept: Color.lerp(actionAccept, other.actionAccept, t)!,
      actionReject: Color.lerp(actionReject, other.actionReject, t)!,
      avatarHalo: Color.lerp(avatarHalo, other.avatarHalo, t)!,
      avatarHaloInner: Color.lerp(avatarHaloInner, other.avatarHaloInner, t)!,
      speakingRing: Color.lerp(speakingRing, other.speakingRing, t)!,
      pipBorder: Color.lerp(pipBorder, other.pipBorder, t)!,
      pipShadow: Color.lerp(pipShadow, other.pipShadow, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipOnBackground: Color.lerp(chipOnBackground, other.chipOnBackground, t)!,
      mutedBadgeBackground:
          Color.lerp(mutedBadgeBackground, other.mutedBadgeBackground, t)!,
      mutedBadgeOnBackground:
          Color.lerp(mutedBadgeOnBackground, other.mutedBadgeOnBackground, t)!,
      groupBackground: Color.lerp(groupBackground, other.groupBackground, t)!,
      groupTileBackground:
          Color.lerp(groupTileBackground, other.groupTileBackground, t)!,
      groupTileShadow: Color.lerp(groupTileShadow, other.groupTileShadow, t)!,
      controlElevation: controlElevation + (other.controlElevation - controlElevation) * t,
    );
  }
}

/// Utilitaires pour les écrans d'appel : barre système et mode chrome vidéo.
class CallUiScope {
  CallUiScope._();

  static bool useVideoChrome({required bool isVideo}) => isVideo;

  static SystemUiOverlayStyle systemOverlayStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
  }

  static SystemUiOverlayStyle systemOverlayStyleForVideo() {
    return SystemUiOverlayStyle.light;
  }

  static void applyOverlayStyle(BuildContext context, {required bool isVideo}) {
    SystemChrome.setSystemUIOverlayStyle(
      isVideo ? systemOverlayStyleForVideo() : systemOverlayStyle(context),
    );
  }
}
