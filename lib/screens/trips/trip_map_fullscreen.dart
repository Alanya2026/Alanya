import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tiles.dart';
import '../../widgets/trips/trip_visuals.dart';

/// Carte plein écran pour visualiser un trajet passé.
class TripMapFullscreen extends StatefulWidget {
  const TripMapFullscreen({
    super.key,
    required this.points,
    this.destination,
    this.destRadiusM,
    this.lastPosition,
    required this.visual,
  });

  final List<LatLng> points;
  final LatLng? destination;
  final double? destRadiusM;
  final LatLng? lastPosition;
  final TripVisual visual;

  @override
  State<TripMapFullscreen> createState() => _TripMapFullscreenState();
}

class _TripMapFullscreenState extends State<TripMapFullscreen> {
  final _carte = MapController();
  bool _cadreFait = false;

  @override
  void initState() {
    super.initState();
    // Ajuster la carte après le premier frame, quand le layout est prêt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cadrer();
    });
  }

  @override
  void dispose() {
    _carte.dispose();
    super.dispose();
  }

  void _cadrer() {
    if (_cadreFait) return;
    _cadreFait = true;

    final tous = <LatLng>[
      ...widget.points,
      if (widget.destination != null) widget.destination!,
      if (widget.lastPosition != null) widget.lastPosition!,
    ];
    if (tous.isEmpty) return;

    double minLat = tous.first.latitude,
        maxLat = tous.first.latitude;
    double minLng = tous.first.longitude,
        maxLng = tous.first.longitude;
    for (final p in tous) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    const marge = 0.005;
    final bounds = LatLngBounds(
      LatLng(minLat - marge, minLng - marge),
      LatLng(maxLat + marge, maxLng + marge),
    );

    _carte.fitCamera(CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(48),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visual;
    final but = widget.destination;
    final dernier = widget.lastPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trajet'),
        actions: [
          if (widget.points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Ajuster au trajet',
              onPressed: () {
                _cadreFait = false;
                _cadrer();
              },
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _carte,
        options: MapOptions(
          initialCenter: dernier ?? const LatLng(3.848, 11.5021),
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

          if (but != null && widget.destRadiusM != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: but,
                  radius: widget.destRadiusM!,
                  useRadiusInMeter: true,
                  color: v.color.withValues(alpha: 0.12),
                  borderColor: v.color.withValues(alpha: 0.45),
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),

          if (widget.points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.points,
                  color: v.color.withValues(alpha: 0.85),
                  strokeWidth: 4,
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
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),

          MapTiles.attributionWidget(),
        ],
      ),
    );
  }
}