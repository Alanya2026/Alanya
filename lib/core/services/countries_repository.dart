import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';

/// Cache local de la liste des pays (`GET /pays`).
class CountriesRepository {
  static const _cacheKey = 'countries_cache_v1';

  final TalkyApiClient _api;
  List<Pays>? _memory;

  CountriesRepository({required TalkyApiClient api}) : _api = api;

  Future<List<Pays>> fetchCountries({bool force = false}) async {
    if (!force && _memory != null && _memory!.isNotEmpty) {
      return _memory!;
    }

    if (!force) {
      final cached = await _loadFromPrefs();
      if (cached != null && cached.isNotEmpty) {
        _memory = cached;
        return cached;
      }
    }

    final raw = await _api.getPays();
    final countries = raw
        .whereType<Map>()
        .map((e) => Pays.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.idPays > 0 && p.libelle.isNotEmpty)
        .toList()
      ..sort((a, b) => a.libelle.compareTo(b.libelle));

    _memory = countries;
    await _saveToPrefs(countries);
    return countries;
  }

  Pays? findById(int idPays, {List<Pays>? countries}) {
    final list = countries ?? _memory;
    if (list == null) return null;
    for (final p in list) {
      if (p.idPays == idPays) return p;
    }
    return null;
  }

  Future<List<Pays>?> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => Pays.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToPrefs(List<Pays> countries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = countries
          .map((p) => {
                'idPays': p.idPays,
                'libelle': p.libelle,
                'prefix': p.prefix,
              })
          .toList();
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {
      // Cache best-effort — ignoré si indisponible.
    }
  }
}
