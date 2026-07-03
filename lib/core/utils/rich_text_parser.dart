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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Détecte les URLs (http, https, ou commençant par www.).
final RegExp _urlRegExp = RegExp(
  r'((?:https?://|www\.)[^\s]+)',
  caseSensitive: false,
);

/// Ouvre une URL dans le navigateur externe. Ajoute https:// si absent (www.…).
/// On n'utilise pas `canLaunchUrl` (qui peut renvoyer false à tort sur
/// Android 11+) : on tente directement l'ouverture, avec un repli.
///
/// Exposée publiquement (via [openUrl]) afin de pouvoir être réutilisée
/// ailleurs que dans le rendu des bulles de discussion — par ex. l'onglet
/// « Liens » des détails d'une conversation.
Future<void> _openUrl(String raw) async {
  var url = raw;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Repli : laisser le système décider du mode d'ouverture.
    try {
      await launchUrl(uri);
    } catch (_) {/* pas d'app pour ouvrir — ignoré */}
  }
}

/// Retire la ponctuation finale qui ne fait généralement pas partie de l'URL
/// (ex. « visite https://exemple.com. » → l'URL s'arrête avant le point).
String _trimUrlTail(String url) {
  const tail = '.,;:!?)]}\'"';
  var end = url.length;
  while (end > 0 && tail.contains(url[end - 1])) {
    end--;
  }
  return url.substring(0, end);
}

/// Ouvre [raw] dans le navigateur externe (ajoute https:// si besoin).
/// Wrapper public de [_openUrl], à utiliser partout où un lien doit être
/// rendu tappable (bulles de discussion, onglet « Liens », etc.).
Future<void> openUrl(String raw) => _openUrl(raw);

/// Renvoie la première URL trouvée dans [text] (nettoyée de sa ponctuation
/// de fin), ou `null` si aucune URL n'y figure.
String? extractFirstUrl(String text) {
  final match = _urlRegExp.firstMatch(text);
  if (match == null) return null;
  return _trimUrlTail(match.group(0)!);
}

/// Comme [extractFirstUrl], mais renvoie une URL **normalisée** (préfixée de
/// https:// si le schéma est absent). Pratique quand l'URL doit être
/// directement téléchargée — par ex. la carte d'aperçu de lien, qui interroge
/// la page pour ses métadonnées Open Graph.
String? firstUrlIn(String text) {
  final raw = extractFirstUrl(text);
  if (raw == null) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  return 'https://$raw';
}

/// Découpe [text] en segments : texte normal + liens tappables (bleu souligné).
void _appendWithLinks(
    List<InlineSpan> out, String text, TextStyle style, Color linkColor) {
  int last = 0;
  for (final match in _urlRegExp.allMatches(text)) {
    if (match.start > last) {
      out.add(TextSpan(text: text.substring(last, match.start), style: style));
    }
    final raw = match.group(0)!;
    final url = _trimUrlTail(raw);
    out.add(TextSpan(
      text: url,
      style: style.copyWith(
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
    ));
    // Ponctuation finale rattachée au texte normal.
    if (url.length < raw.length) {
      out.add(TextSpan(text: raw.substring(url.length), style: style));
    }
    last = match.end;
  }
  if (last < text.length) {
    out.add(TextSpan(text: text.substring(last), style: style));
  }
}

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
/// Les URLs y sont rendues tappables (couleur [linkColor], soulignées).
/// À utiliser dans un `Text.rich(TextSpan(children: parseRichSpans(...)))`.
List<InlineSpan> parseRichSpans(String text, TextStyle base, {Color? linkColor}) {
  return _parse(text, base, linkColor ?? const Color(0xFF1B6EF3));
}

List<InlineSpan> _parse(String text, TextStyle style, Color linkColor) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      // Au lieu d'un simple TextSpan, on détecte les liens dans ce segment.
      _appendWithLinks(spans, buffer.toString(), style, linkColor);
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
        spans.addAll(_parse(inner, transform(style), linkColor));
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
