import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// L'explication qui précède la demande système de localisation.
///
/// Elle existe pour une raison mécanique : **la boîte de dialogue d'Android et
/// d'iOS ne se montre qu'une fois.** Un « Refuser » réflexe est définitif, et
/// se répare ensuite dans les réglages du téléphone — un endroit où presque
/// personne ne va. Demander sans avoir expliqué, c'est donc dépenser son unique
/// chance sur un utilisateur qui n'a aucun contexte.
///
/// Deux phrases seulement, et la seconde est la plus importante : elle dit ce
/// qu'Alanya **ne fait pas**. Une application de sûreté qui demande la position
/// doit répondre à « et le reste du temps ? » avant qu'on ait à le demander,
/// sinon la réponse par défaut est la mauvaise.
///
/// Elle ne s'affiche que si l'autorisation manque encore, et **jamais avant un
/// SOS** : dans ce parcours, chaque seconde entre l'appui et l'alerte est prise
/// sur celle qui en a besoin.
class TripPermissionSheet extends StatelessWidget {
  const TripPermissionSheet({super.key});

  /// Vrai si l'on peut émettre des positions.
  static Future<bool> _dejaAccorde() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      // Plateforme sans géolocalisation : on n'a rien à expliquer, et le garde
      // gèrera l'absence de flux honnêtement.
      return true;
    }
  }

  /// Explique, puis laisse le système demander.
  ///
  /// Renvoie `true` si l'on peut poursuivre — c'est-à-dire dans tous les cas
  /// sauf un refus explicite de la feuille. **Un « Plus tard » ne bloque pas le
  /// départ** : l'échéance est gardée par le serveur, un trajet sans position
  /// reste un trajet utile, et refuser de partir punirait quelqu'un qui a de
  /// bonnes raisons de ne pas partager sa position en continu.
  static Future<bool> demander(BuildContext context) async {
    if (await _dejaAccorde()) return true;
    if (!context.mounted) return true;

    final accepte = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => const TripPermissionSheet(),
    );

    // L'appel système part APRÈS la feuille, jamais pendant : deux boîtes de
    // dialogue empilées ne se lisent pas, et c'est celle du système qui décide.
    if (accepte == true) {
      try {
        await Geolocator.requestPermission();
      } catch (_) {
        // Refus ou plateforme muette : le garde le constatera et l'écran de
        // suivi affichera le bandeau « localisation désactivée ».
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.semantic.brandContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.my_location,
                    size: 28, color: context.colors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.tripsPermissionTitle,
              textAlign: TextAlign.center,
              style:
                  context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.tripsPermissionBody,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),

            // La limite, encadrée. C'est la phrase qui décide du « Autoriser » :
            // ce qu'on promet de ne pas faire pèse plus que ce qu'on demande.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                borderRadius: AppRadius.brSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: AppIconSize.sm, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.tripsPermissionNever,
                      style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
              child: Text(l10n.tripsPermissionAllow,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.tripsPermissionLater),
            ),
          ],
        ),
      ),
    );
  }
}
