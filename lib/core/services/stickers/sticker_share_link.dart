import '../../config/legal_urls.dart';

/// Lecture d'un lien, d'un code ou d'un texte collé contenant l'un des deux,
/// et fabrication du lien à partager.
///
/// Le jeton du contrat : 24 caractères `[A-Za-z0-9_-]` (144 bits).
///
/// Formes reconnues (et seulement elles) :
/// - le jeton nu ;
/// - `https://www.alanya237.com/s/<jeton>` (App Link, hôte de
///   [LegalUrls.baseHost]) : ni `http`, ni autre hôte, ni identifiants
///   (`user@`), ni port ;
/// - `alanya://sticker/<jeton>` (schéma applicatif, sans certificat).
abstract final class StickerShareLink {
  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{24}$');
  static final RegExp _url = RegExp(
    r'(?:alanya|https?)://\S+',
    caseSensitive: false,
  );

  /// Ponctuation qui suit un lien dans une phrase (« …/s/xxx. », « (…) »).
  static final RegExp _trailing = RegExp(r'''[.,;:!?)\]}>"'»”’]+$''');

  /// Schéma applicatif déjà déclaré dans le manifeste (`alanya://`).
  static const String scheme = 'alanya';
  static const String host = 'sticker';

  /// Premier segment du chemin web : `https://<hôte>/s/<jeton>`.
  static const String webSegment = 's';

  static final String _webHost = Uri.parse(LegalUrls.baseHost).host;

  /// Lien https à partager pour [token] : `https://www.alanya237.com/s/<jeton>`.
  static String build(String token) =>
      '${LegalUrls.baseHost}/$webSegment/$token';

  /// Lien du schéma applicatif (`alanya://sticker/<jeton>`).
  static String buildApp(String token) => '$scheme://$host/$token';

  static bool isToken(String s) => _token.hasMatch(s);

  /// Extrait un jeton de [input] : le jeton nu, `alanya://sticker/<jeton>` ou
  /// `https://www.alanya237.com/s/<jeton>`, y compris dans un texte plus long.
  /// `null` si rien d'exploitable.
  static String? parse(String? input) {
    if (input == null) return null;
    final raw = input.trim();
    if (raw.isEmpty) return null;
    if (_token.hasMatch(raw)) return raw;
    for (final m in _url.allMatches(raw)) {
      final url = m.group(0)!.replaceFirst(_trailing, '');
      final t = fromUri(Uri.tryParse(url));
      if (t != null) return t;
    }
    return null;
  }

  /// Jeton d'un lien reçu par la plate-forme (`app_links`), ou `null`.
  static String? fromUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.userInfo.isNotEmpty) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == scheme) {
      // `alanya://sticker/<jeton>` : « sticker » est l'hôte.
      if (uri.host != host || segs.length != 1) return null;
      return _token.hasMatch(segs[0]) ? segs[0] : null;
    }
    if (uri.scheme == 'https') {
      if (uri.host != _webHost || (uri.hasPort && uri.port != 443)) return null;
      if (segs.length != 2 || segs[0] != webSegment) return null;
      return _token.hasMatch(segs[1]) ? segs[1] : null;
    }
    return null;
  }
}
