import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'trip_repository.dart';

/// Pont entre les événements socket des trajets et le cache local.
///
/// Rôle volontairement étroit : recevoir, écrire dans Drift, et laisser les
/// écrans se rafraîchir par les flux. Aucun widget n'écoute la socket
/// directement — sinon un trajet cesserait d'être suivi dès qu'on quitte
/// l'écran.
///
/// Rappel de la règle serveur, qui explique la double écoute ici : la room
/// `trip_<id>` ne porte que les positions. Les changements d'état arrivent par
/// le compte, donc **sans souscription**. C'est pour cela que [start] écoute
/// dès le lancement de l'application, et pas seulement quand un écran s'ouvre.
class TripSocketService {
  TripSocketService({required TalkyApiClient api, required TripRepository trips})
      : _api = api,
        _trips = trips;

  final TalkyApiClient _api;
  final TripRepository _trips;

  bool _demarre = false;

  /// Ce qu'on VEUT suivre — l'intention, indépendante de l'état de la socket.
  final _voulus = <int>{};

  /// Ce qui est réellement rejoint côté serveur. Les deux divergent dès qu'une
  /// émission échoue ou qu'une reconnexion perd les rooms.
  final _abonnes = <int>{};

  /// Trajets dont on reçoit effectivement le flux de positions.
  Set<int> get subscribed => Set.unmodifiable(_abonnes);

  /// Signalé quand l'appareil perd le rôle d'émetteur au profit d'un autre.
  final _deviceRevoked = StreamController<int>.broadcast();
  Stream<int> get deviceRevoked => _deviceRevoked.stream;

  /// « Maman a vu ». Émis quand un destinataire ouvre la carte du trajet.
  ///
  /// C'est le **seul retour qu'un membre du cercle puisse donner** : il ne peut
  /// ni clore le trajet, ni consulter l'historique. Le laisser s'arrêter au
  /// serveur — ce qui était le cas, l'événement n'étant écouté nulle part —
  /// revenait à priver la personne suivie de la seule preuve que quelqu'un la
  /// regarde.
  final _watcherSeen =
      StreamController<({int tripId, int alanyaID})>.broadcast();
  Stream<({int tripId, int alanyaID})> get watcherSeen => _watcherSeen.stream;

  /// Le serveur a refusé nos positions : un autre appareil du compte porte le
  /// trajet (`DEVICE_NOT_OWNER`).
  ///
  /// Sans cet écouteur — et il n'existait pas — le téléphone dépossédé
  /// continuait d'émettre dans le vide : service en avant-plan actif, batterie
  /// consommée, bandeau affichant « trajet en cours », et pas une position
  /// acceptée. Un seul appareil émet, c'est le verrou du volet ; encore
  /// faut-il que le perdant l'apprenne.
  final _deviceNotOwner = StreamController<int>.broadcast();
  Stream<int> get deviceNotOwner => _deviceNotOwner.stream;

  void start() {
    if (_demarre) return;
    _demarre = true;

    // ── Événements de compte : reçus sans souscription ───────────────
    _api.onSocketEvent(SocketEvents.tripStarted, _onStarted);
    _api.onSocketEvent(SocketEvents.tripAlert, _onAlert);
    _api.onSocketEvent(SocketEvents.tripClosed, _onClosed);
    _api.onSocketEvent(SocketEvents.tripStateEvent, _onState);
    _api.onSocketEvent(SocketEvents.tripCardUpdate, _onCardUpdate);
    _api.onSocketEvent(SocketEvents.tripDeviceRevoked, _onDeviceRevoked);
    _api.onSocketEvent(SocketEvents.tripWatcherSeen, _onWatcherSeen);
    _api.onSocketEvent(SocketEvents.tripError, _onError);

    // ── Événements de room : uniquement si l'on est abonné ───────────
    _api.onSocketEvent(SocketEvents.tripPosition, _onPosition);
    _api.onSocketEvent(SocketEvents.tripStale, _onStale);
    _api.onSocketEvent(SocketEvents.tripSignal, _onSignal);

    // Le point d'ancrage du réabonnement. `auth:verified` est émis à la
    // première connexion, après chaque reconnexion, et après un logout/login —
    // c'est-à-dire à chaque fois que les rooms du serveur ont été perdues.
    // Le brancher ici plutôt que dans le garde de session est ce qui permet à un
    // MEMBRE de se réabonner : lui n'a jamais de garde actif.
    _api.onSocketEvent(SocketEvents.authVerified, (_) => resubscribeAll());
  }

