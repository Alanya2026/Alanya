// La version de l'application et l'avis « nouvelle version » (lot D7).
//
// Pas de mise à jour automatique en version 1 : au démarrage puis une fois
// par jour, l'application lit version.json sur le site et, s'il annonce une
// version plus récente, affiche un bandeau avec le lien de téléchargement.
// L'inscrit réinstalle par-dessus, sans perdre sa connexion.
//
// kAppVersion doit suivre `version:` de pubspec.yaml ; la construction
// (.github/workflows/coffre-bureau.yml) vérifie les deux contre l'étiquette.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kAppVersion = '1.1.0';
const String kDownloadPageUrl = 'https://www.alanya237.com/coffre';
const String kVersionUrl = 'https://www.alanya237.com/coffre/version.json';

/// -1, 0 ou 1 : « 1.10.0 » est après « 1.9.2 ». Un morceau illisible vaut 0.
int compareVersions(String a, String b) {
  List<int> morceaux(String v) => [for (final p in v.split('+').first.split('.')) int.tryParse(p.trim()) ?? 0];
  final x = morceaux(a);
  final y = morceaux(b);
  for (var i = 0; i < 3; i += 1) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

class UpdateChecker extends ChangeNotifier {
  UpdateChecker({http.Client? client, this.current = kAppVersion}) : _client = client ?? http.Client();

  static const _cleIgnoree = 'coffre_update_dismissed';

  final http.Client _client;
  final String current;
  Timer? _minuteur;

  String? _disponible;
  String? _ignoree;

  /// La version plus récente annoncée, si l'inscrit ne l'a pas écartée.
  String? get available => _disponible != null && _disponible != _ignoree ? _disponible : null;

  void start() {
    unawaited(check());
    _minuteur ??= Timer.periodic(const Duration(hours: 24), (_) => unawaited(check()));
  }

  Future<void> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ignoree = prefs.getString(_cleIgnoree);
      final r = await _client.get(Uri.parse(kVersionUrl)).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final v = (jsonDecode(r.body) as Map)['version'];
      if (v is String && compareVersions(v, current) > 0) {
        _disponible = v;
        notifyListeners();
      }
    } catch (e) {
      // Hors ligne, page pas encore publiée : on réessaiera demain.
      debugPrint('[Version] lecture impossible : $e');
    }
  }

  /// « Plus tard » : le bandeau ne revient qu'avec une version suivante.
  Future<void> dismiss() async {
    _ignoree = _disponible;
    notifyListeners();
    final v = _disponible;
    if (v == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleIgnoree, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }
}
