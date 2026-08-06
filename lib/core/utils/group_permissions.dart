/// Gating des actions de groupe — **rôles, verrous et tri d'affichage**.
///
/// RÈGLE CARDINALE : ces fonctions ne font que **masquer des boutons**.
/// L'autorité, elle, reste **le serveur** (`src/middleware/groupAuth.js` et
/// `src/utils/groupSendPolicy.js`) : un client modifié qui appellerait quand
/// même l'endpoint se fait rejeter (403 `GROUP_ADMIN_REQUIRED`,
/// `GROUP_OWNER_REQUIRED`, `GROUP_INFO_LOCKED`, `GROUP_ADMINS_ONLY`).
/// Ce fichier n'est donc pas un contrôle d'accès, c'est une politesse d'UI :
/// on n'offre pas un bouton dont on sait qu'il échouera.
///
/// Corollaire pratique : l'UI n'écrit **jamais** `if (myRole >= 1)` en dur,
/// elle appelle ces fonctions. Le gating devient testable sans widget, et une
/// règle produit qui change se corrige à un seul endroit.
///
/// Le rôle vient de `conv_participants.role` (voir [GroupRole]) : il arrive du
/// serveur dans `participants[]` et dans `Conversation.myRole`, et survit hors
/// ligne dans le cache Drift.
library;

import '../../talky_models.dart';

/// Plancher défensif : un rôle strictement négatif n'est pas « simple membre »,
/// c'est une valeur qu'aucun producteur n'émet — donc une donnée corrompue.
/// On préfère masquer que d'offrir une action qui partira en 404.
///
/// À ne **pas** confondre avec « je ne suis plus membre » : tous les producteurs
/// se replient sur [GroupRole.member], jamais sur une valeur négative
/// (`Conversation.myRole` par défaut, `Conversation.fromJson`,
/// `Conversation.roleOf` quand je ne suis plus dans `participants[]`, et la
/// colonne Drift `myRole` avec son `withDefault(0)`). Une exclusion ne se voit
/// donc jamais ici, et ce garde-fou ne remplace pas le vrai mécanisme :
/// `group:participant:removed` → `deleteConversation` → `watchConversation`
/// émet `null` → `pop` (plan §3.4 et §6.9).
bool _isMember(int role) => role >= GroupRole.member;

// ── Infos du groupe ──────────────────────────────────────────────────

/// Modifier le nom, la photo ou la description du groupe.
///
/// Ouvert à **tous les membres** par défaut ; réservé aux administrateurs dès
/// que le verrou [onlyAdminsCanEditInfo] est posé (le serveur répond alors
/// 403 `GROUP_INFO_LOCKED`).
bool canEditInfo(int myRole, bool onlyAdminsCanEditInfo) {
  if (!_isMember(myRole)) return false;
  return !onlyAdminsCanEditInfo || myRole >= GroupRole.admin;
}

/// Ajouter des participants.
///
/// Verrou indépendant de [canEditInfo] : un admin peut laisser tout le monde
/// inviter tout en réservant le renommage, et inversement. Le serveur répond
/// 403 `GROUP_ADD_MEMBERS_LOCKED` si le verrou est actif.
bool canAddParticipants(int myRole, bool onlyAdminsCanAddMembers) {
  if (!_isMember(myRole)) return false;
  return !onlyAdminsCanAddMembers || myRole >= GroupRole.admin;
}

/// Basculer les verrous du groupe (mode annonce, édition réservée).
///
/// Administrateur ou propriétaire — c'est `requireGroupAdmin` côté serveur.
bool canChangeSettings(int myRole) => myRole >= GroupRole.admin;

// ── Gestion des membres ──────────────────────────────────────────────

/// Retirer un membre du groupe.
///
/// [targetRole] est le rôle de la personne visée, [isSelf] indique que c'est
/// moi-même.
bool canRemove(int myRole, int targetRole, {required bool isSelf}) {
  // Se retirer soi-même n'est pas un retrait mais « quitter le groupe » :
  // autre geste, autre endpoint (`POST /:id/leave`), et une succession à
  // organiser si je suis propriétaire. Voir [canLeave].
  //
  // Ce test n'est pas redondant avec `targetRole < myRole` : l'appelant lit
  // [myRole] sur la conversation et [targetRole] sur `participants[]`, deux
  // champs que `conversation:updated` ne rafraîchit **pas** ensemble (la trame
  // omet volontairement les champs par-utilisateur, §2.9). Juste après ma
  // rétrogradation, ma propre ligne vaut donc (myRole=2, targetRole=0) et
  // proposerait « Retirer » sur moi-même.
  if (isSelf) return false;
  if (myRole < GroupRole.admin) return false;
  // Cible dont le rôle est illisible : il n'y a rien à retirer. Même plancher
  // que pour le mien — sans lui, `targetRole < myRole` la rendrait expulsable.
  if (!_isMember(targetRole)) return false;
  // Le propriétaire est inexpulsable, quel que soit le rôle du demandeur.
  // Tant que 2 est le rôle maximum, `targetRole < myRole` couvre déjà le cas
  // (y compris deux propriétaires : 2 < 2 est faux). Ce garde-fou ne mord donc
  // que pour un rôle **supérieur** au propriétaire — valeur écrite par une
  // version ultérieure de l'app, ou donnée corrompue. C'est exactement le cas
  // où le groupe deviendrait décapitable.
  if (targetRole >= GroupRole.owner) return false;
  // Jamais un rôle supérieur **ou égal** au sien : sans le « égal », deux
  // administrateurs pourraient s'exclure mutuellement, et le premier à cliquer
  // gagnerait le groupe.
  return targetRole < myRole;
}

