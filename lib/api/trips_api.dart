// Endpoints trajets de confiance (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension TripsApi on TalkyApiClient {
  // ── TRAJETS DE CONFIANCE ──────────────────────────────────────────

  /// Démarre un trajet.
  ///
  /// [clientId] rend l'appel idempotent : un réseau qui bafouille ne doit pas
  /// créer deux trajets. Réémettre le même identifiant renvoie le trajet
  /// existant, en 200 au lieu de 201.
  ///
  /// L'audience n'est **pas** un paramètre : le serveur lit la liste Confiance
  /// du porteur du jeton, en entier. Passer une liste de destinataires n'aurait
  /// aucun effet.
  ///
  /// [durationMin] est à préférer à [etaAt] — il n'implique aucune horloge
  /// client, et c'est le serveur qui calcule l'échéance de toute façon.
  ///
  /// Erreurs métier remontées telles quelles par [TalkyException] :
  /// `TRUST_LIST_EMPTY` (409), `TRIP_ALREADY_ACTIVE` (409), `INVALID_ETA` (400).
  Future<Map<String, dynamic>> createTrip({
    required String clientId,
    String kind = 'meeting',
    int? durationMin,
    DateTime? etaAt,
    String? note,
    String? deviceId,
    double? destLat,
    double? destLng,
    String? destLabel,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/trips'),
        headers: _headers,
        body: jsonEncode({
          'clientId': clientId,
          'kind': kind,
          if (durationMin != null) 'durationMin': durationMin,
          if (durationMin == null && etaAt != null)
            'etaAt': etaAt.toUtc().toIso8601String(),
          if (note != null && note.isNotEmpty) 'note': note,
          if (deviceId != null) 'deviceId': deviceId,
      if (destLat != null && destLng != null) ...{
        'destLat': destLat,
        'destLng': destLng,
        if (destLabel != null) 'destLabel': destLabel,
      },
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Reprise à froid : mon trajet ouvert, ceux que je suis, et la politique de
  /// cadence à appliquer.
  ///
  /// Appelé au démarrage de l'application. C'est aussi la seule source de
  /// `policy` : la cadence GPS ne doit jamais être codée en dur côté client,
  /// sinon la régler imposerait une publication.
  Future<Map<String, dynamic>> getActiveTrips() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/active'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Détail d'un trajet et sa frise d'événements.
  ///
  /// Accessible au propriétaire et aux destinataires actifs ; 404 indifférencié
  /// sinon — on ne révèle pas l'existence du trajet d'un autre.
  Future<Map<String, dynamic>> getTrip(int tripId) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Confirmer son arrivée. Possible même après une alerte — celle-ci reste au
  /// journal : une alerte émise se résout, elle ne s'efface pas.
  Future<Map<String, dynamic>> confirmTrip(int tripId) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId/confirm'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Prolonger l'échéance. Repart de l'échéance courante, pas de maintenant.
  Future<Map<String, dynamic>> extendTrip(int tripId, int minutes) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId/extend'),
        headers: _headers,
        body: jsonEncode({'minutes': minutes}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Arrêter le partage. Toujours autorisé, sans confirmation.
  /// Arrête le partage.
  ///
  /// [reason] vaut `false_alarm` quand on dément une alerte déjà partie. Le
  /// serveur ne l'accepte que depuis un état d'alerte — ailleurs il retomberait
  /// sur l'arrêt ordinaire, ce qui permettrait d'habiller n'importe quel arrêt
  /// en démenti.
  Future<Map<String, dynamic>> cancelTrip(int tripId, {String? reason}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId/cancel'),
        headers: _headers,
        body: reason == null ? null : jsonEncode({'reason': reason}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Mes trajets passés. Réservé au propriétaire : un destinataire n'a pas
  /// d'historique.
  Future<Map<String, dynamic>> getTripHistory({int? cursor, int limit = 20}) async {
    final q = <String, String>{
      'limit': '$limit',
      if (cursor != null) 'cursor': '$cursor',
    };
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/history')
            .replace(queryParameters: q),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// La trace d'un trajet. `purged` à vrai signale qu'elle a été effacée —
  /// l'écran doit le dire plutôt qu'afficher une carte muette.
  Future<Map<String, dynamic>> getTripPoints(int tripId) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId/points'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Déclenche un SOS. Fonctionne sans trajet en cours : le serveur en crée un,
  /// déjà en alerte. Si un trajet est ouvert, il l'escalade.
  Future<Map<String, dynamic>> triggerSos({String? clientId, String? deviceId}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/sos'),
        headers: _headers,
        body: jsonEncode({
          if (clientId != null) 'clientId': clientId,
          if (deviceId != null) 'deviceId': deviceId,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteTrip(int tripId) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/trips/$tripId'),
        headers: _headers,
      ),
    );
  }

  /// Source des tuiles cartographiques et sa mention légale.
  ///
  /// Servie plutôt que compilée : changer de fournisseur ne doit pas exiger une
  /// publication sur les magasins. Une carte qui blanchit chez une partie du
  /// parc pendant des semaines n'est pas un mode de bascule acceptable.
  ///
  /// Ne lève pas : sans réponse, le client garde son repli compilé, qui reste
  /// une carte valide. Un fond imparfait vaut mieux qu'un écran vide.
  Future<Map<String, dynamic>?> fetchMapTiles() async {
    try {
      final data = await _handleRequest(
        () => _client.get(
          Uri.parse('${TalkyApiClient.baseUrl}/map/tiles'),
          headers: _headers,
        ),
      );
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }
}
