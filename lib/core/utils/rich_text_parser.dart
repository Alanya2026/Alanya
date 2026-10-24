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

import 'alanya_phone_formatter.dart';

/// Détecte les URLs (http, https, ou commençant par www.).
final RegExp _urlRegExp = RegExp(
  r'((?:https?://|www\.)[^\s]+)',
  caseSensitive: false,
);

/// Détecte une adresse e-mail. Volontairement plus étroite que la RFC, qui
/// autorise des formes que personne n'écrit dans un message : ce qui compte
/// ici est de ne jamais décorer en lien une arobase ordinaire.
///
/// Le domaine exige au moins un point, sinon « rendez-vous @ midi » suffirait.
/// La ponctuation de fin de phrase reste dehors d'elle-même : « écris à
/// jean@exemple.com. » s'arrête à `.com`, le dernier point n'étant suivi
/// d'aucun caractère de domaine.
final RegExp _emailRegExp = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',
  caseSensitive: false,
);

/// Détecte un numéro Alanya isolé dans du texte.
///
/// Les longueurs viennent d'[AlanyaPhoneFormatter], source de vérité de l'app
/// (3, 4 ou 8 chiffres aujourd'hui) : la détection suivra si elles changent,
/// plutôt que de dériver dans son coin.
///
/// Les gardes `(?<!\d)` / `(?!\d)` interdisent de tailler un numéro dans un
/// nombre plus long : un « 123456 » n'en contient aucun, et un « 12345678 » en
/// est un seul — pas deux de quatre chiffres.
final RegExp _alanyaNumberRegExp = _buildAlanyaNumberRegExp();

RegExp _buildAlanyaNumberRegExp() {
  // De la plus longue à la plus courte : le moteur essaie les alternatives
  // dans l'ordre, et « 12345678 » doit se lire en huit chiffres.
  final longueurs = [...AlanyaPhoneFormatter.validLengths]
    ..sort((a, b) => b.compareTo(a));
  final alternatives = longueurs.map((n) => '\\d{$n}').join('|');
  return RegExp('(?<!\\d)(?:$alternatives)(?!\\d)');
}

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

/// Confie [adresse] au client mail du système. Même prudence que [_openUrl] :
/// pas de `canLaunchUrl`, qui répond non à tort sur Android 11+ dès que
/// l'app ne déclare pas la requête de paquet correspondante.
Future<void> _openEmail(String adresse) async {
  final uri = Uri(scheme: 'mailto', path: adresse);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      await launchUrl(uri);
    } catch (_) {/* aucun client mail installé — ignoré */}
  }
}

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

/// Décrit comment surligner et rendre tappables les mentions d'un message.
///
/// Le surlignage se fait par CORRESPONDANCE DE NOM et non par offsets stockés :
/// le contenu reste une simple String, aucun format de fil à faire évoluer, et
/// les messages antérieurs se dégradent proprement. La liste faisant autorité
/// (notifications, mentionsOnly, compteur de saut) reste la colonne serveur —
/// ce scan n'est que de la présentation.
class MentionSpec {
  /// Résout les mentions présentes dans un segment de texte.
  final List<({int start, int end, int? userId, bool isAll})> Function(String)
      resolve;

  /// Style appliqué à une mention. Sur une bulle sortante (fond indigo),
  /// l'indigo serait invisible : l'appelant fournit alors une variante claire.
  final TextStyle Function(TextStyle base) style;

  /// `userId` nul = `@Tous`.
  final void Function(int? userId) onTap;

  /// Texte à afficher à la place de la mention telle qu'écrite (« @Nom du
  /// profil »), ou null pour la laisser telle quelle. Sert à montrer mon nom
  /// personnalisé : le message stocké, lui, ne change pas.
  final String? Function(int userId)? label;

  /// Les recognizers créés y sont déposés pour que l'appelant les libère.
  /// Sans ça, chaque reconstruction de bulle en fuit un dans une liste qui
  /// défile.
  final List<GestureRecognizer>? recognizerSink;

