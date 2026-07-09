/// Réécrit les anciennes URLs HTTPS du backend Talky en HTTP.
///
/// Le serveur ne fait plus de TLS ; les messages déjà en cache SQLite ou
/// renvoyés avec l'ancien schéma peuvent encore porter `https://`.
String? normalizeBackendUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  const legacy = 'https://158.220.107.211';
  const target = 'http://158.220.107.211';
  if (url.startsWith(legacy)) {
    return target + url.substring(legacy.length);
  }
  return url;
}
