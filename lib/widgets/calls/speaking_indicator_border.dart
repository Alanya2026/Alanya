import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Enrobe [child] d'une bordure (+ léger glow) qui s'anime en fondu lorsque
/// [isSpeaking] est vrai. Réutilisé par les tuiles vidéo des appels de groupe,
/// des meetings, et par l'avatar des appels 1-1.
class SpeakingIndicatorBorder extends StatelessWidget {
  const SpeakingIndicatorBorder({
    super.key,
    required this.isSpeaking,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.shape = BoxShape.rectangle,
    this.borderWidth = 3,
    this.speakingColor,
  });

  final bool isSpeaking;
  final Widget child;
  final BorderRadius borderRadius;
  final BoxShape shape;
  final double borderWidth;
  final Color? speakingColor;

  @override
  Widget build(BuildContext context) {
    final color = speakingColor ?? context.callUi.speakingRing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
        border: Border.all(
          color: isSpeaking ? color : Colors.transparent,
          width: borderWidth,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

/// @deprecated Utiliser [SpeakingIndicatorBorder] avec [context.callUi.speakingRing].
const Color kSpeakingIndicatorColor = Color(0xFF7C5CFC);
