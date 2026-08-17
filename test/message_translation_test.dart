import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/translation/translatable_content.dart';
import 'package:talky_flutter/core/services/translation/translation_languages.dart';

/// Un message minimal. Les valeurs non pertinentes sont fixées une fois pour
/// que chaque test ne montre que ce qu'il exerce.
LocalMessage _msg({
  int type = 0,
  String? content = 'Are you coming to the meeting tonight?',
  bool isDeleted = false,
  bool isViewOnce = false,
  DateTime? viewedAt,
}) {
  return LocalMessage(
    clientId: 'c_1',
    msgID: 1,
    conversationID: 10,
    senderID: 2,
    content: content,
    type: type,
    status: 1,
    sendAt: DateTime.utc(2026, 1, 1),
    isEdited: false,
    isDeleted: isDeleted,
    isPinned: false,
    isViewOnce: isViewOnce,
    viewedAt: viewedAt,
    isStatusReply: 0,
    isForwarded: false,
    syncPending: false,
    retryCount: 0,
    translationState: 0,
  );
}

void main() {
  group('translatableTextOf — types porteurs de JSON', () {
    // Le test décisif : ces types stockent une structure dans `content`. La
    // confier à un traducteur détruirait le rendu de la bulle.
    const jsonBearing = {
      5: 'localisation',
      6: 'message système',
      7: 'contact',
      8: 'CTA de bienvenue',
      9: 'carte de trajet',
    };

    for (final entry in jsonBearing.entries) {
      test('type ${entry.key} (${entry.value}) est refusé', () {
        final m = _msg(
          type: entry.key,
          content: '{"lat":14.7,"lng":-17.4,"name":"Dakar Plateau"}',
        );
        expect(translatableTextOf(m), isNull);
      });
    }

    test('un type inconnu est refusé par défaut (liste blanche)', () {
      // La garantie de la liste blanche : un type ajouté demain n'atteint pas
      // le traducteur tant que personne ne l'a explicitement autorisé.
      expect(translatableTextOf(_msg(type: 42)), isNull);
    });
  });

  group('translatableTextOf — contenus non traduisibles', () {
    test('marqueur d\'album', () {
      final m = _msg(type: 1, content: '__talky_album__|abc|0|3|2|1');
      expect(translatableTextOf(m), isNull);
    });

    test('message supprimé', () {
      expect(translatableTextOf(_msg(isDeleted: true)), isNull);
    });

    test('vue unique non consultée', () {
      final m = _msg(type: 1, isViewOnce: true);
      expect(translatableTextOf(m), isNull);
    });

    test('contenu vide ou seulement des espaces', () {
      expect(translatableTextOf(_msg(content: null)), isNull);
      expect(translatableTextOf(_msg(content: '   ')), isNull);
    });

    test('texte trop court pour une identification fiable', () {
      expect(translatableTextOf(_msg(content: 'ok')), isNull);
      expect(translatableTextOf(_msg(content: '👍👍')), isNull);
      // Juste sous le seuil.
      expect(translatableTextOf(_msg(content: 'a' * 14)), isNull);
    });
  });

  group('translatableTextOf — contenus traduisibles', () {
    test('texte simple', () {
      const text = 'Are you coming to the meeting tonight?';
      expect(translatableTextOf(_msg(content: text)), text);
    });

    test('exactement au seuil', () {
      final text = 'a' * kMinTranslatableChars;
      expect(translatableTextOf(_msg(content: text)), text);
    });

    test('légende de média', () {
      const caption = 'Here is the document you asked for';
      expect(translatableTextOf(_msg(type: 4, content: caption)), caption);
    });

    test('vue unique déjà consultée', () {
      final m = _msg(
        type: 1,
        isViewOnce: true,
        viewedAt: DateTime.utc(2026, 1, 2),
      );
      expect(translatableTextOf(m), isNotNull);
    });

    test('le texte est rendu détouré de ses espaces', () {
      expect(
        translatableTextOf(_msg(content: '  Are you coming tonight?  ')),
        'Are you coming tonight?',
      );
    });
  });

  group('mlKitLanguageOf', () {
    test('langues connues', () {
      expect(mlKitLanguageOf('fr'), TranslateLanguage.french);
      expect(mlKitLanguageOf('en'), TranslateLanguage.english);
      expect(mlKitLanguageOf('zh'), TranslateLanguage.chinese);
    });

    test('étiquette composée réduite à sa sous-étiquette primaire', () {
      expect(mlKitLanguageOf('pt-BR'), TranslateLanguage.portuguese);
      expect(mlKitLanguageOf('zh-Hans'), TranslateLanguage.chinese);
      expect(mlKitLanguageOf('EN_US'), TranslateLanguage.english);
    });

    test('chinois romanisé refusé plutôt que traité comme du chinois', () {
      // `zh-Latn`, c'est du pinyin en caractères latins. Réduit à `zh`, il
      // partirait au traducteur chinois qui n'y reconnaîtrait rien.
      expect(mlKitLanguageOf('zh-Latn'), isNull);
    });

    test('indéterminé, vide ou inconnu', () {
      expect(mlKitLanguageOf('und'), isNull);
      expect(mlKitLanguageOf(''), isNull);
      expect(mlKitLanguageOf(null), isNull);
      expect(mlKitLanguageOf('wo'), isNull); // wolof : hors ML Kit
    });
  });

  group('catalogue de langues', () {
    test('les langues de l\'app sont proposées comme cibles', () {
      for (final code in kAppLocales) {
        expect(
          kTranslationTargets.any((l) => l.code == code),
          isTrue,
          reason: '$code doit figurer parmi les cibles',
        );
      }
    });

    test('chaque cible est réellement supportée par ML Kit', () {
      for (final l in kTranslationTargets) {
        expect(mlKitLanguageOf(l.code), l.mlKit, reason: l.code);
      }
    });

    test('nativeNameOf retombe sur le code hors catalogue', () {
      expect(nativeNameOf('zh'), '中文');
      expect(nativeNameOf('en'), 'English');
      expect(nativeNameOf('ko'), 'ko');
    });
  });
}
