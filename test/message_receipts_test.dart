// « Infos du message » de groupe : lecture de la réponse serveur, heures et
// barre empilée.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/models/message_receipts.dart';

void main() {
  final json = {
    'msgID': 200,
    'sentAt': '2026-10-09T10:42:00.000Z',
    'total': 53,
    'readCount': 12,
    'deliveredCount': 40,
    'read': [
      {'alanyaID': 2, 'nom': 'Aaron', 'pseudo': null, 'avatar': null, 'at': '2026-10-09T10:44:00.000Z'},
      {'alanyaID': 8, 'nom': '', 'pseudo': 'lys', 'avatar': null, 'at': null},
    ],
    'delivered': [
      {'alanyaID': 3, 'nom': 'Epsilon', 'avatar': 'https://x/a.jpg', 'at': '2026-10-09T10:43:00.000Z'},
    ],
    'pending': [
      {'alanyaID': 4, 'nom': 'Richy', 'at': null},
    ],
  };

  test('lecture de la réponse', () {
    final r = MessageReceipts.fromJson(json);
    expect(r.total, 53);
    expect(r.readCount, 12);
    expect(r.pendingCount, 13);
    expect(r.read.first.displayName, 'Aaron');
    expect(r.read.first.at, isNotNull);
    expect(r.read[1].displayName, 'lys', reason: 'pseudo si pas de nom');
    expect(r.read[1].at, isNull, reason: 'lu avant les accusés par membre');
    expect(r.delivered.single.avatar, 'https://x/a.jpg');
  });

  test('barre : lu, reçu seulement, en attente ; segments vides omis', () {
    final r = MessageReceipts.fromJson(json);
    expect(receiptBarSegments(r), [
      (kind: 'read', flex: 12),
      (kind: 'delivered', flex: 28),
      (kind: 'pending', flex: 13),
    ]);
    final personne = MessageReceipts.fromJson({...json, 'readCount': 0, 'deliveredCount': 0});
    expect(receiptBarSegments(personne), [(kind: 'pending', flex: 53)]);
  });

  test('heures : aujourd\'hui, hier, plus ancien', () {
    final now = DateTime(2026, 10, 10, 9, 0);
    expect(formatReceiptTime(DateTime(2026, 10, 10, 8, 5), now, yesterday: 'Hier'), '08:05');
    expect(formatReceiptTime(DateTime(2026, 10, 9, 22, 41), now, yesterday: 'Hier'), 'Hier 22:41');
    expect(formatReceiptTime(DateTime(2026, 10, 2, 7, 3), now, yesterday: 'Hier'), '02/10 07:03');
  });
}
