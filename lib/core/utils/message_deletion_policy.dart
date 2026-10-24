import '../../talky_models.dart' show GroupRole;

/// Suppression d'un message POUR TOUS : ce que l'interface PROPOSE.
///
/// Miroir de `utils/messageDeletion.js` côté serveur, et **le serveur tranche** :
/// ce code ne sert qu'à ne pas montrer une option qui échouerait. Les deux
/// implémentations lisent la même table de cas
/// (`test/fixtures/message_deletion_cases.json`, copie de
/// `src/testUtils/messageDeletionCases.json` du backend) : si elles s'écartent,
/// un test tombe.
///
/// Règles :
///  - **72 heures** après l'envoi, plus de suppression pour tous (expéditeur
///    comme administrateur) ;
///  - l'expéditeur supprime son message ; dans un **groupe**, un administrateur
///    supprime le message d'un membre, le propriétaire celui d'un membre ou d'un
///    administrateur ;
///  - jamais dans une conversation à deux, jamais sur un message système (6), de
///    bienvenue (8) ou une carte de trajet (9) par un tiers.
const Duration kDeleteForAllWindow = Duration(hours: 72);

/// Types qu'un administrateur ne retire pas (système, bienvenue, trajet).
const List<int> kUnmoderableMessageTypes = [6, 8, 9];

/// La fenêtre de 72 h est-elle encore ouverte ?
///
/// L'horloge du téléphone peut être fausse : ce n'est qu'un guide pour l'affichage.
/// Le serveur compte depuis son propre `sendAt`.
bool isInDeleteWindow(DateTime sendAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).toUtc().difference(sendAt.toUtc());
  return age <= kDeleteForAllWindow;
}

/// Faut-il proposer « Supprimer pour tous » pour ce message ?
///
/// [myRole] et [senderRole] sont des `GroupRole` (`null` pour [senderRole] : le
/// rôle de l'auteur est inconnu ou il a quitté le groupe, ce qui compte comme un
/// membre, comme côté serveur). Dans une conversation à deux, passer
/// `isGroup: false`.
bool canDeleteForAll({
  required int senderID,
  required DateTime sendAt,
  required int type,
  required bool isDeleted,
  required int myId,
  required bool isGroup,
  required int myRole,
  int? senderRole,
  DateTime? now,
}) {
  final mine = senderID == myId;
  if (!mine) {
    final moderates = isGroup &&
        myRole >= GroupRole.admin &&
        myRole > (senderRole ?? GroupRole.member) &&
        !kUnmoderableMessageTypes.contains(type);
    if (!moderates) return false;
  }
  // Déjà supprimé pour tous : idempotent côté serveur, mais rien à proposer.
  if (isDeleted) return false;
  return isInDeleteWindow(sendAt, now: now);
}
