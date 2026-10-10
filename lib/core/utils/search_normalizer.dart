/// Normalisation du texte pour la recherche de messages.
///
/// Fonction pure, sans dépendance : « reunion » doit trouver « Réunion » sans
/// que la base locale stocke une colonne normalisée (ce qui coûterait une
/// migration). La correspondance se fait donc en Dart, sur du texte normalisé
/// à la volée.
library;

/// Texte normalisé + correspondance de chaque position vers le texte d'origine.
///
/// La table existe parce que la normalisation peut allonger le texte
/// (`œ → oe`) : une position trouvée dans [texte] ne vaut pas la même position
/// dans la source. Le surlignage s'en sert pour découper le texte affiché.
class TexteNormalise {
  final String texte;

  /// `origine[i]` = index, dans le texte source, du caractère normalisé `i`.
  final List<int> origine;

  const TexteNormalise(this.texte, this.origine);
}

/// Lettre normalisée → lettres d'origine qu'elle remplace (minuscules et
/// capitales). Écrite à la main plutôt qu'avec une décomposition Unicode, qui
/// demanderait une dépendance.
const Map<String, String> _accents = {
  'a': 'àáâäãåÀÁÂÄÃÅ',
  'c': 'çÇ',
  'e': 'èéêëÈÉÊË',
  'i': 'ìíîïÌÍÎÏ',
  'n': 'ñÑ',
  'o': 'òóôöõÒÓÔÖÕ',
  'u': 'ùúûüÙÚÛÜ',
  'y': 'ýÿÝŸ',
};

/// Caractère → remplacement. Les ligatures produisent deux caractères.
final Map<String, String> _remplacements = _construireRemplacements();

Map<String, String> _construireRemplacements() {
  final table = <String, String>{
    'œ': 'oe',
    'Œ': 'oe',
    'æ': 'ae',
    'Æ': 'ae',
    // Apostrophe typographique et accent aigu isolé : le clavier mobile
    // produit l'une ou l'autre selon la langue, l'utilisateur tape toujours '.
    '’': "'",
    '´': "'",
    // Espace insécable et fine insécable (typographie française avant « : »).
    ' ': ' ',
    ' ': ' ',
  };
  _accents.forEach((base, variantes) {
    for (final c in variantes.split('')) {
      table[c] = base;
    }
  });
  return table;
}

TexteNormalise normaliserPourRecherche(String source) {
  final sortie = StringBuffer();
  final origine = <int>[];
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    final r = _remplacements[c] ?? c.toLowerCase();
    sortie.write(r);
    // `toLowerCase` peut en théorie changer la longueur (ex. « İ ») : on
    // aligne sur la longueur réellement écrite pour que `origine` reste
    // de même taille que `texte`.
    for (var k = 0; k < r.length; k++) {
      origine.add(i);
    }
  }
  return TexteNormalise(sortie.toString(), origine);
}