  const MentionSpec({
    required this.resolve,
    required this.style,
    required this.onTap,
    this.label,
    this.recognizerSink,
  });
}

/// Ce qu'il faut savoir pour décorer un segment, transporté d'un étage de
/// découpage au suivant plutôt que répété en cinq paramètres.
class _SpanOptions {
  const _SpanOptions({
    required this.linkColor,
    this.mentions,
    this.onAlanyaNumber,
    this.recognizerSink,
  });

  final Color linkColor;
  final MentionSpec? mentions;

  /// Nul = les numéros restent du texte ordinaire. C'est le cas partout où le
  /// texte n'est qu'un aperçu (liste des discussions, bandeau de réponse) :
  /// on n'y souligne pas ce qui n'est pas tappable.
  final void Function(String numero)? onAlanyaNumber;

  /// Les recognizers créés y sont déposés pour que l'appelant les libère.
  final List<GestureRecognizer>? recognizerSink;
}

/// Le texte passe par quatre tamis successifs, dans cet ordre : URL, e-mail,
/// numéro Alanya, mention. Chacun découpe ce qu'il reconnaît et confie le
/// reste au suivant — l'ordre n'est donc pas cosmétique. L'URL passe en
/// premier pour qu'une adresse dans un lien (`?mail=a@b.com`) ne soit pas
/// re-découpée, et les chiffres d'une URL ne deviennent pas un numéro. La
/// mention passe en dernier : son « @ » ne peut plus être celui d'un e-mail.
TextSpan _tappable(
  String text,
  TextStyle style,
  Color color,
  VoidCallback onTap,
  List<GestureRecognizer>? sink,
) {
  final recognizer = TapGestureRecognizer()..onTap = onTap;
  sink?.add(recognizer);
  return TextSpan(
    text: text,
    style: style.copyWith(
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color,
    ),
    recognizer: recognizer,
  );
}

/// Premier tamis : les URLs.
void _appendWithLinks(
    List<InlineSpan> out, String text, TextStyle style, _SpanOptions opts) {
  int last = 0;
  for (final match in _urlRegExp.allMatches(text)) {
    if (match.start > last) {
      _appendWithEmails(out, text.substring(last, match.start), style, opts);
    }
    final raw = match.group(0)!;
    final url = _trimUrlTail(raw);
    out.add(_tappable(url, style, opts.linkColor, () => _openUrl(url),
        opts.recognizerSink));
    // Ponctuation finale rattachée au texte normal.
    if (url.length < raw.length) {
      out.add(TextSpan(text: raw.substring(url.length), style: style));
    }
    last = match.end;
  }
  if (last < text.length) {
    _appendWithEmails(out, text.substring(last), style, opts);
  }
}

/// Deuxième tamis : les adresses e-mail, confiées au client mail du système.
void _appendWithEmails(
    List<InlineSpan> out, String text, TextStyle style, _SpanOptions opts) {
  int last = 0;
  for (final match in _emailRegExp.allMatches(text)) {
    if (match.start > last) {
      _appendWithAlanyaNumbers(
          out, text.substring(last, match.start), style, opts);
    }
    final adresse = match.group(0)!;
    out.add(_tappable(adresse, style, opts.linkColor, () => _openEmail(adresse),
        opts.recognizerSink));
    last = match.end;
  }
  if (last < text.length) {
    _appendWithAlanyaNumbers(out, text.substring(last), style, opts);
  }
}

