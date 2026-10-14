import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/contact_aliases.dart';
import 'package:talky_flutter/core/utils/contact_payload.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';
import 'package:talky_flutter/l10n/app_localizations_fr.dart';
import 'package:talky_flutter/models/message_receipts.dart';
import 'package:talky_flutter/talky_models.dart';

User user(int id, String nom, {String pseudo = '', String? preferredName}) =>
    User(
      alanyaID: id,
      nom: nom,
      pseudo: pseudo,
      alanyaPhone: '',
      email: '',
      idPays: 10,
      avatarUrl: '',
      typeCompte: 0,
      isOnline: false,
      lastSeen: '',
      preferredName: preferredName,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ContactAliases.replaceAll({}));

  group('règle unique : nom choisi, sinon nom du profil', () {
    test('nameFor', () {
      ContactAliases.replaceAll({2: 'Maman', 3: '   ', 4: null});
      expect(ContactAliases.nameFor(2, 'Marie-Claire'), 'Maman');
      expect(ContactAliases.nameFor(3, 'Bob'), 'Bob');
      expect(ContactAliases.nameFor(4, 'Sam'), 'Sam');
      expect(ContactAliases.nameFor(null, 'Inconnu'), 'Inconnu');
      expect(ContactAliases.nameFor(9, null), '');
    });

    test('User.displayName, sans toucher nom ni pseudo', () {
      ContactAliases.set(2, 'Maman');
      final u = user(2, 'Marie-Claire', pseudo: 'mcbassa');
      expect(u.displayName, 'Maman');
      expect(u.nom, 'Marie-Claire');
      expect(u.pseudo, 'mcbassa');
      expect(user(5, 'Bob').displayName, 'Bob');
      expect(user(6, '', pseudo: 'sans_nom').displayName, 'sans_nom');
      // Registre pas encore rempli : le champ lu du cache sert de repli.
      expect(user(7, 'Jean', preferredName: 'Plombier').displayName, 'Plombier');
    });

    test('participant et accusé de lecture', () {
      ContactAliases.replaceAll({2: 'Maman'});
      expect(Participant(user: user(2, 'Marie-Claire')).displayName, 'Maman');
      expect(
        ReceiptMember.fromJson({'alanyaID': 2, 'nom': 'Marie-Claire'})
            .displayName,
        'Maman',
      );
      expect(
        ReceiptMember.fromJson({'alanyaID': 3, 'nom': 'Bob'}).displayName,
        'Bob',
      );
    });
  });

  group('ce qui sort de l\'app garde le nom du profil', () {
    test('contact partagé : la carte reçue est aliasée, la charge utile non', () {
      ContactAliases.set(2, 'Maman');
      final c = ContactPayload(alanyaID: 2, nom: 'Marie-Claire', pseudo: 'mc');
      expect(c.shownLabel, 'Maman');
      expect(c.displayLabel, 'Marie-Claire');
      expect((jsonDecode(c.encode()) as Map)['nom'], 'Marie-Claire');
    });
  });

  group('messages système de groupe', () {
    final l10n = AppLocalizationsFr();
    String phrase(Map<String, dynamic> contenu) =>
        SystemEventPayload.tryParse(jsonEncode(contenu))!.label(99, l10n)!;

    test('auteur et cibles sous mon nom personnalisé', () {
      final contenu = {
        'e': 'member_added',
        'by': 2,
        'byName': 'Marie-Claire',
        'ids': [3, 4],
        'names': ['Bob', 'Jean-Paul'],
      };
      final avant = phrase(contenu);
      expect(avant, contains('Marie-Claire'));
      ContactAliases.replaceAll({2: 'Maman', 4: 'Plombier Akwa'});
      final apres = phrase(contenu);
      expect(apres, contains('Maman'));
      expect(apres, contains('Bob'));
      expect(apres, contains('Plombier Akwa'));
      expect(apres, isNot(contains('Marie-Claire')));
      expect(apres, isNot(contains('Jean-Paul')));
    });

    test('listes désappariées : les noms du serveur restent tels quels', () {
      ContactAliases.replaceAll({4: 'Plombier Akwa'});
      final apres = phrase({
        'e': 'member_added',
        'by': 2,
        'byName': 'Marie-Claire',
        'ids': [4],
        'names': ['Bob', 'Jean-Paul'],
      });
      expect(apres, contains('Jean-Paul'));
      expect(apres, isNot(contains('Plombier Akwa')));
    });
  });
}
