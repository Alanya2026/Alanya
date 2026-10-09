import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../../talky_api_client.dart';
import 'e2ee_coffre.dart';
import 'e2ee_database.dart';
import 'e2ee_store.dart';

/// Ce que cette version de l'application sait déchiffrer.
///
/// 0 : elle publie ses clés, mais ne lit encore rien. L'annoncer plus tôt
/// ferait recevoir des messages qu'elle afficherait illisibles. Passe à 1 avec
/// le déchiffrement du texte, 2 avec les médias, 3 avec les groupes — et à
/// chaque montée, l'appareil republie son bundle.
const int kE2eeCapacite = 0;

/// Stock de clés à usage unique visé sur le serveur.
const int kE2eeStockCible = 100;

/// Âge au-delà duquel la pré-clé signée tourne.
const Duration kE2eeRotationSignedPreKey = Duration(days: 30);

/// Après un `E2EE_INACTIF`, délai avant de redemander. Le chiffrement s'ouvre
/// par paliers, pas à la minute : redemander à chaque ouverture de session
/// coûterait une requête par démarrage pour tous les comptes hors cohorte.
const Duration kE2eeReessaiInactif = Duration(hours: 12);

/// Durée pendant laquelle une pré-clé signée retirée reste utilisable : un
/// correspondant a pu lire le bundle juste avant la rotation et n'écrire que
/// des jours après (migration serveur 091).
const Duration kE2eeConservationSignedPreKey = Duration(days: 60);

/// Ce que le serveur offre à `E2eeService`. Une interface pour que les tests
/// remplacent le réseau — mais attention : un faux serveur ne prouve rien sur
/// le contrat HTTP (docs/e2ee, chapitre 10). Les noms de champs sont donc
/// vérifiés à part, contre la validation du serveur.
abstract class E2eeApiPort {
  Future<Map<String, dynamic>> etat();
  Future<Map<String, dynamic>> publier(Map<String, dynamic> bundle);
  Future<Map<String, dynamic>> regarnir(List<Map<String, dynamic>> cles);
  Future<Map<String, dynamic>> tournerSignedPreKey(Map<String, dynamic> spk);
  Future<void> retirer();
}

/// L'adaptateur vers le vrai client.
class E2eeApiClient implements E2eeApiPort {
  E2eeApiClient(this._api);
  final TalkyApiClient _api;

  @override
  Future<Map<String, dynamic>> etat() => _api.fetchE2eeState();
  @override
  Future<Map<String, dynamic>> publier(Map<String, dynamic> bundle) =>
      _api.publishE2eeBundle(bundle);
  @override
  Future<Map<String, dynamic>> regarnir(List<Map<String, dynamic>> cles) =>
      _api.publishE2eePreKeys(cles);
  @override
  Future<Map<String, dynamic>> tournerSignedPreKey(Map<String, dynamic> spk) =>
      _api.rotateE2eeSignedPreKey(spk);
  @override
  Future<void> retirer() => _api.deleteE2eeKeys();
}

/// Issue d'une synchronisation, pour les journaux et les tests.
enum SynchroE2ee {
  /// Chiffrement fermé pour ce compte (`E2EE_INACTIF`). Rien n'est publié.
  inactif,

  /// Jeton sans appareil : il faut une reconnexion (`E2EE_APPAREIL_INCONNU`).
  appareilInconnu,

  /// Rien à faire : le serveur a déjà notre identité et assez de clés.
  aJour,

  /// Bundle publié (première fois, nouvelle identité, ou capacité montée).
  publie,

  /// Stock de clés à usage unique regarni.
  regarni,

  /// Échec réseau ou serveur. On réessaiera à la prochaine ouverture de
  /// session ; rien n'est cassé en attendant, la messagerie reste en clair.
  echec,
}

/// Fait passer les opérations une par une, dans l'ordre d'arrivée.
///
/// La bibliothèque Signal lit un état, le fait avancer, puis le réécrit. Deux
/// opérations entrelacées repartiraient du même état (docs/e2ee, chapitres 11
/// et 19). Ce verrou est le seul endroit où cette garantie se décide.
class VerrouSequentiel {
  Future<void> _fin = Future<void>.value();

  Future<T> executer<T>(Future<T> Function() action) {
    final resultat = _fin.then((_) => action());
    // La suite attend la fin de celle-ci, qu'elle réussisse ou non. Le corps
    // ne renvoie rien : un `=>` renverrait le Future attendu lui-même
    // (docs/e2ee, chapitre 26).
    _fin = resultat.then<void>((_) {}, onError: (Object _) {});
    return resultat;
  }
}

