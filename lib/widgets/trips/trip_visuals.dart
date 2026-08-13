import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_models.dart';
import '../common/status_chip.dart';

/// La grammaire visuelle du volet, en un seul endroit.
///
/// Six surfaces montrent l'état d'un trajet : la carte dans la conversation, le
/// bandeau persistant, l'accueil, l'écran de suivi, l'historique et l'aperçu de
/// conversation. Chacune redérivait sa propre correspondance état → couleur, et
/// donc sa propre version de **la règle de palette du volet** :
///
/// > Un signal perdu est **gris**, jamais rouge. Le rouge signifie une seule
/// > chose — le cercle a été prévenu.
///
/// Six copies d'une règle, c'est six occasions de la perdre. Un écran qui
/// passerait le GPS en rouge apprendrait à l'utilisateur que le rouge ne veut
/// rien dire, et le jour où il compte, il ne serait plus lu. La règle vit donc
/// ici, et nulle part ailleurs.
enum TripTone {
  /// Le trajet court et la position arrive. Seul ton animé.
  live,

  /// Le traceur s'est tu. **Gris** — ce n'est pas un incident.
  stale,

  /// L'échéance est atteinte, le cercle n'est pas encore sollicité.
  awaiting,

  /// Le cercle a été prévenu. Le seul ton rouge du volet.
  alerted,

  /// Arrivée confirmée.
  arrived,

  /// Partage arrêté. Ton neutre, délibérément : si arrêter paraissait suspect,
  /// arrêter deviendrait punissable.
  stopped,
}

/// Tout ce dont une surface a besoin pour peindre un état de trajet.
@immutable
class TripVisual {
  const TripVisual({
    required this.tone,
    required this.color,
    required this.ink,
    required this.container,
    required this.icon,
    required this.label,
  });

  final TripTone tone;

  /// **Couleur de remplissage** : liseré, barre, pastille, tracé, bordure.
  ///
  /// Pleinement saturée, faite pour couvrir des surfaces. À ne jamais utiliser
  /// comme couleur de texte — voir [ink].
  final Color color;

  /// **Couleur d'encre** : texte et icônes posés sur une surface.
  ///
  /// Elle existe parce que la palette sémantique de l'application est
  /// *identique en clair et en sombre* : `success` vaut `#1FA363` dans les deux
  /// thèmes, `warning` `#F59E0B`, `error` `#EF4444`. Ce sont des couleurs de
  /// remplissage, choisies pour être posées sous du blanc — et elles ne
  /// deviennent pas lisibles par le fait qu'on les emploie comme texte.
  ///
  /// L'ambre est le cas d'école : sur fond clair, `#F59E0B` plafonne à environ
  /// 2:1 de contraste, très en deçà des 4.5:1 exigés pour du texte courant. En
  /// sombre, c'est le vert qui décroche, posé sur une surface presque noire.
  /// Un même code couleur ne peut pas servir les deux.
  ///
  /// [ink] garde donc la teinte — c'est elle qui porte le sens — et n'ajuste que
  /// la luminosité, vers le bas en thème clair, vers le haut en thème sombre.
  final Color ink;

  /// Fond atténué, pour poser [ink] dessus sans le fatiguer.
  final Color container;

  final IconData icon;

  /// Libellé court, déjà localisé. La couleur ne porte **jamais** seule le sens.
  final String label;

  bool get pulses => tone == TripTone.live;
  bool get isOpen => tone != TripTone.arrived && tone != TripTone.stopped;

  /// Dérive une encre lisible à partir d'une couleur de remplissage.
  ///
  /// Deux étages, et il faut les deux.
  ///
  /// **Étage 1, la teinte.** Pour une couleur saturée, on garde la teinte — c'est
  /// elle qui porte le sens — et on ne corrige que la luminosité : vers le bas en
  /// thème clair, vers le haut en sombre.
  ///
  /// Les seuils 0,30 et 0,72 sont ceux où **la plus défavorable** des couleurs
  /// du volet franchit 4,5:1 contre la surface du thème correspondant. C'est le
  /// vert qui commande en clair : à 0,32 il plafonnait à 4,42:1 — assez pour
  /// passer inaperçu à l'œil, pas assez pour être lisible. `trip_visuals_test`
  /// vérifie chaque état dans les deux thèmes plutôt que de s'en remettre à
  /// cette note. On ne monte pas plus haut en sombre : au-delà, la teinte se
  /// délave et le rouge cesse de se distinguer de l'ambre.
  ///
  /// **Étage 2, le filet.** Si le résultat n'atteint pas 3:1 contre la surface,
  /// on rend `onSurfaceVariant`. Ce filet existe pour une erreur précise, qui a
  /// été commise : employer `colorScheme.outline` comme couleur de texte.
  /// `outline` est un jeton de **bordure** — il vaut `#E2E5EC` en clair, soit
  /// 1,26:1 sur blanc, et `#3A404C` en sombre, soit 1,66:1 sur le fond sombre.
  /// Invisible dans les deux thèmes. Aucune correction de luminosité ne rattrape
  /// un gris de bordure : il faut changer de jeton, et c'est ce que fait le
  /// filet.
  static Color encre(BuildContext context, Color remplissage) {
    final schema = Theme.of(context).colorScheme;
    final hsl = HSLColor.fromColor(remplissage);

    var candidat = remplissage;
    if (hsl.saturation >= 0.12) {
      final sombre = Theme.of(context).brightness == Brightness.dark;
      final l = sombre
          ? (hsl.lightness < 0.72 ? 0.72 : hsl.lightness)
          : (hsl.lightness > 0.30 ? 0.30 : hsl.lightness);
      candidat = hsl.withLightness(l).toColor();
    }

    if (_contraste(candidat, schema.surface) < 3.0) {
      return schema.onSurfaceVariant;
    }
    return candidat;
  }

