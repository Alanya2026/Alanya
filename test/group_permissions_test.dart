import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/group_permissions.dart';
import 'package:talky_flutter/talky_models.dart';

/// Ces règles n'autorisent rien : elles masquent des boutons. Le serveur reste
/// l'autorité. Les tests vérifient donc uniquement que l'UI ne propose jamais
/// une action qui partirait en 403.
void main() {
  const membre = GroupRole.member;
  const admin = GroupRole.admin;
  const proprio = GroupRole.owner;

  // Fake écrit à la main : un participant réduit à ce que le tri regarde.
  Participant participant(String nom, int role, {int id = 0}) => Participant(
        user: User(
          alanyaID: id,
          nom: nom,
          pseudo: '',
          alanyaPhone: '',
          email: '',
          idPays: 0,
          avatarUrl: '',
          typeCompte: 0,
          isOnline: false,
          lastSeen: '',
        ),
        role: role,
      );

  List<String> nomsTries(List<Participant> membres) =>
      sortParticipantsForDisplay(membres).map((p) => p.nom).toList();

  group('retrait d\'un membre', () {
    test('propriétaire peut retirer un admin', () {
      expect(canRemove(proprio, admin, isSelf: false), isTrue);
    });

    test('admin ne peut pas retirer un autre admin', () {
      expect(canRemove(admin, admin, isSelf: false), isFalse);
    });

    test('admin peut retirer un simple membre', () {
      expect(canRemove(admin, membre, isSelf: false), isTrue);
    });

    test('simple membre ne peut retirer personne', () {
      expect(canRemove(membre, membre, isSelf: false), isFalse);
      expect(canRemove(membre, admin, isSelf: false), isFalse);
      expect(canRemove(membre, proprio, isSelf: false), isFalse);
    });

    test('le propriétaire est inexpulsable, même par un autre propriétaire '
        'théorique', () {
      expect(canRemove(admin, proprio, isSelf: false), isFalse);
      // Un second propriétaire ne devrait pas exister ; la règle ne doit pas
      // reposer sur cette unicité pour tenir.
      expect(canRemove(proprio, proprio, isSelf: false), isFalse);
    });

    test('on ne peut jamais se retirer soi-même', () {
      // Quitter le groupe est un autre geste, sur un autre endpoint.
      expect(canRemove(proprio, proprio, isSelf: true), isFalse);
      expect(canRemove(admin, admin, isSelf: true), isFalse);
      expect(canRemove(membre, membre, isSelf: true), isFalse);
    });

    test('rôle inconnu (donnée absente) → aucune action', () {
      expect(canRemove(-1, membre, isSelf: false), isFalse);
      expect(canLeave(-1), isFalse);
      expect(canSend(-1, false), isFalse);
      expect(canEditInfo(-1, false), isFalse);
    });
  });

  group('menu de gestion', () {
    test('simple membre ne voit aucune action de gestion', () {
      for (final cible in [membre, admin, proprio]) {
        expect(canManageMember(membre, cible, isSelf: false), isFalse,
            reason: 'membre → cible de rôle $cible');
      }
    });

    test('admin voit une action sur un simple membre, aucune sur un pair', () {
      expect(canManageMember(admin, membre, isSelf: false), isTrue);
      expect(canManageMember(admin, admin, isSelf: false), isFalse);
    });

    test('propriétaire voit une action même sur un admin', () {
      expect(canManageMember(proprio, admin, isSelf: false), isTrue);
    });

    test('aucune action de gestion sur sa propre ligne', () {
      expect(canManageMember(proprio, proprio, isSelf: true), isFalse);
      expect(canManageMember(admin, admin, isSelf: true), isFalse);
    });
  });

  group('changement de rôle', () {
    test('seul le propriétaire peut promouvoir ou rétrograder', () {
      expect(canChangeRole(proprio, isSelf: false), isTrue);
      // Un admin ne crée pas d'admin.
      expect(canChangeRole(admin, isSelf: false), isFalse);
      expect(canChangeRole(membre, isSelf: false), isFalse);
    });

    test('on ne peut pas changer son propre rôle', () {
      // Sinon le propriétaire se rétrograde et le groupe perd sa tête.
      expect(canChangeRole(proprio, isSelf: true), isFalse);
      expect(canChangeRole(admin, isSelf: true), isFalse);
    });
  });

  group('réglages du groupe', () {
    test('les verrous se basculent à partir du rôle admin', () {
      expect(canChangeSettings(membre), isFalse);
      expect(canChangeSettings(admin), isTrue);
      expect(canChangeSettings(proprio), isTrue);
    });
  });

  group('mode annonce', () {
    test('mode annonce : membre bloqué, admin autorisé, propriétaire autorisé',
        () {
      expect(canSend(membre, true), isFalse);
      expect(canSend(admin, true), isTrue);
      expect(canSend(proprio, true), isTrue);
    });

    test('hors mode annonce : tout le monde écrit', () {
      expect(canSend(membre, false), isTrue);
      expect(canSend(admin, false), isTrue);
      expect(canSend(proprio, false), isTrue);
    });
  });

  group('édition des infos', () {
    test('verrou infos désactivé : un simple membre peut renommer', () {
      expect(canEditInfo(membre, false), isTrue);
    });

    test('verrou infos activé : le simple membre ne peut plus', () {
      expect(canEditInfo(membre, true), isFalse);
      expect(canEditInfo(admin, true), isTrue);
      expect(canEditInfo(proprio, true), isTrue);
    });

    test('ajouter des participants suit son propre verrou', () {
      expect(canAddParticipants(membre, false), isTrue);
      expect(canAddParticipants(membre, true), isFalse);
      expect(canAddParticipants(admin, true), isTrue);
      expect(canAddParticipants(proprio, true), isTrue);
    });

    test('ajout et édition des infos sont indépendants', () {
      // Edit verrouillé, ajout ouvert
      expect(canEditInfo(membre, true), isFalse);
      expect(canAddParticipants(membre, false), isTrue);
      // Edit ouvert, ajout verrouillé
      expect(canEditInfo(membre, false), isTrue);
      expect(canAddParticipants(membre, true), isFalse);
    });
  });

  group('quitter le groupe', () {
    test('le propriétaire peut quitter — la succession est serveur', () {
      expect(canLeave(membre), isTrue);
      expect(canLeave(admin), isTrue);
      expect(canLeave(proprio), isTrue);
    });
  });

  group('tri des membres', () {
    test('tri des membres : propriétaire, puis admins, puis membres par nom',
        () {
      final ordre = nomsTries([
        participant('Zoé', membre, id: 1),
        participant('Marc', admin, id: 2),
        participant('Anne', membre, id: 3),
        participant('Chris', proprio, id: 4),
        participant('Bob', admin, id: 5),
      ]);

      expect(ordre, ['Chris', 'Bob', 'Marc', 'Anne', 'Zoé']);
    });

    test('noms accentués rangés comme en français, pas par code de caractère',
        () {
      // Sans repli des accents, « Élise » atterrirait après « Zoé ».
      final ordre = nomsTries([
        participant('Zoé', membre, id: 1),
        participant('Élise', membre, id: 2),
        participant('agnès', membre, id: 3),
      ]);

      expect(ordre, ['agnès', 'Élise', 'Zoé']);
    });

    test('homonymes de même rôle départagés par identifiant', () {
      final ordre = sortParticipantsForDisplay([
        participant('Marc', membre, id: 9),
        participant('Marc', membre, id: 4),
      ]).map((p) => p.alanyaID).toList();

      expect(ordre, [4, 9]);
    });

    test('la liste source n\'est pas modifiée', () {
      final source = [
        participant('Zoé', membre, id: 1),
        participant('Chris', proprio, id: 2),
      ];
      sortParticipantsForDisplay(source);

      // La fiche groupe trie une liste qui peut être non modifiable.
      expect(source.map((p) => p.nom), ['Zoé', 'Chris']);
    });

    test('tri générique : fonctionne aussi sur les Map du cache Drift', () {
      // Hors ligne, `decodeParticipants` rend des Map brutes, pas des objets.
      final ordre = sortMembersForDisplay<Map<String, dynamic>>(
        [
          {'nom': 'Zoé', 'role': 0},
          {'nom': 'Chris', 'role': 2},
          {'nom': 'Marc', 'role': 1},
        ],
        roleOf: (m) => (m['role'] as num).toInt(),
        nameOf: (m) => m['nom'] as String,
      ).map((m) => m['nom']).toList();

      expect(ordre, ['Chris', 'Marc', 'Zoé']);
    });
  });
}
