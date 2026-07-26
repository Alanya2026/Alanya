// mention_parser.dart — analyse des mentions `@` dans le texte d'un message.
//
// Utilitaire *pur* : ni widget, ni BuildContext, ni réseau, ni base. C'est le
// seam testable de la fonctionnalité (plan docs/groupes-plan.md §3.5) ;
// l'overlay de saisie (§4.5) et le surlignage des bulles (§4.4) ne font
// qu'appeler ces deux fonctions.
//
// La liste *faisant autorité* des mentions reste la colonne serveur
// `message.mentions` : ce fichier ne sert qu'à l'assistance de frappe et au
// rendu. Une divergence n'a donc jamais d'effet sur les notifications.

import '../../talky_models.dart';

/// Code de `@`, seul déclencheur reconnu.
const int _kAt = 0x40;

/// Longueur maximale d'une requête de mention en cours de frappe.
///
/// Sans borne, un `@` isolé laisserait l'overlay ouvert jusqu'à la fin du
/// message : les noms contenant des espaces (§4.5), on ne peut pas simplement
/// s'arrêter au premier blanc rencontré.
const int kMaxMentionQueryLength = 48;

/// Nombre maximal d'espaces **internes** à une requête.
///
/// « Marie Claire De Boissieu » = 3 espaces ; au-delà, l'utilisateur écrit une
/// phrase, pas un nom.
const int kMaxMentionQuerySpaces = 3;

/// Requête de mention en cours de frappe, ou `null` s'il n'y en a pas.
///
/// [caret] est la position du curseur dans [text] (`selection.baseOffset`).
/// Un curseur hors bornes — ce que renvoie un `TextEditingController` non
/// focalisé (`-1`) — donne `null`, jamais une exception.
///
/// Renvoie une chaîne **vide** quand le curseur suit immédiatement un `@`
/// valide : c'est un cas nominal, l'overlay s'ouvre et montre tout le monde.
///
/// La signature ne rend que la requête, pas sa plage : l'appelant qui doit
/// remplacer le texte la reconstruit sans ambiguïté par
/// `start = caret - query.length - 1`.
String? extractMentionQuery(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;

  // Le `@` ne peut pas être plus loin en arrière que la requête maximale.
  final lowerBound = caret - kMaxMentionQueryLength - 1;
  var spaces = 0;

  for (var i = caret - 1; i >= 0 && i >= lowerBound; i--) {
    final cu = text.codeUnitAt(i);

    if (cu == _kAt) {
      // Un `@` collé à un caractère précédent n'ouvre pas de mention : c'est ce
      // qui écarte d'un seul test « a@b.com » et « https://x.com/@lea ».
      if (i > 0 && !_opensMention(text.codeUnitAt(i - 1))) return null;
      // Un espace juste après le `@` signe l'abandon de la mention ; les
      // espaces internes, eux, sont légitimes (« @Jean Dupont »).
      if (i + 1 < caret && _isBlank(text.codeUnitAt(i + 1))) return null;
      return text.substring(i + 1, caret);
    }

    // Une requête ne franchit pas une fin de ligne.
    if (_isLineBreak(cu)) return null;

    if (_isBlank(cu)) {
      spaces++;
      if (spaces > kMaxMentionQuerySpaces) return null;
    }
  }
  return null;
}

/// Une mention effectivement présente dans le texte d'un message.
class MentionMatch {
  /// Position du `@` dans le texte source.
  final int start;

  /// Position **exclusive** de fin : `text.substring(start, end)` rend
  /// `'@Jean Dupont'`, `'@'` compris.
  final int end;

  /// Identifiant du membre mentionné, `null` pour `@Tous`.
  final int? userId;

  /// `true` pour le libellé spécial `@Tous` / `@All`, qui n'est pas un membre.
  final bool isAll;

  /// Libellé canonique (le nom tel que le groupe le connaît), sans le `@`.
  /// Il peut différer du texte source, qui a pu être frappé sans accents.
  final String name;

