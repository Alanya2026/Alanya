import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/trip_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/trips/trip_live_screen.dart';
import '../../talky_models.dart';
import 'trip_visuals.dart';

/// Bandeau persistant du trajet en cours, posé **au-dessus** de la barre de
/// navigation.
///
/// C'est la réponse au fait que la barre est figée à cinq onglets
/// (`glass_nav_bar.dart`, `List.generate(5, …)`) : le bandeau est visible sur
/// les cinq, tapotable, et occupe l'espace déjà réservé par
/// `kGlassNavBarSpace`. Le sixième onglet sans en être un.
///
/// Il ne s'affiche que si un trajet est ouvert — sinon il rend un
/// [SizedBox.shrink] et ne coûte rien.
class TripBanner extends StatelessWidget {
  const TripBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trips = context.read<TripRepository>();

    return StreamBuilder<LocalTrip?>(
      stream: trips.watchMyOpenTrip(),
      builder: (context, snap) {
        final t = snap.data;
        if (t == null) return const SizedBox.shrink();

        final sem = context.semantic;
        // La couleur EST l'information. Gris pour un signal perdu, jamais
        // rouge : le rouge est réservé au moment où le cercle a été prévenu.
        final (fond, encre) = switch (t.state) {
          TripState.alert || TripState.sos => (context.colors.error, Colors.white),
          TripState.awaitingConfirm => (sem.warning, const Color(0xFF3A2A00)),
          // Fond gris lisible et encre = la surface du thème. L'ancien couple
          // (`outline`, blanc) donnait du blanc sur un gris presque blanc en
          // thème clair : le bandeau existait, son texte non.
          _ when t.stale =>
            (context.colors.onSurfaceVariant, context.colors.surface),
          _ => (sem.success, Colors.white),
        };
        // Le bandeau bat tant que les positions arrivent. C'est la seule chose
        // qu'un utilisateur voit du trajet depuis les cinq onglets, et « est-ce
        // que ça tourne encore ? » est la seule question qu'il se pose.
        final vivant = TripState.isOpen(t.state) &&
            !t.stale &&
            !TripState.isAlerting(t.state);

        final libelle = switch (t.state) {
          TripState.alert || TripState.sos => l10n.tripsAlerted,
          TripState.awaitingConfirm => l10n.tripsAwaitingConfirm,
          _ when t.stale => l10n.tripsStale,
          _ => l10n.tripsInProgress,
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: Material(
            color: fond,
            borderRadius: AppRadius.brSm,
            // Une ombre teintée de sa propre couleur : le bandeau se pose sur le
            // contenu de l'onglet au lieu d'y être collé, sans introduire un
            // gris qui jurerait avec le vert ou le rouge.
            shadowColor: fond.withValues(alpha: 0.5),
            elevation: 4,
            child: InkWell(
              borderRadius: AppRadius.brSm,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripLiveScreen(tripId: t.id, isOwner: true),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 9),
                child: Row(
                  children: [
                    TripPulse(color: encre, size: 7, animate: vivant),
                    const SizedBox(width: 3),
                    Icon(Icons.shield_rounded, size: 15, color: encre),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        libelle,
                        style: context.text.labelLarge?.copyWith(
                            color: encre, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.etaAt != null)
                      Text(
                        _hhmm(t.etaAt!),
                        style: context.text.labelMedium?.copyWith(
                            color: encre.withValues(alpha: 0.92),
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.chevron_right, size: 16, color: encre),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
