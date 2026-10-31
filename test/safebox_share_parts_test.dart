import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/screens/safebox/safebox_chat_picker.dart';

/// Envoyer des dossiers entiers : découpage au-delà de 500 fichiers, et
/// reprise après une coupure sans rien envoyer deux fois.
void main() {
  test('découpage : « Kribi · 1/3 », une carte vide disparaît, les fichiers à part sans titre', () {
    final parts = safeboxShareParts<int>([
      ('Kribi', List.generate(1200, (i) => i)),
      ('Vide', const []),
      ('Noël', [1, 2]),
      (null, [7]),
    ]);
    expect(parts.map((p) => p.$1), ['Kribi · 1/3', 'Kribi · 2/3', 'Kribi · 3/3', 'Noël', null]);
    expect(parts.map((p) => p.$2.length), [500, 500, 200, 2, 1]);
    expect(parts[1].$2.first, 500, reason: 'dans l\'ordre, sans trou ni doublon');
    expect(safeboxShareParts<int>([('Juste', List.generate(500, (i) => i))]).single.$1, 'Juste');
  });

  test('coupure au milieu : tout est tenté, l\'erreur remonte, le nouvel essai n\'envoie que le reste', () async {
    final envoyes = <String>[];
    final done = <String>{};
    var coupure = true;
    Future<void> envoyer(int part, int conv) async {
      if (coupure && part == 1 && conv == 20) throw Exception('réseau');
      envoyes.add('$part:$conv');
    }

    await expectLater(
      safeboxSendParts(parts: 2, conversationIds: [10, 20], done: done, send: envoyer),
      throwsException,
    );
    expect(envoyes, ['0:10', '0:20', '1:10'], reason: 'les autres sont partis malgré la coupure');

    coupure = false;
    envoyes.clear();
    expect(await safeboxSendParts(parts: 2, conversationIds: [10, 20], done: done, send: envoyer), isTrue);
    expect(envoyes, ['1:20'], reason: 'seul ce qui manquait');
  });
}