  const MentionMatch({
    required this.start,
    required this.end,
    required this.name,
    this.userId,
    this.isAll = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MentionMatch &&
      other.start == start &&
      other.end == end &&
      other.userId == userId &&
      other.isAll == isAll &&
      other.name == name;

  @override
  int get hashCode => Object.hash(start, end, userId, isAll, name);

  @override
  String toString() =>
      'MentionMatch($start..$end, ${isAll ? '@tous' : 'user $userId'}, "$name")';
}

/// Mentions présentes dans le texte final, résolues contre [members].
///
/// [allLabelFr] et [allLabelEn] sont les **deux** libellés de `@Tous`, passés
/// en paramètre plutôt que lus depuis `l10n` pour deux raisons :
///
/// 1. un utilitaire pur ne dépend pas du contexte de localisation ;
/// 2. surtout, le libellé est stocké **tel quel** dans le texte du message
///    (§4.8) : un message écrit en français (`@Tous`) puis lu par un client
///    anglais doit rester surligné. Reconnaître le seul libellé de la locale
///    courante ferait disparaître la mention au passage d'une frontière.
///
/// Les deux libellés sont acceptés avec ou sans leur `@` de tête (la clé ARB
/// `mentionAll` vaut `@Tous`, le `@` inclus).
///
/// Un membre **parti du groupe** n'est simplement plus dans [members] : son nom
/// reste dans le texte mais ne produit aucune correspondance — pas d'erreur, le
/// rendu le laissera non tappable (§6.6).
List<MentionMatch> resolveMentions(
  String text,
  List<Participant> members, {
  String? allLabelFr,
  String? allLabelEn,
}) {
  if (text.isEmpty) return const [];

  final candidates = <_MentionCandidate>[];

  // `@Tous` d'abord : à longueur égale avec un membre homonyme, le libellé
  // spécial l'emporte.
  for (final label in [allLabelFr, allLabelEn]) {
    final name = _stripLeadingAt(label?.trim() ?? '');
    if (name.isEmpty) continue;
    candidates.add(_MentionCandidate(
      name: name,
      folded: foldForMention(name),
      order: candidates.length,
      isAll: true,
    ));
  }
  for (final member in members) {
    final name = member.nom.trim();
    if (name.isEmpty) continue;
    candidates.add(_MentionCandidate(
      name: name,
      folded: foldForMention(name),
      order: candidates.length,
      userId: member.alanyaID,
    ));
  }
  if (candidates.isEmpty) return const [];

  // Correspondance la plus longue d'abord : sans ce tri, un membre « Jean »
  // masquerait « Jean Dupont » et la mention serait tronquée à l'envoi comme au
  // rendu. `order` départage les ex æquo pour un résultat déterministe (le tri
  // de Dart n'est pas stable).
  candidates.sort((a, b) {
    final byLength = b.folded.length.compareTo(a.folded.length);
    return byLength != 0 ? byLength : a.order.compareTo(b.order);
  });

  final folded = foldForMention(text);
  assert(folded.length == text.length,
      'Le repli doit rester 1:1 pour que les index restent comparables');

  final matches = <MentionMatch>[];
  var cursor = 0;
  while (cursor < text.length) {
    final at = text.indexOf('@', cursor);
    if (at < 0) break;

    if (at > 0 && !_opensMention(text.codeUnitAt(at - 1))) {
      cursor = at + 1;
      continue;
    }

    _MentionCandidate? hit;
    for (final candidate in candidates) {
      final end = at + 1 + candidate.folded.length;
      if (end > folded.length) continue;
      if (!folded.startsWith(candidate.folded, at + 1)) continue;
      // Frontière de fin : « @Jean » ne doit pas se déclencher au milieu de
      // « @Jeanne ».
      if (end < folded.length && _isWordChar(folded.codeUnitAt(end))) continue;
      hit = candidate;
      break;
    }

    if (hit == null) {
      cursor = at + 1;
      continue;
    }

    final end = at + 1 + hit.folded.length;
    matches.add(MentionMatch(
      start: at,
      end: end,
      name: hit.name,
      userId: hit.userId,
      isAll: hit.isAll,
    ));
    cursor = end;
  }
  return matches;
}

/// Minuscules + repli des diacritiques latins courants, **sans changer la
/// longueur** de la chaîne.
///
/// Cet invariant 1:1 est porteur : il permet de comparer le texte replié et de
/// réutiliser les index obtenus tels quels sur le texte source, donc de
/// surligner la plage exacte que l'utilisateur a écrite.
///
/// Table écrite à la main plutôt qu'une dépendance (`diacritic`, `unorm`) : on
/// n'a besoin que du latin des noms francophones, la table tient en huit
/// lignes, elle garantit le 1:1 (une décomposition NFD, elle, *allonge* la
/// chaîne et casserait les index) et elle évite d'ajouter un paquet transitif à
/// une application déjà lourde en dépendances natives.
String foldForMention(String input) {
  if (input.isEmpty) return input;
  final out = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final cu = input.codeUnitAt(i);

    // Chemin rapide ASCII, de loin le plus fréquent : pas d'allocation.
    if (cu < 128) {
      out.writeCharCode(cu >= 0x41 && cu <= 0x5A ? cu + 32 : cu);
      continue;
    }

    final folded = _diacriticFolds[cu];
    if (folded != null) {
      out.writeCharCode(folded);
      continue;
    }

    // Hors table (cyrillique, grec…) : minuscule Unicode, mais uniquement si
    // elle tient sur une seule unité de code — sinon l'invariant de longueur
    // sauterait et les index deviendraient faux.
    final lowered = String.fromCharCode(cu).toLowerCase();
    out.write(lowered.length == 1 ? lowered : String.fromCharCode(cu));
  }
  return out.toString();
}

/// Un candidat à la résolution : un membre, ou le libellé `@Tous`.
class _MentionCandidate {
  final String name;
  final String folded;
  final int order;
  final int? userId;
  final bool isAll;

