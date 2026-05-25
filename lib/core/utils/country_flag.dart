import '../../talky_models.dart' show Pays;

/// Correspondance pays → emoji drapeau, sans modification de la base.
/// Le matching se fait d'abord par nom (libellé tel qu'en base), puis par
/// idPays en repli. Si le pays est inconnu, on renvoie une chaîne vide et
/// l'appelant affiche simplement le nom du pays.
class CountryFlags {
  CountryFlags._();

  /// Codes ISO-3166 alpha-2 par nom de pays (libellé normalisé : minuscule,
  /// sans accent). Source : table `pays` de la base Alanya.
  static const Map<String, String> _iso2ByName = {
    'france': 'FR',
    'united states': 'US',
    'united kingdom': 'GB',
    'germany': 'DE',
    'spain': 'ES',
    'italy': 'IT',
    'belgium': 'BE',
    'switzerland': 'CH',
    'canada': 'CA',
    'cameroon': 'CM',
    'congo': 'CD',
    'gabon': 'GA',
    "cote d'ivoire": 'CI',
    'senegal': 'SN',
    'mali': 'ML',
    'burkina faso': 'BF',
    'niger': 'NE',
    'chad': 'TD',
    'central african republic': 'CF',
    'equatorial guinea': 'GQ',
    'china': 'CN',
    'japan': 'JP',
    'india': 'IN',
    'brazil': 'BR',
    'argentina': 'AR',
    'mexico': 'MX',
    'australia': 'AU',
    'russia': 'RU',
    'south africa': 'ZA',
    'nigeria': 'NG',
  };

  /// Repli par identifiant (au cas où le libellé diffère).
  static const Map<int, String> _iso2ById = {
    1: 'FR', 2: 'US', 3: 'GB', 4: 'DE', 5: 'ES', 6: 'IT', 7: 'BE', 8: 'CH',
    9: 'CA', 10: 'CM', 11: 'CD', 12: 'GA', 13: 'CI', 14: 'SN', 15: 'ML',
    16: 'BF', 17: 'NE', 18: 'TD', 19: 'CF', 20: 'GQ', 21: 'CN', 22: 'JP',
    23: 'IN', 24: 'BR', 25: 'AR', 26: 'MX', 27: 'AU', 28: 'RU', 29: 'ZA',
    30: 'NG',
  };

  /// Code ISO-3166 alpha-2 d'un pays, ou null si inconnu.
  static String? iso2For(Pays pays) {
    return _iso2ByName[_normalize(pays.libelle)] ?? _iso2ById[pays.idPays];
  }

  /// Emoji drapeau d'un pays ('' si inconnu — l'appelant affiche le nom seul).
  static String flagFor(Pays pays) => countryFlagEmoji(iso2For(pays));

  /// Normalise un libellé : minuscule, accents retirés, espaces compactés.
  static String _normalize(String s) {
    var out = s.toLowerCase().trim();
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ì': 'i',
      'ô': 'o', 'ö': 'o', 'ò': 'o', 'õ': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((k, v) => out = out.replaceAll(k, v));
    return out.split(' ').where((w) => w.isNotEmpty).join(' ');
  }
}

/// Convertit un code ISO-3166 alpha-2 (ex. 'FR') en emoji drapeau (ex. '🇫🇷').
/// Renvoie '' si le code est invalide.
String countryFlagEmoji(String? iso2) {
  if (iso2 == null) return '';
  final code = iso2.trim().toUpperCase();
  if (code.length != 2) return '';
  final a = code.codeUnitAt(0);
  final b = code.codeUnitAt(1);
  const upperA = 0x41, upperZ = 0x5A;
  if (a < upperA || a > upperZ || b < upperA || b > upperZ) return '';
  const base = 0x1F1E6; // 🇦 (regional indicator A)
  return String.fromCharCode(base + (a - upperA)) +
      String.fromCharCode(base + (b - upperA));
}
