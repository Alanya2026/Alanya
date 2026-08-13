import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Fond de carte de l'application.
///
/// Centralisé parce que les tuiles apparaissent dans trois écrans — partage de
/// position, choix de destination, suivi de trajet. Dispersées, elles auraient
/// divergé au premier changement.
///
/// **Le rendu est la feuille OpenStreetMap standard.** Un détour par CartoDB
/// (Voyager / Dark Matter) a été essayé pour son rendu plus doux et sa variante
/// sombre : à l'usage, les éléments s'y lisaient moins bien. Les fonds « allégés »
/// gagnent en élégance en retirant du contenu — noms de rues, numéros, points de
/// repère — et c'est précisément ce contenu qui permet à un proche de reconnaître
/// un endroit. Sur une carte de sûreté, la lisibilité des repères passe avant
/// l'esthétique du fond.
///
/// Deux dispositions préparent la mise en production :
///
///  1. **La source vient du serveur** ([adopt]), avec un repli compilé. Changer
///     de fournisseur ne demande donc pas de publier une version — ce qui
///     compte, parce qu'une publication met des jours à atteindre le parc et
///     qu'une partie des utilisateurs ne met jamais à jour.
///  2. **Les tuiles sont mises en cache sur disque.** Le fournisseur par défaut
///     l'exige, et c'est de toute façon la bonne chose à faire : sans cache, une
///     carte rouverte retélécharge tout.
class MapTiles {
  MapTiles._();

  // ── Source ────────────────────────────────────────────────────────

  /// Repli compilé, utilisé tant que le serveur n'a pas répondu.
  ///
  /// ⚠ `tile.openstreetmap.org` tourne sur les ressources données à la
  /// fondation OSM et sa politique n'autorise qu'un usage léger. C'est le
  /// défaut de développement ; en production, le serveur doit servir autre
  /// chose. Voir `docs/exploitation/tuiles.md`.
  static const _urlDefaut = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _attributionDefaut = '© OpenStreetMap';

  static String _url = _urlDefaut;
  static String _attribution = _attributionDefaut;

  /// Dernier niveau que le fournisseur publie vraiment. La feuille OSM standard
  /// s'arrête à 19.
  static int _maxZoom = 19;

  /// Niveaux de zoom autorisés **au-delà** de ce que le fournisseur publie.
  ///
  /// Deux crans : la carte devient floue mais reste utilisable, et c'est tout
  /// l'enjeu. Sur un suivi, on zoome pour distinguer deux positions séparées de
  /// quelques mètres — savoir si la personne est devant l'immeuble ou dans la
  /// cour. À cet instant, la netteté des noms de rue ne sert à rien : c'est
  /// l'écart entre les deux points qui compte, et lui reste net.
  ///
  /// Au-delà de deux crans, l'image devient une bouillie de pixels qui donne une
  /// fausse impression de précision — le pire résultat possible sur une carte de
  /// sûreté.
  static const _zoomSupplementaire = 2;

  /// Zoom maximal que la **caméra** doit autoriser.
  ///
  /// À passer à `MapOptions.maxZoom`, et pas seulement à la couche de tuiles.
  /// Sans cette borne, `MapOptions.maxZoom` vaut `null` : le geste de zoom n'est
  /// jamais arrêté, l'utilisateur dépasse le dernier niveau dessinable et se
  /// retrouve devant un aplat uni. Brider la caméra fait que le geste **bute**
  /// — c'est un comportement de carte normal, que tout le monde comprend, au
  /// lieu d'un écran vide qu'on prend pour une panne.
  static double get maxDisplayZoom =>
      (_maxZoom + _zoomSupplementaire).toDouble();

  /// Zoom minimal. En deçà, on voit la planète entourée de vide : les tuiles
  /// existent, mais le monde ne remplit plus l'écran.
  static const double minDisplayZoom = 3;