/// Le chiffrement de bout en bout de cet appareil, étape 1 : les clés.
///
/// Prépare l'identité Signal de l'appareil, la publie, garde le stock de clés
/// à usage unique garni et fait tourner la pré-clé signée. Ne chiffre encore
/// aucun message.
///
/// ── À qui appartient le coffre ──
///
/// Le coffre est lié au couple (compte, appareil) que le serveur annonce.
/// S'il a été écrit pour un autre — autre compte sur ce téléphone, ligne
/// d'appareil révoquée puis recréée —, il est vidé et une identité neuve est
/// créée. Publier l'identité d'un autre compte comme la sienne est
/// exactement ce qu'il faut empêcher (docs/e2ee, chapitre 22).
class E2eeService {
  E2eeService({
    required E2eeDatabase db,
    required CleDuCoffreStore cleDuCoffre,
    required E2eeApiPort api,
    DateTime Function()? horloge,
  })  : _db = db,
        _coffre = CoffreE2ee(cleDuCoffre),
        _api = api,
        _horloge = horloge ?? DateTime.now {
    _store = AlanyaSignalStore(_db, _coffre, horloge: _horloge);
  }

  static E2eeService? _instance;

  /// L'instance de l'application, ou `null` tant qu'elle n'est pas installée.
  static E2eeService? get maybeInstance => _instance;

  /// Installe l'instance de l'application (une fois, au démarrage).
  static E2eeService installer(TalkyApiClient api) => _instance ??= E2eeService(
        db: E2eeDatabase.appareil(),
        cleDuCoffre: CleDuCoffreSecureStorage(),
        api: E2eeApiClient(api),
      );

  final E2eeDatabase _db;
  final CoffreE2ee _coffre;
  final E2eeApiPort _api;
  final DateTime Function() _horloge;
  late final AlanyaSignalStore _store;
  final VerrouSequentiel _verrou = VerrouSequentiel();
  Future<SynchroE2ee>? _synchroEnCours;

  static const String _metaProprietaire = 'proprietaire';
  static const String _metaInactifJusqua = 'inactif_jusqua';
  static const String _metaProchainePreKey = 'prochaine_prekey';
  static const String _metaProchaineSpk = 'prochaine_spk';

  /// Le store, pour les étapes suivantes. Ne s'appelle que sous [executer].
  @visibleForTesting
  AlanyaSignalStore get store => _store;

  /// Fait passer [action] sous le verrou, coffre ouvert.
  Future<T> executer<T>(Future<T> Function() action) => _verrou.executer(() async {
        await _ouvrirCoffre();
        return action();
      });

  /// Synchronise les clés de cet appareil avec le serveur.
  ///
  /// À appeler à chaque ouverture de session. Une seule à la fois : un second
  /// appel pendant la première rend le même résultat. Ne lève jamais : un
  /// échec laisse la messagerie telle qu'elle est, en clair.
  Future<SynchroE2ee> synchroniser(int alanyaID) {
    return _synchroEnCours ??= _verrou
        .executer(() => _synchroniser(alanyaID))
        .catchError((Object e, StackTrace st) {
      debugPrint('[E2EE] synchronisation impossible : $e');
      return SynchroE2ee.echec;
    }).whenComplete(() {
      _synchroEnCours = null;
    });
  }

  /// Oublie tout : identité, sessions, pré-clés, clé du coffre.
  ///
  /// [retirerDuServeur] : retire aussi le bundle publié — à faire tant que la
  /// session est encore valide, donc AVANT d'effacer les jetons. Un échec du
  /// retrait n'empêche pas l'oubli local : la déconnexion est un geste de
  /// sécurité, elle ne doit pas attendre le réseau.
  Future<void> oublier({bool retirerDuServeur = false}) => _verrou.executer(() async {
        if (retirerDuServeur) {
          try {
            await _api.retirer().timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint('[E2EE] retrait du bundle impossible : $e');
          }
        }
        await _db.toutEffacer();
        await _coffre.detruire();
      });

  // ── Internes, toujours sous le verrou ──────────────────────────────────

  Future<void> _ouvrirCoffre() async {
    final cleNeuve = await _coffre.ouvrir();
    // Une clé neuve devant un coffre plein : le contenu est scellé sous une
    // clé perdue (Keystore invalidé, restauration sur un autre appareil). Il
    // est illisible pour toujours ; le garder, ce serait buter dessus à chaque
    // opération.
    if (cleNeuve && await _store.aUneIdentite()) {
      debugPrint('[E2EE] clé du coffre perdue : état Signal remis à zéro');
      await _db.toutEffacer();
    }
  }

