import '../../config/legal_urls.dart';

/// Lien d'invitation de groupe : lecture et fabrication.
///
/// Le jeton du contrat serveur : 16 caractères `[A-Za-z0-9_-]` (96 bits).
///
/// Formes reconnues (et seulement elles) :
/// - `https://www.alanya237.com/g/<jeton>` (App Link, hôte de
///   [LegalUrls.baseHost]) : ni autre hôte, ni identifiants (`user@`), ni port ;
/// - `alanya://group/<jeton>` (schéma applicatif, bouton de la page web).
abstract final class GroupInviteLink {
  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]{16}$');
  static final RegExp _url = RegExp(r'(?:alanya|https?)://\S+', caseSensitive: false);
  static final RegExp _trailing = RegExp(r'''[.,;:!?)\]}>"'»”’]+$''');

  static const String scheme = 'alanya';
  static const String host = 'group';

  /// Premier segment du chemin web : `https://<hôte>/g/<jeton>`.
  static const String webSegment = 'g';

  static final String _webHost = Uri.parse(LegalUrls.baseHost).host;

  static bool isToken(String s) => _token.hasMatch(s);

  /// Jeton d'un lien reçu (plate-forme, texte d'un message), ou `null`.
  static String? fromUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.userInfo.isNotEmpty) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == scheme) {
      if (uri.host != host || segs.length != 1) return null;
      return _token.hasMatch(segs[0]) ? segs[0] : null;
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (uri.host != _webHost || (uri.hasPort && uri.port != 443 && uri.port != 80)) {
        return null;
      }
      if (segs.length != 2 || segs[0] != webSegment) return null;
      return _token.hasMatch(segs[1]) ? segs[1] : null;
    }
    return null;
  }

  /// Premier lien d'invitation trouvé dans [text], ou `null`.
  static String? parse(String? text) {
    if (text == null) return null;
    final raw = text.trim();
    if (raw.isEmpty) return null;
    for (final m in _url.allMatches(raw)) {
      final url = m.group(0)!.replaceFirst(_trailing, '');
      final t = fromUri(Uri.tryParse(url));
      if (t != null) return t;
    }
    return null;
  }
}