  void dispose() {
    for (final e in const [
      SocketEvents.tripStarted, SocketEvents.tripAlert, SocketEvents.tripClosed,
      SocketEvents.tripStateEvent, SocketEvents.tripCardUpdate,
      SocketEvents.tripDeviceRevoked, SocketEvents.tripPosition,
      SocketEvents.tripStale, SocketEvents.tripSignal,
      SocketEvents.tripWatcherSeen, SocketEvents.tripError,
    ]) {
      _api.offSocketEvent(e);
    }
    _abonnes.clear();
    _voulus.clear();
    // Remettre le drapeau à faux : sinon un logout/login (qui vide les
    // listeners de la socket) laisserait `start()` sans effet, et plus aucun
    // événement de trajet n'arriverait de toute la session.
    _demarre = false;
    _deviceRevoked.close();
    _watcherSeen.close();
    _deviceNotOwner.close();
  }

  /// Détache les écouteurs sans fermer le service — à la déconnexion du compte.
  /// [start] pourra les réattacher à la reconnexion suivante.
  void detach() {
    for (final e in const [
      SocketEvents.tripStarted, SocketEvents.tripAlert, SocketEvents.tripClosed,
      SocketEvents.tripStateEvent, SocketEvents.tripCardUpdate,
      SocketEvents.tripDeviceRevoked, SocketEvents.tripPosition,
      SocketEvents.tripStale, SocketEvents.tripSignal,
      SocketEvents.tripWatcherSeen, SocketEvents.tripError,
    ]) {
      _api.offSocketEvent(e);
    }
    _abonnes.clear();
    _voulus.clear();
    _demarre = false;
  }

  // ── Souscription au flux ──────────────────────────────────────────

  /// Rejoint le flux de positions d'un trajet.
  ///
  /// L'intention est enregistrée **même si l'émission échoue** : la socket peut
  /// n'être pas encore authentifiée à l'ouverture de l'écran. `auth:verified`
  /// rejouera l'abonnement. Sans cette distinction, un abonnement raté restait
  /// raté pour toujours — l'ensemble contenait l'identifiant, donc tout
  /// `subscribe` ultérieur devenait un no-op.
  void subscribe(int tripId) {
    _voulus.add(tripId);
    if (_api.sendSocketEvent(SocketEvents.tripSubscribe, {'tripId': tripId})) {
      _abonnes.add(tripId);
    }
  }

  void unsubscribe(int tripId) {
    _voulus.remove(tripId);
    _abonnes.remove(tripId);
    _api.sendSocketEvent(SocketEvents.tripUnsubscribe, {'tripId': tripId});
  }

  /// Re-souscrit tout ce qui est voulu. Une reconnexion socket.io crée une
  /// nouvelle socket côté serveur : **les rooms sont perdues**, alors que le
  /// client se croit toujours abonné. Sans ce rappel, la carte du membre gèle à
  /// la première micro-coupure, sans aucun indicateur.
  void resubscribeAll() {
    _abonnes.clear();
    for (final id in _voulus) {
      if (_api.sendSocketEvent(SocketEvents.tripSubscribe, {'tripId': id})) {
        _abonnes.add(id);
      }
    }
    if (_voulus.isNotEmpty) {
      debugPrint('[Trips] réabonnement de ${_voulus.length} trajet(s)');
    }
  }

  // ── Émission ──────────────────────────────────────────────────────

  /// @returns vrai si la trame est réellement partie. L'appelant doit en tenir
  /// compte : marquer un point « envoyé » sans vérifier viderait le tampon de
  /// points qui n'ont jamais quitté le téléphone.
  bool sendPosition(int tripId, TripPoint p, int clientSeq) {
    return _api.sendSocketEvent(SocketEvents.tripPosition, {
      'tripId': tripId,
      'clientSeq': clientSeq,
      'lat': p.lat,
      'lng': p.lng,
      if (p.accuracyM != null) 'accuracyM': p.accuracyM,
      if (p.batteryPct != null) 'battery': p.batteryPct,
      'recordedAt': p.recordedAt.toUtc().toIso8601String(),
    });
  }

  /// Vidange du tampon hors ligne. Chaque point repart avec **son** horodatage
  /// de capture ; le serveur déduplique par `clientSeq`, donc rejouer est sans
  /// risque.
  void sendBatch(int tripId, List<Map<String, dynamic>> points) {
    if (points.isEmpty) return;
    _api.sendSocketEvent(SocketEvents.tripPositionBatch, {
      'tripId': tripId,
      'points': points,
    });
  }

  void claimDevice(int tripId) =>
      _api.sendSocketEvent(SocketEvents.tripClaimDevice, {'tripId': tripId});

  void signal(int tripId, String reason) =>
      _api.sendSocketEvent(SocketEvents.tripSignal,
          {'tripId': tripId, 'reason': reason});

