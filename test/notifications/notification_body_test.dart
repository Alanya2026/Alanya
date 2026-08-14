import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/notifications/notification_body.dart';

void main() {
  group('stripLeadingSenderPrefix', () {
    test('retire le préfixe serveur une fois', () {
      expect(
        NotificationBody.stripLeadingSenderPrefix('Bob', 'Bob: Hello team'),
        'Hello team',
      );
    });

    test('retire aussi l’ancien double préfixe client', () {
      expect(
        NotificationBody.stripLeadingSenderPrefix(
          'Bob',
          'Bob: Bob: Hello team',
        ),
        'Hello team',
      );
    });

    test('ne touche pas un 1-1 sans préfixe', () {
      expect(
        NotificationBody.stripLeadingSenderPrefix('Alice', 'Salut'),
        'Salut',
      );
    });

    test('maxStrips 0 = no-op', () {
      expect(
        NotificationBody.stripLeadingSenderPrefix(
          'Bob',
          'Bob: Hello',
          maxStrips: 0,
        ),
        'Bob: Hello',
      );
    });

    test('nom vide = no-op', () {
      expect(
        NotificationBody.stripLeadingSenderPrefix('', 'Bob: Hello'),
        'Bob: Hello',
      );
    });
  });

  group('resolveSenderName', () {
    test('groupe : senderName, pas le title (nom du groupe)', () {
      expect(
        NotificationBody.resolveSenderName(
          data: {'senderName': 'Bob', 'title': 'Équipe'},
          title: 'Équipe',
          isGroup: true,
          fallback: 'Alanya',
        ),
        'Bob',
      );
    });

    test('groupe sans senderName : ne pas prendre le nom du groupe', () {
      expect(
        NotificationBody.resolveSenderName(
          data: {'title': 'Équipe'},
          title: 'Équipe',
          isGroup: true,
          fallback: 'Alanya',
        ),
        'Alanya',
      );
    });

    test('1-1 : title = expéditeur', () {
      expect(
        NotificationBody.resolveSenderName(
          data: {'title': 'Alice'},
          title: 'Alice',
          isGroup: false,
          fallback: 'Alanya',
        ),
        'Alice',
      );
    });
  });
}
