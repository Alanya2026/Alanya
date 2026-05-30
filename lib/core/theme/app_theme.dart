import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Extension de thème pour les couleurs sémantiques que `ColorScheme` ne
/// couvre pas nativement (succès, avertissement, info, présence en ligne,
/// conteneur de marque). Accessible via
/// `Theme.of(context).extension<AppSemanticColors>()!` ou le raccourci
/// `context.semantic`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.online,
    required this.brandContainer,
    required this.onBrandContainer,
    required this.surfaceMuted,
    required this.immersiveBackground,
    required this.immersiveSurface,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color online;
  final Color brandContainer;
  final Color onBrandContainer;
  final Color surfaceMuted;
  final Color immersiveBackground;
  final Color immersiveSurface;

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.success,
    onSuccess: AppColors.white,
    successContainer: AppColors.successContainer,
    warning: AppColors.warning,
    onWarning: AppColors.white,
    warningContainer: AppColors.warningContainer,
    info: AppColors.info,
    onInfo: AppColors.white,
    infoContainer: AppColors.infoContainer,
    online: AppColors.online,
    brandContainer: AppColors.brandContainer,
    onBrandContainer: AppColors.brandPrimary,
    surfaceMuted: AppColors.surfaceMuted,
    immersiveBackground: AppColors.immersiveBackground,
    immersiveSurface: AppColors.immersiveSurface,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColors.success,
    onSuccess: AppColors.white,
    successContainer: Color(0xFF143726),
    warning: AppColors.warning,
    onWarning: AppColors.black,
    warningContainer: Color(0xFF3A2C10),
    info: AppColors.info,
    onInfo: AppColors.white,
    infoContainer: Color(0xFF10283F),
    online: AppColors.online,
    brandContainer: Color(0xFF283593),
    onBrandContainer: Color(0xFFC5CAE9),
    surfaceMuted: AppColors.darkSurfaceMuted,
    immersiveBackground: AppColors.immersiveBackground,
    immersiveSurface: AppColors.immersiveSurface,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? online,
    Color? brandContainer,
    Color? onBrandContainer,
    Color? surfaceMuted,
    Color? immersiveBackground,
    Color? immersiveSurface,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      online: online ?? this.online,
      brandContainer: brandContainer ?? this.brandContainer,
      onBrandContainer: onBrandContainer ?? this.onBrandContainer,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      immersiveBackground: immersiveBackground ?? this.immersiveBackground,
      immersiveSurface: immersiveSurface ?? this.immersiveSurface,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      online: Color.lerp(online, other.online, t)!,
      brandContainer: Color.lerp(brandContainer, other.brandContainer, t)!,
      onBrandContainer: Color.lerp(onBrandContainer, other.onBrandContainer, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      immersiveBackground:
          Color.lerp(immersiveBackground, other.immersiveBackground, t)!,
      immersiveSurface: Color.lerp(immersiveSurface, other.immersiveSurface, t)!,
    );
  }
}

/// Raccourcis ergonomiques sur le `BuildContext`.
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Couleurs sémantiques (succès, warning, online…). Toujours non-null car
  /// l'extension est déclarée sur les deux thèmes.
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}

/// Fabrique des thèmes clair / sombre de Talky.
///
/// **Mode sombre** : structure prête mais désactivée à la livraison
/// (`themeMode: ThemeMode.light` dans `main.dart`). Les écrans qui consomment
/// `ColorScheme` / `AppSemanticColors` basculeront automatiquement quand on
/// l'activera.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight ? _lightScheme : _darkScheme;
    final semantic = isLight ? AppSemanticColors.light : AppSemanticColors.dark;
    final textTheme = _textTheme(colorScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      extensions: [semantic],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceMuted,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brSm,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceMuted,
        selectedColor: colorScheme.primary,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: textTheme.bodySmall,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colorScheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colorScheme.primary.withAlpha(120)
              : null,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }

  // ── ColorSchemes ────────────────────────────────────────────────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.textOnBrand,
    primaryContainer: AppColors.brandContainer,
    onPrimaryContainer: AppColors.brandPrimary,
    secondary: AppColors.brandPrimaryStrong,
    onSecondary: AppColors.textOnBrand,
    secondaryContainer: AppColors.brandContainer,
    onSecondaryContainer: AppColors.brandPrimaryDark,
    tertiary: AppColors.info,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.surfaceMuted,
    surfaceContainer: AppColors.surfaceMuted,
    surfaceContainerHigh: AppColors.surfaceSubtle,
    surfaceContainerHighest: AppColors.surfaceSubtle,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineStrong,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.white,
    shadow: AppColors.black,
    scrim: AppColors.black,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9FA8DA), // indigo.shade200
    onPrimary: Color(0xFF1A237E),
    primaryContainer: Color(0xFF283593), // indigo.shade800
    onPrimaryContainer: Color(0xFFC5CAE9),
    secondary: Color(0xFFB0B7E3),
    onSecondary: Color(0xFF1A237E),
    secondaryContainer: Color(0xFF283593),
    onSecondaryContainer: Color(0xFFC5CAE9),
    tertiary: AppColors.info,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: Color(0xFF3A1414),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    surfaceContainerLowest: AppColors.darkBackground,
    surfaceContainerLow: AppColors.darkSurfaceMuted,
    surfaceContainer: AppColors.darkSurfaceMuted,
    surfaceContainerHigh: Color(0xFF242832),
    surfaceContainerHighest: Color(0xFF2C313B),
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF3A404C),
    inverseSurface: AppColors.darkTextPrimary,
    onInverseSurface: AppColors.darkSurface,
    shadow: AppColors.black,
    scrim: AppColors.black,
  );

  // ── TextTheme ───────────────────────────────────────────────────────
  // Échelle unique remplaçant les TextStyle inline (10 → 80 dispersés).
  static TextTheme _textTheme(Color onSurface) {
    final secondary = onSurface.withAlpha(160);
    return TextTheme(
      // Grands titres d'écran (« Discussions », « Appels »…).
      headlineLarge: TextStyle(
        fontSize: 30, fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w700, color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500, color: secondary,
      ),
    );
  }
}
