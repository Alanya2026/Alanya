import 'package:flutter/foundation.dart';

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

  /// Incrémenté à chaque changement réel : les écrans qui affichent un nom
  /// de discussion s'y abonnent pour se redessiner.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Nom personnalisé de [alanyaID], ou null s'il n'en a pas.
  static String? of(int alanyaID) => _names[alanyaID];

  static void set(int alanyaID, String? name) {
    final clean = (name ?? '').trim();
    if ((_names[alanyaID] ?? '') == clean) return;
    if (clean.isEmpty) {
      _names.remove(alanyaID);
    } else {
      _names[alanyaID] = clean;
    }
    revision.value++;
  }

  static void replaceAll(Map<int, String?> names) {
    final next = <int, String>{};
    names.forEach((id, name) {
      final clean = (name ?? '').trim();
      if (clean.isNotEmpty) next[id] = clean;
    });
    if (mapEquals(next, _names)) return;
    _names
      ..clear()
      ..addAll(next);
    revision.value++;
  }
}
