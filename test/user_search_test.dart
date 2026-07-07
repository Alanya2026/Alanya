import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/user_search.dart';
import 'package:talky_flutter/talky_models.dart';

void main() {
  final alice = User(
    alanyaID: 1,
    nom: 'Alice Martin',
    pseudo: 'alice_m',
    alanyaPhone: '12345678',
  );

  final bob = User(
    alanyaID: 2,
    nom: 'Bob Dupont',
    pseudo: 'bobd',
    alanyaPhone: '87654321',
  );

  group('userMatchesSearch', () {
    test('match par nom', () {
      expect(userMatchesSearch(alice, 'mart'), isTrue);
    });

    test('match par pseudo', () {
      expect(userMatchesSearch(alice, 'alice'), isTrue);
    });

    test('match par numéro partiel', () {
      expect(userMatchesSearch(bob, '8765'), isTrue);
    });

    test('pas de match', () {
      expect(userMatchesSearch(alice, 'zzzz'), isFalse);
    });

    test('match dès un caractère', () {
      expect(userMatchesSearch(alice, 'a'), isTrue);
    });

    test('requête vide', () {
      expect(userMatchesSearch(alice, ''), isFalse);
    });
  });

  group('filterUsersBySearch', () {
    test('filtre une liste', () {
      final results = filterUsersBySearch([alice, bob], 'bob');
      expect(results, [bob]);
    });
  });
}