/// Troisième tamis : les numéros Alanya.
///
/// Tout nombre isolé de la bonne longueur est retenu — y compris un « 250 »
/// qui ne parlait que d'une quantité. Le choix est assumé : le tap coûte au
/// pire un « Numéro indisponible », alors qu'exiger une écriture particulière
/// raterait la façon dont les gens se passent réellement un numéro.
void _appendWithAlanyaNumbers(
    List<InlineSpan> out, String text, TextStyle style, _SpanOptions opts) {
  final onTap = opts.onAlanyaNumber;
  if (onTap == null) {
    _appendWithMentions(out, text, style, opts.mentions);
    return;
  }

  int last = 0;
  for (final match in _alanyaNumberRegExp.allMatches(text)) {
    if (match.start > last) {
      _appendWithMentions(
          out, text.substring(last, match.start), style, opts.mentions);
    }
    final numero = match.group(0)!;
    out.add(_tappable(numero, style, opts.linkColor, () => onTap(numero),
        opts.recognizerSink));
    last = match.end;
  }
  if (last < text.length) {
    _appendWithMentions(out, text.substring(last), style, opts.mentions);
  }
}

/// Découpe un segment SANS URL en texte normal + mentions.
///
/// Appelé après le découpage des liens : un « @ » dans une URL a donc déjà été
/// consommé et ne peut pas être pris pour une mention.
void _appendWithMentions(
    List<InlineSpan> out, String text, TextStyle style, MentionSpec? spec) {
  if (spec == null || text.isEmpty) {
    if (text.isNotEmpty) out.add(TextSpan(text: text, style: style));
    return;
  }

  final trouvees = spec.resolve(text);
  if (trouvees.isEmpty) {
    out.add(TextSpan(text: text, style: style));
    return;
  }

  int last = 0;
  for (final m in trouvees) {
    if (m.start < last || m.end > text.length) continue; // plage incohérente
    if (m.start > last) {
      out.add(TextSpan(text: text.substring(last, m.start), style: style));
    }
    final recognizer = TapGestureRecognizer()
      ..onTap = () => spec.onTap(m.userId);
    spec.recognizerSink?.add(recognizer);
    out.add(TextSpan(
      text: (m.userId == null ? null : spec.label?.call(m.userId!)) ??
          text.substring(m.start, m.end),
      style: spec.style(style),
      recognizer: recognizer,
    ));
    last = m.end;
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
  // couleur et les décorations héritées en passant `textStyle`. Caveat a une
  // hauteur d'œil plus faible que le sans-serif : on grossit pour aligner
  // visuellement le corps du message.
  '#': (s) => GoogleFonts.caveat(textStyle: s).copyWith(
        fontSize: (s.fontSize ?? 16) * 1.5,
        fontFamilyFallback: _kHandwritingFallback,
      ),
};

/// Repli de police pour le style manuscrit.
///
/// Caveat ne contient **aucun glyphe CJK** : un message écrit en chinois avec
/// le marqueur `#` s'afficherait entièrement en carrés vides. Le repli ne
/// s'applique qu'aux caractères absents de Caveat, donc un texte latin garde
/// son rendu manuscrit — seuls les idéogrammes basculent sur la police
/// système, qui n'est pas manuscrite mais reste lisible.
///
/// C'est le seul endroit de l'app où une police non système est appliquée à du
/// texte saisi par l'utilisateur ; le thème de base n'impose aucune
/// `fontFamily` et gère donc le CJK nativement.
const List<String> _kHandwritingFallback = <String>[
  'Noto Sans SC', // Android
  'PingFang SC', // iOS / macOS
  'Heiti SC', // iOS ancien
  'Microsoft YaHei', // Windows (mode bureau)
];

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
List<InlineSpan> parseRichSpans(
  String text,
  TextStyle base, {
  Color? linkColor,
  MentionSpec? mentions,
  void Function(String numero)? onAlanyaNumber,
  List<GestureRecognizer>? recognizerSink,
}) {
  return _parse(
    text,
    base,
    _SpanOptions(
      linkColor: linkColor ?? const Color(0xFF1B6EF3),
      mentions: mentions,
      onAlanyaNumber: onAlanyaNumber,
      recognizerSink: recognizerSink,
    ),
  );
}

List<InlineSpan> _parse(String text, TextStyle style, _SpanOptions opts) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      // Au lieu d'un simple TextSpan, on passe ce segment aux tamis.
      _appendWithLinks(spans, buffer.toString(), style, opts);
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
        spans.addAll(_parse(inner, transform(style), opts));
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
