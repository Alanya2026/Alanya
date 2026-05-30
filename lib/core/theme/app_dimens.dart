import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Échelle d'espacement — **source unique** pour paddings, marges et gaps.
///
/// Historiquement l'app utilisait 4/6/8/10/12/14/16/20/24/32 sans logique.
/// On normalise sur une échelle 4-points ; les valeurs intermédiaires
/// (6/10/14) sont arrondies au token le plus proche.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // Gaps verticaux/horizontaux prêts à l'emploi (évite SizedBox(height: …)).
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);
  static const SizedBox vGapXxl = SizedBox(height: xxl);

  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);

  /// Marge horizontale standard d'un écran.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);

  /// Padding standard d'une carte / d'un conteneur posé.
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Échelle de rayons d'angle. Avant : 6/8/10/12/14/16/20/24/28 mélangés.
class AppRadius {
  AppRadius._();

  /// Boutons, champs, petits éléments.
  static const double sm = 12;

  /// Cartes, tuiles, conteneurs.
  static const double md = 16;

  /// Bottom sheets, grands conteneurs.
  static const double lg = 20;

  /// Pilules, barre de navigation, boutons ronds.
  static const double pill = 28;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Coins supérieurs arrondis (bottom sheets).
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Tailles d'icônes normalisées. Avant : 18/20/22/24/26/32/44/52/80.
class AppIconSize {
  AppIconSize._();

  static const double sm = 20;
  static const double md = 24;
  static const double lg = 28;
  static const double xl = 44;
}

/// Hauteurs / dimensions de composants récurrents.
class AppSizes {
  AppSizes._();

  /// Hauteur standard d'un bouton / champ tactile (≥ 48 dp accessibilité).
  static const double buttonHeight = 48;

  /// Cible tactile minimale recommandée.
  static const double minTapTarget = 48;

  /// Tailles d'avatar usuelles.
  static const double avatarSm = 40;
  static const double avatarMd = 48;
  static const double avatarLg = 56;
  static const double avatarXl = 72;
}

/// Ombres standard (subtle / medium / strong). Avant : alphas 10/13/18/50 au cas par cas.
class AppShadows {
  AppShadows._();

  /// Ombre discrète — cartes, tuiles posées.
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  /// Ombre moyenne — éléments flottants (FAB, menus).
  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Ombre prononcée — barre de navigation flottante, modaux.
  static const List<BoxShadow> strong = [
    BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Ombre teintée marque (boutons primaires proéminents).
  static List<BoxShadow> brand = [
    BoxShadow(
      color: AppColors.brandPrimary.withAlpha(56),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Durées d'animation cohérentes.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}
