import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart';
import '../../../talky_models.dart';
import '../list_ringtone_preferences.dart';
import '../translation/message_translation_service.dart';
import 'billing_models.dart';
import 'entitlements.dart';

/// Un paiement vient de changer d'état chez le fournisseur.
typedef PaymentUpdate = ({int paymentId, PaymentStatus status});

/// Droits d'accès Alanya Plus : cache local et synchronisation serveur.
///
/// Le serveur calcule, le téléphone lit. Les droits arrivent avec `/auth/me`
/// (via [AuthProvider]) et se rafraîchissent par `GET /billing/me` : quand
/// `validUntil` est dépassé, au retour au premier plan, et sur l'événement
/// `entitlements:updated`. Sans réponse serveur, le dernier état connu
/// s'applique — et sans aucun état connu, tout est permis.
class EntitlementService extends ChangeNotifier {
  EntitlementService({required TalkyApiClient api}) : _api = api {
    _instance = this;
    // Le registre du client ré-attache ces écoutes à chaque nouvelle socket
    // (déconnexion puis reconnexion) : un seul enregistrement suffit.
    _api.onSocketEvent(SocketEvents.entitlementsUpdated, _onEntitlementsUpdated);
    _api.onSocketEvent(SocketEvents.paymentUpdated, _onPaymentUpdated);
  }

  static const _cacheKey = 'plus_entitlements_json_v1';
  static const _offerKey = 'plus_offer_json_v1';

  /// Dernière purge serveur déjà répercutée sur le téléphone (horodatage ISO) :
  /// une purge ne s'applique qu'une fois, pas à chaque relecture des droits.
  static const _purgeAppliedKey = 'plus_local_purge_applied_v1';

  /// Relu par le code natif Android quand l'application est tuée
  /// (`CallIncomingHelper`, `MessageNotificationHelper`) : les sonneries par
  /// liste y sont résolues sans Dart. Absent, tout est permis — comme ici.
  static const listRingtonesFlagKey = 'plus_list_ringtones';

  static EntitlementService? _instance;

  /// Pour les services sans contexte (traduction, sonneries) : même instance
  /// que celle exposée par le `MultiProvider`.
  static EntitlementService? get maybeInstance => _instance;

  /// Lecture synchrone. Sans service (tests, démarrage), rien n'est fermé.
  static bool allows(PlusFeature feature) =>
      _instance?.has(feature) ?? true;

  final TalkyApiClient _api;
  final StreamController<PaymentUpdate> _payments =
      StreamController<PaymentUpdate>.broadcast();
  final StreamController<void> _outgoingBlocked =
      StreamController<void>.broadcast();
  Entitlements _current = Entitlements.unrestricted;
  PlusOffer? _offer;
  bool _refreshing = false;
  DateTime? _lastOutgoingBlock;

  Entitlements get current => _current;

  /// Dernière offre connue : les prix de la carte du profil et du panneau,
  /// y compris hors connexion. Nulle tant qu'elle n'a jamais été chargée.
  PlusOffer? get offer => _offer;

  bool has(PlusFeature feature) => _current.has(feature);

  /// Le compte peut-il envoyer un message ou lancer un appel ?
  bool get canSend => _current.canSend;

  /// Plafonds d'envoi du compte, lus sans contexte : la taille d'un fichier et le
  /// nombre de médias d'un album. Palier standard sans service ni droits connus.
  static PlusLimits get limits => _instance?._current.limits ?? PlusLimits.standard;
  static int get maxUploadBytes => limits.maxUploadBytes;
  static int get maxUploadMb => limits.maxUploadMb;
  static int get maxAlbumItems => limits.maxAlbumItems;

  /// Lecture synchrone du droit d'émettre, pour les services sans contexte.
  /// Sans service (tests, démarrage), rien n'est fermé.
  static bool get allowsOutgoing => _instance?.canSend ?? true;

  /// Un envoi ou un appel vient d'être refusé — par le téléphone, qui savait
  /// déjà, ou par le serveur, qui vient de le dire. Un seul abonné s'en sert :
  /// l'écoute racine qui ouvre le panneau de l'abonnement.
  ///
  /// Plusieurs refus coup sur coup (cinq messages en file qui échouent
  /// ensemble) ne font qu'un seul signal : le panneau ne s'ouvre pas cinq fois.
  Stream<void> get outgoingBlocked => _outgoingBlocked.stream;

  /// Fenêtre où des refus rapprochés ne font qu'un signal. Assez longue pour une
  /// rafale (des messages en file qui échouent ensemble arrivent à quelques
  /// millisecondes), assez courte pour qu'un appui volontaire — « réessayer »,
  /// un bouton d'appel — rouvre le panneau juste après qu'on l'a fermé.
  static const _outgoingCoalesce = Duration(seconds: 2);

