// Mise en forme des messages — approche « marqueurs inline » (façon WhatsApp).
//
// Le contenu reste une simple String stockée telle quelle (aucun changement
// côté backend / base de données). La mise en forme est encodée par des paires
// de marqueurs et n'est décodée qu'à l'affichage, ici, en une liste de TextSpan.
//
//   *texte*   → gras
//   _texte_   → italique / cursif
//   ~texte~   → barré
//   =texte=   → souligné
//   #texte#   → manuscrit (police d'écriture)
//
// Les styles peuvent s'imbriquer : `*_=gras italique souligné=_*` est géré
// grâce à l'analyse récursive du contenu interne de chaque paire.
//
// Limite connue : un marqueur isolé (sans paire fermante) est rendu littéralement,
// et un marqueur présent dans une URL (ex. les `_` d'un lien) peut être interprété
// comme de la mise en forme. C'est le même compromis que WhatsApp.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Caractères de marquage et la transformation de style associée.
/// Chaque fonction reçoit le style courant et renvoie le style enrichi,
/// ce qui permet aux styles imbriqués de se cumuler.
final Map<String, TextStyle Function(TextStyle)> _markers = {
  '*': (s) => s.copyWith(fontWeight: FontWeight.bold),
  '_': (s) => s.copyWith(fontStyle: FontStyle.italic),
  '~': (s) => s.copyWith(decoration: _addDecoration(s, TextDecoration.lineThrough)),
  '=': (s) => s.copyWith(decoration: _addDecoration(s, TextDecoration.underline)),
  // Manuscrit : police d'écriture chargée via google_fonts. On conserve la
  // couleur, la taille et les décorations héritées en passant `textStyle`.
  '#': (s) => GoogleFonts.caveat(textStyle: s).copyWith(fontSize: (s.fontSize ?? 16) * 1.25),
};

/// Combine une nouvelle décoration avec celle déjà présente (barré + souligné).
TextDecoration _addDecoration(TextStyle s, TextDecoration add) {
  final current = s.decoration;
  if (current == null || current == TextDecoration.none) return add;
  if (current == add) return current;
  return TextDecoration.combine([current, add]);
}

/// Transforme [text] en liste de spans stylés à partir du style de base [base].
/// À utiliser dans un `Text.rich(TextSpan(children: parseRichSpans(...)))`.
List<InlineSpan> parseRichSpans(String text, TextStyle base) {
  return _parse(text, base);
}

List<InlineSpan> _parse(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }
  }

  int i = 0;
  while (i < text.length) {
    final ch = text[i];
    final transform = _markers[ch];
    if (transform != null) {
      final close = _findClose(text, i + 1, ch);
      if (close != -1) {
        flush();
        final inner = text.substring(i + 1, close);
        // Analyse récursive → les marqueurs internes se combinent au style courant.
        spans.addAll(_parse(inner, transform(style)));
        i = close + 1;
        continue;
      }
    }
    buffer.write(ch);
    i++;
  }

  flush();
  return spans;
}

/// Renvoie l'index du marqueur fermant valide, ou -1 si absent.
/// Règles : pas d'espace juste après l'ouverture, contenu non vide.
int _findClose(String text, int from, String marker) {
  if (from >= text.length || text[from] == ' ') return -1;
  for (int j = from; j < text.length; j++) {
    if (text[j] == marker) {
      return j == from ? -1 : j; // `**` (vide) → invalide
    }
  }
  return -1;
}

/// Retire tous les marqueurs de mise en forme.
/// À utiliser pour les aperçus en texte simple (bandeau « Réponse »,
/// dernier message d'une conversation, notifications) afin de ne pas afficher
/// les caractères `* _ ~ = #` bruts.
String stripMarkers(String text) => text.replaceAll(RegExp(r'[*_~=#]'), '');

// ── Rendu « live » dans le champ de saisie ──────────────────────────────
// Contrairement à parseRichSpans (qui retire les marqueurs pour l'affichage
// final), ce rendu CONSERVE chaque caractère — y compris les marqueurs, qu'il
// affiche atténués. C'est indispensable dans un TextField : le nombre de
// caractères dessinés doit rester identique au texte réel, sinon le curseur
// et la sélection se décalent.

/// Construit les spans pour l'édition : texte stylé + marqueurs grisés.
List<InlineSpan> buildEditingSpans(String text, TextStyle base) {
  final markerStyle = base.copyWith(
    color: (base.color ?? const Color(0xFF000000)).withAlpha(90),
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    decoration: TextDecoration.none,
  );
  return _parseEditing(text, base, markerStyle);
}

List<InlineSpan> _parseEditing(String text, TextStyle style, TextStyle markerStyle) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }
  }

  int i = 0;
  while (i < text.length) {
    final ch = text[i];
    final transform = _markers[ch];
    if (transform != null) {
      final close = _findClose(text, i + 1, ch);
      if (close != -1) {
        flush();
        spans.add(TextSpan(text: ch, style: markerStyle)); // marqueur ouvrant
        final inner = text.substring(i + 1, close);
        spans.addAll(_parseEditing(inner, transform(style), markerStyle));
        spans.add(TextSpan(text: ch, style: markerStyle)); // marqueur fermant
        i = close + 1;
        continue;
      }
    }
    buffer.write(ch);
    i++;
  }

  flush();
  return spans;
}

/// Contrôleur de saisie qui applique la mise en forme **en direct**, pendant
/// que l'utilisateur tape, sans attendre l'envoi.
///
/// Le texte sous-jacent (`.text`) reste inchangé : il contient toujours les
/// marqueurs (`*gras*`, `_italique_`, …). Les marqueurs restent affichés (mais
/// atténués), et le texte qu'ils encadrent apparaît déjà stylé. On NE retire
/// PAS les marqueurs ici : dans un TextField, le nombre de caractères dessinés
/// doit rester égal au texte réel, sinon le curseur et la sélection se décalent.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(style: base, children: buildEditingSpans(text, base));
  }
}
