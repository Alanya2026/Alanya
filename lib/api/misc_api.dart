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
      return const [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
  }

  // ── PAYS ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getPays() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/pays'), headers: _headers),
    );
    return data is List ? data : [];
  }

  // ── HEALTH ────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('http://158.220.107.211/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
