import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/utils/map_tiles.dart';
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
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/trips/trip_arrival_sheet.dart';
import '../../widgets/trips/trip_degraded_banner.dart';
import '../../widgets/trips/trip_rail.dart';
import '../../widgets/trips/trip_visuals.dart';
import 'trip_sos_screen.dart';
import '../../talky_models.dart';

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

  /// Rafraîchit « maj il y a 8 s » sans attendre une nouvelle position : sans
  /// cela, l'ancienneté affichée gèle dès que le traceur se tait — exactement
  /// le moment où elle devient l'information la plus utile de l'écran.
  Timer? _horloge;

  @override
  void initState() {
    super.initState();
    final trips = context.read<TripRepository>();
    final socket = context.read<TripSocketService>();

    // On rejoint le flux à l'ouverture et on le quitte en sortant : inutile de
    // recevoir une position toutes les cinq secondes pour une carte que
    // personne ne regarde.
    socket.subscribe(widget.tripId);
    unawaited(trips.syncTrip(widget.tripId, isOwner: widget.isOwner));

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trips = context.read<TripRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trips)),
      body: StreamBuilder<LocalTrip?>(
        stream: trips.watchTrip(widget.tripId),
        builder: (context, snap) {
          final t = snap.data;
          if (t == null) {
            return const Center(child: CircularProgressIndicator());
          }
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

          return Column(
            children: [
              _bandeauEtat(l10n, t, v),
              TripRail(state: t.state, stale: t.stale),
              if (widget.isOwner)
                TripDegradedBanner(trip: t, onAction: _ouvrirReglages),
              Expanded(child: _carteGeo(t, v)),
              _pied(l10n, t, v),
            ],
          );
        },
      ),
    );
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

        if (position != null && _suitLaPosition) {
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
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPointerDown: (_, __) => setState(() => _suitLaPosition = false),
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
                        radius: (t.destRadiusM ?? 150).toDouble(),
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
                  MarkerLayer(markers: [
                    Marker(
                      point: but,
                      width: 34,
                      height: 34,
                      child: _marqueurBut(),
                    ),
                  ]),

                if (position != null)
                  MarkerLayer(markers: [
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
              ],
            ),

            if (!_suitLaPosition && position != null)
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                // 48 dp au minimum : `FloatingActionButton.small` fait 40 et
                // passait sous le seuil tactile.
                child: SizedBox(
                  width: AppSizes.minTapTarget,
                  height: AppSizes.minTapTarget,
                  child: FloatingActionButton(
                    heroTag: 'trip-recenter',
                    tooltip: l10n.tripsRecenter,
                    elevation: 3,
                    onPressed: () => setState(() => _suitLaPosition = true),
                    child: const Icon(Icons.my_location, size: AppIconSize.sm),
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

  // ── Pied d'écran ──────────────────────────────────────────────────

  /// Le pied est une feuille posée **sur** la carte : ombre vers le haut et
  /// coins arrondis. Sans ce relief, les boutons flottent sur les tuiles et on
  /// ne sait plus ce qui appartient à la carte et ce qui appartient au trajet.
  Widget _pied(dynamic l10n, LocalTrip t, TripVisual v) {
    final faits = <Widget>[
      if (t.etaAt != null)
        TripFactChip(
          icon: Icons.schedule,
          label: l10n.tripsEtaAt(TripFormat.hhmm(t.etaAt!)),
          tint: v.tone == TripTone.awaiting ? v.ink : null,
        ),
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
            if (widget.isOwner) ...[
              const SizedBox(height: AppSpacing.lg),
              // Confirmer est l'action dominante dès que l'échéance approche :
              // c'est la seule qui clôt le trajet, et la seule qui rassure.
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
                      l10n.tripsKeepsRunning,
                      style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _occupe ? null : _sos,
                    icon: Icon(Icons.warning_amber_rounded,
                        size: AppIconSize.sm, color: context.colors.error),
                    label: Text(l10n.tripsSosButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.colors.error,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                      side: BorderSide(
                          color: context.colors.error.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // « Arrêter » reste à un appui et sans confirmation : si
                // arrêter coûtait cher, arrêter deviendrait punissable.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _occupe ? null : _arreter,
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: AppIconSize.sm),
                    label: Text(l10n.tripsStop,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
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
      child: urgent
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