  Future<SynchroE2ee> _synchroniser(int alanyaID) async {
    final inactifJusqua = int.tryParse(await _db.lireMeta(_metaInactifJusqua) ?? '');
    if (inactifJusqua != null &&
        _horloge().millisecondsSinceEpoch < inactifJusqua &&
        await _db.lireMeta(_metaProprietaire) == null) {
      return SynchroE2ee.inactif;
    }

    final Map<String, dynamic> etat;
    try {
      etat = await _api.etat();
    } on TalkyException catch (e) {
      if (e.code == 'E2EE_INACTIF') {
        await _db.ecrireMeta(
          _metaInactifJusqua,
          '${_horloge().add(kE2eeReessaiInactif).millisecondsSinceEpoch}',
        );
        return SynchroE2ee.inactif;
      }
      if (e.code == 'E2EE_APPAREIL_INCONNU') return SynchroE2ee.appareilInconnu;
      rethrow;
    }

    // Ouvert seulement maintenant : un compte hors cohorte ne doit pas se
    // retrouver avec une clé de coffre dans son Keystore pour rien.
    await _ouvrirCoffre();

    final appareilId = (etat['appareilId'] as num).toInt();
    await _lierAuProprietaire(alanyaID, appareilId);
    await _assurerIdentite();
    final servie = (etat['signedPreKeyId'] as num?)?.toInt();
    await _tournerSignedPreKeySiAgee(servieParLeServeur: servie);

    final identite = await _store.getIdentityKeyPair();
    final registrationId = await _store.getLocalRegistrationId();
    final maCle = base64Encode(identite.getPublicKey().serialize());

    final publie = etat['publie'] == true;
    final memeIdentite = publie &&
        etat['identityKey'] == maCle &&
        (etat['registrationId'] as num?)?.toInt() == registrationId;
    final libres = memeIdentite ? (etat['otpkLibres'] as num?)?.toInt() ?? 0 : 0;

    if (!memeIdentite || (etat['capacite'] as num?)?.toInt() != kE2eeCapacite) {
      // Le bundle complet porte déjà la pré-clé signée la plus récente.
      final aGarnir = memeIdentite ? (kE2eeStockCible - libres).clamp(0, kE2eeStockCible) : kE2eeStockCible;
      await _api.publier(await _bundle(await _nouvellesPreKeys(aGarnir)));
      return SynchroE2ee.publie;
    }

    // Le serveur détient NOTRE identité : la rotation peut s'y poser. Plus
    // tôt, elle aurait pu atterrir sur le bundle d'une installation
    // précédente, signée par une autre identité.
    //
    // On compare à ce que le serveur SERT, pas à « vient-on de tourner ? » :
    // une rotation dont l'envoi a échoué (réseau coupé) n'est plus récente à
    // la synchronisation suivante, et ne repartirait jamais.
    final courante = (await _store.pagesSignedPreKeys()).first.id;
    if (servie != courante) {
      await _api.tournerSignedPreKey(_signedPreKeyJson(await _store.loadSignedPreKey(courante)));
    }

    if (etat['regarnissageNecessaire'] == true) {
      final cles = await _nouvellesPreKeys(kE2eeStockCible - libres);
      if (cles.isNotEmpty) {
        await _api.regarnir([for (final c in cles) _preKeyJson(c)]);
        return SynchroE2ee.regarni;
      }
    }
    return SynchroE2ee.aJour;
  }

  /// Vide le coffre s'il a été écrit pour un autre (compte, appareil).
  Future<void> _lierAuProprietaire(int alanyaID, int appareilId) async {
    final attendu = '$alanyaID:$appareilId';
    final actuel = await _db.lireMeta(_metaProprietaire);
    if (actuel != null && actuel != attendu) {
      debugPrint('[E2EE] coffre écrit pour $actuel, session $attendu : remis à zéro');
      await _db.toutEffacer();
    }
    if (actuel != attendu) {
      await _db.ecrireMeta(_metaProprietaire, attendu);
    }
  }

  Future<void> _assurerIdentite() async {
    if (await _store.aUneIdentite()) return;
    await _store.poserIdentite(generateIdentityKeyPair(), generateRegistrationId(false));
    await _nouvelleSignedPreKey();
  }

