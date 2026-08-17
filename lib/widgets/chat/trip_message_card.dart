import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/trip_payload.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_models.dart';
import '../trips/trip_map_thumb.dart';
import '../trips/trip_visuals.dart';

/// La carte de trajet, telle que la voit un membre du cercle.
///
/// C'est la **seule surface qu'un membre verra à coup sûr** : elle arrive là où
/// il parle déjà avec la personne, elle porte la notification, elle survit au
/// redémarrage et elle reste dans l'archive. Un écran dédié seul serait
/// invisible pour qui ignore que la fonctionnalité existe. Elle mérite donc
/// d'être lisible d'un coup d'œil, pas seulement correcte.
///
/// Cinq étages, du plus voyant au plus discret : le liseré d'état, la vignette,
/// le titre qui dit le fait, les faits chiffrés en puces, l'action. On lit dans
/// cet ordre, et on peut s'arrêter à n'importe quel étage.
///
/// La vignette est **inerte**, et la nuance est tout le sujet : une carte
/// *interactive* dans une bulle capture le geste de défilement du fil, charge
/// des tuiles à l'infini quand on remonte l'historique et dépense de la batterie
/// pour un contenu que personne ne manipule à cet endroit. [TripMapThumb]
/// n'accepte aucun geste, et ne s'affiche que sur un trajet ouvert — un trajet
/// clos replie sa carte.
///
/// Un seul message par trajet : il est réécrit sur place à chaque transition,
/// cinq à six fois au maximum. **Les positions ne touchent jamais la
/// conversation** — la vignette s'anime depuis le flux temps réel, sans écriture.
class TripMessageCard extends StatelessWidget {
  const TripMessageCard({
    super.key,
    required this.payload,
    required this.senderName,
    this.isOwner = false,
    this.onOpen,
  });

  final TripCardPayload payload;
  final String senderName;

  /// Vue propriétaire de la bulle (message sortant). Change le CTA et le ton
  /// une fois le trajet clos — le vert « bien arrivé » reste pour le cercle.
  final bool isOwner;
  final VoidCallback? onOpen;

  /// La vignette n'apparaît que là où elle répond à une question.
  ///
  /// Sur un trajet **ouvert ou en alerte**, « où est-elle ? » est exactement ce
  /// qu'on se demande en voyant la carte, et la vignette y répond sans ouvrir
  /// d'écran.
  ///
  /// Sur un trajet **clos**, elle ne répond plus à rien : la personne est
  /// arrivée, ou a arrêté le partage. La carte se replie — plus de carte, plus
  /// de flux. C'est aussi ce qui évite qu'un historique de discussion long
  /// charge des tuiles pour des dizaines de trajets terminés il y a des mois.
  bool get _vignette => TripState.isOpen(payload.state);

  bool get _clos => !TripState.isOpen(payload.state);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Côté owner, un trajet clos se lit en gris : ce n'est plus une alerte ni
    // une bonne nouvelle à célébrer dans son propre fil, c'est une archive.
    final v = TripVisual.resolve(
      context,
      state: isOwner && _clos && !payload.isFalseAlarm
          ? TripState.closedCancelled
          : payload.state,
      fausseAlerte: payload.isFalseAlarm,
    );

    // Côté propriétaire, « Moi a arrêté le partage » est illisible : les
    // phrases à la 3e personne sont pour le cercle. Même voix « Vous » que
    // les messages système (`sysTripSosByMe`, etc.).
    final titre = switch (payload.state) {
      // Le démenti passe avant l'état : après une alerte, le cercle attend une
      // réponse à la question qu'on lui a posée, pas un compte rendu d'arrêt.
      _ when payload.isFalseAlarm => isOwner
          ? l10n.tripsCardFalseAlarmByMe
          : l10n.tripsCardFalseAlarm(senderName),
      TripState.sos =>
        isOwner ? l10n.tripsCardSosByMe : l10n.tripsCardSos(senderName),
      TripState.alert =>
        isOwner ? l10n.tripsCardAlertByMe : l10n.tripsCardAlert(senderName),
      TripState.awaitingConfirm =>
        isOwner ? l10n.tripsCardAwaitingByMe : l10n.tripsCardAwaiting(senderName),
      TripState.closedConfirmed =>
        isOwner ? l10n.tripsCardArrivedByMe : l10n.tripsCardArrived(senderName),
      TripState.closedCancelled ||
      TripState.closedExpired ||
      TripState.closedUnwatched =>
        // Ton neutre, délibérément : si arrêter paraissait suspect, arrêter
        // deviendrait punissable.
        isOwner
            ? l10n.tripsCardStoppedByMe
            : l10n.tripsCardStopped(senderName),
      _ => isOwner
          ? l10n.tripsCardStartedByMe
          : l10n.tripsCardStarted(senderName),
    };