  void markSeen(int tripId) =>
      _api.sendSocketEvent(SocketEvents.tripSeen, {'tripId': tripId});

  // ── Réception ─────────────────────────────────────────────────────

  int? _tripId(dynamic data) =>
      data is Map ? (data['tripId'] as num?)?.toInt() : null;

  Future<void> _onStarted(dynamic data) async {
    // Un trajet démarré chez un proche : on le récupère en entier plutôt que
    // de reconstruire depuis un payload partiel.
    final raw = data is Map ? data['trip'] : null;
    final id = raw is Map ? (raw['id'] as num?)?.toInt() : null;
    if (id != null) await _trips.syncTrip(id);
  }

  Future<void> _onState(dynamic data) async {
    final id = _tripId(data);
    final state = data is Map ? data['state']?.toString() : null;
    if (id == null || state == null) return;
    await _trips.applyState(id, state);
  }

  Future<void> _onAlert(dynamic data) async {
    final id = _tripId(data);
    if (id == null) return;
    // Une alerte est le moment où l'on veut l'information complète : dernière
    // position, frise, tout.
    await _trips.syncTrip(id);
  }

  Future<void> _onClosed(dynamic data) async {
    final id = _tripId(data);
    if (id == null) return;
    final state = data is Map
        ? (data['state']?.toString() ?? TripState.closedConfirmed)
        : TripState.closedConfirmed;
    await _trips.applyState(id, state,
        closedAt: DateTime.now(),
        closeReason: data is Map ? data['closeReason']?.toString() : null);
    unsubscribe(id);
  }

  Future<void> _onPosition(dynamic data) async {
    final id = _tripId(data);
    if (id == null || data is! Map) return;
    final p = TripPoint.tryParse(data);
    if (p == null) return;
    // Côté destinataire, `clientSeq` est absent : on horodate la séquence pour
    // conserver l'ordre sans risque de collision.
    await _trips.savePoint(id, p,
        clientSeq: p.recordedAt.millisecondsSinceEpoch ~/ 1000);
  }

  Future<void> _onStale(dynamic data) async {
    final id = _tripId(data);
    if (id == null) return;
    await _trips.setStale(id, data is Map ? data['stale'] != false : true);
  }

  void _onWatcherSeen(dynamic data) {
    final id = _tripId(data);
    if (id == null || data is! Map) return;
    final qui = (data['alanyaID'] as num?)?.toInt() ??
        (data['watcherId'] as num?)?.toInt();
    if (qui == null || qui == 0) return;
    if (!_watcherSeen.isClosed) {
      _watcherSeen.add((tripId: id, alanyaID: qui));
    }
  }

  Future<void> _onSignal(dynamic data) async {
    final id = _tripId(data);
    if (id == null) return;
    await _trips.setStale(id, data is Map && data['stale'] == true);
  }

  /// La carte de type 9 a été réécrite côté serveur.
  ///
  /// Il ne suffit pas de refléter l'état du trajet : il faut réécrire le
  /// `content` du MESSAGE en cache, sinon la bulle et l'aperçu de conversation
  /// restent sur l'ancien état jusqu'au prochain sync HTTP. C'est le même
  /// symptôme que la carte qui n'arrive pas, un cran plus loin dans le cycle
  /// de vie.
  Future<void> _onCardUpdate(dynamic data) async {
    await _onState(data);
    final id = _tripId(data);
    final content = data is Map ? data['content']?.toString() : null;
    if (id == null || content == null || content.isEmpty) return;
    await _onTripCardContent?.call(id, content);
  }

  /// Réécriture du message local. Injecté par le dépôt de chat, qui seul sait
  /// retrouver la ligne et relancer le recalcul de l'aperçu.
  Future<void> Function(int tripId, String content)? _onTripCardContent;

  // ignore: use_setters_to_change_properties
  void bindCardWriter(Future<void> Function(int, String) writer) {
    _onTripCardContent = writer;
  }

  void _onError(dynamic data) {
    if (data is! Map) return;
    if (data['code']?.toString() != 'DEVICE_NOT_OWNER') return;
    final id = _tripId(data);
    if (id == null) return;
    debugPrint('[Trips] positions refusées : le trajet $id est porté ailleurs');
    if (!_deviceNotOwner.isClosed) _deviceNotOwner.add(id);
  }

  void _onDeviceRevoked(dynamic data) {
    final id = _tripId(data);
    if (id == null) return;
    debugPrint('[Trips] émission reprise par un autre appareil (trajet $id)');
    if (!_deviceRevoked.isClosed) _deviceRevoked.add(id);
  }
}
