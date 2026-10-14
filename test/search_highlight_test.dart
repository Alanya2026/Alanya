// Protège le surlignage de la recherche : le mot est découpé dans le texte
// affiché (après `parseRichSpans`), accents ignorés, et les liens ou mentions
// gardent leur recognizer, sinon ils cesseraient d'être cliquables.
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/search_highlight.dart';

TextStyle surligne(TextStyle s) =>
    s.copyWith(fontWeight: FontWeight.w700, backgroundColor: const Color(0xFFFF0000));

/// Texte de chaque feuille, avec son état surligné.
List<(String, bool)> feuilles(List<InlineSpan> spans) {
  final out = <(String, bool)>[];
  void visite(InlineSpan s) {
    if (s is! TextSpan) return;
    if (s.text != null) {
      out.add((s.text!, s.style?.backgroundColor == const Color(0xFFFF0000)));
    }
    s.children?.forEach(visite);
  }

  spans.forEach(visite);
  return out;
}

void main() {
  test('une occurrence au milieu du texte', () {
    final r = surlignerSpans(
        [const TextSpan(text: 'bonjour le monde')], 'le', surligne);
    expect(feuilles(r),
        [('bonjour ', false), ('le', true), (' monde', false)]);
  });

  test('deux occurrences', () {
    final r = surlignerSpans([const TextSpan(text: 'ab xx ab')], 'ab', surligne);
    expect(feuilles(r),
        [('ab', true), (' xx ', false), ('ab', true)]);
  });

  test('occurrence accentuée : « reunion » trouve « Réunion »', () {
    final r = surlignerSpans(
        [const TextSpan(text: 'Une Réunion demain')], 'reunion', surligne);
    expect(feuilles(r),
        [('Une ', false), ('Réunion', true), (' demain', false)]);
  });

  test('ligature : œ est englobé en bloc', () {
    final r = surlignerSpans([const TextSpan(text: 'Œuvre')], 'oeuvre', surligne);
    expect(feuilles(r), [('Œuvre', true)]);
  });

  test('le recognizer du span d\'origine est conservé sur chaque morceau', () {
    final rec = TapGestureRecognizer();
    addTearDown(rec.dispose);
    final r = surlignerSpans(
        [TextSpan(text: 'voir exemple.com ici', recognizer: rec)],
        'exemple',
        surligne);
    final morceaux = (r.single as TextSpan).children!.cast<TextSpan>();
    expect(morceaux, hasLength(3));
    expect(morceaux.every((m) => identical(m.recognizer, rec)), isTrue);
  });

  test('un WidgetSpan reste intact', () {
    const w = WidgetSpan(child: SizedBox());
    final r = surlignerSpans([w, const TextSpan(text: 'abc')], 'ab', surligne);
    expect(identical(r.first, w), isTrue);
  });

  test('recherche dans les enfants, en gardant le style du parent', () {
    const gras = TextStyle(fontWeight: FontWeight.bold);
    final r = surlignerSpans([
      const TextSpan(children: [TextSpan(text: 'un mot', style: gras)])
    ], 'mot', surligne);
    expect(feuilles(r), [('un ', false), ('mot', true)]);
  });

  test('requête absente ou trop courte : mêmes spans', () {
    final spans = <InlineSpan>[const TextSpan(text: 'bonjour')];
    expect(identical(surlignerSpans(spans, 'zzz', surligne).first, spans.first),
        isTrue);
    expect(identical(surlignerSpans(spans, 'b', surligne), spans), isTrue);
  });
}
