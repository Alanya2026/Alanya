import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/locale_controller.dart';
import '../../talky_models.dart';
import 'trip_repository.dart';
import 'trip_socket_service.dart';

/// Émission des positions pendant un trajet, côté propriétaire.
///
/// Structure reprise de [CallSessionGuard] : singleton, cycle acquire/release,
/// [WidgetsBindingObserver] pour le cycle de vie. Deux différences assumées :
///
///   • **Un service en avant-plan porte le suivi sur Android.** Sans lui, le
///     système coupe les mises à jour dès le verrouillage de l'écran — au moment
///     précis où le suivi sert. Il démarre application visible, ce qui n'exige
///     ni `ACCESS_BACKGROUND_LOCATION` ni déclaration au Play Store. Sur les
///     autres plateformes, l'émission s'interrompt en arrière-plan et l'écran le
///     dit honnêtement ; la garantie reste l'échéance, gardée par le serveur.
///
///   • **Le régime n'est pas fixe.** Filtre, plancher et battement viennent du
///     serveur ([TripPolicy]) et changent à l'approche de l'échéance.
///
/// Trois mécanismes cohabitent, et il faut les trois :
///   1. le flux `getPositionStream` déclenche à la **distance parcourue** ;
///   2. le **plancher** borne le débit — sans lui, un taxi en ville émettrait
///      une position toutes les six secondes ;
///   3. le **battement** force un envoi à l'arrêt, sans quoi « immobile » et
///      « traceur mort » seraient indiscernables.
class TripSessionGuard with WidgetsBindingObserver {
  TripSessionGuard._();
  static final TripSessionGuard instance = TripSessionGuard._();

  static const _canal = MethodChannel('com.alanya237.alanya/trip_location');

  bool get _androidNatif =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Appelé quand l'utilisateur appuie sur « Arrêter » dans la notification
  /// persistante. Renseigné par le bootstrap, qui seul sait clore le trajet.
  Future<void> Function(int tripId)? onStopRequested;

  bool _fgsActif = false;

  TripRepository? _trips;
  TripSocketService? _socket;

  int? _tripId;
  DateTime? _etaAt;
  TripPolicy _policy = TripPolicy.fallback;

  StreamSubscription<Position>? _flux;
  Timer? _battement;
  Timer? _revueRegime;

  String _regime = 'nominal';
  DateTime? _dernierEnvoi;
  TripPoint? _dernierPoint;
  int _seq = 0;
  bool _horsLigne = false;

  // ── Batterie ──────────────────────────────────────────────────────
  //
  // Un téléphone qui s'éteint au milieu d'un trajet est le pire scénario du
  // volet : le cercle voit la position se figer et n'a aucun moyen de savoir
  // s'il s'agit d'un tunnel, d'un vol ou d'une agression. On ne peut pas
  // empêcher la batterie de mourir — on peut refuser qu'elle meure en silence.
  //
  // Trois paliers, du plus discret au plus explicite :
  //   • à chaque point, le niveau accompagne la position, et le cercle le voit ;
  //   • sous 15 %, la cadence ralentit (plancher 60 s, battement 120 s) et un
  //     signal `battery_saver` prévient que le rythme change — sinon le cercle
  //     lirait le ralentissement comme une perte de signal ;
  //   • sous 5 %, une dernière position part immédiatement, sans attendre le
  //     prochain créneau. C'est peut-être la dernière que le cercle recevra.
  static const _seuilFaible = 15;
  static const _seuilCritique = 5;

  final _batterie = Battery();

  /// Dernier niveau connu, en pourcentage. Nul tant qu'aucune lecture n'a
  /// abouti — sur un appareil qui refuse la lecture, tout doit continuer de
  /// fonctionner exactement comme avant.
  int? _niveauBatterie;

  /// Vrai depuis qu'on est passé sous [_seuilFaible]. Sert d'anti-rebond : sans
  /// lui, un niveau qui oscille autour du seuil enverrait un signal toutes les
  /// trente secondes.
  bool _batterieFaible = false;
  bool _batterieCritique = false;

