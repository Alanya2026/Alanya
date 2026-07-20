import 'package:flutter/material.dart';

/// Palette brute de Talky — **source unique de vérité** pour les couleurs.
///
/// Aucune couleur ne doit être codée en dur ailleurs dans l'app : on passe
/// toujours par ces constantes, par le `ColorScheme` (cf. [app_theme.dart])
/// ou par [AppSemanticColors].
///
/// Historiquement l'app mélangeait 4 indigos concurrents (`Colors.indigo`,
/// `0xFF1E66D8`, `0xFF3949AB`, `0xFF1A237E`). On les unifie ici en une seule
/// échelle de marque dérivée de l'indigo « action » `0xFF1E66D8`.
class AppColors {
  AppColors._();

  // ── Marque (indigo unifié) ────────────────────────────────────────────
  // Teinte historique de l'app : le `Colors.indigo` de Material (#3F51B5),
  // la couleur dominante d'origine. Les 3 autres indigos concurrents
  // (#1E66D8, #3949AB, #1A237E) sont unifiés autour de cette échelle.
  /// Indigo principal — boutons, accents, états actifs, liens.
  static const Color brandPrimary = Color(0xFF3F51B5); // Colors.indigo

  /// Variante foncée — fonds immersifs (appels, vidéo, réunions).
  static const Color brandPrimaryDark = Color(0xFF1A237E); // indigo.shade900

  /// Variante encore plus profonde pour les dégradés d'appel.
  static const Color brandPrimaryDarker = Color(0xFF0D123E);

  /// Indigo soutenu (hover/pressed, dégradés clairs).
  static const Color brandPrimaryStrong = Color(0xFF303F9F); // indigo.shade700

  /// Conteneur clair (fonds de badges, surfaces teintées, sélection).
  static const Color brandContainer = Color(0xFFE8EAF6); // indigo.shade50

  /// Teinte indigo très claire (séparateurs, fonds subtils branchés).
  static const Color brandSurfaceTint = Color(0xFFF2F3FB);

  // ── Neutres ───────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Fond d'écran par défaut.
  static const Color background = Color(0xFFF6F7FB);

  /// Surface des cartes / éléments posés sur le fond.
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface secondaire atténuée (champs, sections, fonds discrets).
  static const Color surfaceMuted = Color(0xFFF4F5F8);

  /// Surface tertiaire (survol de tuiles, états pressés clairs).
  static const Color surfaceSubtle = Color(0xFFEDEFF4);

  /// Bordures / séparateurs.
  static const Color outline = Color(0xFFE2E5EC);

  /// Bordures plus marquées (inputs au repos, dividers visibles).
  static const Color outlineStrong = Color(0xFFCBD0E0);

  // ── Texte ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF5B6273);
  static const Color textTertiary = Color(0xFF9AA0AE);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ── Sémantiques ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF1FA363);
  static const Color successContainer = Color(0xFFE2F6EC);

  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFDECEC);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFDF1DC);

  static const Color info = Color(0xFF2E90FA);
  static const Color infoContainer = Color(0xFFE5F1FF);

  /// Indicateur de présence « en ligne ».
  static const Color online = Color(0xFF1FA363);

  // ── Surfaces immersives (appels / réunions / médias) ──
  /// Fond immersif clair (appels audio en mode clair).
  static const Color immersiveBackgroundLight = Color(0xFFF2F3FB);

  /// Surface immersive claire (tuiles, contrôles en mode clair).
  static const Color immersiveSurfaceLight = Color(0xFFE8EAF6);

  /// Fond immersif sombre (appels vidéo, mode sombre).
  static const Color immersiveBackground = Color(0xFF0E1330);

  /// Surface immersive sombre.
  static const Color immersiveSurface = Color(0xFF1B2147);

  /// Chrome semi-transparent pour contrôles vidéo.
  static const Color callChromeDark = Color(0xCC1A1D23);

  static const Color overlayScrim = Color(0x99000000);

  // ── Mode sombre (stub — à compléter lors de l'activation) ─────────────
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF181B21);
  static const Color darkSurfaceMuted = Color(0xFF1F232B);
  /// Bordures / séparateurs en sombre — distinct de `surfaceContainerHighest`
  /// (évite pouce/piste de Switch confondus quand on utilise `outline`).
  static const Color darkOutline = Color(0xFF3A404C);
  static const Color darkTextPrimary = Color(0xFFF2F4F8);
  static const Color darkTextSecondary = Color(0xFFAAB1C0);
  static const Color darkTextTertiary = Color(0xFF6F7787);

  // ── Barre de navigation flottante « glass » ───────────────────────────
  // Alpha pré-calculé dans le canal ARGB (pour rester `const`) : le panneau
  // givré s'éclaircit par rapport au fond (blanc translucide en clair,
  // surface élevée translucide en sombre) et le liseré capte la lumière.
  /// Fond du panneau (blanc translucide, alpha 130).
  static const Color navGlass = Color(0x82FFFFFF);
  /// Liseré du panneau (blanc franc, alpha 150).
  static const Color navGlassBorder = Color(0x96FFFFFF);
  /// Anneau des badges posés sur le panneau (couleur du panneau, opaque).
  static const Color navGlassBadgeBorder = white;

  /// Fond du panneau en sombre (surfaceContainerHigh translucide, alpha 205).
  static const Color darkNavGlass = Color(0xCD242832);
  /// Liseré du panneau en sombre (blanc très discret, alpha 20).
  static const Color darkNavGlassBorder = Color(0x14FFFFFF);
  /// Anneau des badges en sombre (couleur du panneau, opaque).
  static const Color darkNavGlassBadgeBorder = Color(0xFF242832);
}
