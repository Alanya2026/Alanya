import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bornes alignées sur celles du serveur (`authCustomController.AGE_MIN/MAX`).
const int kAgeMin = 13;
const int kAgeMax = 120;

/// Valeurs acceptées par la colonne `users.genre`.
enum ProfileGender { homme, femme, autre, nonPrecise }

extension ProfileGenderApi on ProfileGender {
  String get apiValue => switch (this) {
        ProfileGender.homme => 'homme',
        ProfileGender.femme => 'femme',
        ProfileGender.autre => 'autre',
        ProfileGender.nonPrecise => 'non_precise',
      };

  String label(BuildContext context) => switch (this) {
        ProfileGender.homme => context.l10n.profileGenderMale,
        ProfileGender.femme => context.l10n.profileGenderFemale,
        ProfileGender.autre => context.l10n.profileGenderOther,
        ProfileGender.nonPrecise => context.l10n.profileGenderUnspecified,
      };

  /// Libellé court pour la barre segmentée (écran Modifier le profil).
  String segmentLabel(BuildContext context) => switch (this) {
        ProfileGender.homme => context.l10n.profileGenderMale,
        ProfileGender.femme => context.l10n.profileGenderFemale,
        ProfileGender.autre => context.l10n.profileGenderOther,
        ProfileGender.nonPrecise => context.l10n.profileGenderSegmentPreferNotSay,
      };

  static ProfileGender? fromApi(String? value) {
    for (final g in ProfileGender.values) {
      if (g.apiValue == value) return g;
    }
    return null;
  }
}
