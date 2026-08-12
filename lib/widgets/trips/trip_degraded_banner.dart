import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/services/trip_session_guard.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'trip_visuals.dart';

/// Ce qui ne va pas, quand quelque chose ne va pas.
enum TripDegraded { aucun, permission, signalPerdu, batterieFaible }

/// Bandeau des états dégradés.
///
/// **La règle de palette la plus importante du volet est ici : un signal perdu
/// est gris, jamais rouge.** Le rouge signifie une seule chose — le cercle a
/// été prévenu. Colorer en rouge un GPS qui a lâché, c'est apprendre à
/// l'utilisateur que le rouge ne veut rien dire, et le jour où il compte
/// vraiment, il ne sera plus lu.
///
/// Chaque état dit aussi **ce qui tient malgré tout** : l'échéance est gardée
/// par le serveur et continue de courir sans une seule position. Sans cette
/// phrase, une dégradation se lit comme une panne.
class TripDegradedBanner extends StatelessWidget {
  const TripDegradedBanner({super.key, required this.trip, this.onAction});

  final LocalTrip trip;
  final VoidCallback? onAction;

  TripDegraded get _etat {
    final guard = TripSessionGuard.instance;
    if (guard.isActive && guard.tripId == trip.id && !guard.isStreaming) {
      return TripDegraded.permission;
    }
    if ((trip.lastBattery ?? 100) <= 15) return TripDegraded.batterieFaible;
    if (trip.stale) return TripDegraded.signalPerdu;
    return TripDegraded.aucun;
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    if (etat == TripDegraded.aucun) return const SizedBox.shrink();

    final l10n = context.l10n;
    final sem = context.semantic;

    // Ni l'un ni l'autre n'est rouge — aucun de ces états n'a prévenu le
    // cercle.
    final (couleur, icone, titre, corps) = switch (etat) {
      TripDegraded.permission => (
          sem.warning,
          Icons.location_disabled,
          l10n.tripsDegradedPermission,
          l10n.tripsDegradedPermissionBody,
        ),
      TripDegraded.batterieFaible => (
          sem.warning,
          Icons.battery_alert_outlined,
          l10n.tripsDegradedBattery,
          l10n.tripsDegradedBatteryBody,
        ),
      _ => (
          context.colors.onSurfaceVariant,
          Icons.cloud_off,
          l10n.tripsDegradedStale,
          l10n.tripsDegradedStaleBody,
        ),
    };

    // Le titre prend l'encre dérivée : `warning` (#F59E0B) posé en texte sur
    // fond clair plafonne à 2:1 — un avertissement illisible n'avertit personne.
    final encre = TripVisual.encre(context, couleur);

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        // Carte encadrée plutôt que bandeau pleine largeur : posé entre la
        // rampe et la carte, un aplat de plus se lisait comme une troisième
        // barre d'état. Encadré, il se lit comme ce qu'il est — une remarque.
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: couleur.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône ET texte : la couleur ne porte jamais seule le sens.
            Icon(icone, size: AppIconSize.sm, color: encre),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: context.text.labelLarge?.copyWith(
                          color: encre, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(corps,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (etat == TripDegraded.permission && onAction != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onAction,
                child: Text(l10n.tripsDegradedFix),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
