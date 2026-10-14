/// Surlignage du mot recherché dans les spans d'une bulle.
///
/// Fonction pure, appliquée **après** `parseRichSpans` : `_parse` retire les
/// marqueurs `*gras*`, `_italique_` et `~barré~`, donc des positions calculées
/// sur le texte brut seraient fausses dans le texte affiché. On cherche dans
/// le texte réellement affiché, span par span.
library;

import 'package:flutter/painting.dart';

import '../services/chat/message_search.dart' show requeteValide;
import 'search_normalizer.dart';

/// Renvoie [spans] avec chaque occurrence de [requete] mise en forme par
/// [surligne]. Les spans sans occurrence sont renvoyés tels quels (même
/// instance), ce qui évite de reconstruire un arbre inchangé.
///
/// Chaque morceau garde le `recognizer` du span d'origine : un lien ou une
/// mention surlignés restent cliquables. On **réutilise** ces recognizers sans
/// en créer, donc ceux que `_mentionRecognizers` libère restent les seuls.
/// Une occurrence à cheval sur deux spans (deux styles) n'est pas trouvée :
/// compromis accepté, chaque span est cherché séparément.
List<InlineSpan> surlignerSpans(
  List<InlineSpan> spans,
  String requete,
  TextStyle Function(TextStyle) surligne,
) {
  final q = requeteValide(requete);
  if (q == null) return spans;
  return [for (final s in spans) _surlignerSpan(s, q, surligne)];
}

InlineSpan _surlignerSpan(
  InlineSpan span,
  String q,
  TextStyle Function(TextStyle) surligne,
) {
  // WidgetSpan et autres : rien à chercher dedans.
  if (span is! TextSpan) return span;

  final plages = _plages(span.text, q);
  final enfants = span.children;
  final nouveauxEnfants = enfants == null
      ? null
      : [for (final e in enfants) _surlignerSpan(e, q, surligne)];
  // `identical` et non `==` : l'égalité de TextSpan parcourt tout l'arbre.
  final enfantsChanges = enfants != null &&
      [for (var i = 0; i < enfants.length; i++)
        !identical(enfants[i], nouveauxEnfants![i])].contains(true);

  if (plages.isEmpty && !enfantsChanges) return span;

  final texte = span.text;
  if (plages.isEmpty || texte == null) {
    return _copie(span, texte: texte, children: nouveauxEnfants);
  }

  final morceaux = <InlineSpan>[];
  var curseur = 0;
  for (final (debut, fin) in plages) {
    if (debut > curseur) {
      morceaux.add(TextSpan(
        text: texte.substring(curseur, debut),
        recognizer: span.recognizer,
      ));
    }
    morceaux.add(TextSpan(
      text: texte.substring(debut, fin),
      style: surligne(span.style ?? const TextStyle()),
      recognizer: span.recognizer,
    ));
    curseur = fin;
  }
  if (curseur < texte.length) {
    morceaux.add(TextSpan(
      text: texte.substring(curseur),
      recognizer: span.recognizer,
    ));
  }
  // Le style d'origine reste sur le conteneur : les morceaux non surlignés
  // l'héritent, les surlignés le complètent.
  return _copie(span,
      texte: null, children: [...morceaux, ...?nouveauxEnfants]);
}

TextSpan _copie(TextSpan s, {String? texte, List<InlineSpan>? children}) =>
    TextSpan(
      text: texte,
      children: children,
      style: s.style,
      recognizer: s.recognizer,
      mouseCursor: s.mouseCursor,
      onEnter: s.onEnter,
      onExit: s.onExit,
      semanticsLabel: s.semanticsLabel,
      locale: s.locale,
      spellOut: s.spellOut,
    );

/// Plages `[début, fin)` du texte d'origine qui contiennent [q] (déjà
/// normalisée), sans chevauchement.
List<(int, int)> _plages(String? texte, String q) {
  if (texte == null || texte.isEmpty) return const [];
  final n = normaliserPourRecherche(texte);
  final plages = <(int, int)>[];
  var depuis = 0;
  var dernierFin = 0;
  while (true) {
    final i = n.texte.indexOf(q, depuis);
    if (i < 0) break;
    depuis = i + q.length;
    // Début de la lettre source de la 1re lettre trouvée, fin de celle de la
    // dernière : `œ` (une lettre source, deux normalisées) est englobé en bloc.
    var debut = n.origine[i];
    final fin = n.origine[i + q.length - 1] + 1;
    // Deux occurrences peuvent partager une lettre source (« œ »).
    if (debut < dernierFin) debut = dernierFin;
    if (debut >= fin) continue;
    plages.add((debut, fin));
    dernierFin = fin;
  }
  return plages;
}
