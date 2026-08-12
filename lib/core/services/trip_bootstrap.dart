import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../utils/map_tiles.dart';
import 'trip_repository.dart';
import 'trip_session_guard.dart';
import 'trip_socket_service.dart';

/// Reprise des trajets au démarrage de l'application.
///
/// Sans ce point d'entrée, l'émission de positions ne reprenait **jamais** après
/// un redémarrage : le seul appel à `TripSessionGuard.acquire` vivait dans
/// l'écran de composition. Le trajet continuait de courir côté serveur —
/// échéance armée, alerte prévue — pendant que le bandeau affichait « trajet en
/// cours » sans qu'une seule position ne parte. Un mensonge à l'écran, et un
/// cercle qui regarde une carte figée.
///
/// Il vit hors des écrans, à côté du démarrage de [TripSocketService] : un
/// trajet doit survivre à la navigation, pas dépendre d'une page ouverte.
class TripBootstrap {
  TripBootstrap({
    required TalkyApiClient api,
    required TripRepository trips,
    required TripSocketService socket,
  })  : _api = api,
        _trips = trips,
        _socket = socket;

  final TalkyApiClient _api;
  final TripRepository _trips;
  final TripSocketService _socket;

  bool _enCours = false;
  bool _demarre = false;

  /// S'accroche à `auth:verified`, comme le font déjà `chat_provider`,
  /// `chat_repository` et `call_signaling`. C'est le seul signal qui couvre à la
  /// fois le premier lancement, la reconnexion et le retour après logout.
  void start() {
    if (_demarre) return;
    _demarre = true;
    _api.onSocketEvent(SocketEvents.authVerified, (_) {
      unawaited(resume());
      unawaited(_adopterFondDeCarte());
    });
  }

  /// Récupère la source des tuiles servie par le serveur.
  ///
  /// Ici plutôt que dans un écran de carte : la configuration doit être en place
  /// **avant** qu'une carte ne s'ouvre, sinon le premier affichage se fait avec
  /// le repli compilé et les tuiles chargées pour rien sont ensuite jetées au
  /// changement de source.
  ///
  /// Accroché à `auth:verified` comme la reprise de trajet, et pour la même
  /// raison : c'est le seul signal qui couvre le premier lancement, la
  /// reconnexion et le retour après déconnexion.
  Future<void> _adopterFondDeCarte() async {
    MapTiles.adopt(await _api.fetchMapTiles());
  }

  /// À appeler une fois la session authentifiée, et à chaque retour d'avant-plan.
  ///
  /// Idempotent : `acquire` ne relance rien si le garde tourne déjà sur ce
  /// trajet, et un trajet clos entre-temps est simplement ignoré.
  Future<void> resume() async {
    if (_enCours) return;
    _enCours = true;
    try {
      await _trips.syncActiveTrips();

      // Les trajets suivis et clos ne doivent pas traîner : le membre n'a pas
      // d'historique, c'est une règle produit.
      await _trips.pruneClosedWatched();

      final mien = await _trips.myOpenTripOnce();
      if (mien == null) {
        // Plus de trajet ouvert : si le garde tournait encore (trajet clos
        // depuis un autre appareil, ou expiré côté serveur), on le relâche.
        if (TripSessionGuard.instance.isActive) {
          await TripSessionGuard.instance.release();
        }
        return;
      }

      if (!TripState.isOpen(mien.state)) return;

      debugPrint('[Trips] reprise du suivi du trajet ${mien.id}');
      await TripSessionGuard.instance.acquire(
        tripId: mien.id,
        trips: _trips,
        socket: _socket,
        etaAt: mien.etaAt,
      );
    } catch (e) {
      // Best-effort : une reprise ratée ne doit pas empêcher l'application de
      // démarrer. L'échéance serveur protège de toute façon l'utilisateur.
      debugPrint('[Trips] reprise échouée: $e');
    } finally {
      _enCours = false;
    }
  }

  /// À la déconnexion du compte : on arrête d'émettre, sans clore le trajet —
  /// il appartient au serveur, pas à cette session.
  Future<void> stop() async {
    await TripSessionGuard.instance.release();
    _socket.detach();
  }
}