  const _MentionCandidate({
    required this.name,
    required this.folded,
    required this.order,
    this.userId,
    this.isAll = false,
  });
}

/// Clé = caractère de remplacement, valeur = variantes repliées vers lui.
const Map<String, String> _diacriticSources = {
  'a': 'àáâãäåÀÁÂÃÄÅ',
  'e': 'éèêëÉÈÊË',
  'i': 'îïíìÎÏÍÌ',
  'o': 'ôöòóõÔÖÒÓÕ',
  'u': 'ùûüúÙÛÜÚ',
  'c': 'çÇ',
  'n': 'ñÑ',
  'y': 'ÿýŸÝ',
};

/// Table dépliée en unités de code, construite une seule fois.
final Map<int, int> _diacriticFolds = {
  for (final entry in _diacriticSources.entries)
    for (final source in entry.value.codeUnits) source: entry.key.codeUnitAt(0),
};

/// Un `@` n'ouvre une mention qu'en début de texte, après un blanc, ou après
/// une **ponctuation ouvrante**.
///
/// Le cœur de la règle disqualifie d'un coup les adresses e-mail (`a@b.com`,
/// précédé d'une lettre) et les URL (`https://x.com/@lea`, précédé d'une barre
/// oblique) : tout ce qui est collé à un caractère de mot est écarté.
///
/// Les ouvrantes sont admises en plus parce qu'écrire « (@Marc) » ou
/// « "@Léa" » est courant, et qu'aucune d'elles ne réintroduit le faux positif
/// e-mail : une adresse est toujours précédée d'un caractère de mot, jamais
/// d'une parenthèse. Le tiret et le point sont volontairement exclus — ils
/// apparaissent, eux, dans les adresses (`jean-luc@x.fr`, `j.dupont@x.fr`).
bool _opensMention(int codeUnit) =>
    _isBlank(codeUnit) ||
    _isLineBreak(codeUnit) ||
    _kOpeningPunctuation.contains(codeUnit);

/// `(` `[` `{` `«` `"` `'` `’` `“` `‘` — ponctuations ouvrantes usuelles —
/// plus les marqueurs de mise en forme inline `*` `_` `~` `=` `#`.
///
/// Les marqueurs sont indispensables à la COHÉRENCE entre affichage et envoi :
/// `parseRichSpans` les retire avant de résoudre les mentions (il passe
/// « @Marie » au résolveur), alors que le chemin d'envoi travaille sur le texte
/// brut « *@Marie* ». Sans eux, une mention en gras était surlignée et
/// tappable chez l'expéditeur, mais n'était jamais transmise — donc aucune
/// notification pour la personne citée.
///
/// Aucun de ces caractères ne réintroduit le faux positif e-mail : une adresse
/// est toujours précédée d'un caractère de mot.
const Set<int> _kOpeningPunctuation = {
  0x28, 0x5B, 0x7B, 0xAB, 0x22, 0x27, 0x2019, 0x201C, 0x2018,
  0x2A, 0x5F, 0x7E, 0x3D, 0x23,
};

bool _isBlank(int codeUnit) =>
    codeUnit == 0x20 || // espace
    codeUnit == 0x09 || // tabulation
    codeUnit == 0xA0 || // espace insécable
    codeUnit == 0x202F; // espace insécable étroite

bool _isLineBreak(int codeUnit) =>
    codeUnit == 0x0A ||
    codeUnit == 0x0D ||
    codeUnit == 0x2028 ||
    codeUnit == 0x2029;

/// Caractère « de mot » pour la frontière de fin d'une mention.
///
/// Testé sur le texte **replié** : les accents y sont déjà devenus des lettres
/// ASCII. Les caractères non latins restants comptent comme des frontières,
/// choix indulgent — au pire une mention reste résolue.
bool _isWordChar(int codeUnit) =>
    (codeUnit >= 0x61 && codeUnit <= 0x7A) || // a-z (le texte est replié)
    (codeUnit >= 0x30 && codeUnit <= 0x39) || // 0-9
    codeUnit == 0x5F; // _

/// La clé ARB `mentionAll` vaut `@Tous` : le `@` fait partie du libellé, mais
/// la résolution le gère elle-même.
String _stripLeadingAt(String label) =>
    label.startsWith('@') ? label.substring(1).trim() : label;
