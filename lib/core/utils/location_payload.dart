import 'dart:convert';

import 'package:http/http.dart' as http;

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
    return 'Position';
  }

  String get previewLabel => '📍 $displayLabel';

  String encode() {
    final map = <String, dynamic>{
      'lat': lat,
      'lng': lng,
    };
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
      final name = data['name'] is String ? (data['name'] as String).trim() : null;
      final address =
          data['address'] is String ? (data['address'] as String).trim() : null;
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
  return loc?.previewLabel ?? '📍 Position';
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
