import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_models.dart';
import 'trip_visuals.dart';

/// Les quatre temps d'un trajet : **partir, suivre, confirmer, clore**.
///
/// C'est la seule chose qui reste identique d'un écran à l'autre, et c'est
/// volontaire : elle répond en permanence à « où en suis-je, et que va-t-il se
/// passer ensuite ». Un trajet est un contrat dans le temps ; sans repère, on
/// ne sait pas s'il reste une action à faire.
///
/// La position se lit **sans lire le texte** — trois signaux redondants la
/// portent : le remplissage de la barre, sa couleur, et la marque devant le
/// libellé (coche pour l'acquis, point qui bat pour le temps en cours). Jamais
/// la couleur seule : un daltonien lit la coche, un écran au soleil lit le
/// remplissage.
class TripRail extends StatelessWidget {
  const TripRail({super.key, required this.state, this.stale = false});

  final String state;
  final bool stale;

  /// Indice du temps en cours, ou -1 quand le trajet a basculé en alerte.
  int get _etape => switch (state) {
        TripState.alert || TripState.sos => -1,
        TripState.awaitingConfirm => 2,
        TripState.closedConfirmed ||
        TripState.closedCancelled ||
        TripState.closedExpired ||
        TripState.closedUnwatched =>
          3,
        _ => 1,
      };

  @override
  Widget build(BuildContext context) {
    final sem = context.semantic;
    final l10n = context.l10n;
    final libelles = [
      l10n.tripsRailStart,
      l10n.tripsRailFollow,
      l10n.tripsRailConfirm,
      l10n.tripsRailClose,
    ];
    final etape = _etape;
    final enAlerte = etape < 0;

    return Semantics(
      // Un lecteur d'écran doit obtenir l'étape, pas quatre barres muettes.
      label: enAlerte
          ? l10n.tripsAlerted
          : '${libelles[etape]} — ${etape + 1}/4',
      excludeSemantics: true,
      child: Container(
        color: context.colors.surface,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < libelles.length; i++) ...[
              Expanded(child: _pas(context, i, libelles[i], etape, sem)),
              // 8 px entre deux segments : en dessous, ils se lisent comme une
              // seule barre continue.
              if (i < libelles.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pas(BuildContext context, int i, String libelle, int etape,
      dynamic sem) {
    final enAlerte = etape < 0;
    // En alerte, les deux premiers temps sont acquis et le troisième vire au
    // rouge : c'est là que la promesse a été rompue.
    final (couleur, actif, acquis) = switch (true) {
      _ when enAlerte && i < 2 => (sem.success, true, true),
      _ when enAlerte && i == 2 => (context.colors.error, true, false),
      _ when enAlerte => (context.colors.outlineVariant, false, false),
      _ when i < etape => (sem.success, true, true),
      _ when i == etape =>
        (stale
            ? context.colors.onSurfaceVariant
            : context.colors.primary, true, false),
      _ => (context.colors.outlineVariant, false, false),
    };
    final courant = !acquis && actif;
    // La barre garde le remplissage, le libellé prend l'encre : à 10,5 px, le
    // vert et l'ambre de la palette passent sous le seuil de lisibilité — sur
    // fond clair pour l'ambre, sur fond sombre pour le vert.
    final encre = TripVisual.encre(context, couleur);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // La transition est animée : quand le trajet change de temps sous les
        // yeux — l'échéance tombe, l'alerte part — la barre doit glisser, pas
        // sauter. Un saut se lit comme un rechargement d'écran.
        AnimatedContainer(
          duration: AppDurations.normal,
          curve: Curves.easeOut,
          height: courant ? 4 : 3,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(2),
            boxShadow: courant
                ? [
                    BoxShadow(
                      color: couleur.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            if (acquis) ...[
              Icon(Icons.check_rounded, size: 11, color: encre),
              const SizedBox(width: 2),
            ] else if (courant) ...[
              // Le point bat sur le temps en cours — sauf en signal perdu, où
              // rien ne bat justement plus.
              TripPulse(
                color: encre,
                size: 5,
                animate: !stale && !enAlerte,
              ),
              const SizedBox(width: 1),
            ],
            Flexible(
              child: Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  color: actif ? encre : context.colors.onSurfaceVariant,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
