import 'dart:async';

import 'package:app_links/app_links.dart';

import '../utils/app_log.dart';

/// Réception des liens `…/q/u/<jeton>` — partagés par lien ou ouverts depuis
/// la page d'accueil web d'un code QR.
///
/// Ce service ne fait que EXTRAIRE le jeton et l'annoncer. Il ne résout rien et
/// n'écrit aucun contact : c'est l'app authentifiée qui appellera
/// `POST /api/qr/resolve`, exactement comme après un scan. Un lien reçu alors
/// que personne n'est connecté est donc mis de côté, pas perdu, et rejoué une
/// fois la session ouverte.
class QrDeepLinkService {
  QrDeepLinkService._();
  static final QrDeepLinkService instance = QrDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  final StreamController<({String kind, String token})> _tokens =
      StreamController<({String kind, String token})>.broadcast();

  /// Jetons d'identité reçus par lien, avec leur genre (`c` éphémère /
  /// `u` permanent). Diffusion sans mémoire tampon : un abonné arrivé trop
  /// tard rate l'événement, d'où [consumePendingToken].
  Stream<({String kind, String token})> get identityTokens => _tokens.stream;

  /// Jeton reçu avant qu'un abonné soit prêt (démarrage à froid, ou session
  /// pas encore ouverte). Se lit une seule fois.
  ({String kind, String token})? _pending;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      // Lien ayant provoqué le démarrage de l'app : il n'arrive jamais par le
      // flux, il faut le demander explicitement.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);

      _subscription = _appLinks.uriLinkStream.listen(
        _handle,
        onError: (Object e, StackTrace st) =>
            AppLog.w('QrDeepLink', 'Flux de liens en erreur', e, st),
      );
    } catch (e, st) {
      AppLog.e('QrDeepLink', 'Initialisation des liens échouée', e, st);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Met un jeton de côté faute de session ouverte. Il sera rejoué par
  /// [consumePendingToken] une fois la connexion faite.
  void stashToken(({String kind, String token}) token) => _pending = token;

  /// Récupère et efface le jeton en attente. Appelé une fois la session
  /// ouverte, pour rejouer un lien reçu avant la connexion.
  ({String kind, String token})? consumePendingToken() {
    final token = _pending;
    _pending = null;
    return token;
  }

  void _handle(Uri uri) {
    final token = extractIdentityToken(uri);
    if (token == null) {
      AppLog.w('QrDeepLink', 'Lien ignoré (forme inattendue) : $uri');
      return;
    }
    if (_tokens.hasListener) {
      _tokens.add(token);
    } else {
      _pending = token;
    }
  }

  /// Extrait `(genre, jeton)` de `alanya://q/<genre>/<jeton>` comme de
  /// `https://<hôte>/q/<genre>/<jeton>`. Genres connus : `c` (contact
  /// éphémère, le régime des comptes personnels) et `u` (permanent, futurs
  /// comptes business). Retourne null pour toute autre forme.
  ///
  /// Le schéma applicatif place `q` dans l'hôte et non dans le chemin
  /// (`alanya://q/c/X` → host `q`, segments `[c, X]`), d'où les deux cas.
  static ({String kind, String token})? extractIdentityToken(Uri uri) {
    const genres = {'u', 'c'};
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (segments.length >= 3 &&
          segments[0] == 'q' &&
          genres.contains(segments[1])) {
        return (kind: segments[1], token: segments[2]);
      }
      return null;
    }

    if (uri.host == 'q' && segments.length >= 2 && genres.contains(segments[0])) {
      return (kind: segments[0], token: segments[1]);
    }
    if (segments.length >= 3 &&
        segments[0] == 'q' &&
        genres.contains(segments[1])) {
      return (kind: segments[1], token: segments[2]);
    }
    return null;
  }
}
