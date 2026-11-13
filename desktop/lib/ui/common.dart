// Couleurs, accès aux services, formats : partagés par tous les écrans.

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/session.dart';
import '../core/settings.dart';
import '../core/vault.dart';
import '../l10n/app_localizations.dart';

/// Couleurs des maquettes (indigo de l'application mobile).
abstract final class Palette {
  static const brand = Color(0xFF3F51B5);
  static const brandDark = Color(0xFF283593);
  static const brandContainer = Color(0xFFE8EAF6);
  static const text = Color(0xFF1B1C22);
  static const muted = Color(0xFF5B5F6E);
  static const border = Color(0xFFE3E5EE);
  static const background = Color(0xFFF5F6FA);
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFF8A5A00);
  static const warningContainer = Color(0xFFFFF4E0);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.brand, primary: Palette.brand, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.background,
    dividerColor: Palette.border,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Palette.border),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Palette.text),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Palette.text),
      bodyMedium: TextStyle(fontSize: 14, color: Palette.text),
      bodySmall: TextStyle(fontSize: 13, color: Palette.muted),
    ),
  );
}

/// Les services de l'application, pour tous les écrans.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.session, required this.locale, required this.vault, required super.child});

  final Session session;
  final LocaleSetting locale;

  /// Nul hors connexion.
  final Vault? vault;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => old.vault != vault || old.session != session || old.locale != locale;
}

extension Contexte on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
  Vault get vault => AppScope.of(this).vault!;
}

/// « 640 Mo », « 1,95 Go », « 640 MB »… Même calcul que l'application mobile
/// (lib/core/utils/byte_format.dart) : 1 Go = 1024 Mo, sinon les deux
/// applications n'affichent pas le même espace.
String formatBytes(BuildContext context, int bytes) {
  final l = context.l;
  final locale = Localizations.localeOf(context).toLanguageTag();
  String n(double v, int decimales) =>
      NumberFormat(decimales == 0 ? '#,##0' : '#,##0.${'#' * decimales}', locale).format(v);
  if (bytes < 1024) return l.bytesB(bytes);
  final ko = bytes / 1024;
  if (ko < 1024) return l.bytesKB(n(ko, 0));
  final mo = ko / 1024;
  if (mo < 1024) return l.bytesMB(n(mo, 1));
  return l.bytesGB(n(mo / 1024, 2));
}

String rootName(BuildContext context, SafeboxRoot r) {
  final l = context.l;
  return switch (r) {
    SafeboxRoot.photos => l.rootPhotos,
    SafeboxRoot.videos => l.rootVideos,
    SafeboxRoot.audios => l.rootAudios,
    SafeboxRoot.documents => l.rootDocuments,
    SafeboxRoot.albums => l.rootAlbums,
    SafeboxRoot.partager => l.rootShare,
  };
}

IconData rootIcon(SafeboxRoot r) => switch (r) {
      SafeboxRoot.photos => Icons.photo_outlined,
      SafeboxRoot.videos => Icons.videocam_outlined,
      SafeboxRoot.audios => Icons.music_note_outlined,
      SafeboxRoot.documents => Icons.description_outlined,
      SafeboxRoot.albums => Icons.grid_view_outlined,
      SafeboxRoot.partager => Icons.send_outlined,
    };

IconData familyIcon(SafeboxFamily f) => switch (f) {
      SafeboxFamily.photos => Icons.photo_outlined,
      SafeboxFamily.videos => Icons.videocam_outlined,
      SafeboxFamily.audios => Icons.music_note_outlined,
      SafeboxFamily.documents => Icons.description_outlined,
    };

/// Nom affiché d'un dossier : le nom traduit pour une racine.
String folderName(BuildContext context, SafeboxFolder f) => f.name ?? rootName(context, f.root);

/// Texte d'une erreur pour l'écran : jamais la prose du serveur.
String errorText(BuildContext context, Object? e) {
  final l = context.l;
  if (e is SafeboxHttpException) {
    if (e.statusCode == 0) return l.errorNetwork;
    switch (e.code) {
      case 'SAFEBOX_NAME_TAKEN':
        return l.errorNameTaken;
      case 'SAFEBOX_WRONG_FAMILY':
        return l.errorWrongFamily;
      case 'SAFEBOX_INVALID_MOVE':
        return l.errorInvalidMove;
      case 'SAFEBOX_TOO_DEEP':
        return l.errorTooDeep;
      case 'SAFEBOX_FOLDER_LIMIT':
        return l.errorFolderLimit;
      case 'SAFEBOX_INVALID_NAME':
        return l.errorInvalidName;
      case 'SAFEBOX_ROOT_LOCKED':
        return l.errorRootLocked;
      case 'SAFEBOX_NOT_FOUND':
        return l.errorNotFound;
      case 'SAFEBOX_QUOTA_EXCEEDED':
        return l.uploadErrorQuota;
    }
  }
  return l.errorGeneric;
}

/// Bloc d'erreur avec « Réessayer ».
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: Palette.muted),
          const SizedBox(height: 12),
          Text(errorText(context, error), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(context.l.retry)),
        ]),
      );
}
