import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/trip_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tiles.dart';
import '../../talky_models.dart';
import 'trip_visuals.dart';

/// Vignette cartographique d'une carte de trajet, dans le fil de discussion.
///
/// **Statique et inerte, délibérément.** Une carte *interactive* dans une bulle
/// est un défaut connu : elle capture le geste de défilement du fil, elle charge
/// des tuiles à l'infini quand on remonte l'historique, et elle dépense de la
/// batterie pour un contenu que personne ne manipule à cet endroit. La vignette
/// ne se déplace pas, ne zoome pas, n'accepte aucun geste — un appui ouvre la
/// carte plein écran, qui est faite pour ça.
///
/// **Elle vit quand même.** Sur un trajet ouvert, elle suit la position du cache
/// local, alimenté par le socket : le point glisse sans qu'aucun message ne soit
/// réécrit. C'est la règle du volet appliquée à la lettre — la carte porte
/// l'état, le socket porte le mouvement. Réécrire le message à chaque position
/// remonterait la conversation en tête de liste et déclencherait une
/// notification toutes les cinq secondes.
///
/// Sur un trajet clos ou hors ligne, elle retombe sur l'instantané figé dans le
/// message. C'est ce qui permet à une carte d'alerte rouverte des semaines plus
/// tard de tenir sa promesse — « voir la dernière position » — alors que la
/// trace détaillée a été purgée depuis longtemps.
class TripMapThumb extends StatelessWidget {
  const TripMapThumb({
    super.key,
    required this.tripId,
    required this.visual,
    required this.instantane,
    this.hauteur = 116,
  });

  final int tripId;
  final TripVisual visual;

  /// Position figée dans le message, utilisée à défaut de suivi vivant.
  ///
  /// Nulle sur une carte fraîche : au moment où le serveur pose le message, le
  /// trajet vient d'être créé et aucune position n'est encore remontée. La
  /// vignette apparaît alors dès le premier point reçu par le socket, sans
  /// qu'aucun message n'ait à être réécrit.
  final LatLng? instantane;

  final double hauteur;

  @override
  Widget build(BuildContext context) {
    // Le trajet suivi en direct, s'il est encore dans le cache. `watchTrip`
    // n'émet rien quand la ligne a été purgée (trajet clos côté membre) : on
    // reste alors sur l'instantané, ce qui est exactement le comportement voulu.
    return StreamBuilder<LocalTrip?>(
      stream: context.read<TripRepository>().watchTrip(tripId),
      builder: (context, snap) {
        final t = snap.data;
        final vivant = t != null &&
            TripState.isOpen(t.state) &&
            t.lastLat != null &&
            t.lastLng != null;
        final point =
            vivant ? LatLng(t.lastLat!, t.lastLng!) : instantane;

        // Ni suivi vivant ni instantané : on n'affiche rien plutôt qu'un carré
        // vide ou un point posé à une coordonnée par défaut, qui situerait la
        // personne quelque part où elle n'est pas.
        if (point == null) return const SizedBox.shrink();

        return SizedBox(
          height: hauteur,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // `IgnorePointer` plutôt que `InteractiveFlag.none` seul : le
              // second désarme les gestes de la carte, mais la carte reste dans
              // l'arbre des pointeurs et peut encore avaler l'appui destiné à la
              // bulle. Ici, aucun événement ne l'atteint.
              IgnorePointer(
                child: FlutterMap(
                  // La clé force une reconstruction quand le point change : sans
                  // elle, `initialCenter` n'étant lu qu'à la création, la
                  // vignette resterait figée sur la première position reçue.
                  key: ValueKey('$tripId:${point.latitude},${point.longitude}'),
                  options: MapOptions(
                    initialCenter: point,
                    // 15 : le quartier. Plus près, on ne reconnaît rien sans
                    // pouvoir déplacer la carte ; plus loin, le point ne dit
                    // plus où la personne se trouve.
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    MapTiles.layer(context),
                    MarkerLayer(markers: [
                      Marker(
                        point: point,
                        width: 30,
                        height: 30,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            TripPulse(
                              color: visual.ink,
                              size: 11,
                              animate: vivant && visual.pulses,
                            ),
                            Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: visual.color,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              // Mention légale. Minuscule, mais présente : c'est la contrepartie
              // du droit d'usage des tuiles, et une vignette qui en affiche
              // reste une carte publiée.
              Positioned(
                right: 3,
                bottom: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    MapTiles.attribution,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.2,
                      color: Color(0xFF3C4048),
                    ),
                  ),
                ),
              ),

              // Dégradé bas : le bandeau de titre qui suit se pose sur des
              // tuiles dont on ne maîtrise pas la couleur. Sans cette bascule
              // vers la surface, la séparation change d'aspect selon qu'on
              // s'arrête sur un parc ou sur un carrefour.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.colors.surface.withValues(alpha: 0),
                          context.colors.surface,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
