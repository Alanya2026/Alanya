// Suppression pour tous : ce que l'interface propose (72 h, expéditeur ou
// administrateur de groupe). Même table de cas que le serveur
// (`src/testUtils/messageDeletionCases.json`, copie octet pour octet) : si les deux
// s'écartent, un des deux tests tombe.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/message_deletion_policy.dart';
import 'package:talky_flutter/talky_models.dart' show GroupRole;

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);
  DateTime ago(Duration d) => now.subtract(d);

  bool can({
    int sender = 10,
    Duration age = const Duration(hours: 1),
    int type = 0,
    bool deleted = false,
    int me = 10,
    bool group = true,
    int myRole = GroupRole.member,
    int? senderRole,
  }) => canDeleteForAll(
    senderID: sender,
    sendAt: ago(age),
    type: type,
    isDeleted: deleted,
    myId: me,
    isGroup: group,
    myRole: myRole,
    senderRole: senderRole,
    now: now,
  );

  group('fenêtre de 72 heures', () {
    test('72 h exactement : ouverte ; une milliseconde de plus : fermée', () {
      expect(kDeleteForAllWindow, const Duration(hours: 72));
      expect(isInDeleteWindow(ago(Duration.zero), now: now), isTrue);
      expect(isInDeleteWindow(ago(const Duration(hours: 71, minutes: 59)), now: now), isTrue);
      expect(isInDeleteWindow(ago(const Duration(hours: 72)), now: now), isTrue);
      expect(isInDeleteWindow(ago(const Duration(hours: 72, milliseconds: 1)), now: now), isFalse);
      expect(isInDeleteWindow(ago(const Duration(days: 30)), now: now), isFalse);
    });

    test('l\'heure locale ou UTC de la date ne change rien', () {
      final utc = DateTime.utc(2026, 10, 8, 12); // exactement 72 h avant
      expect(isInDeleteWindow(utc, now: now), isTrue);
      expect(isInDeleteWindow(utc.toLocal(), now: now), isTrue);
      expect(isInDeleteWindow(utc.subtract(const Duration(milliseconds: 1)).toLocal(), now: now), isFalse);
    });

    test('date dans le futur (horloge du téléphone en retard) : ouverte', () {
      expect(isInDeleteWindow(now.add(const Duration(minutes: 5)), now: now), isTrue);
    });
  });

  group('exemples', () {
    test('expéditeur : oui dans la fenêtre, non après', () {
      expect(can(), isTrue);
      expect(can(age: const Duration(hours: 73)), isFalse);
    });

    test('administrateur : le message d\'un membre, pas celui d\'un admin ni du propriétaire', () {
      expect(can(sender: 30, myRole: GroupRole.admin, senderRole: GroupRole.member), isTrue);
      expect(can(sender: 30, myRole: GroupRole.admin, senderRole: null), isTrue, reason: 'a quitté : membre');
      expect(can(sender: 30, myRole: GroupRole.admin, senderRole: GroupRole.admin), isFalse);
      expect(can(sender: 30, myRole: GroupRole.admin, senderRole: GroupRole.owner), isFalse);
    });

    test('propriétaire : membre ou administrateur', () {
      expect(can(sender: 30, myRole: GroupRole.owner, senderRole: GroupRole.member), isTrue);
      expect(can(sender: 30, myRole: GroupRole.owner, senderRole: GroupRole.admin), isTrue);
    });

    test('administrateur : la fenêtre de 72 h s\'applique aussi', () {
      expect(can(sender: 30, myRole: GroupRole.admin, age: const Duration(hours: 80)), isFalse);
    });

    test('membre simple et conversation à deux : jamais le message d\'un autre', () {
      expect(can(sender: 30, myRole: GroupRole.member), isFalse);
      expect(can(sender: 30, group: false, myRole: GroupRole.owner), isFalse);
    });

    test('message système, bienvenue, trajet : un administrateur ne les retire pas', () {
      for (final t in kUnmoderableMessageTypes) {
        expect(can(sender: 30, type: t, myRole: GroupRole.admin), isFalse, reason: 'type $t');
        expect(can(type: t), isTrue, reason: 'son auteur le peut (comportement existant)');
      }
      expect(kUnmoderableMessageTypes, [6, 8, 9]);
    });

    test('déjà supprimé : rien à proposer', () {
      expect(can(deleted: true), isFalse);
    });
  });

  test('parité avec le serveur : 780 cas de la table commune', () {
    final doc = jsonDecode(File('test/fixtures/message_deletion_cases.json').readAsStringSync()) as Map;
    expect(doc['colonnes'], [
      'isGroup', 'roleActeur', 'roleAuteur', 'acteurEstAuteur', 'type', 'ageMs', 'dejaSupprime', 'attendu',
    ]);
    final cas = (doc['cas'] as List).cast<List>();
    expect(cas.length, greaterThanOrEqualTo(700));
    var verifies = 0;
    for (final c in cas) {
      final isGroup = c[0] == 1;
      final roleActeur = c[1] as int?;
      final roleAuteur = c[2] as int?;
      final acteurEstAuteur = c[3] == 1;
      final type = c[4] as int;
      final ageMs = c[5] as int;
      final dejaSupprime = c[6] == 1;
      final attendu = c[7] as String;

      // Pas participant : l'application n'a pas de « mon rôle » à lui donner, et le
      // serveur répond 404 — il n'y a rien à proposer.
      if (roleActeur == null) {
        expect(attendu, 'MESSAGE_NOT_FOUND');
        continue;
      }
      final obtenu = can(
        sender: acteurEstAuteur ? 10 : 11,
        age: Duration(milliseconds: ageMs),
        type: type,
        deleted: dejaSupprime,
        group: isGroup,
        myRole: roleActeur,
        senderRole: roleAuteur,
      );
      // Différence voulue : sur un message DÉJÀ supprimé le serveur répond OK
      // (idempotent) mais l'interface ne propose plus rien.
      final attenduUi = attendu.startsWith('OK') && !dejaSupprime;
      expect(obtenu, attenduUi, reason: 'cas $c');
      verifies += 1;
    }
    expect(verifies, greaterThan(400));
  });
}
