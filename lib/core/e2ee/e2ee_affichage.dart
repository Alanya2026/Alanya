import '../../l10n/app_localizations.dart';

/// Préfixe du libellé rangé à la place d'un message chiffré que cet appareil
/// n'a pas (encore) déchiffré.
///
/// Un caractère invisible (U+2063, séparateur invisible) : il ne se tape pas,
/// et il permet de distinguer le libellé d'un vrai texte sans changer le
/// schéma de la base locale. Le libellé lui-même est lisible et localisé : la
/// bulle, l'aperçu de la liste et la recherche l'affichent tel quel.
const String kE2eePrefixeAttente = '⁣';

/// Libellé « en attente » à ranger dans `content`.
String e2eeLibelleAttente(AppLocalizations l10n) =>
    '$kE2eePrefixeAttente${l10n.e2eeMessageEnAttente}';

/// Ce contenu est-il un VRAI texte (et non vide, ni le libellé d'attente) ?
///
/// C'est la question que se pose le dépôt avant d'écraser une ligne : un texte
/// déchiffré n'existe que sur cet appareil, il ne doit jamais être remplacé
/// par le `null` du serveur ni par le libellé (docs/e2ee, chapitre 17).
bool e2eeEstTexteReel(String? contenu) =>
    contenu != null && contenu.isNotEmpty && !contenu.startsWith(kE2eePrefixeAttente);

/// La ligne du serveur décrit-elle un message chiffré ?
bool e2eeEstChiffre(Map<String, dynamic> json) {
  final v = json['enc_version'] ?? json['encVersion'];
  return v == 1 || v == '1';
}

/// Aperçu générique posé par le serveur pour un message chiffré
/// (`messagePreview`, backend). Le serveur n'écrit que du français : on le
/// remplace par le libellé localisé.
const String kE2eeApercuServeur = '🔒 Message chiffré';