  /// Signale un refus d'émettre, et relit les droits : le compte a peut-être
  /// été abonné depuis un autre appareil, que le cache ne sait pas encore.
  void reportOutgoingBlocked() {
    final now = DateTime.now();
    final last = _lastOutgoingBlock;
    if (last != null && now.difference(last) < _outgoingCoalesce) return;
    _lastOutgoingBlock = now;
    if (!_outgoingBlocked.isClosed) _outgoingBlocked.add(null);
    unawaited(refresh());
  }

  /// Les changements d'état des paiements, tels que le serveur les annonce.
  /// L'écran d'attente s'y abonne ; rien n'est rejoué à un abonné tardif.
  Stream<PaymentUpdate> get paymentUpdates => _payments.stream;

  void _onEntitlementsUpdated(dynamic _) => unawaited(refresh());

  void _onPaymentUpdated(dynamic data) {
    if (data is! Map) return;
    final id = (data['paymentId'] as num?)?.toInt();
    final status = PaymentStatus.fromWire(data['status']);
    if (id == null || status == null) return;
    if (!_payments.isClosed) _payments.add((paymentId: id, status: status));
    // Le serveur annonce aussi `entitlements:updated`, mais l'utilisateur
    // regarde l'écran de confirmation : ne pas dépendre d'un second message.
    if (status == PaymentStatus.succeeded) unawaited(refresh());
  }

  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final rawOffer = prefs.getString(_offerKey);
      if (raw == null && rawOffer == null) return;
      if (raw != null) {
        _current = Entitlements.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
      if (rawOffer != null) {
        _offer = PlusOffer.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawOffer) as Map),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Entitlements] cache illisible : $e');
    }
  }

  /// Recharge l'offre, et les droits qu'elle transporte.
  ///
  /// Lève en cas d'échec : l'écran d'offre affiche l'erreur. Les autres
  /// appelants passent par [ensureOffer], qui l'avale.
  Future<PlusOffer> loadOffer() async {
    final raw = await _api.getPlusOffer();
    final offer = PlusOffer.fromJson(raw);
    _offer = offer;
    if (raw['entitlements'] is Map) {
      await apply(raw['entitlements']);
    } else {
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offerKey, jsonEncode(raw));
    } catch (e) {
      debugPrint('[Entitlements] offre non mise en cache : $e');
    }
    return offer;
  }

  /// Charge l'offre si on ne la connaît pas encore. Silencieux.
  Future<void> ensureOffer() async {
    if (_offer != null) return;
    try {
      await loadOffer();
    } catch (e) {
      debugPrint('[Entitlements] offre indisponible : $e');
    }
  }

  /// Le profil `/auth/me` : sa clé `entitlements`, ou rien (serveur ancien).
  Future<void> applyFromProfile(Map<String, dynamic> me) =>
      apply(me['entitlements']);

  Future<void> apply(Object? raw) async {
    _current = raw is Map
        ? Entitlements.fromJson(Map<String, dynamic>.from(raw))
        : Entitlements.unrestricted;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_current.known) {
        await prefs.setString(_cacheKey, jsonEncode(_current.toJson()));
      } else {
        await prefs.remove(_cacheKey);
      }
      await prefs.setBool(
        listRingtonesFlagKey,
        _current.has(PlusFeature.listRingtones),
      );
      await _applyLocalPurge(prefs);
    } catch (e) {
      debugPrint('[Entitlements] cache non écrit : $e');
    }
  }

  /// Le serveur a effacé les données payantes du compte : le téléphone efface
  /// les siennes — modèles et traductions, sons des listes. La sauvegarde
  /// n'est jamais concernée.
  Future<void> _applyLocalPurge(SharedPreferences prefs) async {
    final purgedAt = _current.purgedAt;
    if (purgedAt == null) return;
    final marker = purgedAt.toUtc().toIso8601String();
    if (prefs.getString(_purgeAppliedKey) == marker) return;
    try {
      await MessageTranslationService.maybeInstance?.purgePaidData();
      await ListRingtonePreferences.purgeLocal();
      await prefs.setString(_purgeAppliedKey, marker);
      debugPrint('[Entitlements] purge locale appliquée ($marker)');
    } catch (e) {
      // Le marqueur n'est pas posé : la prochaine lecture des droits réessaie.
      debugPrint('[Entitlements] purge locale incomplète : $e');
    }
  }

  /// Relit les droits. Un échec (réseau, serveur ancien) garde l'état connu.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await apply(await _api.getMyEntitlements());
    } catch (e) {
      debugPrint('[Entitlements] rafraîchissement impossible : $e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> refreshIfStale() async {
    if (_current.isStale(DateTime.now())) await refresh();
  }

  /// À la déconnexion : les droits d'un compte ne passent pas au suivant.
  Future<void> clear() async {
    _current = Entitlements.unrestricted;
    _offer = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_offerKey);
      await prefs.remove(listRingtonesFlagKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _api.removeSocketListener(
        SocketEvents.entitlementsUpdated, _onEntitlementsUpdated);
    _api.removeSocketListener(SocketEvents.paymentUpdated, _onPaymentUpdated);
    unawaited(_payments.close());
    unawaited(_outgoingBlocked.close());
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }
}