/// Promouvoir un membre administrateur, ou lui retirer ses droits.
///
/// **Propriétaire uniquement** : un admin ne crée pas d'admin, sinon le rôle se
/// propage sans que le propriétaire puisse l'endiguer.
///
/// Jamais sur soi-même non plus : le propriétaire se rétrograderait et le
/// groupe se retrouverait sans propriétaire — donc définitivement ingérable,
/// le transfert explicite de propriété étant hors périmètre v1.
bool canChangeRole(int myRole, {required bool isSelf}) {
  if (isSelf) return false;
  return myRole >= GroupRole.owner;
}

/// Y a-t-il **au moins une** action de gestion à proposer sur ce membre ?
///
/// Sert à masquer entièrement le menu contextuel d'une ligne de la liste des
/// membres, plutôt que d'ouvrir un menu vide (ou réduit au seul « voir le
/// profil », que l'appelant ajoute de son côté).
bool canManageMember(int myRole, int targetRole, {required bool isSelf}) =>
    canRemove(myRole, targetRole, isSelf: isSelf) ||
    canChangeRole(myRole, isSelf: isSelf);

/// Quitter le groupe de son plein gré.
///
/// Ouvert à tous, **propriétaire compris** : la succession est automatique côté
/// serveur (l'admin le plus ancien, à défaut le membre le plus ancien). Ne
/// jamais bloquer le propriétaire ici — il serait prisonnier de son groupe.
bool canLeave(int myRole) => _isMember(myRole);

// ── Envoi de messages ────────────────────────────────────────────────

/// Écrire dans la conversation.
///
/// Mode annonce ([onlyAdminsCanSend]) : seuls les administrateurs et le
/// propriétaire peuvent envoyer. Le composeur affiche sinon un bandeau, mais
/// c'est bien le serveur qui rejette (`GROUP_ADMINS_ONLY`), y compris un
/// message parti de l'outbox avant l'activation du verrou.
bool canSend(int myRole, bool onlyAdminsCanSend) {
  if (!_isMember(myRole)) return false;
  return !onlyAdminsCanSend || myRole >= GroupRole.admin;
}

// ── Tri d'affichage ──────────────────────────────────────────────────

/// Trie les membres pour l'affichage : **propriétaire, puis administrateurs,
/// puis membres**, et à rôle égal par nom.
///
/// Générique et non mutante à dessein : la fiche groupe lit tantôt des
/// [Participant] (réponse HTTP), tantôt les `Map` brutes du cache Drift
/// (`decodeParticipants`), et la liste source peut être non modifiable.
///
/// [idOf] n'est là que pour départager deux homonymes de même rôle :
/// `List.sort` n'est pas stable en Dart, l'ordre sauterait d'une reconstruction
/// à l'autre sans ce dernier critère.
List<T> sortMembersForDisplay<T>(
  Iterable<T> members, {
  required int Function(T) roleOf,
  required String Function(T) nameOf,
  int Function(T)? idOf,
}) {
  final sorted = members.toList();
  sorted.sort((a, b) {
    final byRole = roleOf(b).compareTo(roleOf(a)); // rôle décroissant
    if (byRole != 0) return byRole;
    final byName = _foldForSort(nameOf(a)).compareTo(_foldForSort(nameOf(b)));
    if (byName != 0) return byName;
    if (idOf == null) return 0;
    return idOf(a).compareTo(idOf(b));
  });
  return sorted;
}

/// Variante typée de [sortMembersForDisplay] pour la liste des participants.
List<Participant> sortParticipantsForDisplay(Iterable<Participant> members) =>
    sortMembersForDisplay<Participant>(
      members,
      roleOf: (p) => p.role,
      nameOf: (p) => p.nom,
      idOf: (p) => p.alanyaID,
    );

/// Replie casse et accents avant comparaison.
///
/// Sans ce repli, « Élise » (U+00E9…) se retrouverait **après** « Zoé » dans un
/// tri par code d'unité : inacceptable dans une app francophone.
String _foldForSort(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentFolding[ch] ?? ch);
  }
  return buffer.toString();
}

const Map<String, String> _accentFolding = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'œ': 'oe',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'š': 's', 'ž': 'z',
};
