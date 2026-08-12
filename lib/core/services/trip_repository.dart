import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

/// Trajets de confiance — REST et cache Drift.
///
/// Même patron que [LocalCacheRepository] : `watchXxx()` expose un flux Drift
/// réactif, `syncXxx()` interroge l'API et met à jour le cache. L'écran se
/// branche sur le flux et ne connaît jamais le réseau.
///
/// Deux règles propres à ce volet, appliquées ici et pas dans les écrans :
///
///   • **Un membre n'a pas d'historique.** Un trajet suivi est effacé du cache
///     dès qu'il est clos ([pruneClosedWatched]). C'est ce qui empêche
///     « montre-moi où tu étais mardi » d'exister comme fonctionnalité.
///
///   • **La cadence vient du serveur.** [policy] n'est jamais devinée : elle
///     arrive avec chaque réponse portant un trajet. Le repli n'existe que pour
///     un serveur plus ancien.
class TripRepository {
  final AppDatabase _db;
  final TalkyApiClient _api;

  TripRepository({required AppDatabase db, required TalkyApiClient api})
      : _db = db,
        _api = api;

  /// Dernière politique de cadence servie. Lue par le service de localisation
  /// pour régler filtre, plancher et battement.
  TripPolicy _policy = TripPolicy.fallback;
  TripPolicy get policy => _policy;

  final _policyController = StreamController<TripPolicy>.broadcast();
  Stream<TripPolicy> get policyChanges => _policyController.stream;

  void _adoptPolicy(dynamic raw) {
    if (raw is! Map) return;
    final next = TripPolicy.fromJson(raw.cast<String, dynamic>());
    _policy = next;
    if (!_policyController.isClosed) _policyController.add(next);
  }

  void dispose() => _policyController.close();

  // ── LECTURE (hors ligne d'abord) ────────────────────────────────────

