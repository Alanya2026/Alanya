import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/trip_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tiles.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/trips/trip_visuals.dart';
import '../../widgets/trips/trip_watchers_row.dart';

/// Récapitulatif d'un trajet passé — **propriétaire uniquement**.
///
/// Résumé, frise d'événements, et polyligne figée si la trace n'a pas encore
/// été purgée. Pas de replay animé : la carte dit « où c'est passé », pas
/// « rejoue la course ».
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId, this.initial});

  final int tripId;
  final Trip? initial;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Trip? _trip;
  List<LocalTripEvent> _events = const [];
  List<TripPoint>? _trace;
  bool _tracePurged = false;
  bool _charge = true;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _trip = widget.initial;
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = null;
    });
    final trips = context.read<TripRepository>();
    try {
      final synced = await trips.syncTrip(widget.tripId, isOwner: true);
      final events = await trips.getEventsOnce(widget.tripId);
      List<TripPoint>? trace;
      var purged = false;
      try {
        trace = await trips.loadTrace(widget.tripId);
        purged = trace == null;
      } catch (_) {
        purged = true;
        trace = null;
      }
      if (!mounted) return;
      setState(() {
        if (synced != null) _trip = synced;
        _events = events;
        _trace = trace;
        _tracePurged = purged;
        _charge = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e;
        _charge = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = _trip;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripsDetailTitle)),
      body: _charge && t == null
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null && t == null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: l10n.tripsHistoryUnavailable,
                  message: l10n.tripsHistoryOnline,
                  action: FilledButton(
                    onPressed: _charger,
                    child: Text(l10n.retry),
                  ),
                )
              : t == null
                  ? EmptyState(
                      icon: Icons.shield_outlined,
                      title: l10n.tripsNoLongerShared,
                      message: l10n.tripsNoLongerSharedBody,
                      action: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.commonClose),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        children: [
                          _entete(l10n, t),
                          const SizedBox(height: AppSpacing.md),
                          _carteSection(l10n, t),
                          const SizedBox(height: AppSpacing.lg),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: Text(
                              l10n.tripsDetailTimeline,
                              style: context.text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_events.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                l10n.tripsDetailNoEvents,
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            ..._events.map((e) => _ligneEvent(l10n, e)),
                        ],
                      ),
                    ),
    );
  }

  Widget _entete(dynamic l10n, Trip t) {
    final v = TripVisual.resolve(
      context,
      state: t.state,
      alerte: t.alertedAt != null || t.state == TripState.closedExpired,
    );
    final duree = t.closedAt?.difference(t.startedAt).inMinutes;

    return Container(
      width: double.infinity,
      color: v.color.withValues(alpha: 0.10),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TripCrest(visual: v, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.destLabel ?? v.label,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.label,
                      style: context.text.labelMedium?.copyWith(
                        color: v.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TripFactChip(
                icon: Icons.schedule,
                label:
                    '${TripFormat.hhmm(t.startedAt)}${t.closedAt != null ? ' – ${TripFormat.hhmm(t.closedAt!)}' : ''}',
              ),
              if (duree != null)
                TripFactChip(
                  icon: Icons.timelapse,
                  label: l10n.tripsMinutes(duree),
                ),
              TripFactChip(
                icon: Icons.group_outlined,
                label: l10n.tripsWatcherFollowedCount(
                    t.watchersSeenCount ??
                        t.watchers.where((w) => w.seenAt != null).length),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TripWatchersRow(
            tripId: t.id,
            allowRevoke: false,
            pastTense: true,
          ),
        ],
      ),
    );
  }

  Widget _carteSection(dynamic l10n, Trip t) {
    if (_charge && _trace == null && !_tracePurged) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_tracePurged || (_trace != null && _trace!.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: EmptyState(
          icon: Icons.route_outlined,
          title: l10n.tripsTraceExpired,
          message: l10n.tripsTraceExpiredBody,
        ),
      );
    }

    final points = (_trace ?? const <TripPoint>[])
        .map((p) => LatLng(p.lat, p.lng))
        .toList();
    final but = (t.destLat != null && t.destLng != null)
        ? LatLng(t.destLat!, t.destLng!)
        : null;
    final dernier = points.isNotEmpty
        ? points.last
        : (t.lastPoint != null
            ? LatLng(t.lastPoint!.lat, t.lastPoint!.lng)
            : but);
    final v = TripVisual.resolve(context, state: t.state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: AppRadius.brMd,
        child: SizedBox(
          height: 240,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: dernier ?? but ?? const LatLng(3.848, 11.5021),
              initialZoom: 14,
              maxZoom: MapTiles.maxDisplayZoom,
              minZoom: MapTiles.minDisplayZoom,
              backgroundColor: MapTiles.background(context),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              MapTiles.layer(context),
              if (but != null && t.destRadiusM != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: but,
                      radius: (t.destRadiusM ?? 100).toDouble(),
                      useRadiusInMeter: true,
                      color: v.color.withValues(alpha: 0.12),
                      borderColor: v.color.withValues(alpha: 0.45),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: v.color.withValues(alpha: 0.85),
                      strokeWidth: 3.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (but != null)
                    Marker(
                      point: but,
                      width: 28,
                      height: 28,
                      child: Icon(Icons.flag_rounded, color: v.ink, size: 22),
                    ),
                  if (dernier != null)
                    Marker(
                      point: dernier,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: v.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneEvent(dynamic l10n, LocalTripEvent e) {
    return ListTile(
      dense: true,
      leading: Icon(_iconeEvent(e.kind), size: 20,
          color: context.colors.onSurfaceVariant),
      title: Text(_libelleEvent(l10n, e.kind),
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      trailing: Text(
        TripFormat.hhmm(e.at),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  IconData _iconeEvent(String kind) => switch (kind) {
        'started' => Icons.play_arrow_rounded,
        'extended' => Icons.more_time,
        'arrival_detected' || 'eta_due' => Icons.place_outlined,
        'confirmed' => Icons.check_circle_outline,
        'alerted' || 'sos' => Icons.warning_amber_rounded,
        'resolved' => Icons.verified_outlined,
        'closed' => Icons.stop_circle_outlined,
        'signal_lost' => Icons.location_disabled,
        'signal_back' => Icons.my_location,
        'low_battery' => Icons.battery_alert,
        'watcher_seen' => Icons.visibility_outlined,
        'watcher_revoked' => Icons.person_remove_outlined,
        'device_takeover' => Icons.phonelink_setup,
        _ => Icons.circle_outlined,
      };

  String _libelleEvent(dynamic l10n, String kind) => switch (kind) {
        'started' => l10n.tripsEventStarted,
        'extended' => l10n.tripsEventExtended,
        'arrival_detected' => l10n.tripsEventArrivalDetected,
        'eta_due' => l10n.tripsEventEtaDue,
        'confirmed' => l10n.tripsOutcomeConfirmed,
        'alerted' => l10n.tripsEventAlerted,
        'sos' => l10n.tripsSosTitle,
        'resolved' => l10n.tripsSosFalseAlarm,
        'closed' => l10n.tripsEventClosed,
        'signal_lost' => l10n.tripsStale,
        'signal_back' => l10n.tripsEventSignalBack,
        'low_battery' => l10n.tripsEventLowBattery,
        'watcher_seen' => l10n.tripsEventWatcherSeen,
        'watcher_revoked' => l10n.tripsEventWatcherRevoked,
        'device_takeover' => l10n.tripsEventDeviceTakeover,
        _ => kind,
      };
}
