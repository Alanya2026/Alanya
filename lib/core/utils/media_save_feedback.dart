import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Retours utilisateur communs à l'enregistrement manuel d'un média, partagés
/// entre la visionneuse plein écran et le menu d'appui long sur un message.
///
/// Le libellé suit la destination réelle du fichier : photos et vidéos
/// rejoignent l'album galerie, les documents le dossier Téléchargements.
/// Promettre la galerie puis déposer ailleurs ferait douter de tout le reste.
class MediaSaveFeedback {
  MediaSaveFeedback._();

  /// True pour les types qui atterrissent réellement dans la galerie.
  static bool goesToGallery(int type) => type == 1 || type == 2;

  /// Libellé de l'action (menu, bouton).
  static String actionLabel(BuildContext context, int type) =>
      goesToGallery(type)
          ? context.l10n.mediaSaveToGallery
          : context.l10n.mediaSaveToDownloads;

  static void showSaved(BuildContext context, int type) {
    final l10n = context.l10n;
    _show(
      context,
      SnackBar(
        content: Text(goesToGallery(type)
            ? l10n.mediaSavedToGallery
            : l10n.mediaSavedToDownloads),
      ),
    );
  }

  static void showFailed(BuildContext context) {
    _show(context, SnackBar(content: Text(context.l10n.mediaSaveFailed)));
  }

  /// Média déjà exporté : on l'annonce au lieu de créer un doublon en silence,
  /// et on laisse l'utilisateur en décider.
  static void showAlreadySaved(
    BuildContext context,
    int type, {
    required VoidCallback onSaveAgain,
  }) {
    final l10n = context.l10n;
    _show(
      context,
      SnackBar(
        content: Text(goesToGallery(type)
            ? l10n.mediaAlreadyInGallery
            : l10n.mediaAlreadyInDownloads),
        action: SnackBarAction(
          label: l10n.mediaSaveAgain,
          onPressed: onSaveAgain,
        ),
      ),
    );
  }

  static void _show(BuildContext context, SnackBar bar) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(bar);
  }
}
