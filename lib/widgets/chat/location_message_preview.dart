import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location_payload.dart';
import '../../core/utils/map_tiles.dart';

/// Preview carte dans une bulle (style WhatsApp) :
/// mêmes tuiles que l'écran d'envoi (source servie par le serveur),
/// non interactive, un seul pin, libellé en overlay bas.
class LocationMessagePreview extends StatelessWidget {
  const LocationMessagePreview({
    super.key,
    required this.location,
    this.width = 240,
    this.height = 160,
  });

  final LocationPayload location;
  final double width;
  final double height;

  static const _pinColor = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final point = LatLng(location.lat, location.lng);
    final title = location.displayLabel;
    final subtitle = _subtitle;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions: MapTiles.inert,
                  backgroundColor: MapTiles.background(context),
                ),
                children: [
                  MapTiles.layer(context),
                ],
              ),
            ),
            // Pin unique : pointe alignée sur le centre (comme l'écran d'envoi).
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 28),
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: _pinColor,
                    shadows: [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ),
            // Bandeau bas façon WhatsApp.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x99000000),
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Mention légale. Minuscule, mais présente : le fond est servi par le
            // serveur (Mapbox, OSM, tuiles propres…), et sa licence exige
            // l'attribution là où il est affiché — y compris dans cette bulle.
            // Posée en haut à droite : le bas appartient au bandeau.
            Positioned(
              top: 4,
              right: 4,
              child: IgnorePointer(
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
            ),
          ],
        ),
      ),
    );
  }

  String? get _subtitle {
    final address = location.address?.trim();
    if (address == null || address.isEmpty) return null;
    if (address == location.displayLabel) return null;
    // Évite de répéter le name déjà affiché en titre.
    final name = location.name?.trim();
    if (name != null &&
        name.isNotEmpty &&
        address.toLowerCase().startsWith(name.toLowerCase())) {
      final rest = address.substring(name.length).replaceFirst(RegExp(r'^,\s*'), '');
      return rest.isEmpty ? null : rest;
    }
    return address;
  }
}