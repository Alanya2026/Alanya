import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'trip_visuals.dart';

/// Ce que la feuille d'arrivée a rendu.
enum TripArrivalChoice { confirme, prolonge15, prolonge30, plusTard }

/// La question d'arrivée — le moment pour lequel toute la fonctionnalité
/// existe.
///
/// Deux tons, et la différence n'est pas cosmétique :
///
///  - **destination atteinte** : le GPS a une hypothèse, il ne l'impose pas.
///    Ton doux, pas de décompte. Un faux positif doit coûter un balayage, rien
///    de plus.
///  - **échéance dépassée** : le cercle sera prévenu à une heure connue. On
///    l'affiche, et on décompte — mais **le cercle ne sait toujours rien**.
///
/// Trois sorties, jamais deux : confirmer, prolonger, ou refermer. Sans
/// « prolonger », un embouteillage n'aurait d'autre issue que l'alerte, et le
/// cercle apprendrait à ignorer les alertes.
class TripArrivalSheet extends StatefulWidget {
  const TripArrivalSheet({
    super.key,
    required this.parDestination,
    this.alerteA,
  });

  /// Vrai quand c'est le rayon qui a déclenché, faux quand c'est l'heure.
  final bool parDestination;

  /// Heure à laquelle le cercle sera prévenu. Affichée telle quelle : c'est la
  /// moitié du contrat annoncé au départ, elle ne se devine pas.
  final DateTime? alerteA;

  static Future<TripArrivalChoice?> montrer(
    BuildContext context, {
    required bool parDestination,
    DateTime? alerteA,
  }) {
    return showModalBottomSheet<TripArrivalChoice>(
      context: context,
      isScrollControlled: true,
      // Non balayable : c'est une question à laquelle il faut répondre. Mais
      // « Pas encore » existe — on ne piège personne dans une modale.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => TripArrivalSheet(
        parDestination: parDestination,
        alerteA: alerteA,
      ),
    );
  }

  @override
  State<TripArrivalSheet> createState() => _TripArrivalSheetState();
}

class _TripArrivalSheetState extends State<TripArrivalSheet> {
  Timer? _tic;
  Duration _restant = Duration.zero;

  /// Temps restant au moment où la feuille s'est ouverte. Il sert de référence
  /// à la jauge : on montre la part consommée de la fenêtre qu'on a sous les
  /// yeux, pas une fraction de la grâce totale que personne n'a vue passer.
  Duration _fenetre = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Vibration légère : la feuille peut apparaître écran éteint dans la poche.
    HapticFeedback.mediumImpact();
    if (widget.alerteA != null) {
      _majRestant();
      _fenetre = _restant;
      _tic = Timer.periodic(const Duration(seconds: 1), (_) => _majRestant());
    }
  }

  void _majRestant() {
    final d = widget.alerteA!.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _restant = d.isNegative ? Duration.zero : d);
  }

  /// Part de la fenêtre encore devant soi, de 1 à 0.
  double get _part {
    final total = _fenetre.inSeconds;
    if (total <= 0) return 0;
    return (_restant.inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = _restant.inMinutes;
    final s = _restant.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sem = context.semantic;
    final presse = !widget.parDestination;

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

            // L'écusson dit d'un coup d'œil laquelle des deux questions est
            // posée : un lieu atteint, ou une heure dépassée.
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: presse ? sem.warningContainer : sem.successContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  presse ? Icons.schedule : Icons.where_to_vote_outlined,
                  size: 28,
                  color: TripVisual.encre(
                      context, presse ? sem.warning : sem.success),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Le décompte n'apparaît que sur l'échéance : une arrivée détectée
            // ne met la pression à personne.
            if (presse && widget.alerteA != null) ...[
              Center(
                child: Text(
                  _mmss,
                  style: context.text.displaySmall?.copyWith(
                    // Encre dérivée : à cette taille l'ambre reste lisible en
                    // sombre, mais se dissout sur le fond clair d'une feuille.
                    color: TripVisual.encre(context, sem.warning),
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // La jauge double le chiffre : un nombre qui décroît se lit, une
              // barre qui se vide se voit. Les deux ensemble se comprennent
              // sans y penser, ce qui est l'objectif à cet instant précis.
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _part,
                  minHeight: 5,
                  backgroundColor: sem.warning.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation(sem.warning),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            Text(
              widget.parDestination
                  ? l10n.tripsArrivalReachedTitle
                  : l10n.tripsArrivalDueTitle,
              style: context.text.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.parDestination
                  ? l10n.tripsArrivalReachedBody
                  : (widget.alerteA == null
                      ? l10n.tripsArrivalDueBodyPlain
                      : l10n.tripsArrivalDueBody(_hhmm(widget.alerteA!))),
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action dominante, et une seule : c'est elle qui clôt le trajet et
            // rassure le cercle.
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, TripArrivalChoice.confirme),
              icon: const Icon(Icons.check),
              label: Text(l10n.tripsConfirmArrival),
              style: FilledButton.styleFrom(
                backgroundColor: sem.success,
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, TripArrivalChoice.prolonge15),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.minTapTarget),
                    ),
                    child: Text(l10n.tripsExtendBy(15)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, TripArrivalChoice.prolonge30),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.minTapTarget),
                    ),
                    child: Text(l10n.tripsExtendBy(30)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Sortie sans réponse. Elle existe pour ne pas enfermer, mais elle
            // ne suspend rien : l'échéance continue de courir côté serveur, et
            // le texte le dit.
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, TripArrivalChoice.plusTard),
              child: Text(l10n.tripsArrivalLater),
            ),
          ],
        ),
      ),
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
