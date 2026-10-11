/// Noms personnalisés de mes contacts préférés, en mémoire.
///
/// Le nom choisi vit dans le cache local (`local_users.preferred_name`), mais
/// certains affichages — le titre d'une discussion — partent d'un participant
/// venu du serveur, qui ne porte pas MA relation. Ce registre leur donne la
/// réponse sans requête : le cache le remplit à chaque lecture ou
/// synchronisation des contacts préférés.
class ContactAliases {
  ContactAliases._();

  static final Map<int, String> _names = {};

  /// Nom personnalisé de [alanyaID], ou null s'il n'en a pas.
  static String? of(int alanyaID) => _names[alanyaID];

  static void set(int alanyaID, String? name) {
    final clean = (name ?? '').trim();
    if (clean.isEmpty) {
      _names.remove(alanyaID);
    } else {
      _names[alanyaID] = clean;
    }
  }

  static void replaceAll(Map<int, String?> names) {
    _names.clear();
    names.forEach(set);
  }
}
