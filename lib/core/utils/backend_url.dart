/// Réécrit les anciennes URLs du backend Talky vers le nouveau domaine HTTPS.
///
/// Le backend a migré de `158.220.107.211` (HTTP, ex self-signed HTTPS) vers
/// `https://www.alanya237.com`. Les médias déjà en cache SQLite ou renvoyés
/// avec l'ancien hôte (http ou https) doivent être réécrits pour rester
/// accessibles après la migration.
String? normalizeBackendUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  const target = 'https://www.alanya237.com';
  const legacyHosts = ['https://158.220.107.211', 'http://158.220.107.211'];
  for (final legacy in legacyHosts) {
    if (url.startsWith(legacy)) {
      return target + url.substring(legacy.length);
    }
  }
  return url;
}