  /// Rapport de contraste WCAG entre deux couleurs opaques.
  static double _contraste(Color a, Color b) {
    final la = _luminance(a), lb = _luminance(b);
    return ((la > lb ? la : lb) + 0.05) / ((la < lb ? la : lb) + 0.05);
  }

  static double _luminance(Color c) {
    double canal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  StatusChipTone get chipTone => switch (tone) {
        TripTone.live || TripTone.arrived => StatusChipTone.success,
        TripTone.awaiting => StatusChipTone.warning,
        TripTone.alerted => StatusChipTone.error,
        TripTone.stale || TripTone.stopped => StatusChipTone.neutral,
      };

  /// Résout l'état d'un trajet en une apparence.
  ///
  /// [stale] n'est consulté que sur un trajet ouvert et non alerté : une alerte
  /// reste rouge même sans position — c'est justement le cas où l'absence de
  /// position est le sujet.
  ///
  /// [alerte] force le ton rouge sur un trajet **déjà clos**. C'est ce qui
  /// distingue les deux publics du volet : dans la conversation d'un membre, un
  /// trajet terminé est terminé, quelle qu'en soit la fin — insister serait de
  /// la mise en accusation. Dans l'historique du propriétaire, au contraire,
  /// savoir lesquels de ses trajets ont fini par réveiller son cercle est
  /// précisément ce qu'il vient chercher.
  static TripVisual resolve(
    BuildContext context, {
    required String state,
    bool stale = false,
    bool alerte = false,
    bool fausseAlerte = false,
  }) {
    final l10n = context.l10n;
    final sem = context.semantic;
    final colors = context.colors;

    // Toutes les apparences passent par ce constructeur, et lui seul : c'est ce
    // qui garantit qu'aucun état ne puisse arriver à l'écran avec une encre non
    // dérivée. Un `TripVisual(...)` direct exigerait `ink`, et le compilateur
    // refuserait de l'oublier.
    TripVisual faire({
      required TripTone tone,
      required Color color,
      required Color container,
      required IconData icon,
      required String label,
    }) =>
        TripVisual(
          tone: tone,
          color: color,
          ink: encre(context, color),
          container: container,
          icon: icon,
          label: label,
        );

    // Un démenti après une alerte est une bonne nouvelle, et doit se lire comme
    // telle. Le rendre gris comme un arrêt ordinaire laisserait le cercle sur
    // son inquiétude ; le rendre vert en écrivant « arrivée confirmée » serait
    // faux — la personne n'est pas arrivée, elle a démenti. D'où sa propre
    // apparence, avec ses propres mots.
    if (fausseAlerte) {
      return faire(
        tone: TripTone.arrived,
        color: sem.success,
        container: sem.successContainer,
        icon: Icons.verified_outlined,
        label: l10n.tripsSosFalseAlarm,
      );
    }

    if (alerte && !TripState.isOpen(state)) {
      return faire(
        tone: TripTone.alerted,
        color: colors.error,
        container: colors.errorContainer,
        icon: Icons.warning_amber_rounded,
        label: l10n.tripsOutcomeAlert,
      );
    }

    return switch (state) {
      TripState.alert || TripState.sos => faire(
          tone: TripTone.alerted,
          color: colors.error,
          container: colors.errorContainer,
          icon: Icons.warning_amber_rounded,
          label: l10n.tripsAlerted,
        ),
      TripState.awaitingConfirm => faire(
          tone: TripTone.awaiting,
          color: sem.warning,
          container: sem.warningContainer,
          icon: Icons.schedule,
          label: l10n.tripsAwaitingConfirm,
        ),
      TripState.closedConfirmed => faire(
          tone: TripTone.arrived,
          color: sem.success,
          container: sem.successContainer,
          icon: Icons.check_circle,
          label: l10n.tripsOutcomeConfirmed,
        ),
      TripState.closedCancelled ||
      TripState.closedExpired ||
      TripState.closedUnwatched =>
        faire(
          tone: TripTone.stopped,
          // `onSurfaceVariant`, PAS `outline` : ce gris remplit un liseré, une
          // pastille de carte et une barre de rampe. `outline` est un jeton de
          // bordure à 1,26:1 sur blanc — un liseré d'état qu'on ne voit pas ne
          // porte aucun état.
          color: colors.onSurfaceVariant,
          container: sem.surfaceMuted,
          icon: Icons.stop_circle_outlined,
          label: l10n.tripsOutcomeStopped,
        ),
      _ when stale => faire(
          tone: TripTone.stale,
          color: colors.onSurfaceVariant,
          container: sem.surfaceMuted,
          icon: Icons.location_disabled,
          label: l10n.tripsStale,
        ),
      _ => faire(
          tone: TripTone.live,
          color: sem.success,
          container: sem.successContainer,
          icon: Icons.navigation_rounded,
          label: l10n.tripsLive,
        ),
    };
  }
}

/// Le point qui respire — la seule animation du volet.
///
/// Elle ne décore pas : elle répond à la question qu'on se pose en regardant une
/// carte figée, « est-ce que ça tourne encore ? ». Un point immobile et un
/// traceur mort se ressemblent trait pour trait ; un point qui bat les sépare
/// sans un mot.
///
/// Elle s'arrête donc **exactement** quand la réponse cesse d'être oui : dès que
/// le trajet n'est plus en direct, le halo disparaît au lieu de continuer à
/// promettre une vie qui n'existe plus.
class TripPulse extends StatefulWidget {
  const TripPulse({
    super.key,
    required this.color,
    this.size = 10,
    this.animate = true,
  });

