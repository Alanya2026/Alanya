/// Nombre de discussions non lues, pour le badge de l'onglet Discussions.
///
/// Le badge additionnait les messages : 246 messages non lus dans un seul
/// groupe affichaient « 246 » pour une seule discussion, là où les
/// utilisateurs attendent le nombre de discussions, comme sur WhatsApp
/// (groupe 3GI 2029, bug A19). Les discussions archivées n'y comptent pas :
/// elles ne sont pas dans la liste principale.
int compterDiscussionsNonLues<T>(
  Iterable<T> conversations, {
  required int Function(T) nonLus,
  required bool Function(T) archivee,
}) =>
    conversations.where((c) => nonLus(c) > 0 && !archivee(c)).length;