    final String? action;
    if (_clos) {
      action = isOwner ? l10n.tripsCardView : null;
    } else {
      action = switch (payload.state) {
        TripState.sos || TripState.alert => l10n.tripsCardSeeLast,
        TripState.awaitingConfirm => l10n.tripsCardSeePosition,
        _ => l10n.tripsCardFollow,
      };
    }

    final figee = !_clos &&
        payload.lastAt != null &&
        DateTime.now().difference(payload.lastAt!).inSeconds > 180;

    final faits = <Widget>[
      if (payload.destLabel != null)
        TripFactChip(icon: Icons.place_outlined, label: payload.destLabel!),
      if (payload.etaAt != null)
        TripFactChip(
          icon: Icons.schedule,
          label: l10n.tripsEtaAt(TripFormat.hhmm(payload.etaAt!)),
          // L'échéance est la garantie du trajet, pas un détail : sur une carte
          // en attente ou en alerte, elle se lit à la couleur de l'état.
          tint: v.tone == TripTone.awaiting || v.tone == TripTone.alerted
              ? v.ink
              : null,
        ),
      if (payload.lastAt != null && !_clos)
        TripFactChip(
          icon: Icons.my_location,
          label: figee
              ? l10n.tripsPositionFrozen
              : l10n.tripsUpdatedAgo(TripFormat.depuis(payload.lastAt!)),
          tint: figee ? context.colors.onSurfaceVariant : null,
        ),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          // Une alerte cerne la carte au lieu de se contenter d'un liseré : dans
          // un fil qu'on fait défiler vite, un trait de 3 px se rate.
          color: v.tone == TripTone.alerted
              ? v.color.withValues(alpha: 0.55)
              : context.colors.outlineVariant,
          width: v.tone == TripTone.alerted ? 1.5 : 1,
        ),
        boxShadow: AppShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le liseré porte l'état : on doit pouvoir lire la situation en
          // faisant défiler, sans lire le texte.
          Container(height: 3, color: v.color),
          if (_vignette)
            TripMapThumb(
              tripId: payload.tripId,
              visual: v,
              instantane: payload.hasPoint
                  ? LatLng(payload.lastLat!, payload.lastLng!)
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TripCrest(visual: v, size: 38),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titre,
                            style: context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _etatEnLigne(context, v),
                        ],
                      ),
                    ),
                  ],
                ),
                if (faits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: 6, runSpacing: 6, children: faits),
                ],
                if (payload.note != null && payload.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _note(context, payload.note!),
                ],
              ],
            ),
          ),
          if (action != null && onOpen != null) _action(context, v, action),
        ],
      ),
    );
  }

  /// L'état en toutes lettres, précédé du point qui bat quand — et seulement
  /// quand — la position arrive encore.
  Widget _etatEnLigne(BuildContext context, TripVisual v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TripPulse(color: v.ink, size: 7, animate: v.pulses),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              v.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: v.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );

  /// La note du propriétaire — « taxi jaune, plaque LT 4471 ». C'est le seul
  /// texte libre de la carte : on le distingue par un filet, jamais par des
  /// guillemets, qui se perdent à cette taille.
  Widget _note(BuildContext context, String texte) => Container(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: context.colors.outlineVariant, width: 2),
          ),
        ),
        child: Text(
          texte,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
        ),
      );

  Widget _action(BuildContext context, TripVisual v, String libelle) => Material(
        color: v.container.withValues(alpha: 0.55),
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  libelle,
                  style: context.text.labelLarge
                      ?.copyWith(color: v.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 15, color: v.ink),
              ],
            ),
          ),
        ),
      );
}
