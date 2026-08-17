import 'dart:convert';

import 'package:http/http.dart' as http;
import '../theme/locale_controller.dart';

/// Payload JSON d'un message localisation (`type = 5`).
class LocationPayload {
  const LocationPayload({
    required this.lat,
    required this.lng,
    this.name,
    this.address,
  });

  final double lat;
  final double lng;
  final String? name;
  final String? address;

  String get displayLabel {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final a = address?.trim();
    if (a != null && a.isNotEmpty) return a;
    return LocaleController.instance.l10n.location2;
  }

  String get previewLabel => '📍 $displayLabel';

  String encode() {
    final map = <String, dynamic>{'lat': lat, 'lng': lng};
    final n = name?.trim();
    if (n != null && n.isNotEmpty) map['name'] = n;
    final a = address?.trim();
    if (a != null && a.isNotEmpty) map['address'] = a;
    return jsonEncode(map);
  }

  static LocationPayload? tryParse(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    try {
      final data = jsonDecode(content);
      if (data is! Map) return null;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      final name = data['name'] is String
          ? (data['name'] as String).trim()
          : null;
      final address = data['address'] is String
          ? (data['address'] as String).trim()
          : null;
      return LocationPayload(
        lat: lat,
        lng: lng,
        name: (name != null && name.isNotEmpty) ? name : null,
        address: (address != null && address.isNotEmpty) ? address : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// URL pour ouvrir la position dans une app / navigateur Maps.
  Uri mapsOpenUri() {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
  }

  Uri geoUri() => Uri.parse('geo:$lat,$lng?q=$lat,$lng');
}

/// Aperçu conversation / notif pour un message type 5.
String locationPreviewLabel(String? content) {
  final loc = LocationPayload.tryParse(content);
  return loc?.previewLabel ?? LocaleController.instance.l10n.location;
}

/// Un résultat de recherche de lieu.
class PlaceHit {
  const PlaceHit({
    required this.lat,
    required this.lng,
    required this.name,
    required this.address,
  });

  final double lat;
  final double lng;

  /// Première partie de l'adresse — le nom reconnaissable du lieu.
  final String name;

  /// Adresse complète, affichée en second pour lever l'ambiguïté entre deux
  /// lieux qui portent le même nom.
  final String address;
}

/// Une recherche aboutie, même sans résultat, est distincte d'un échec réseau.
class PlaceSearchResult {
  const PlaceSearchResult.found(this.hits) : failed = false;
  const PlaceSearchResult.failed() : hits = const [], failed = true;

  final List<PlaceHit> hits;
  final bool failed;
}

/// Recherche de lieu (géocodage direct) via Nominatim.
///
/// Pendant du géocodage inverse déjà utilisé pour nommer une position. Même
/// contrat : délai court et échec silencieux — une recherche qui ne répond pas
/// ne doit jamais bloquer le choix sur la carte, qui reste toujours possible.
///
/// ⚠ Nominatim impose un maximum d'une requête par seconde et un `User-Agent`
/// identifiant. L'appelant DOIT temporiser la saisie ; c'est fait dans
/// `location_picker_screen.dart`.
///
/// [near] recentre la recherche autour d'un point : sans lui, « pharmacie »
/// renvoie des résultats à l'autre bout du monde.
Future<PlaceSearchResult> searchPlaces(
  String query, {
  LocationPayload? near,
  int limit = 8,
}) async {
  final q = query.trim();
  if (q.length < 3) return const PlaceSearchResult.found([]);
  try {
    final params = <String, String>{
      'format': 'json',
      'q': q,
      'limit': '$limit',
      'addressdetails': '0',
      if (near != null)
        // Boîte englobante d'environ 1°, soit ~110 km : assez large pour ne
        // rien manquer localement, assez étroite pour écarter le reste.
        'viewbox':
            '${near.lng - 0.5},${near.lat + 0.5},'
            '${near.lng + 0.5},${near.lat - 0.5}',
      if (near != null) 'bounded': '1',
    };
    final res = await http
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', params),
          headers: {
            'User-Agent': 'AlanyaTalky/1.0 (place search)',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const PlaceSearchResult.failed();

    final data = jsonDecode(res.body);
    if (data is! List) return const PlaceSearchResult.failed();

    return PlaceSearchResult.found(
      data
          .whereType<Map>()
          .map((r) {
            final lat = double.tryParse('${r['lat']}');
            final lng = double.tryParse('${r['lon']}');
            final display = '${r['display_name'] ?? ''}'.trim();
            if (lat == null || lng == null || display.isEmpty) return null;
            final parts = display.split(',');
            return PlaceHit(
              lat: lat,
              lng: lng,
              name: parts.first.trim(),
              address: parts.length > 1
                  ? parts.sublist(1).join(',').trim()
                  : display,
            );
          })
          .whereType<PlaceHit>()
          .toList(),
    );
  } catch (_) {
    return const PlaceSearchResult.failed();
  }
}

/// Reverse geocode Nominatim (timeout court, fallback silencieux).
Future<LocationPayload> enrichLocationWithAddress(LocationPayload base) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'json',
      'lat': base.lat.toString(),
      'lon': base.lng.toString(),
      'zoom': '18',
      'addressdetails': '0',
    });
    final res = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'AlanyaTalky/1.0 (location share)',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return base;
    final data = jsonDecode(res.body);
    if (data is! Map) return base;
    final display = data['display_name'];
    if (display is! String || display.trim().isEmpty) return base;
    final address = display.trim();
    // Première partie = nom approximatif du lieu.
    final name = address.split(',').first.trim();
    return LocationPayload(
      lat: base.lat,
      lng: base.lng,
      name: name.isNotEmpty ? name : base.name,
      address: address,
    );
  } catch (_) {
    return base;
  }
}