  Future<SignedPreKeyRecord> _nouvelleSignedPreKey() async {
    final id = await _prochainIdentifiant(_metaProchaineSpk, 1);
    final spk = generateSignedPreKey(await _store.getIdentityKeyPair(), id);
    await _store.storeSignedPreKey(spk.id, spk);
    return spk;
  }

  /// Crée une nouvelle pré-clé signée si la plus récente a plus de 30 jours,
  /// et retire celles dont le délai de conservation est passé.
  ///
  /// La publication n'a pas lieu ici : elle dépend de ce que le serveur
  /// détient. [servieParLeServeur] n'est jamais retirée, quel que soit son âge :
  /// tant que le serveur la sert, un correspondant peut amorcer dessus.
  Future<void> _tournerSignedPreKeySiAgee({int? servieParLeServeur}) async {
    final maintenant = _horloge();
    final avant = await _store.pagesSignedPreKeys();
    if (avant.isEmpty || maintenant.difference(avant.first.creeLe) >= kE2eeRotationSignedPreKey) {
      await _nouvelleSignedPreKey();
    }

    // Du plus récent au plus ancien. Une pré-clé cesse de servir le jour où
    // la suivante est créée : c'est de CE jour que court la conservation, pas
    // de sa propre création — sinon une pré-clé retirée hier, créée il y a
    // deux mois, partirait aussitôt.
    final pages = await _store.pagesSignedPreKeys();
    for (var i = 1; i < pages.length; i++) {
      if (pages[i].id == servieParLeServeur) continue;
      final retireeLe = pages[i - 1].creeLe;
      if (maintenant.difference(retireeLe) > kE2eeConservationSignedPreKey) {
        await _store.removeSignedPreKey(pages[i].id);
      }
    }
  }

  /// Tire [nombre] pré-clés à usage unique, d'identifiants CONSÉCUTIFS
  /// réservés par un compteur — jamais au hasard : deux lots tirés au hasard
  /// peuvent se chevaucher, et le doublon écraserait une clé encore publiée
  /// (docs/e2ee, chapitre 13).
  Future<List<PreKeyRecord>> _nouvellesPreKeys(int nombre) async {
    if (nombre <= 0) return const [];
    final debut = await _prochainIdentifiant(_metaProchainePreKey, nombre);
    final cles = generatePreKeys(debut, nombre);
    for (final c in cles) {
      await _store.storePreKey(c.id, c);
    }
    return cles;
  }

  /// Réserve [nombre] identifiants consécutifs et rend le premier.
  ///
  /// Le compteur démarre au-dessus de tout identifiant déjà rangé : une base
  /// dont la méta aurait été perdue ne doit pas réémettre un numéro existant.
  /// Les identifiants vivent dans [1, 0xFFFFFE] et bouclent, comme ceux de
  /// `generatePreKeys`.
  Future<int> _prochainIdentifiant(String meta, int nombre) async {
    const borne = maxValue - 1;
    var debut = int.tryParse(await _db.lireMeta(meta) ?? '') ?? 0;
    if (debut < 1) {
      final plancher = meta == _metaProchainePreKey
          ? await _store.plusGrandePreKey()
          : (await _store.pagesSignedPreKeys()).fold<int>(0, (m, p) => p.id > m ? p.id : m);
      debut = (plancher % borne) + 1;
    }
    final suivant = ((debut - 1 + nombre) % borne) + 1;
    await _db.ecrireMeta(meta, '$suivant');
    return debut;
  }

  Future<Map<String, dynamic>> _bundle(List<PreKeyRecord> preKeys) async {
    final identite = await _store.getIdentityKeyPair();
    final pages = await _store.pagesSignedPreKeys();
    final spk = await _store.loadSignedPreKey(pages.first.id);
    return {
      'registrationId': await _store.getLocalRegistrationId(),
      'identityKey': base64Encode(identite.getPublicKey().serialize()),
      'capacite': kE2eeCapacite,
      'signedPreKey': _signedPreKeyJson(spk),
      'oneTimePreKeys': [for (final c in preKeys) _preKeyJson(c)],
    };
  }

  static Map<String, dynamic> _signedPreKeyJson(SignedPreKeyRecord spk) => {
        'keyId': spk.id,
        'publicKey': base64Encode(spk.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(spk.signature),
      };

  static Map<String, dynamic> _preKeyJson(PreKeyRecord c) => {
        'keyId': c.id,
        'publicKey': base64Encode(c.getKeyPair().publicKey.serialize()),
      };
}