  /// Vrai quand le trajet tourne mais que la localisation est refusée. Le garde
  /// reste alors en veille active : il réessaie, au lieu de rester muet à vie.
  bool _sansPermission = false;

  bool get isActive => _tripId != null;
  int? get tripId => _tripId;
  String get regime => _regime;

  /// Émet-on réellement des positions ? `isActive` ne suffit pas : un garde peut
  /// être attaché à un trajet sans autorisation de localisation.
  bool get isStreaming => _flux != null;

  // ── Cycle de vie ──────────────────────────────────────────────────

  /// Démarre l'émission pour un trajet. Idempotent : réappeler pour le même
  /// trajet ne relance rien.
  Future<void> acquire({
    required int tripId,
    required TripRepository trips,
    required TripSocketService socket,
    DateTime? etaAt,
  }) async {
    if (_tripId == tripId) return;
    if (_tripId != null) await release();

    _tripId = tripId;
    _trips = trips;
    _socket = socket;
    _etaAt = etaAt;
    _policy = trips.policy;
    _seq = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    WidgetsBinding.instance.addObserver(this);

    socket.subscribe(tripId);

    if (!await _permissionOk()) {
      // On n'abandonne pas le trajet : l'échéance tient sans GPS. On le déclare,
      // pour que le cercle lise « position indisponible » plutôt que rien.
      //
      // Mais on reste RÉVEILLABLE : sans cette revue, accorder la permission
      // ensuite ne relançait jamais rien, et `acquire` refusait de rejouer
      // (`_tripId == tripId`). Le guard restait « actif » et muet à vie.
      _sansPermission = true;
      socket.signal(tripId, 'permission_denied');
      _revueRegime = Timer.periodic(const Duration(seconds: 20), (_) {
        unawaited(_reessayerPermission());
      });
      return;
    }

    await _demarrerFlux();
  }

