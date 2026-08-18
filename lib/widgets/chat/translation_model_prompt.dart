import 'package:flutter/material.dart';

import '../../core/services/translation/message_translation_service.dart';
import '../../core/services/translation/translation_languages.dart';
import '../../core/theme/app_theme.dart';

/// Propose le téléchargement d'un modèle de langue, puis le télécharge.
///
/// Partagée entre l'écran de réglages et le fil de discussion : quand un
/// utilisateur demande explicitement une traduction, on ne l'envoie pas
/// chercher le modèle ailleurs dans l'application. Il l'obtient là où il est.
///
/// Renvoie `true` si le modèle est disponible à la sortie.
Future<bool> promptTranslationModelDownload(
  BuildContext context,
  String bcpCode,
) async {
  final lang = kTranslationTargets.where((l) => l.code == bcpCode).firstOrNull;
  final store = TranslationModelStore();

  // Langue hors catalogue : elle reste téléchargeable, seul le libellé change.
  final label = lang?.nativeName ?? nativeNameOf(bcpCode);
  if (label.isEmpty) return false;

  if (await store.isDownloaded(bcpCode)) return true;
  if (!context.mounted) return false;

  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.languageModels),
      content: Text(
        '${l10n.downloadLanguageModel(label, kApproxModelSizeMb)}'
        '\n\n${l10n.modelDownloadWifiNotice}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.notNow),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.downloadModel),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  // Bandeau persistant plutôt qu'un dialogue bloquant : le téléchargement dure
  // des dizaines de secondes, et rien n'oblige l'utilisateur à regarder le fil
  // pendant ce temps.
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(minutes: 2),
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(l10n.downloadingModel(label))),
        ],
      ),
    ),
  );

  var success = false;
  try {
    success = await store.download(bcpCode);
  } catch (_) {
    success = false;
  }

  messenger.hideCurrentSnackBar();
  if (!success) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.modelDownloadFailed)),
    );
    return false;
  }

  // Les messages restés en attente de ce modèle redeviennent traitables.
  await MessageTranslationService.maybeInstance?.onModelInstalled();
  return true;
}