  /// Couleur du fond, sous les tuiles.
  ///
  /// `flutter_map` utilise par défaut un gris clair **fixe** (`#E0E0E0`), le
  /// même dans les deux thèmes. On le voit à chaque instant où une tuile manque
  /// — chargement, réseau lent, tuile en erreur — et en thème sombre, cela
  /// produit un aplat clair en plein écran, exactement l'effet « la carte est
  /// blanche ».
  ///
  /// La surface du thème, elle, se fond dans l'écran : une tuile qui tarde
  /// laisse un trou discret au lieu d'un rectangle éclatant.
  static Color background(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  /// Identifie l'application auprès du fournisseur. C'est une exigence de la
  /// politique d'usage OSM — et l'unité par laquelle on se ferait bloquer, ce
  /// qui est le comportement correct : mieux vaut être identifiable que
  /// clandestin.
  static const _userAgent = 'com.alanya.talky';

  static String get attribution => _attribution;

  /// Adopte la configuration servie par `GET /api/map/tiles`.
  ///
  /// Sans effet si la charge utile est incomplète : une URL vide viderait la
  /// carte, et un fond de carte absent est pire qu'un fond de carte imparfait.
  static void adopt(Map<String, dynamic>? config) {
    if (config == null) return;
    final url = config['url']?.toString();
    if (url == null || !url.contains('{z}')) return;

    _url = url;
    _attribution = config['attribution']?.toString().trim().isNotEmpty == true
        ? config['attribution'].toString()
        : _attributionDefaut;
    _maxZoom = (config['maxZoom'] as num?)?.toInt() ?? _maxZoom;

    final jours = (config['cacheDays'] as num?)?.toInt();
    if (jours != null && jours > 0) _peremption = Duration(days: jours);

    // Changer de fournisseur invalide le cache : les tuiles gardées viennent de
    // l'ancien rendu, et les mélanger donnerait une carte en patchwork.
    if (url != _urlAuCache) {
      _urlAuCache = url;
      _cache?.emptyCache();
      _cache = null;
    }
  }

  // ── Cache disque ──────────────────────────────────────────────────

  static Duration _peremption = const Duration(days: 30);
  static String? _urlAuCache;
  static CacheManager? _cache;

  /// Cache dédié aux tuiles, séparé de celui des avatars et des médias.
  ///
  /// Séparé pour une raison précise : les volumes n'ont rien à voir. Un trajet
  /// suivi charge des centaines de tuiles, et les laisser concourir avec les
  /// photos de profil dans un même quota ferait expulser les unes par les
  /// autres — on retéléchargerait en boucle ce qu'on venait de garder.
  ///
  /// Trente jours : une rue ne bouge pas d'un jour à l'autre. Deux mille
  /// objets : de quoi couvrir une ville aux zooms utiles, soit quelques dizaines
  /// de mégaoctets, sans transformer le téléphone en atlas.
  static CacheManager get _gestionnaire => _cache ??= CacheManager(
        Config(
          'alanya_map_tiles',
          stalePeriod: _peremption,
          maxNrOfCacheObjects: 2000,
        ),
      );

  // ── Rendu ─────────────────────────────────────────────────────────

  /// Couche de tuiles.
  ///
  /// Pas de variante sombre : la feuille standard n'en publie pas, et assombrir
  /// les tuiles par un filtre rendrait les libellés illisibles — on retomberait
  /// sur le défaut qu'on vient de corriger.
  static TileLayer layer(BuildContext context) {
    return TileLayer(
      urlTemplate: _url,
      userAgentPackageName: _userAgent,
      // ⚠ Deux molettes, et c'est la mauvaise qui était réglée.
      //
      // `maxNativeZoom` dit jusqu'où le fournisseur publie réellement des
      // tuiles. Au-delà, flutter_map réutilise celles de ce niveau **en les
      // agrandissant** : la carte reste affichée, simplement plus floue.
      //
      // `maxZoom` coupe la couche : au-dessus, plus rien n'est dessiné. La
      // renseigner à 19 rendait la carte **blanche** dès qu'on zoomait un cran
      // trop loin, au lieu de flouter. `MapOptions.maxZoom` étant nul par
      // défaut, la caméra, elle, ne bridait rien.
      maxNativeZoom: _maxZoom,
      maxZoom: (_maxZoom + _zoomSupplementaire).toDouble(),
      tileProvider: _CachedTileProvider(_gestionnaire),
      // Les tuiles manquantes restent transparentes plutôt que d'afficher un
      // carré gris : sur un réseau lent, un damier gris donne l'impression que
      // l'application est cassée.
      errorTileCallback: (_, __, ___) {},
    );
  }

  /// Mention légale — contrepartie du droit d'usage, pas une décoration.
  ///
  /// À placer **dans les `children` de [FlutterMap]**, jamais dans une pile
  /// au-dessus : le widget s'abonne au flux d'événements de la carte pour se
  /// replier quand on la déplace, et n'a pas ce contexte en dehors.
  ///
  /// Ancrée à gauche : le coin bas-droit appartient aux boutons flottants, et
  /// une mention qu'un bouton recouvre n'est plus une mention.
  static Widget attributionWidget() => RichAttributionWidget(
        alignment: AttributionAlignment.bottomLeft,
        showFlutterMapAttribution: false,
        attributions: [TextSourceAttribution(_attribution)],
      );
}

/// Fournisseur de tuiles adossé au cache disque.
///
/// `flutter_map` ne s'appuie par défaut que sur le cache mémoire de Flutter,
/// vidé à chaque fermeture : rouvrir un suivi retéléchargeait l'intégralité de
/// la carte. Sur un réseau mobile, c'est de l'attente et des données pour
/// afficher exactement ce qu'on venait d'afficher.
class _CachedTileProvider extends TileProvider {
  _CachedTileProvider(this._cache);

  final CacheManager _cache;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheManager: _cache,
      // L'en-tête doit accompagner CHAQUE requête : c'est par lui que le
      // fournisseur nous identifie, et son absence vaut refus de service.
      headers: const {'User-Agent': MapTiles._userAgent},
    );
  }
}
