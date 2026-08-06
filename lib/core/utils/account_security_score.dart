import '../../talky_models.dart';

/// Résultat du calcul de score de sécurité du compte (0–100).
class AccountSecurityScore {
  final int score;
  final int maxScore;
  final List<SecuritySuggestion> suggestionTypes;

  const AccountSecurityScore({
    required this.score,
    this.maxScore = 100,
    this.suggestionTypes = const [],
  });

  double get ratio => maxScore == 0 ? 0 : score / maxScore;

  bool get isStrong => score >= 80;

  bool get isModerate => score >= 50 && score < 80;
}

enum SecuritySuggestion { addEmail, enableBiometric }

/// Calcule un score de sécurité à partir du profil et des protections locales.
///
/// Barème aligné sur la maquette « Mon compte » (base 32 + email 30 + biométrie 38).
AccountSecurityScore calculateAccountSecurityScore({
  required User? user,
  required bool biometricEnabled,
}) {
  const baseScore = 32;
  const emailScore = 30;
  const biometricScore = 38;

  var score = baseScore;
  final suggestionTypes = <SecuritySuggestion>[];

  final hasEmail = user != null && user.email.trim().isNotEmpty;
  if (hasEmail) {
    score += emailScore;
  } else {
    suggestionTypes.add(SecuritySuggestion.addEmail);
  }

  if (biometricEnabled) {
    score += biometricScore;
  } else {
    suggestionTypes.add(SecuritySuggestion.enableBiometric);
  }

  return AccountSecurityScore(
    score: score.clamp(0, 100),
    suggestionTypes: suggestionTypes,
  );
}
