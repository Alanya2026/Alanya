import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/conversation_display.dart';

void main() {
  // resolveL10n() interroge WidgetsBinding pour la locale plateforme.
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = 1;

  /// Participant au format serveur : clés `alanyaID` / `nom` / `avatar_url`.
  /// (Ne PAS reprendre `userID` / `username` du ChatTestHarness : ces clés-là
  /// ne sont jamais lues par conversation_display, le test passerait à vide.)
  Map<String, dynamic> part(int id, String nom, {String? avatar}) => {
        'alanyaID': id,
        'nom': nom,
        'avatar_url': avatar,
      };

  LocalConversation conv({
    int conversID = 1,
    bool isGroup = false,
    String? groupName,
    String? groupPhoto,
    String? lastMessage,
    int? lastMessageSenderID,
    int lastMessageType = 0,
    List<Map<String, dynamic>> participants = const [],
  }) {
    return LocalConversation(
      conversID: conversID,
      isGroup: isGroup,
      groupName: groupName,
      groupPhoto: groupPhoto,
      lastMessage: lastMessage,
      lastMessageAt: DateTime.utc(2026, 1, 1, 12),
      lastMessageSenderID: lastMessageSenderID,
      lastMessageType: lastMessageType,
      lastMessageStatus: 1,
      unreadCount: 0,
      isPinned: false,
      isArchived: false,
      participantsJson: jsonEncode(participants),
      onlyAdminsCanSend: false,
      onlyAdminsCanEditInfo: false,
      hideHistoryForNewMembers: false,
      onlyAdminsCanAddMembers: false,
      myRole: 0,
      muteForever: false,
      mentionsOnly: false,
      hasUnreadMention: false,
    );
  }

  final selfConv = conv(
    conversID: 1,
    groupName: kSelfChatMarker,
    participants: [part(me, 'Chris', avatar: 'http://a/me.png')],
  );

  final normalConv = conv(
    conversID: 2,
    participants: [part(me, 'Chris'), part(2, 'Bob', avatar: 'http://a/bob.png')],
  );

  group('conversation avec soi-même', () {
    test('nom, avatar et interlocuteur', () {
      expect(isSelfConversation(selfConv, me), isTrue);
      expect(
        conversationDisplayName(selfConv, me),
        resolveL10n().selfChatTitle('Chris'),
      );
      expect(conversationDisplayAvatar(selfConv, me), 'http://a/me.png');
      // L'AUTRE personne : aucune.
      expect(conversationOtherUserId(selfConv, me), isNull);
      // L'interlocuteur : moi.
      expect(conversationCounterpartId(selfConv, me), me);
    });

    test('participants absents : repli sur « Moi »', () {
      final tronquee = conv(groupName: kSelfChatMarker);
      expect(isSelfConversation(tronquee, me), isTrue);
      final l10n = resolveL10n();
      expect(
        conversationDisplayName(tronquee, me),
        l10n.selfChatTitle(l10n.meLabel),
      );
    });

    test('trouvée par findLocalDirectConversationId avec mon propre id', () {
      expect(
        findLocalDirectConversationId([selfConv, normalConv], me, me),
        selfConv.conversID,
      );
    });

    test('jamais renvoyée pour un autre interlocuteur', () {
      expect(
        findLocalDirectConversationId([selfConv, normalConv], me, 2),
        normalConv.conversID,
      );
      expect(findAllDirectConversationIds([selfConv], me, 2), isEmpty);
    });

    test('cherchable par mon propre nom', () {
      expect(conversationMatchesSearch(selfConv, me, 'chris'), isTrue);
    });
  });

  group('non-régression : ce qui NE DOIT PAS être pris pour un self-chat', () {
    test('1-1 orphelin — le pair a supprimé son côté', () {
      // Même forme qu'un self-chat (un seul participant, moi) mais SANS le
      // marqueur : c'est une vraie discussion, dont l'historique appartient à
      // un tiers. La confondre l'afficherait comme mes notes personnelles.
      final orpheline = conv(conversID: 3, participants: [part(me, 'Chris')]);

      expect(isSelfConversation(orpheline, me), isFalse);
      expect(
        conversationDisplayName(orpheline, me),
        resolveL10n().unknownSender,
      );
      expect(conversationCounterpartId(orpheline, me), isNull);
      expect(findLocalDirectConversationId([orpheline], me, me), isNull);
    });

    test('ligne marquée héritée d\'un autre compte', () {
      final autreCompte = conv(
        groupName: kSelfChatMarker,
        participants: [part(99, 'Quelqu\'un')],
      );
      expect(isSelfConversation(autreCompte, me), isFalse);
    });

    test('groupe nommé « __self__ »', () {
      final groupe = conv(
        isGroup: true,
        groupName: kSelfChatMarker,
        participants: [part(me, 'Chris'), part(2, 'Bob')],
      );
      expect(isSelfConversation(groupe, me), isFalse);
      expect(conversationDisplayName(groupe, me), kSelfChatMarker);
    });

    test('myId inconnu (auth pas encore hydratée)', () {
      expect(isSelfConversation(selfConv, 0), isFalse);
      expect(conversationCounterpartId(selfConv, 0), isNull);
    });
  });

  group('non-régression : conversations ordinaires', () {
    test('1-1 normal inchangé', () {
      expect(isSelfConversation(normalConv, me), isFalse);
      expect(conversationDisplayName(normalConv, me), 'Bob');
      expect(conversationDisplayAvatar(normalConv, me), 'http://a/bob.png');
      expect(conversationOtherUserId(normalConv, me), 2);
      expect(conversationCounterpartId(normalConv, me), 2);
    });

    test('groupe inchangé', () {
      final groupe = conv(
        isGroup: true,
        groupName: 'Équipe',
        groupPhoto: 'http://a/g.png',
        participants: [part(me, 'Chris'), part(2, 'Bob')],
      );
      expect(conversationDisplayName(groupe, me), 'Équipe');
      expect(conversationDisplayAvatar(groupe, me), 'http://a/g.png');
      expect(conversationCounterpartId(groupe, me), isNull);
    });
  });

  group('conversationListPreview', () {
    final l10n = resolveL10n();
    final members = [part(me, 'Chris'), part(2, 'Bob')];

    test('groupe, message texte entrant → préfixe nom', () {
      final g = conv(
        isGroup: true,
        groupName: 'Équipe',
        lastMessage: 'Bonjour tout le monde',
        lastMessageSenderID: 2,
        participants: members,
      );
      expect(
        conversationListPreview(g, me, l10n),
        'Bob: Bonjour tout le monde',
      );
    });

    test('groupe, message sortant → Vous :', () {
      final g = conv(
        isGroup: true,
        groupName: 'Équipe',
        lastMessage: 'Salut',
        lastMessageSenderID: me,
        participants: members,
      );
      expect(conversationListPreview(g, me, l10n), '${l10n.youLabel}: Salut');
    });

    test('type 6 → pas de double préfixe', () {
      final g = conv(
        isGroup: true,
        groupName: 'Équipe',
        lastMessage: 'Bob a ajouté des membres',
        lastMessageSenderID: 2,
        lastMessageType: 6,
        participants: members,
      );
      expect(
        conversationListPreview(g, me, l10n),
        'Bob a ajouté des membres',
      );
    });

    test('1-1 inchangé (pas de préfixe)', () {
      final c = conv(
        lastMessage: 'Hey',
        lastMessageSenderID: 2,
        participants: [part(me, 'Chris'), part(2, 'Bob')],
      );
      expect(conversationListPreview(c, me, l10n), 'Hey');
    });

    test('expéditeur absent des participants → unknownSender', () {
      final g = conv(
        isGroup: true,
        groupName: 'Équipe',
        lastMessage: 'Au revoir',
        lastMessageSenderID: 99,
        participants: members,
      );
      expect(
        conversationListPreview(g, me, l10n),
        '${l10n.unknownSender}: Au revoir',
      );
    });
  });
}