  /// Ouvre le flux GPS et émet une première position sans attendre le premier
  /// déplacement.
  Future<void> _demarrerFlux() async {
    _sansPermission = false;
    _revueRegime?.cancel();

    await _demarrerServiceAvantPlan();
    // Avant le premier régime : un trajet démarré à 8 % doit partir directement
    // en cadence ralentie, pas y basculer trente secondes plus tard.
    await _releverBatterie();
    await _appliquerRegime(_choisirRegime());

    // Indispensable : sans ce relevé forcé, un départ à l'arrêt — taxi qui
    // attend, rendez-vous avant de partir — n'émet strictement rien tant que le
    // `distanceFilter` n'est pas franchi. Le cercle ouvre une carte vide.
    await _envoyerMaintenant(force: true);

    // La revue de régime est indépendante du flux : à l'arrêt, aucun point
    // n'arrive, mais l'échéance approche quand même — et la batterie descend.
    _revueRegime = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_revoir());
    });
  }

  /// L'utilisateur a peut-être accordé la permission depuis les réglages.
  Future<void> _reessayerPermission() async {
    if (_tripId == null || !_sansPermission) return;
    if (!await _permissionOk()) return;
    debugPrint('[TripGuard] permission accordée — reprise de l\'émission');
    await _demarrerFlux();
    _socket?.signal(_tripId!, 'back');
  }

  Future<void> release() async {
    final id = _tripId;
    _tripId = null;
    await _flux?.cancel();
    _flux = null;
    _battement?.cancel();
    _battement = null;
    _revueRegime?.cancel();
    _revueRegime = null;
    _dernierEnvoi = null;
    _dernierPoint = null;
    _horsLigne = false;
    _niveauBatterie = null;
    _batterieFaible = false;
    _batterieCritique = false;
    WidgetsBinding.instance.removeObserver(this);
    await _arreterServiceAvantPlan();
    if (id != null) _socket?.unsubscribe(id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final id = _tripId;
    if (id == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Avec le service en avant-plan, le flux continue : il n'y a rien à
        // signaler, et prétendre le contraire ferait basculer le cercle en
        // « position indisponible » alors que tout va bien.
        if (!_fgsActif) {
          _socket?.signal(id, 'background_killed');
          _battement?.cancel();
        }
      case AppLifecycleState.resumed:
        // L'utilisateur a pu appuyer sur « Arrêter » depuis la notification
        // pendant que Dart ne tournait pas : l'intention est relevée ici.
        unawaited(_releverDemandeArret());
        if (!_fgsActif) _socket?.signal(id, 'back');
        _socket?.resubscribeAll();
        unawaited(_viderTampon());
        unawaited(_envoyerMaintenant(force: true));
        _armerBattement();
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ── Service en avant-plan (Android) ───────────────────────────────

  /// Démarre le service qui maintient la localisation active écran verrouillé.
  ///
  /// La notification qu'il affiche **nomme les destinataires** : une notification
  /// de suivi qui ne dit pas à qui elle envoie la position se comporte comme un
  /// logiciel espion, et c'est ce détail qui distingue les deux.
  Future<void> _demarrerServiceAvantPlan() async {
    if (!_androidNatif || _fgsActif) return;
    final id = _tripId;
    final trips = _trips;
    if (id == null || trips == null) return;

    try {
      final destinataires = await trips.watcherNames(id);
      final l10n = LocaleController.instance.l10n;
      await _canal.invokeMethod('start', {
        'title': l10n.tripsFgsTitle,
        'body': destinataires.isEmpty
            ? l10n.tripsFgsBodyPlain
            : l10n.tripsFgsBody(destinataires.join(', ')),
        'stopLabel': l10n.tripsStop,
      });
      _fgsActif = true;
      _canal.setMethodCallHandler(_surAppelNatif);
    } catch (e) {
      // Le service peut être refusé (permission manquante, version d'Android).
      // Le suivi continue en avant-plan seul plutôt que d'échouer entièrement.
      debugPrint('[TripGuard] service avant-plan indisponible: $e');
    }
  }

  Future<void> _arreterServiceAvantPlan() async {
    if (!_androidNatif || !_fgsActif) return;
    _fgsActif = false;
    try {
      await _canal.invokeMethod('stop');
    } catch (e) {
      debugPrint('[TripGuard] arrêt du service: $e');
    }
  }

  Future<dynamic> _surAppelNatif(MethodCall call) async {
    if (call.method == 'stopRequested') await _traiterDemandeArret();
  }

  Future<void> _releverDemandeArret() async {
    if (!_androidNatif) return;
    try {
      final demande = await _canal.invokeMethod<bool>('consumeStopRequest');
      if (demande == true) await _traiterDemandeArret();
    } catch (_) {
      // Canal absent : rien à relever.
    }
  }

  Future<void> _traiterDemandeArret() async {
    final id = _tripId;
    if (id == null) return;
    _fgsActif = false;
    debugPrint('[TripGuard] arrêt demandé depuis la notification');
    await (onStopRequested?.call(id) ?? Future<void>.value());
    await release();
  }

  // ── Permissions ───────────────────────────────────────────────────

  Future<bool> _permissionOk() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('[TripGuard] permission: $e');
      return false;
    }
  }

  // ── Régimes ───────────────────────────────────────────────────────

  /// Choisit le régime. Miroir exact de `regimeFor()` côté serveur — les deux
  /// doivent rester d'accord, sinon la cadence annoncée au cercle ne serait pas
  /// celle réellement appliquée.
  String _choisirRegime() {
    // La garde batterie ne change pas de *nom* de régime, elle en ralentit les
    // temps — exactement comme le serveur, qui renvoie `nominal` avec un
    // plancher et un battement relevés. Voir `_effectif`.
    final eta = _etaAt;
    if (eta == null) return 'nominal';
    final reste = eta.difference(DateTime.now());
    return reste <= const Duration(minutes: 10) ? 'approach' : 'nominal';
  }

  /// Revue périodique : l'échéance approche, la batterie descend. Les deux
  /// peuvent changer la cadence sans qu'aucune position n'arrive.
  Future<void> _revoir() async {
    final etaitFaible = _batterieFaible;
    await _releverBatterie();
    final voulu = _choisirRegime();
    // Le passage sous le seuil doit ré-appliquer le régime même quand son nom
    // n'a pas bougé : c'est le plancher et le battement qui changent.
    if (voulu != _regime || _batterieFaible != etaitFaible) {
      await _appliquerRegime(voulu);
    }
  }

  /// Réglages réellement appliqués : le régime servi par le serveur, ralenti si
  /// la batterie est basse.
  ///
  /// Miroir de la garde batterie de `regimeFor()` (tripPolicy.js). Le serveur
  /// applique la sienne de son côté ; l'appliquer aussi ici évite d'émettre à
  /// pleine cadence des points que le serveur écarterait de toute façon — ce qui
  /// dépenserait la batterie qu'on cherche justement à préserver.
  TripRegime _effectif(TripRegime r) {
    if (!_batterieFaible) return r;
    return TripRegime(
      // La précision ne baisse pas : une position rare et fausse ne vaut rien.
      // C'est la fréquence qu'on sacrifie, jamais la justesse.
      accuracy: r.accuracy,
      filterM: r.filterM,
      floorS: r.floorS < 60 ? 60 : r.floorS,
      beatS: r.beatS < 120 ? 120 : r.beatS,
    );
  }

  TripRegime get _reglageCourant => _effectif(_policy.regime(_regime));

  Future<void> _appliquerRegime(String nom) async {
    _regime = nom;
    final r = _reglageCourant;

    await _flux?.cancel();
    _flux = Geolocator.getPositionStream(
      locationSettings: _reglages(r),
    ).listen(_surPosition, onError: (Object e) {
      debugPrint('[TripGuard] flux: $e');
      final id = _tripId;
      if (id != null) _socket?.signal(id, 'gps_off');
    });

    _armerBattement();
  }

  /// Traduit le niveau servi par le serveur en précision geolocator.
  ///
  /// ⚠ Le repli est `high`, **jamais `medium`**. Chez geolocator, `medium`
  /// annonce 100 à 500 mètres : une précision de quartier. C'est ce que
  /// demandait le régime nominal, celui qui tourne 90 % du temps — le pin
  /// pouvait donc se poser à deux rues de la personne, et la détection
  /// d'arrivée n'avait aucune chance.
  ///
  /// Pour une fonctionnalité de sûreté, le plancher est `high` (0–100 m
  /// annoncés, 5 à 15 m en pratique à ciel ouvert). La différence de batterie
  /// entre `medium` et `high` est réelle mais modeste ; la différence d'utilité
  /// est totale.

  /// Réglages de capture, spécialisés par plateforme.
  ///
  /// `LocationSettings` générique laissait les réglages Android aux valeurs par
  /// défaut du plugin — notamment un intervalle de 5 s, alors qu'on veut un
  /// suivi réactif. `AndroidSettings` donne accès à `intervalDuration`, qui
  /// borne la fréquence à laquelle le *fused provider* est autorisé à nous
  /// pousser un point.
  ///
  /// À noter, pour éviter une tentation : sur Android, `high`, `best` et
  /// `bestForNavigation` se traduisent TOUS par `PRIORITY_HIGH_ACCURACY`
  /// (`FusedLocationClient.toPriority`, geolocator_android). Monter le niveau
  /// n'y gagne rien. C'est sur iOS que la distinction existe — et là,
  /// `bestForNavigation` maintient le GPS en continu, ce qu'Apple réserve à la
  /// navigation embarquée, appareil branché.
  LocationSettings _reglages(TripRegime r) {
    final precision = _precision(r.accuracy);
    if (_androidNatif) {
      return AndroidSettings(
        accuracy: precision,
        distanceFilter: r.filterM,
        // La moitié du plancher d'envoi : le système peut nous fournir un point
        // frais dès qu'on est prêt à l'émettre, sans jamais aller plus vite que
        // ce qu'on sait consommer.
        intervalDuration: Duration(seconds: (r.floorS / 2).ceil().clamp(1, 30)),
      );
    }
    return AppleSettings(
      accuracy: precision,
      distanceFilter: r.filterM,
      // La pastille bleue reste visible : on ne masque jamais le fait qu'on
      // suit la position.
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
    );
  }

  LocationAccuracy _precision(String nom) => switch (nom) {
        'best' => LocationAccuracy.best,
        'balanced' => LocationAccuracy.high,
        _ => LocationAccuracy.high,
      };

  // ── Émission ──────────────────────────────────────────────────────

  void _surPosition(Position p) {
    _dernierPoint = _versPoint(p);
    unawaited(_envoyerSiPossible());
  }

  /// Le plancher. Une position trop rapprochée n'est pas jetée : elle attend le
  /// prochain créneau, et le battement la fera partir si rien d'autre n'arrive.
  Future<void> _envoyerSiPossible() async {
    final r = _reglageCourant;
    final dernier = _dernierEnvoi;
    if (dernier != null &&
        DateTime.now().difference(dernier).inSeconds < r.floorS) {
      return;
    }
    await _envoyerMaintenant();
  }

  /// Envoie la dernière position connue.
  ///
  /// [force] provoque un relevé immédiat si aucune position n'a encore été
  /// captée — c'est le cas au démarrage, et c'est ce qui permet à un trajet
  /// commencé à l'arrêt d'émettre quand même.
  ///
  /// ⚠ Le réarmement du battement est en `finally`, et ce n'est pas de la
  /// coquetterie : une sortie anticipée qui le saute laisse la minuterie morte
  /// **définitivement**, puisque seul cet envoi la réarme. C'était le défaut qui
  /// rendait le suivi silencieux.
  Future<void> _envoyerMaintenant({bool force = false}) async {
    try {
      final id = _tripId;
      final trips = _trips;
      final socket = _socket;
      if (id == null || trips == null || socket == null) return;

      var p = _dernierPoint;
      if (p == null && force) p = await _releverMaintenant();
      if (p == null) return;

      final seq = ++_seq;
      // On écrit d'abord, on émet ensuite : si l'envoi échoue, le point reste au
      // tampon et repartira à la reconnexion, avec son horodatage réel.
      await trips.savePoint(id, p, clientSeq: seq, pending: true);

      // `sendPosition` ne lève pas : il renvoie faux quand la socket n'est pas
      // prête. Marquer le point « envoyé » sans vérifier viderait le tampon de
      // points qui n'ont jamais quitté le téléphone.
      final parti = socket.sendPosition(id, p, seq);
      if (parti) {
        await trips.markPointsSent(id, [seq]);
        _dernierEnvoi = DateTime.now();
        if (_horsLigne) {
          _horsLigne = false;
          socket.signal(id, 'back');
        }
      } else if (!_horsLigne) {
        _horsLigne = true;
        debugPrint('[TripGuard] socket non prête — position mise au tampon');
        // Inutile de signaler : le signal passerait par la même socket morte.
      }
    } catch (e) {
      debugPrint('[TripGuard] envoi: $e');
    } finally {
      _armerBattement();
    }
  }

  /// Relevé ponctuel, pour le tout premier point. Même repli que
  /// `location_picker_screen.dart` : un dernier point connu vaut mieux que rien.
  Future<TripPoint?> _releverMaintenant() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _versPoint(p);
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        return p == null ? null : _versPoint(p);
      } catch (_) {
        return null;
      }
    }
  }

  TripPoint _versPoint(Position p) => TripPoint(
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy.isFinite ? p.accuracy.round() : null,
        // Le niveau accompagne chaque position. C'est ce qui permet au cercle de
        // faire la différence entre « elle ne bouge plus » et « son téléphone
        // est à 4 % » — deux situations qui appellent des réactions opposées.
        batteryPct: _niveauBatterie,
        recordedAt: p.timestamp.toLocal(),
      );

  // ── Garde batterie ────────────────────────────────────────────────

  /// Relève le niveau et applique les deux paliers.
  ///
  /// Ne lève jamais : sur un appareil où la lecture est refusée, le suivi doit
  /// continuer exactement comme avant, simplement sans cette information.
  Future<void> _releverBatterie() async {
    try {
      final n = await _batterie.batteryLevel;
      if (n < 0 || n > 100) return;
      _niveauBatterie = n;
      final id = _tripId;

      if (n <= _seuilCritique && !_batterieCritique) {
        _batterieCritique = true;
        _batterieFaible = true;
        if (id != null) _socket?.signal(id, 'battery_saver');
        // Une dernière position, tout de suite. Passé ce seuil, l'appareil peut
        // s'éteindre à n'importe quelle seconde, et attendre le prochain
        // créneau reviendrait à jouer la dernière position aux dés.
        //
        // Seulement si le flux tourne déjà : au démarrage, `_demarrerFlux`
        // enchaîne de toute façon sur un envoi forcé, en faire un second ici
        // poserait deux points pour le même instant.
        if (_flux != null) await _envoyerMaintenant(force: true);
        return;
      }

      if (n <= _seuilFaible && !_batterieFaible) {
        _batterieFaible = true;
        // On prévient explicitement : sans ce signal, le cercle lirait le
        // ralentissement comme une perte de signal — donc comme un problème,
        // alors que c'est une mesure de conservation.
        if (id != null) _socket?.signal(id, 'battery_saver');
        return;
      }

      // Retour au-dessus du seuil (téléphone branché). Cinq points de marge :
      // un niveau qui oscille autour de 15 % ferait sinon clignoter la cadence
      // et le bandeau du cercle.
      if (_batterieFaible && n >= _seuilFaible + 5) {
        _batterieFaible = false;
        _batterieCritique = false;
        if (id != null) _socket?.signal(id, 'back');
      }
    } catch (e) {
      debugPrint('[TripGuard] batterie illisible: $e');
    }
  }

  /// Le battement. Il ne rallume pas le GPS : il renvoie le dernier point connu
  /// avec son horodatage de capture. C'est l'écart entre cet horodatage et
  /// l'heure de réception qui dit au serveur si l'appareil mesure encore.
  void _armerBattement() {
    _battement?.cancel();
    final r = _reglageCourant;
    _battement = Timer(Duration(seconds: r.beatS), () {
      unawaited(_envoyerMaintenant(force: true));
    });
  }

  // ── Tampon hors ligne ─────────────────────────────────────────────

  /// Rejoue les points restés en attente. Le serveur déduplique par `clientSeq`,
  /// donc une vidange partiellement rejouée est sans conséquence.
  Future<void> _viderTampon() async {
    final id = _tripId;
    final trips = _trips;
    final socket = _socket;
    if (id == null || trips == null || socket == null) return;

    final attente = await trips.pendingPoints(id);
    if (attente.isEmpty) return;

    socket.sendBatch(id, [
      for (final p in attente.take(200))
        {
          'clientSeq': p.clientSeq,
          'lat': p.lat,
          'lng': p.lng,
          if (p.accuracyM != null) 'accuracyM': p.accuracyM,
          if (p.battery != null) 'battery': p.battery,
          'recordedAt': p.recordedAt.toUtc().toIso8601String(),
        },
    ]);
    await trips.markPointsSent(id, attente.take(200).map((p) => p.clientSeq));
  }

  /// Met à jour la politique quand le serveur en sert une nouvelle — un réglage
  /// prend effet sur un trajet déjà en cours, sans redémarrage.
  Future<void> adoptPolicy(TripPolicy p) async {
    _policy = p;
    if (_tripId != null) await _appliquerRegime(_regime);
  }
}
