import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/validators.dart';
import 'support/french_locale.dart';

/// Nom et pseudo : 3 caractères au moins, sans ponctuation. Nouveau mot de
/// passe : sans espace. Mêmes règles que `accountInputRules.js` côté serveur.
void main() {
  useFrenchLocale();

  group('Validators.displayName', () {
    test('accepts names from every script, with spaces, dashes and apostrophes', () {
      expect(Validators.displayName('Chris'), isNull);
      expect(Validators.displayName('Jean-Pierre'), isNull);
      expect(Validators.displayName("N'Diaye Aïcha"), isNull);
      expect(Validators.displayName('N’Diaye'), isNull);
      expect(Validators.displayName('chris_237'), isNull);
      expect(Validators.displayName('张小明'), isNull);
      expect(Validators.displayName('  Léa  '), isNull);
    });

    test('rejects fewer than 3 characters once trimmed', () {
      expect(Validators.displayName(''), isNotNull);
      expect(Validators.displayName(null), isNotNull);
      expect(Validators.displayName('Al'), isNotNull);
      expect(Validators.displayName(' Al  '), isNotNull);
    });

    test('rejects punctuation', () {
      for (final v in ['chris.', 'Chris,Doe', 'a;bc', 'abc!', 'abc?', 'ch@ris', 'abc:', 'a/bc']) {
        expect(Validators.displayName(v), isNotNull, reason: v);
      }
    });
  });

  group('Validators.newPassword', () {
    test('accepts 6 characters or more without spaces', () {
      expect(Validators.newPassword('abc123'), isNull);
      expect(Validators.newPassword('P@ss.w0rd!'), isNull);
    });

    test('rejects short passwords', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('abc12'), isNotNull);
    });

    test('rejects any whitespace', () {
      expect(Validators.newPassword('abc 123'), isNotNull);
      expect(Validators.newPassword(' abc123'), isNotNull);
      expect(Validators.newPassword('abc123\t'), isNotNull);
    });
  });
}
