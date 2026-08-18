import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/call_service.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/trip_repository.dart';
import '../../core/services/trip_session_guard.dart';
import '../../core/services/trip_socket_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tiles.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/maps/map_compass.dart';
import '../../widgets/trips/trip_arrival_sheet.dart';
import '../../widgets/trips/trip_degraded_banner.dart';
import '../../widgets/trips/trip_other_device_banner.dart';
import '../../widgets/trips/trip_rail.dart';
import '../../widgets/trips/trip_visuals.dart';
import '../../widgets/trips/trip_watchers_row.dart';
import 'trip_sos_screen.dart';

/// Suivi d'un trajet en direct — vue propriétaire et vue destinataire.
///
/// La couleur du bandeau porte l'état : on doit pouvoir lire la situation sans
/// lire le texte. Un seul état est rouge, et **ce n'est pas celui où le GPS a
/// lâché** — perdre le signal est une information, pas un incident.
///
/// La carte montre trois choses, dans cet ordre d'importance : où l'on est, où
/// l'on va, d'où l'on vient. Le but et son rayon d'arrivée sont dessinés dès
/// qu'une destination a été déclarée — sans eux, un pin qui se déplace ne dit
/// pas s'il se rapproche.
class TripLiveScreen extends StatefulWidget {
  const TripLiveScreen({super.key, required this.tripId, required this.isOwner});

  final int tripId;
  final bool isOwner;

  @override
  State<TripLiveScreen> createState() => _TripLiveScreenState();
}

class _TripLiveScreenState extends State<TripLiveScreen> {
  final _carte = MapController();
  bool _suitLaPosition = true;

  /// Évite de reposer la question à chaque reconstruction du flux Drift : la
  /// feuille ne doit s'ouvrir qu'une fois par passage en « à confirmer ».
  bool _feuillePosee = false;

  /// Sheet urgence watcher : une fois par passage en alerte/SOS.
  bool _alerteSheetPosee = false;

  /// Rafraîchit « maj il y a 8 s » sans attendre une nouvelle position : sans
  /// cela, l'ancienneté affichée gèle dès que le traceur se tait — exactement
  /// le moment où elle devient l'information la plus utile de l'écran.
  Timer? _horloge;

  /// Nom du porteur pour l'écran de fin (évite de relancer la requête Drift
  /// à chaque rebuild du [FutureBuilder]).
  Future<String>? _nomFin;

  /// Carte edge-to-edge : masque bandeau, rail et pied pour laisser lire le
  /// déplacement. Owner et watcher.
  bool _immersif = false;

  /// Un seul cadrage automatique position+but au premier couple connu.
  bool _cadreInitialFait = false;

