import '../../../talky_api_client.dart' show TalkyApiClient;

/// Garde de confiance des URLs de fichiers stickers.
///
/// Le serveur est la source des URLs (catalogue, fiches packs, messages),
/// mais un message de type 10 stocké AVANT la normalisation serveur (ou
/// écrit par un type fractionnaire contournant les contrôles de l'ancien
/// serveur) peut porter une `mediaUrl` arbitraire. On ne laisse JAMAIS
/// l'appareil aller chercher un fichier sticker ailleurs que chez Alanya :
/// sinon, une ligne malveillante ferait télécharger n'importe quel hôte
/// (`http://169.254.169.254/…`, site tiers…) et laisserait des empreintes
/// réseau chez des tiers.
///
/// Deux conditions, toutes deux nécessaires :
///  - hôte : celui du backend configuré (production comme développement) ou
///    un bucket d'objets public d'Alanya (B2 `*.backblazeb2.com`, R2
///    `*.r2.dev`) ;
///  - chemin : l'un des deux préfixes de clé du serveur
///    (`official/stickers/` pour le catalogue, `stickers/u/` pour un pack
///    perso — cf. `stickerAsset.js`), présents dans l'URL du bucket comme
///    dans le repli `BASE_URL/uploads/<clé>`.
///
/// Ce n'est pas un contrôle de sécurité au sens serveur — c'est une
/// posture client : hors de ces hôtes et chemins, on affiche le repli
/// « Sticker » sans télécharger ni partager.
abstract final class StickerTrust {
  /// Hôte canonique du backend : les médias (dont le repli
  /// `BASE_URL/uploads/…`) sont servis sur la même origine.
  static const String canonicalHost = 'www.alanya237.com';

  /// `true` si [url] est une URL de fichier sticker que l'application peut
  /// charger (et partager).
  ///
  /// `http` n'est accepté que pour un hôte de confiance : le développement
  /// sert le backend en HTTP (IP LAN, localhost). Rien d'autre.
  static bool isTrustedStickerUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    // `user:pass@` devant l'hôte : interdit, y compris quand l'hôte finit par
    // un nom de confiance (`evil@www.alanya237.com`).
    if (uri.userInfo.isNotEmpty) return false;
    if (!_trustedHost(uri.host)) return false;
    return _hasStickerPath(uri.path);
  }

  static bool _trustedHost(String rawHost) {
    final host = rawHost.toLowerCase();
    if (host == canonicalHost) return true;
    // L'hôte du client API configuré : la production (www.alanya237.com) comme
    // la machine de développement (IP LAN, localhost). Même origine que les
    // URLs que le serveur génère.
    final apiHost = Uri.tryParse(TalkyApiClient.baseUrl)?.host.toLowerCase();
    if (apiHost != null && apiHost.isNotEmpty && host == apiHost) return true;
    // Buckets d'objets publics d'Alanya : B2 (`<bucket>.s3.<région>.backblazeb2.com`)
    // et R2 (`*.r2.dev`).
    return host.endsWith('.backblazeb2.com') || host.endsWith('.r2.dev');
  }

  /// Les deux préfixes de clé du serveur (`stickerAsset.js`), retracés dans
  /// le chemin de l'URL — en bucket public comme dans `/uploads/<clé>`.
  static bool _hasStickerPath(String path) =>
      path.contains('official/stickers/') || path.contains('stickers/u/');
}