  /// Mon trajet ouvert, s'il y en a un. Alimente le bandeau persistant.
  Stream<LocalTrip?> watchMyOpenTrip() {
    final q = _db.select(_db.localTrips)
      ..where((t) => t.isOwner.equals(true) & t.state.isIn(TripState.open))
      ..limit(1);
    return q.watch().map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Les trajets que je suis, en tant que membre du cercle.
  Stream<List<LocalTrip>> watchTripsIFollow() {
    final q = _db.select(_db.localTrips)
      ..where((t) => t.isOwner.equals(false) & t.state.isIn(TripState.open))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return q.watch();
  }

  Stream<LocalTrip?> watchTrip(int tripId) {
    final q = _db.select(_db.localTrips)..where((t) => t.id.equals(tripId));
    return q.watchSingleOrNull();
  }

  Stream<List<LocalTripEvent>> watchEvents(int tripId) {
    final q = _db.select(_db.localTripEvents)
      ..where((e) => e.tripId.equals(tripId))
      ..orderBy([(e) => OrderingTerm.asc(e.seq)]);
    return q.watch();
  }

  /// Trace en cache, pour tracer la polyligne sans attendre le réseau.
  Stream<List<LocalTripPoint>> watchPoints(int tripId) {
    final q = _db.select(_db.localTripPoints)
      ..where((p) => p.tripId.equals(tripId))
      ..orderBy([(p) => OrderingTerm.asc(p.recordedAt)]);
    return q.watch();
  }

  Future<LocalTrip?> getTripOnce(int tripId) {
    final q = _db.select(_db.localTrips)..where((t) => t.id.equals(tripId));
    return q.getSingleOrNull();
  }

  /// Prénoms des destinataires d'un trajet, pour la notification persistante.
  ///
  /// Elle doit **nommer** les personnes qui reçoivent la position : une
  /// notification de suivi qui ne le dit pas se comporte comme un logiciel
  /// espion. C'est ce détail qui distingue les deux.
  Future<List<String>> watcherNames(int tripId) async {
    try {
      final data = await _api.getTrip(tripId);
      final trip = data['trip'];
      final watchers = trip is Map ? (trip['watchers'] as List?) : null;
      return (watchers ?? const [])
          .whereType<Map>()
          .map((w) => (w['nom'] ?? w['pseudo'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[Trips] watcherNames échoué: $e');
      return const [];
    }
  }

  /// Mon trajet ouvert, en lecture ponctuelle. Utilisé par la reprise au
  /// démarrage, qui a besoin d'une valeur et non d'un flux.
  Future<LocalTrip?> myOpenTripOnce() async {
    final q = _db.select(_db.localTrips)
      ..where((t) => t.isOwner.equals(true) & t.state.isIn(TripState.open))
      ..limit(1);
    final rows = await q.get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Réécrit le contenu de la carte de type 9 d'un trajet dans le cache de
  /// messages. Le dépôt de chat fournit l'implémentation — lui seul sait
  /// retrouver la ligne et relancer le recalcul de l'aperçu de conversation.
  Future<void> Function(int tripId, String content)? cardWriter;

  // ── SYNCHRONISATION ─────────────────────────────────────────────────

  /// Reprise à froid : mon trajet ouvert, ceux que je suis, et la cadence.
  /// Best-effort — en cas d'erreur réseau, le cache reste utilisable.
  Future<void> syncActiveTrips() async {
    try {
      final data = await _api.getActiveTrips();
      _adoptPolicy(data['policy']);

      final mine = data['mine'];
      final watching = (data['watching'] as List?) ?? const [];

      final vus = <int>{};
      if (mine is Map) {
        final t = Trip.fromJson(mine.cast<String, dynamic>(), isOwner: true);
        vus.add(t.id);
        await _upsert(t);
      }
      for (final raw in watching.whereType<Map>()) {
        final t = Trip.fromJson(raw.cast<String, dynamic>(), isOwner: false);
        vus.add(t.id);
        await _upsert(t);
      }

      // Un trajet ouvert dans le cache mais absent de la réponse a été clos
      // pendant qu'on était hors ligne : on l'oublie plutôt que de l'afficher
      // indéfiniment « en cours ».
      final ouverts = await (_db.select(_db.localTrips)
            ..where((t) => t.state.isIn(TripState.open)))
          .get();
      for (final t in ouverts) {
        if (!vus.contains(t.id)) await forget(t.id);
      }
    } catch (e) {
      debugPrint('[Trips] syncActiveTrips échoué: $e');
    }
  }

  /// Détail et frise. Utilisé à l'ouverture de l'écran de suivi.
  Future<Trip?> syncTrip(int tripId, {bool isOwner = false}) async {
    try {
      final data = await _api.getTrip(tripId);
      _adoptPolicy(data['policy']);

      final raw = data['trip'];
      if (raw is! Map) return null;
      final t = Trip.fromJson(raw.cast<String, dynamic>(), isOwner: isOwner);
      await _upsert(t);

      final events = (data['events'] as List?) ?? const [];
      await _db.batch((b) {
        var seq = 0;
        for (final e in events.whereType<Map>()) {
          final companion = LocalTripEventsCompanion(
            tripId: Value(tripId),
            seq: Value(seq++),
            kind: Value(e['kind']?.toString() ?? ''),
            actorId: Value((e['actorId'] as num?)?.toInt()),
            meta: Value(e['meta'] == null ? null : jsonEncode(e['meta'])),
            at: Value(
                DateTime.tryParse(e['at']?.toString() ?? '')?.toLocal() ??
                    DateTime.now()),
          );
          b.insert(_db.localTripEvents, companion,
              onConflict: DoUpdate((_) => companion));
        }
      });
      return t;
    } catch (e) {
      debugPrint('[Trips] syncTrip($tripId) échoué: $e');
      return null;
    }
  }

  // ── MUTATIONS ───────────────────────────────────────────────────────

  /// Démarre un trajet.
  ///
  /// [clientId] est engendré ici et non par l'écran : c'est ce qui rend l'appel
  /// rejouable si la réponse se perd. Un double appui, ou une reprise après
  /// coupure, ne crée jamais deux trajets.
  ///
  /// Les erreurs métier remontent telles quelles ([TalkyException]) — l'écran
  /// distingue `TRUST_LIST_EMPTY` de `TRIP_ALREADY_ACTIVE` par le code, pas par
  /// le texte du message.
  Future<Trip> startTrip({
    required String kind,
    int? durationMin,
    DateTime? etaAt,
    String? note,
    String? deviceId,
    String? clientId,
    double? destLat,
    double? destLng,
    String? destLabel,
  }) async {
    final data = await _api.createTrip(
      clientId: clientId ?? newTripClientId(),
      kind: kind,
      durationMin: durationMin,
      etaAt: etaAt,
      note: note,
      deviceId: deviceId,
      destLat: destLat,
      destLng: destLng,
      destLabel: destLabel,
    );
    _adoptPolicy(data['policy']);

    final trip = Trip.fromJson(
      (data['trip'] as Map).cast<String, dynamic>(),
      isOwner: true,
    );
    await _upsert(trip);
    return trip;
  }

  /// Identifiant d'idempotence. Horodatage plus aléa : deux appareils du même
  /// compte ne peuvent pas produire la même valeur au même instant.
  static String newTripClientId() {
    final r = Random();
    final suffixe = List.generate(6, (_) => r.nextInt(16).toRadixString(16))
        .join();
    return 'trip_${DateTime.now().millisecondsSinceEpoch}_$suffixe';
  }


  /// Confirmer son arrivée. Clôt le trajet.
  Future<Trip> confirmTrip(int tripId) => _action(_api.confirmTrip(tripId));

  /// Prolonger. Le serveur repart de l'échéance courante et ré-arme les jobs.
  Future<Trip> extendTrip(int tripId, int minutes) =>
      _action(_api.extendTrip(tripId, minutes));

  /// Arrêter le partage. Sans confirmation : si arrêter coûtait cher, arrêter
  /// deviendrait punissable par quelqu'un qui regarde par-dessus l'épaule.
  Future<Trip> cancelTrip(int tripId, {String? reason}) =>
      _action(_api.cancelTrip(tripId, reason: reason));

  /// Dément une alerte déjà partie : « fausse alerte, je vais bien ».
  ///
  /// Clôt le trajet comme un arrêt, mais avec un motif que la carte du cercle
  /// sait rendre. Le journal d'incident, lui, reste : une alerte émise se
  /// résout, elle ne s'efface pas.
  Future<Trip> declareFalseAlarm(int tripId) =>
      cancelTrip(tripId, reason: 'false_alarm');

  /// Déclenche un SOS.
  ///
  /// L'identifiant client rend l'appel rejouable : dans une situation où l'on
  /// appuie plusieurs fois, ou si la réponse se perd, il ne doit jamais partir
  /// deux alertes.
  Future<Trip> triggerSos({String? deviceId}) async {
    final data = await _api.triggerSos(
      clientId: newTripClientId(),
      deviceId: deviceId,
    );
    final trip = Trip.fromJson(
      (data['trip'] as Map).cast<String, dynamic>(),
      isOwner: true,
    );
    await _upsert(trip);
    return trip;
  }

  Future<Trip> _action(Future<Map<String, dynamic>> appel) async {
    final data = await appel;
    final trip = Trip.fromJson(
      (data['trip'] as Map).cast<String, dynamic>(),
      isOwner: true,
    );
    await _upsert(trip);
    return trip;
  }

  /// Mes trajets passés. Ils ne vivent PAS dans le cache : l'historique se lit
  /// en ligne, à la demande. Le garder localement ferait de l'appareil un
  /// registre de déplacements, ce que la rétention serveur s'emploie justement
  /// à éviter.
  Future<({List<Trip> trips, int? nextCursor})> loadHistory({int? cursor}) async {
    final data = await _api.getTripHistory(cursor: cursor);
    final brut = (data['trips'] as List?) ?? const [];
    return (
      trips: brut
          .whereType<Map>()
          .map((r) => Trip.fromJson(r.cast<String, dynamic>(), isOwner: true))
          .toList(),
      nextCursor: (data['nextCursor'] as num?)?.toInt(),
    );
  }

  /// Recharge la trace complète depuis le serveur, pour rejouer un trajet.
  /// Renvoie `null` si elle a été purgée — l'écran doit le dire.
  Future<List<TripPoint>?> loadTrace(int tripId) async {
    final data = await _api.getTripPoints(tripId);
    if (data['purged'] == true) return null;
    return ((data['points'] as List?) ?? const [])
        .map(TripPoint.tryParse)
        .whereType<TripPoint>()
        .toList();
  }

  Future<void> deleteTrip(int tripId) async {
    await _api.deleteTrip(tripId);
    await forget(tripId);
  }

  // ── ÉCRITURES LOCALES ───────────────────────────────────────────────

  Future<void> _upsert(Trip t) async {
    final companion = LocalTripsCompanion(
      id: Value(t.id),
      ownerId: Value(t.ownerId),
      kind: Value(t.kind),
      state: Value(t.state),
      etaAt: Value(t.etaAt),
      graceMinutes: Value(t.graceMinutes),
      extensions: Value(t.extensions),
      note: Value(t.note),
      destLabel: Value(t.destLabel),
      destLat: Value(t.destLat),
      destLng: Value(t.destLng),
      destRadiusM: Value(t.destRadiusM),
      lastLat: Value(t.lastPoint?.lat),
      lastLng: Value(t.lastPoint?.lng),
      lastAccuracyM: Value(t.lastPoint?.accuracyM),
      lastBattery: Value(t.lastPoint?.batteryPct),
      lastAt: Value(t.lastPoint?.recordedAt),
      stale: Value(t.stale),
      startedAt: Value(t.startedAt),
      closedAt: Value(t.closedAt),
      closeReason: Value(t.closeReason),
      isOwner: Value(t.isOwner),
      watcherCount: Value(t.watcherCount),
      cachedAt: Value(DateTime.now()),
    );
    await _db.into(_db.localTrips).insert(
          companion,
          onConflict: DoUpdate((_) => companion),
        );

    // Un trajet suivi qui se clôt sort du cache immédiatement : le membre n'a
    // pas d'historique, c'est une règle produit et non un oubli.
    if (!t.isOwner && !t.isOpen) await forget(t.id);
  }

  /// Applique un changement d'état reçu par socket, sans aller-retour réseau.
  Future<void> applyState(int tripId, String state,
      {DateTime? closedAt, String? closeReason}) async {
    await (_db.update(_db.localTrips)..where((t) => t.id.equals(tripId))).write(
      LocalTripsCompanion(
        state: Value(state),
        closedAt: Value(closedAt),
        closeReason: Value(closeReason),
        cachedAt: Value(DateTime.now()),
      ),
    );
    if (!TripState.isOpen(state)) {
      final t = await getTripOnce(tripId);
      if (t != null && !t.isOwner) await forget(tripId);
    }
  }

  /// Enregistre une position reçue ou capturée.
  ///
  /// [pending] à vrai marque un point du tampon hors ligne, en attente d'envoi.
  /// L'anneau est plafonné à [maxPoints] par trajet : les plus anciens points
  /// non-pending sont écartés, jamais ceux qui restent à transmettre.
  Future<void> savePoint(
    int tripId,
    TripPoint p, {
    required int clientSeq,
    bool pending = false,
    int maxPoints = 500,
  }) async {
    final companion = LocalTripPointsCompanion(
      tripId: Value(tripId),
      clientSeq: Value(clientSeq),
      lat: Value(p.lat),
      lng: Value(p.lng),
      accuracyM: Value(p.accuracyM),
      battery: Value(p.batteryPct),
      recordedAt: Value(p.recordedAt),
      pending: Value(pending),
    );
    await _db.into(_db.localTripPoints).insert(
          companion,
          onConflict: DoUpdate((_) => companion),
        );

    await (_db.update(_db.localTrips)..where((t) => t.id.equals(tripId))).write(
      LocalTripsCompanion(
        lastLat: Value(p.lat),
        lastLng: Value(p.lng),
        lastAccuracyM: Value(p.accuracyM),
        lastBattery: Value(p.batteryPct),
        lastAt: Value(p.recordedAt),
        stale: const Value(false),
        cachedAt: Value(DateTime.now()),
      ),
    );

    await _trimPoints(tripId, maxPoints);
  }

  Future<void> _trimPoints(int tripId, int maxPoints) async {
    final total = await (_db.select(_db.localTripPoints)
          ..where((p) => p.tripId.equals(tripId)))
        .get();
    if (total.length <= maxPoints) return;
    final aJeter = total
        .where((p) => !p.pending)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final surplus = total.length - maxPoints;
    for (final p in aJeter.take(surplus)) {
      await (_db.delete(_db.localTripPoints)
            ..where((r) =>
                r.tripId.equals(tripId) & r.clientSeq.equals(p.clientSeq)))
          .go();
    }
  }

  /// Points restés à transmettre après une coupure réseau, dans l'ordre de
  /// capture. Ils repartent avec **leur** horodatage, jamais celui de l'envoi.
  Future<List<LocalTripPoint>> pendingPoints(int tripId) {
    final q = _db.select(_db.localTripPoints)
      ..where((p) => p.tripId.equals(tripId) & p.pending.equals(true))
      ..orderBy([(p) => OrderingTerm.asc(p.recordedAt)]);
    return q.get();
  }

  Future<void> markPointsSent(int tripId, Iterable<int> clientSeqs) async {
    if (clientSeqs.isEmpty) return;
    await (_db.update(_db.localTripPoints)
          ..where((p) =>
              p.tripId.equals(tripId) & p.clientSeq.isIn(clientSeqs.toList())))
        .write(const LocalTripPointsCompanion(pending: Value(false)));
  }

  Future<void> setStale(int tripId, bool stale) async {
    await (_db.update(_db.localTrips)..where((t) => t.id.equals(tripId)))
        .write(LocalTripsCompanion(stale: Value(stale)));
  }

  /// Oublie un trajet et tout ce qui s'y rattache.
  Future<void> forget(int tripId) async {
    await (_db.delete(_db.localTripPoints)..where((p) => p.tripId.equals(tripId)))
        .go();
    await (_db.delete(_db.localTripEvents)..where((e) => e.tripId.equals(tripId)))
        .go();
    await (_db.delete(_db.localTrips)..where((t) => t.id.equals(tripId))).go();
  }

  /// Filet de sécurité au démarrage : aucun trajet suivi et clos ne doit
  /// traîner dans le cache, même après un plantage en plein trajet.
  Future<void> pruneClosedWatched() async {
    final clos = await (_db.select(_db.localTrips)
          ..where((t) => t.isOwner.equals(false) & t.state.isNotIn(TripState.open)))
        .get();
    for (final t in clos) {
      await forget(t.id);
    }
  }
}