  @override
  void initState() {
    super.initState();
    final trips = context.read<TripRepository>();
    final socket = context.read<TripSocketService>();

    // On rejoint le flux à l'ouverture et on le quitte en sortant : inutile de
    // recevoir une position toutes les cinq secondes pour une carte que
    // personne ne regarde.
    socket.subscribe(widget.tripId);
    // On se reconstruit à l'issue de la synchronisation, et pas seulement sur
    // le flux Drift : quand elle échoue, rien n'est écrit en base, donc le flux
    // n'émet pas — et l'écran resterait sur son tourniquet alors que le verdict
    // est tombé.
    unawaited(trips.syncTrip(widget.tripId, isOwner: widget.isOwner).then((_) {
      if (mounted) setState(() {});
    }));

    // Côté destinataire, ouvrir l'écran vaut « j'ai vu » — c'est le seul retour
    // qu'il puisse donner, et il remonte au propriétaire.
    if (!widget.isOwner) socket.markSeen(widget.tripId);

    _horloge = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _horloge?.cancel();
    // Ne pas désabonner un trajet dont on est l'émetteur : le garde de session
    // partage cet abonnement, et le lui retirer en fermant la carte désarmerait
    // son propre réabonnement après reconnexion. L'émission, elle, continue —
    // elle ne dépend pas de la room.
    final guard = TripSessionGuard.instance;
    if (!(guard.isActive && guard.tripId == widget.tripId)) {
      context.read<TripSocketService>().unsubscribe(widget.tripId);
    }
    context.read<TripRepository>().clearCloseInfo(widget.tripId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trips = context.read<TripRepository>();

    return PopScope(
      canPop: !_immersif,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _immersif) setState(() => _immersif = false);
      },
      child: Scaffold(
        appBar: _immersif ? null : AppBar(title: Text(l10n.trips)),
        body: StreamBuilder<LocalTrip?>(
          stream: trips.watchTrip(widget.tripId),
          builder: (context, snap) {
            final t = snap.data;
            if (t == null) return _sansTrajet(l10n, trips);
            final v = TripVisual.resolve(context, state: t.state, stale: t.stale);

            // La question d'arrivée s'impose d'elle-même : c'est le moment pour
            // lequel toute la fonctionnalité existe, il ne doit pas dépendre du
            // fait que l'utilisateur pense à regarder le pied d'écran.
            if (widget.isOwner &&
                t.state == TripState.awaitingConfirm &&
                !_feuillePosee) {
              _feuillePosee = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_demanderArrivee(t));
              });
            } else if (t.state != TripState.awaitingConfirm) {
              _feuillePosee = false;
            }

            // Watcher : une seule décision au moment de l'alerte — Appeler.
            if (!widget.isOwner &&
                (t.state == TripState.alert || t.state == TripState.sos) &&
                !_alerteSheetPosee) {
              _alerteSheetPosee = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_feuilleUrgence(t, v));
              });
            } else if (t.state != TripState.alert && t.state != TripState.sos) {
              _alerteSheetPosee = false;
            }

            if (_immersif) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _carteGeo(t, v),
                  if (TripState.isOpen(t.state)) _overlayImmersif(l10n, t, v),
                  if (!TripState.isOpen(t.state)) _overlayClos(l10n, t, v),
                ],
              );
            }

            return Column(
              children: [
                _bandeauEtat(l10n, t, v),
                TripRail(state: t.state, stale: t.stale),
                if (widget.isOwner && TripState.isOpen(t.state))
                  TripOtherDeviceBanner(trip: t),
                if (widget.isOwner && TripState.isOpen(t.state))
                  TripDegradedBanner(trip: t, onAction: _ouvrirReglages),
                Expanded(child: _carteGeo(t, v)),
                if (TripState.isOpen(t.state))
                  _pied(l10n, t, v)
                else
                  _piedClos(l10n, t, v),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Chrome minimal en mode carte immersif.
  Widget _overlayImmersif(dynamic l10n, LocalTrip t, TripVisual v) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Material(
                    color: context.colors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TripPulse(color: v.ink, size: 8, animate: v.pulses),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              v.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelLarge?.copyWith(
                                color: v.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: context.colors.surface.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: l10n.tripsMapReduce,
                    onPressed: () => setState(() => _immersif = false),
                    icon: const Icon(Icons.fullscreen_exit),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.isOwner &&
                    t.state == TripState.awaitingConfirm) ...[
                  FloatingActionButton.extended(
                    heroTag: 'trip-immersive-confirm',
                    backgroundColor: context.semantic.success,
                    foregroundColor: context.semantic.onSuccess,
                    onPressed: _occupe ? null : _confirmer,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l10n.tripsConfirmArrival),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (widget.isOwner)
                  FloatingActionButton(
                    heroTag: 'trip-immersive-sos',
                    // Neutre : le rouge n'apparaît que sur l'écran d'armement.
                    // Un FAB rouge ici trahirait le SOS à qui regarde par-dessus
                    // l'épaule — exactement l'inverse du mode discret.
                    backgroundColor:
                        context.colors.surface.withValues(alpha: 0.92),
                    foregroundColor: context.colors.onSurface,
                    tooltip: l10n.tripsSosButton,
                    onPressed: _occupe ? null : _sos,
                    child: const Icon(Icons.sos_outlined),
                  )
                else
                  FloatingActionButton(
                    heroTag: 'trip-immersive-call',
                    backgroundColor: v.tone == TripTone.alerted
                        ? context.colors.error
                        : context.colors.primary,
                    foregroundColor: Colors.white,
                    tooltip: l10n.tripsCall,
                    onPressed: _occupe ? null : () => _appeler(t),
                    child: const Icon(Icons.call),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Le trajet n'est pas — ou plus — dans le cache.
  ///
  /// Trois situations très différentes, qui appelaient toutes le même
  /// tourniquet infini. C'est le pire des états : l'utilisateur ne sait pas
  /// s'il doit attendre, et il attendra donc pour toujours.
  ///
  /// Le serveur répond **404 indifférencié** à qui n'est plus destinataire, et
  /// c'est délibéré : personne ne doit apprendre qu'un trajet existe encore, ni
  /// pourquoi il n'y a plus accès. La pierre tombale ne donne donc **aucune
  /// raison** — c'est exactement ce que prévoit la conception, et ce qui
  /// empêche la révocation de devenir une accusation.
  ///
  /// Exception : si l'on suivait déjà le trajet et qu'on a reçu sa clôture
  /// ([TripCloseInfo]), on peut dire « bien arrivé·e » / « partage arrêté »
  /// sans inventer une raison — c'est l'état qu'on a vu passer.
  Widget _sansTrajet(dynamic l10n, TripRepository trips) {
    final fin = trips.closeInfoOf(widget.tripId);
    if (fin != null) {
      _nomFin ??= _nomProprietaire(fin.ownerId);
      return FutureBuilder<String>(
        future: _nomFin,
        builder: (context, snap) {
          final nom = snap.data?.trim() ?? '';
          final v = TripVisual.resolve(context, state: fin.state);
          final titre = fin.arrivedSafely
              ? (nom.isEmpty
                  ? l10n.tripsLiveEndedArrived
                  : l10n.tripsCardArrived(nom))
              : (nom.isEmpty
                  ? l10n.tripsLiveEndedStopped
                  : l10n.tripsCardStopped(nom));
          return EmptyState(
            icon: v.icon,
            iconColor: v.ink,
            title: titre,
            message: l10n.tripsLiveEndedBody,
            action: FilledButton(
              onPressed: () {
                trips.clearCloseInfo(widget.tripId);
                Navigator.pop(context);
              },
              child: Text(l10n.commonClose),
            ),
          );
        },
      );
    }

    switch (trips.accessOf(widget.tripId)) {
      case TripAccess.plusPartage:
        return EmptyState(
          icon: Icons.lock_outline,
          title: l10n.tripsNoLongerShared,
          message: l10n.tripsNoLongerSharedBody,
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        );

      case TripAccess.injoignable:
        return EmptyState(
          icon: Icons.cloud_off,
          title: l10n.tripsUnreachable,
          message: l10n.tripsUnreachableBody,
          action: FilledButton(
            onPressed: () async {
              await trips.syncTrip(widget.tripId, isOwner: widget.isOwner);
              if (mounted) setState(() {});
            },
            child: Text(l10n.retry),
          ),
        );

      // Accès encore « ok » mais cache vide : oubli / course, pas un chargement.
      // Sans ce filet, le tourniquet revient dès qu'un forget n'a pas posé _fin.
      case TripAccess.ok:
        return EmptyState(
          icon: Icons.lock_outline,
          title: l10n.tripsNoLongerShared,
          message: l10n.tripsNoLongerSharedBody,
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        );

      // La première synchronisation n'a encore ni abouti ni échoué : c'est le
      // seul cas où un tourniquet est honnête.
      case TripAccess.inconnu:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Future<String> _nomProprietaire(int ownerId) async {
    final cache = context.read<LocalCacheRepository>();
    final u = await cache.getKnownUser(ownerId);
    if (u == null) return '';
    final nom = u.nom.trim();
    if (nom.isNotEmpty) return nom;
    return u.pseudo.trim();
  }

  // ── Bandeau d'état ────────────────────────────────────────────────

  /// Deux lignes : ce qui se passe, et vers quoi. La destination est répétée
  /// ici parce qu'elle disparaît du champ de vision dès qu'on fait glisser la
  /// carte.
  Widget _bandeauEtat(dynamic l10n, LocalTrip t, TripVisual v) {
    return Container(
      width: double.infinity,
      color: v.color.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          TripPulse(color: v.ink, size: 9, animate: v.pulses),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.label,
                  style: context.text.labelLarge
                      ?.copyWith(color: v.ink, fontWeight: FontWeight.w700),
                ),
                if (t.destLabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    t.destLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (t.lastAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: v.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                TripFormat.depuis(t.lastAt!),
                style: context.text.labelSmall?.copyWith(
                  color: v.ink,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Carte ─────────────────────────────────────────────────────────

  Widget _carteGeo(LocalTrip t, TripVisual v) {
    final l10n = context.l10n;
    final position = (t.lastLat != null && t.lastLng != null)
        ? LatLng(t.lastLat!, t.lastLng!)
        : null;
    final but = (t.destLat != null && t.destLng != null)
        ? LatLng(t.destLat!, t.destLng!)
        : null;

    return StreamBuilder<List<LocalTripPoint>>(
      stream: context.read<TripRepository>().watchPoints(widget.tripId),
      builder: (context, snap) {
        final trace = (snap.data ?? const <LocalTripPoint>[])
            .map((p) => LatLng(p.lat, p.lng))
            .toList();

        if (position != null && but != null && !_cadreInitialFait) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _cadreInitialFait) return;
            _cadreInitialFait = true;
            _cadrerTrajet(position, but);
          });
        } else if (position != null && _suitLaPosition) {
          // Recentrage doux : on ne reprend la main que si l'utilisateur n'a
          // pas déplacé la carte lui-même.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _suitLaPosition) {
              _carte.move(position, _carte.camera.zoom);
            }
          });
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _carte,
              options: MapOptions(
                initialCenter: position ?? but ?? const LatLng(3.848, 11.5021),
                initialZoom: 15,
                // Bornes de la CAMÉRA, distinctes de celles de la couche de
                // tuiles. Sans elles, le geste de zoom n'est jamais arrêté :
                // on dépasse le dernier niveau dessinable et on tombe sur un
                // aplat uni qu'on prend pour une panne. Bridée, la carte bute
                // — comportement normal, compris de tout le monde.
                maxZoom: MapTiles.maxDisplayZoom,
                minZoom: MapTiles.minDisplayZoom,
                backgroundColor: MapTiles.background(context),
                interactionOptions: MapTiles.interactive,
                onMapEvent: (event) {
                  if (!_suitLaPosition) return;
                  final source = event.source;
                  // Uniquement un glisser : zoom et rotation ne doivent pas
                  // couper le suivi — c'est précisément en suivant qu'on
                  // oriente la carte.
                  if (source == MapEventSource.dragStart ||
                      source == MapEventSource.onDrag ||
                      source == MapEventSource.flingAnimationController) {
                    setState(() => _suitLaPosition = false);
                  }
                },
              ),
              children: [
                MapTiles.layer(context),

                // Le rayon d'arrivée, sous tout le reste : c'est un décor de
                // fond, pas un objet à cliquer. Il rend visible la règle qui
                // décidera de poser la question d'arrivée.
                if (but != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: but,
                        radius: (t.destRadiusM ?? 100).toDouble(),
                        useRadiusInMeter: true,
                        color: context.colors.primary.withValues(alpha: 0.10),
                        borderColor:
                            context.colors.primary.withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),

                if (trace.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trace,
                        strokeWidth: 5,
                        // Le liseré clair détache le tracé du fond : sans lui,
                        // une polyligne bleue sur une route bleue disparaît.
                        borderStrokeWidth: 2,
                        borderColor:
                            context.colors.surface.withValues(alpha: 0.9),
                        // Une trace grise doit rester visible SUR LES TUILES,
                        // qui sont déjà claires : `outline` s'y dissout.
                        color: t.stale
                            ? context.colors.onSurfaceVariant
                            : context.colors.primary,
                      ),
                    ],
                  ),

                if (but != null)
                  MarkerLayer(rotate: true, markers: [
                    Marker(
                      point: but,
                      width: 34,
                      height: 34,
                      child: _marqueurBut(),
                    ),
                  ]),

                if (position != null)
                  MarkerLayer(rotate: true, markers: [
                    Marker(
                      point: position,
                      width: 40,
                      height: 40,
                      child: _marqueurPosition(v),
                    ),
                  ]),

                // Dans les enfants de la carte, pas dans la pile au-dessus :
                // la mention s'abonne aux événements de la carte pour se
                // replier quand on la déplace.
                MapTiles.attributionWidget(),
                MapCompass(
                  alignment: Alignment.centerLeft,
                  useSafeArea: _immersif,
                ),
              ],
            ),

            if (!_suitLaPosition && position != null)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                // 48 dp au minimum : `FloatingActionButton.small` fait 40 et
                // passait sous le seuil tactile.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (but != null) ...[
                      SizedBox(
                        width: AppSizes.minTapTarget,
                        height: AppSizes.minTapTarget,
                        child: FloatingActionButton(
                          heroTag: 'trip-fit',
                          tooltip: l10n.tripsMapFitBounds,
                          elevation: 3,
                          onPressed: () => _cadrerTrajet(position, but),
                          child: const Icon(Icons.zoom_out_map,
                              size: AppIconSize.sm),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SizedBox(
                      width: AppSizes.minTapTarget,
                      height: AppSizes.minTapTarget,
                      child: FloatingActionButton(
                        heroTag: 'trip-recenter',
                        tooltip: l10n.tripsRecenter,
                        elevation: 3,
                        onPressed: () =>
                            setState(() => _suitLaPosition = true),
                        child:
                            const Icon(Icons.my_location, size: AppIconSize.sm),
                      ),
                    ),
                  ],
                ),
              ),

            // Même accès au cadrage quand on suit encore la position (but hors
            // cadre fréquent en ville dense).
            if (_suitLaPosition && position != null && but != null)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: SizedBox(
                  width: AppSizes.minTapTarget,
                  height: AppSizes.minTapTarget,
                  child: FloatingActionButton(
                    heroTag: 'trip-fit-follow',
                    tooltip: l10n.tripsMapFitBounds,
                    elevation: 3,
                    onPressed: () => _cadrerTrajet(position, but),
                    child:
                        const Icon(Icons.zoom_out_map, size: AppIconSize.sm),
                  ),
                ),
              ),

            if (!_immersif)
              Positioned(
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                child: SizedBox(
                  width: AppSizes.minTapTarget,
                  height: AppSizes.minTapTarget,
                  child: FloatingActionButton(
                    heroTag: 'trip-expand',
                    tooltip: l10n.tripsMapExpand,
                    elevation: 3,
                    onPressed: () => setState(() => _immersif = true),
                    child: const Icon(Icons.fullscreen, size: AppIconSize.sm),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Le point de la personne suivie. Le halo bat tant que les positions
  /// arrivent, et **s'éteint dès qu'elles cessent** — c'est ce qui distingue
  /// une carte vivante d'une carte figée sur un vieux point.
  Widget _marqueurPosition(TripVisual v) => Stack(
        alignment: Alignment.center,
        children: [
          TripPulse(color: v.color, size: 14, animate: v.pulses),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: v.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        ],
      );

  Widget _marqueurBut() => Container(
        decoration: BoxDecoration(
          color: context.colors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
      );

  /// Pied quand le trajet est déjà clos — plus de Confirmer / SOS.
  Widget _piedClos(dynamic l10n, LocalTrip t, TripVisual v) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.sheetTop,
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(v.icon, color: v.ink),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    v.label,
                    style: context.text.titleSmall?.copyWith(
                      color: v.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlayClos(dynamic l10n, LocalTrip t, TripVisual v) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Material(
            color: context.colors.surface.withValues(alpha: 0.94),
            borderRadius: AppRadius.brMd,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(v.icon, color: v.ink),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(v.label,
                        style: context.text.labelLarge?.copyWith(
                          color: v.ink,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonClose),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pied d'écran ──────────────────────────────────────────────────

  /// Le pied est une feuille posée **sur** la carte : ombre vers le haut et
  /// coins arrondis. Sans ce relief, les boutons flottent sur les tuiles et on
  /// ne sait plus ce qui appartient à la carte et ce qui appartient au trajet.
  Widget _pied(dynamic l10n, LocalTrip t, TripVisual v) {
    final distanceM = _distanceAuButM(t);
    final faits = <Widget>[
      if (t.etaAt != null)
        TripFactChip(
          icon: Icons.schedule,
          label: l10n.tripsEtaAt(TripFormat.hhmm(t.etaAt!)),
          tint: v.tone == TripTone.awaiting ? v.ink : null,
        ),
      if (distanceM != null)
        TripFactChip(
          icon: Icons.near_me_outlined,
          label: distanceM >= 1000
              ? l10n.tripsDistanceKm((distanceM / 1000))
              : l10n.tripsDistanceM(distanceM),
        ),
      // Owner : ne pas afficher watcherCount ici (= taille du cercle, promesse).
      // Le vrai suivi est dans TripWatchersRow (« X sur Y ont vu » / seenAt).
      // Membre : décompte anonymisé uniquement (pas les identités du cercle).
      if (!widget.isOwner)
        TripFactChip(
          icon: Icons.group_outlined,
          label: l10n.tripsWatcherCount(t.watcherCount),
        ),
      if (t.lastAccuracyM != null)
        TripFactChip(
          icon: Icons.adjust,
          label: '± ${t.lastAccuracyM} m',
        ),
      if (t.lastBattery != null)
        TripFactChip(
          icon: Icons.battery_std,
          label: '${t.lastBattery} %',
          tint: (t.lastBattery ?? 100) <= 15 ? context.semantic.warning : null,
        ),
    ];

    final aConfirmer = t.state == TripState.awaitingConfirm;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.sheetTop,
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: faits),
            if (!widget.isOwner) _actionsMembre(l10n, t, v),
            // Qui regarde, et qui a ouvert. Réservé au propriétaire : un membre
            // n'a pas à connaître le carnet d'adresses de quelqu'un d'autre —
            // c'est aussi pourquoi il ne voit qu'un décompte.
            if (widget.isOwner && TripState.isOpen(t.state))
              TripWatchersRow(tripId: widget.tripId),
            if (widget.isOwner) ...[
              if (aConfirmer) ...[
                const SizedBox(height: AppSpacing.lg),
                // Confirmer n'est dominant qu'à l'arrivée : en trajet actif,
                // un bouton vert plein ment sur l'urgence.
                FilledButton.icon(
                  onPressed: _occupe ? null : _confirmer,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.tripsConfirmArrival,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.semantic.success,
                    foregroundColor: context.semantic.onSuccess,
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  for (final m in const [15, 30]) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _occupe ? null : () => _prolonger(m),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.minTapTarget),
                        ),
                        child: Text(l10n.tripsExtendBy(m)),
                      ),
                    ),
                    if (m == 15) const SizedBox(width: AppSpacing.sm),
                  ],
                ]),
              ],
              const SizedBox(height: AppSpacing.md),
              // Le suivi continue écran verrouillé grâce au service en
              // avant-plan. On le dit, parce que c'est exactement la question
              // que se pose quelqu'un qui range son téléphone dans sa poche.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: 14, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      // On dit ce qui est vrai sur CET appareil, pas ce qui est
                      // vrai en général. Sur un iPhone où seul « Pendant
                      // l'utilisation » a été accordé, le partage s'interrompt
                      // dès qu'on quitte l'application — affirmer le contraire
                      // serait la pire des promesses à arrondir.
                      TripSessionGuard.instance.suitEnArrierePlan
                          ? l10n.tripsKeepsRunning
                          : l10n.tripsForegroundOnly,
                      style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Arrêter d'abord (discret) ; SOS tertiaire — le rouge n'occupe
              // pas la moitié du pied pendant un trajet calme.
              OutlinedButton.icon(
                onPressed: _occupe ? null : _arreter,
                icon: const Icon(Icons.stop_circle_outlined,
                    size: AppIconSize.sm),
                label: Text(l10n.tripsStop),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                ),
              ),
              TextButton.icon(
                onPressed: _occupe ? null : _sos,
                icon: Icon(Icons.sos_outlined,
                    size: AppIconSize.sm,
                    color: context.colors.onSurfaceVariant),
                label: Text(l10n.tripsSosButton,
                    style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Cadre la position et le but. Coupe le suivi pin-seul pour ne pas
  /// recentrer immédiatement sur un seul point.
  void _cadrerTrajet(LatLng? position, LatLng? but) {
    if (position == null || but == null) return;
    setState(() => _suitLaPosition = false);
    try {
      _carte.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(position, but),
          padding: const EdgeInsets.all(56),
          maxZoom: 16,
        ),
      );
    } catch (e) {
      debugPrint('[TripLive] cadrage: $e');
    }
  }

  int? _distanceAuButM(LocalTrip t) {
    if (t.lastLat == null ||
        t.lastLng == null ||
        t.destLat == null ||
        t.destLng == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      t.lastLat!,
      t.lastLng!,
      t.destLat!,
      t.destLng!,
    ).round();
  }

  // ── Côté membre ───────────────────────────────────────────────────

  /// Un membre du cercle a exactement deux gestes, et pas un de plus.
  ///
  /// **« J'ai vu »** est implicite : ouvrir cet écran vaut accusé de réception,
  /// et il remonte au propriétaire. C'est le seul retour qu'un membre puisse
  /// donner, et il vaut mieux qu'il parte tout seul qu'oublié dans un bouton.
  ///
  /// **« Appeler »** est le geste qui compte. Suivre un point sur une carte
  /// pendant que quelqu'un ne confirme pas son arrivée est une position
  /// insupportable si l'on n'a rien à en faire ; l'appel est la seule action
  /// qui transforme l'inquiétude en quelque chose d'utile. Il est mis en avant
  /// dès que le cercle a été prévenu.
  ///
  /// Ce qu'un membre ne peut **pas** faire : clore le trajet, ni consulter les
  /// trajets passés. Ce n'est pas à lui d'en décider, et il n'a pas à disposer
  /// d'un historique des déplacements de quelqu'un d'autre.
  Widget _actionsMembre(dynamic l10n, LocalTrip t, TripVisual v) {
    final urgent = v.tone == TripTone.alerted;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          urgent
          ? FilledButton.icon(
              onPressed: _occupe ? null : () => _appeler(t),
              icon: const Icon(Icons.call),
              label: Text(l10n.tripsCall,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError,
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
            )
          : OutlinedButton.icon(
              onPressed: _occupe ? null : () => _appeler(t),
              icon: const Icon(Icons.call, size: AppIconSize.sm),
              label: Text(l10n.tripsCall),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          // Discret, et à sa place : sortir ne doit jamais concurrencer
          // « Appeler », mais doit rester trouvable. Personne n'a demandé à
          // entrer dans un cercle, et la décision de suivre appartient à celui
          // qu'on y a mis.
          TextButton(
            onPressed: _occupe ? null : () => _quitter(t),
            child: Text(l10n.tripsLeave),
          ),
        ],
      ),
    );
  }

  /// Quitter le suivi d'un trajet.
  ///
  /// On demande confirmation, contrairement à « Arrêter le partage » côté
  /// porteur qui reste sans frein. Les deux gestes n'ont pas le même risque :
  /// arrêter son propre partage doit rester gratuit, sous peine de devenir
  /// punissable ; cesser de veiller sur quelqu'un mérite une seconde de
  /// réflexion, et le texte dit exactement ce qu'on perd.
  Future<void> _quitter(LocalTrip t) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.tripsLeaveTitle),
        content: Text(l10n.tripsLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(c).colorScheme.error,
            ),
            child: Text(l10n.tripsLeave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _agir(() async {
      final moi = context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
      if (moi == 0) return;
      await context.read<TripRepository>().leaveTrip(t.id, moi);
      if (!mounted) return;
      context.read<TripSocketService>().unsubscribe(t.id);
      Navigator.pop(context);
    });
  }

  /// Une décision pour le watcher en alerte : Appeler, ou rester sur la carte.
  Future<void> _feuilleUrgence(LocalTrip t, TripVisual v) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final maj = t.lastAt != null
        ? (t.stale
            ? l10n.tripsPositionFrozen
            : l10n.tripsUpdatedAgo(TripFormat.depuis(t.lastAt!)))
        : l10n.tripsUnreachable;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TripCrest(visual: v, size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.label,
                            style: Theme.of(c).textTheme.titleMedium?.copyWith(
                                  color: v.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            maj,
                            style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(c)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    unawaited(_appeler(t));
                  },
                  icon: const Icon(Icons.call),
                  label: Text(l10n.tripsCall,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                    foregroundColor: Theme.of(c).colorScheme.onError,
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(l10n.tripsCardFollow),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Appelle la personne suivie.
  ///
  /// Son profil est lu dans le cache local plutôt que demandé au réseau : au
  /// moment où l'on appuie sur ce bouton, le réseau peut être mauvais, et un
  /// appel qui attend une requête de profil est un appel qu'on n'a pas passé.
  /// C'est un contact du cercle, il est donc dans le cache par construction.
  Future<void> _appeler(LocalTrip t) => _agir(() async {
        final me = context.read<AuthProvider>().currentUser;
        if (me == null) return;
        final proprietaire =
            await context.read<LocalCacheRepository>().getKnownUserProfile(t.ownerId);
        if (!mounted) return;

        await context.read<CallService>().initiateCall(
              targetUserId: t.ownerId,
              myId: me.alanyaID,
              myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
              myPhoto: me.avatarUrl,
              targetUserName: proprietaire?.nom ?? '',
              targetUserPhoto: proprietaire?.avatarUrl ?? '',
              isVideo: false,
            );
      });

  bool _occupe = false;

  Future<void> _agir(Future<void> Function() action) async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      await action();
    } on TalkyException catch (e) {
      if (mounted) {
        _erreur(e.statusCode == 409
            ? context.l10n.tripsAlreadyClosed
            : context.l10n.tripsActionFailed);
      }
    } catch (_) {
      if (mounted) _erreur(context.l10n.tripsActionFailed);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _confirmer() => _agir(() async {
        await context.read<TripRepository>().confirmTrip(widget.tripId);
        await TripSessionGuard.instance.release();
        if (!mounted) return;
        // Retour haptique + message : une clôture silencieuse laisse douter
        // qu'elle a bien eu lieu, au pire moment pour douter.
        HapticFeedback.lightImpact();
        _info(context.l10n.tripsConfirmed);
        Navigator.pop(context);
      });

  /// Prolonger est à deux appuis et sans limite de nombre : un embouteillage ne
  /// doit pas coûter une alerte, et le cercle est informé — cela rassure sans
  /// alerter.
  Future<void> _prolonger(int minutes) => _agir(() async {
        await context.read<TripRepository>().extendTrip(widget.tripId, minutes);
        if (mounted) _info(context.l10n.tripsExtended(minutes));
      });

  /// « Arrêter le partage » est toujours à un appui, et sans confirmation.
  /// Si arrêter coûtait cher, arrêter deviendrait punissable par quelqu'un qui
  /// regarde par-dessus l'épaule.
  Future<void> _arreter() => _agir(() async {
        await context.read<TripRepository>().cancelTrip(widget.tripId);
        await TripSessionGuard.instance.release();
        if (mounted) Navigator.pop(context);
      });

  /// Passe par le même écran d'armement que le SOS autonome : le maintien et
  /// le décompte protègent autant du déclenchement en poche ici qu'ailleurs.
  Future<void> _sos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripSosScreen()),
    );
    if (mounted) {
      unawaited(context.read<TripRepository>().syncTrip(widget.tripId,
          isOwner: widget.isOwner));
    }
  }

  /// Pose la question d'arrivée, et applique la réponse.
  ///
  /// « Pas encore » ne suspend rien : l'échéance est gardée par le serveur et
  /// continue de courir. C'est écrit dans la feuille, et c'est ce qui distingue
  /// une sortie honnête d'une échappatoire trompeuse.
  Future<void> _demanderArrivee(LocalTrip t) async {
    if (_immersif) setState(() => _immersif = false);
    final choix = await TripArrivalSheet.montrer(
      context,
      // Une arrivée détectée par le rayon est une hypothèse ; une échéance
      // dépassée est un fait. Les deux ne se disent pas sur le même ton.
      parDestination: t.destLabel != null && t.etaAt != null
          ? DateTime.now().isBefore(t.etaAt!)
          : t.etaAt == null,
      alerteA: t.etaAt?.add(Duration(minutes: t.graceMinutes)),
    );
    if (!mounted || choix == null) return;

    switch (choix) {
      case TripArrivalChoice.confirme:
        await _confirmer();
      case TripArrivalChoice.prolonge15:
        await _prolonger(15);
      case TripArrivalChoice.prolonge30:
        await _prolonger(30);
      case TripArrivalChoice.plusTard:
        break;
    }
  }

  /// Ouvre les réglages système pour rétablir la localisation.
  Future<void> _ouvrirReglages() async {
    await Geolocator.openAppSettings();
  }

  void _erreur(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  void _info(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));
}
