import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/mention_parser.dart';
import 'package:talky_flutter/talky_models.dart';

/// Les mentions sont analysées sur une simple `String` : le contenu d'un message
/// reste stocké tel quel, sans offsets ni balisage. Ces tests fixent les deux
/// pièges du plan (§4.4, §4.5) — les adresses e-mail / URL qui ne doivent jamais
/// produire de mention, et les noms à espaces qui interdisent de découper sur le
/// premier blanc venu.
void main() {
  // Un participant minimal : seuls l'identifiant et le nom comptent ici.
  Participant membre(int id, String nom) =>
      Participant.fromJson({'alanyaID': id, 'nom': nom});

  group('extractMentionQuery', () {
    test('curseur après @ma → requête « ma »', () {
      const texte = 'salut @ma';
      expect(extractMentionQuery(texte, texte.length), 'ma');
    });

    test("@ seul en fin de texte → requête vide (l'overlay s'ouvre)", () {
      const texte = 'salut @';
      expect(extractMentionQuery(texte, texte.length), '');
    });

    test('curseur avant le @ → aucune requête', () {
      const texte = 'salut @marc';
      // Au milieu du mot précédent…
      expect(extractMentionQuery(texte, 3), isNull);
      // …et juste avant le `@`.
      expect(extractMentionQuery(texte, 6), isNull);
    });

    test('mention en début de texte → requête reconnue', () {
      expect(extractMentionQuery('@ma', 3), 'ma');
    });

    test('nom composé en cours de frappe → espaces internes conservés', () {
      const texte = 'salut @Jean Dup';
      expect(extractMentionQuery(texte, texte.length), 'Jean Dup');
    });

    test('adresse e-mail a@b.com → aucune requête', () {
      const texte = 'écris à a@b.com';
      expect(extractMentionQuery(texte, texte.length), isNull);
    });

    test('@ dans une URL → aucune requête', () {
      const texte = 'voir https://x.com/@lea';
      expect(extractMentionQuery(texte, texte.length), isNull);
    });

    test('espace juste après le @ → la mention est abandonnée', () {
      const texte = 'salut @ marc';
      expect(extractMentionQuery(texte, texte.length), isNull);
    });

    // Écrire « (@Marc) » ou « "@Léa" » est courant. Une ponctuation ouvrante
    // ne réintroduit aucun faux positif : une adresse e-mail est toujours
    // précédée d'un caractère de mot, jamais d'une parenthèse.
    test('ponctuation ouvrante avant le @ → la mention s\'ouvre quand même', () {
      for (final ouvrante in ['(', '[', '{', '«', '"', "'"]) {
        final texte = '$ouvrante@ma';
        expect(
          extractMentionQuery(texte, texte.length),
          'ma',
          reason: 'ouvrante « $ouvrante » devrait laisser passer la mention',
        );
      }
    });

    // Cohérence affichage / envoi : parseRichSpans retire les marqueurs avant
    // de résoudre, le chemin d'envoi travaille sur le texte brut. Sans les
    // marqueurs ici, une mention en gras était surlignée mais jamais transmise.
    test('marqueur de mise en forme avant le @ → mention reconnue', () {
      for (final marqueur in ['*', '_', '~', '=', '#']) {
        final texte = '$marqueur@ma';
        expect(extractMentionQuery(texte, texte.length), 'ma',
            reason: 'marqueur « $marqueur » : mention perdue à l\'envoi');
      }
    });

    // Le tiret et le point, eux, apparaissent DANS les adresses : les admettre
    // comme ouvrantes ferait resurgir le faux positif e-mail.
    test('tiret ou point avant le @ → toujours aucune requête', () {
      expect(extractMentionQuery('jean-luc@x.fr', 13), isNull);
      expect(extractMentionQuery('j.dupont@x.fr', 13), isNull);
    });

    test('la requête ne franchit pas une fin de ligne', () {
      const texte = 'salut @\nmarc';
      expect(extractMentionQuery(texte, texte.length), isNull);
    });

    test('requête trop longue → abandon (le @ est hors de portée)', () {
      final texte = '@${'a' * (kMaxMentionQueryLength + 5)}';
      expect(extractMentionQuery(texte, texte.length), isNull);
    });

    test("texte vide ou curseur hors bornes → pas d'exception", () {
      expect(extractMentionQuery('', 0), isNull);
      expect(extractMentionQuery('', -1), isNull);
      // `TextEditingController` non focalisé renvoie -1.
      expect(extractMentionQuery('salut @ma', -1), isNull);
      expect(extractMentionQuery('salut @ma', 99), isNull);
    });
  });

  group('resolveMentions', () {
    test('nom composé avec espace résolu entièrement', () {
      const texte = 'merci @Jean Dupont pour tout';
      final trouvees = resolveMentions(texte, [membre(45, 'Jean Dupont')]);

      expect(trouvees, hasLength(1));
      expect(trouvees.single.userId, 45);
      expect(trouvees.single.isAll, isFalse);
      expect(texte.substring(trouvees.single.start, trouvees.single.end),
          '@Jean Dupont');
    });

    test('deux membres de même préfixe → correspondance la plus longue', () {
      final membres = [membre(1, 'Jean'), membre(2, 'Jean Dupont')];

      const complet = '@Jean Dupont arrive';
      final long = resolveMentions(complet, membres);
      expect(long.single.userId, 2);
      expect(complet.substring(long.single.start, long.single.end),
          '@Jean Dupont');

      // Le membre au nom court reste joignable quand rien ne le suit.
      expect(resolveMentions('@Jean arrive', membres).single.userId, 1);
    });

    test('insensible aux accents : @lea trouve Léa', () {
      final membres = [membre(7, 'Léa')];

      const texte = 'salut @lea !';
      final trouvees = resolveMentions(texte, membres);
      expect(trouvees.single.userId, 7);
      // Le libellé rendu est le nom canonique, pas la frappe.
      expect(trouvees.single.name, 'Léa');
      expect(texte.substring(trouvees.single.start, trouvees.single.end),
          '@lea');

      expect(resolveMentions('salut @LÉA !', membres).single.userId, 7);
    });

    test('adresse e-mail a@b.com → aucune mention', () {
      final membres = [membre(3, 'Jean')];
      expect(resolveMentions('contacte jean@exemple.com stp', membres),
          isEmpty);
    });

    test('@ dans une URL → aucune mention', () {
      final membres = [membre(7, 'Léa')];
      expect(
          resolveMentions('voir https://x.com/@Lea maintenant', membres),
          isEmpty);
    });

    test('@Jean ne se déclenche pas au milieu de @Jeanne', () {
      expect(resolveMentions('salut @Jeanne', [membre(1, 'Jean')]), isEmpty);
    });

    test('deux mentions dans le même message → deux plages disjointes', () {
      final membres = [membre(1, 'Jean'), membre(2, 'Léa')];
      const texte = '@Jean et @Léa, à demain';

      final trouvees = resolveMentions(texte, membres);
      expect(trouvees.map((m) => m.userId).toList(), [1, 2]);
      expect(texte.substring(trouvees.first.start, trouvees.first.end),
          '@Jean');
      expect(texte.substring(trouvees.last.start, trouvees.last.end), '@Léa');
    });

    test('@Tous reconnu quelle que soit la locale de lecture', () {
      final membres = [membre(1, 'Jean'), membre(2, 'Léa')];

      // Message écrit en français, lu par un client anglais : le libellé est
      // stocké tel quel dans le texte, il doit rester surligné.
      const enFrancais = 'Coucou @Tous !';
      final fr = resolveMentions(enFrancais, membres,
          allLabelFr: '@Tous', allLabelEn: '@All');
      expect(fr.single.isAll, isTrue);
      expect(fr.single.userId, isNull);
      expect(enFrancais.substring(fr.single.start, fr.single.end), '@Tous');

      // Et réciproquement, un message anglais lu en français.
      final en = resolveMentions('Hi @All !', membres,
          allLabelFr: '@Tous', allLabelEn: '@All');
      expect(en.single.isAll, isTrue);

      // La casse et les accents suivent la même règle que les membres.
      expect(
          resolveMentions('salut @tous', membres, allLabelFr: '@Tous')
              .single
              .isAll,
          isTrue);

      // Sans libellé fourni (conversation 1-1), « @Tous » n'est qu'un mot.
      expect(resolveMentions(enFrancais, membres), isEmpty);
    });

    test('membre parti du groupe → non résolu, sans planter', () {
      const texte = 'merci @Marc pour tout';
      expect(resolveMentions(texte, [membre(1, 'Jean')]), isEmpty);
      expect(resolveMentions(texte, const []), isEmpty);
    });

    test("texte vide ou groupe sans membre → pas d'exception", () {
      expect(resolveMentions('', [membre(1, 'Jean')]), isEmpty);
      expect(resolveMentions('@', [membre(1, 'Jean')]), isEmpty);
      expect(resolveMentions('@@@', const []), isEmpty);
    });
  });

  group('foldForMention', () {
    // Invariant porteur : les index du texte replié servent tels quels à
    // surligner le texte source.
    test('le repli conserve la longueur du texte', () {
      const texte = 'Léa Çà ÿ';
      expect(foldForMention(texte), 'lea ca y');
      expect(foldForMention(texte).length, texte.length);
    });

    test('les caractères hors table traversent sans changer de longueur', () {
      const texte = 'Привет 😀 ok';
      expect(foldForMention(texte).length, texte.length);
    });
  });
}
