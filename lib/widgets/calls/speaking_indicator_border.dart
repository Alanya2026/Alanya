import 'package:flutter/material.dart';

/// Couleur standard de l'indicateur "locuteur actif", utilisée sur tous les
/// écrans d'appel (1-1, groupe, meeting) pour rester cohérent visuellement.
const Color kSpeakingIndicatorColor = Color(0xFF7C5CFC);

/// Enrobe [child] d'une bordure (+ léger glow) violette qui s'anime en
/// fondu lorsque [isSpeaking] est vrai. Réutilisé par les tuiles vidéo des
/// appels de groupe, des meetings, et par l'avatar des appels 1-1.
///
/// Le fondu (`AnimatedContainer`) est volontairement assez rapide mais pas
/// instantané, pour accompagner l'hystérésis du `SpeakingDetector` et éviter
/// un effet "clignotant" agressif.
class SpeakingIndicatorBorder extends StatelessWidget {
  const SpeakingIndicatorBorder({
    super.key,
    required this.isSpeaking,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.shape = BoxShape.rectangle,
    this.borderWidth = 3,
  });

  final bool isSpeaking;
  final Widget child;

  /// Ignoré si [shape] == [BoxShape.circle].
  final BorderRadius borderRadius;
  final BoxShape shape;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
        border: Border.all(
          color: isSpeaking
              ? kSpeakingIndicatorColor
              : Colors.transparent,
          width: borderWidth,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: kSpeakingIndicatorColor.withValues(alpha: 0.55),
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