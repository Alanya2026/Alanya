// Divers : config WebRTC/TURN, pays, health (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension MiscApi on TalkyApiClient {
  // ── WEBRTC / TURN ─────────────────────────────────────────────────

  /// Récupère la config iceServers depuis le backend. Cache 50 min par défaut
  /// (les credentials TURN éphémères ont 60 min — on les renouvelle avant).
  Future<List<Map<String, dynamic>>> fetchIceServers({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedIceServers != null &&
        _iceServersExpiresAt != null &&
        now.isBefore(_iceServersExpiresAt!)) {
      debugPrint('[TalkyApiClient] 🧊 fetchIceServers (cache, ${_cachedIceServers!.length} serveur(s))');
      return _cachedIceServers!;
    }

    try {
      final data = await _handleRequest(
        () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/turn/credentials'), headers: _headers),
      ) as Map<String, dynamic>;

      final List<dynamic> raw = data['iceServers'] as List<dynamic>? ?? [];
      final servers = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final ttlSec = (data['ttlSec'] as num?)?.toInt() ?? 0;
      _cachedIceServers = servers;
      _iceServersExpiresAt = ttlSec > 60
          ? now.add(Duration(seconds: ttlSec - 600))
          : now.add(const Duration(minutes: 50));
      debugPrint('[TalkyApiClient] 🧊 fetchIceServers: ${servers.length} serveur(s)');
      for (final s in servers) {
        final urls = s['urls'];
        final hasCreds = s.containsKey('username') && s.containsKey('credential');
        debugPrint('  • urls=$urls, auth=${hasCreds ? "TURN avec creds" : "STUN"}');
      }
      return servers;
    } catch (e) {
      // Fallback STUN public si le backend est injoignable — l'app reste utilisable
      // sur les réseaux non-symétriques.
      debugPrint('[TalkyApiClient] fetchIceServers fallback: $e');
      // Un cache encore rempli vaut infiniment mieux que deux STUN publics.
      //
      // Le repli les rendait sans regarder ce qu'on avait déjà : une requête
      // qui échoue — réseau qui se réveille, jeton à rafraîchir — jetait des
      // identifiants TURN parfaitement valides, sur le chemin critique de tout
      // appel. Sans relais, un réseau à NAT symétrique ne peut pas établir la
      // moindre paire : appel muet des deux côtés.
      //
      // On ne teste pas l'expiration ici : `_iceServersExpiresAt` porte déjà
      // une marge de dix minutes, et des identifiants un peu vieux valent mieux
      // que pas de relais du tout.
      final cache = _cachedIceServers;
      if (cache != null && cache.isNotEmpty) {
        debugPrint(
          '[TalkyApiClient] 🧊 repli sur le cache TURN (${cache.length} serveur(s))',
        );
        return cache;
      }
      return const [
        {'urls': 'stun:turn.kemita.eu:3478'},
        {'urls': 'stun:turn.alanya226.com:3478'},
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
  }

  // ── PAYS ──────────────────────────────────────────────────────────

  /// Liste des pays — endpoint public, utilisable sans token (inscription).
  Future<List<dynamic>> getPays() async {
    final response = await _client
        .get(
          Uri.parse('${TalkyApiClient.baseUrl}/pays'),
          headers: const {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    final data = _parseResponse(response);
    return data is List ? data : [];
  }

  // ── HEALTH ────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('https://www.alanya237.com/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