  final Color color;
  final double size;
  final bool animate;

  @override
  State<TripPulse> createState() => _TripPulseState();
}

class _TripPulseState extends State<TripPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(TripPulse old) {
    super.didUpdateWidget(old);
    if (widget.animate == old.animate) return;
    // Le halo suit l'état, pas le cycle de vie du widget : un trajet qui passe
    // en alerte doit cesser de battre sans être reconstruit.
    widget.animate ? _c.repeat() : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noyau = widget.size;
    // Le halo culmine à 2,4× le noyau : au-delà il empiète sur le texte voisin,
    // en deçà on ne le voit pas sur un écran de téléphone au soleil.
    final total = noyau * 2.4;

    // Barrière de repeinture : le halo bat pendant toute la durée d'un trajet,
    // y compris sur le bandeau persistant visible depuis les cinq onglets. Sans
    // elle, chaque battement redessinerait la ligne de texte voisine — une
    // dépense continue, au moment précis où la batterie sert au GPS.
    return RepaintBoundary(
      child: SizedBox(
        width: total,
        height: total,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.animate)
                  Opacity(
                    // Décroissance rapide : le halo doit s'être éteint avant de
                    // toucher le bord, sinon on lit un disque, pas une onde.
                    opacity: (1 - t) * 0.35,
                    child: Container(
                      width: noyau + (total - noyau) * t,
                      height: noyau + (total - noyau) * t,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Container(
                  width: noyau,
                  height: noyau,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Formats partagés par toutes les surfaces du volet.
///
/// Dupliqués jusqu'ici dans six fichiers, avec le risque qu'une heure s'affiche
/// « 9:5 » sur l'un et « 09:05 » sur l'autre.
abstract final class TripFormat {
  /// Heure sur deux chiffres. Toujours à rendre en chiffres tabulaires : sans
  /// cela, l'heure danse d'un pixel à chaque minute qui passe.
  static String hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// Ancienneté compacte — « 8 s », « 4 min », « 2 h ».
  static String depuis(DateTime d) {
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return '${s < 0 ? 0 : s} s';
    if (s < 3600) return '${s ~/ 60} min';
    return '${s ~/ 3600} h';
  }

  /// « dans 32 min » — le temps restant, en minutes, jamais négatif.
  static int minutesRestantes(DateTime d) {
    final m = d.difference(DateTime.now()).inMinutes;
    return m < 0 ? 0 : m;
  }

  static const tabular = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Puce d'information d'un trajet : icône + valeur, sur fond atténué.
///
/// Remplace les lignes « 21:45 · 3 personnes · ± 22 m » collées par des points
/// médians. Séparées, elles se balayent du regard ; jointes, il faut les lire.
class TripFactChip extends StatelessWidget {
  const TripFactChip({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color? tint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final encre = tint ?? context.colors.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 13, color: encre),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? context.text.labelSmall : context.text.labelMedium)
                  ?.copyWith(
                color: encre,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Écusson d'état : l'icône du trajet dans une pastille teintée.
///
/// C'est l'ancrage visuel de toutes les surfaces du volet — même forme, même
/// place, seule la couleur change. On reconnaît un trajet avant de l'avoir lu.
class TripCrest extends StatelessWidget {
  const TripCrest({
    super.key,
    required this.visual,
    this.size = 40,
  });

  final TripVisual visual;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.container,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      // L'encre, pas le remplissage : posée sur son conteneur atténué, la
      // couleur pleine tombe sous 2.5:1 en thème sombre.
      child: Icon(visual.icon, size: size * 0.5, color: visual.ink),
    );
  }
}
