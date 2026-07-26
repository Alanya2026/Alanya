import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/chat/conversation_merge.dart';
import 'package:talky_flutter/talky_models.dart';

void main() {
  group('ConversationMerge (preview monotonic, unread deferred to reducer)', () {
    LocalConversation localConv({
      required int unread,
      int? senderId,
      DateTime? at,
      String preview = 'local',
    }) {
      return LocalConversation(
        conversID: 1,
        isGroup: false,
        groupName: null,
        groupPhoto: null,
        lastMessage: preview,
        lastMessageAt: at ?? DateTime.utc(2026, 1, 1, 12),
        lastMessageSenderID: senderId,
        lastMessageType: 0,
        lastMessageStatus: 1,
        unreadCount: unread,
        isPinned: false,
        isArchived: false,
        participantsJson: '[]',
        onlyAdminsCanSend: false,
        onlyAdminsCanEditInfo: false,
        myRole: 0,
        muteForever: false,
        mentionsOnly: false,
        hasUnreadMention: false,
      );
    }

    Conversation serverConv({
      required int unread,
      int? senderId,
      String? at,
      String preview = 'server',
    }) {
      return Conversation(
        conversID: 1,
        isGroup: false,
        lastMessage: preview,
        lastMessageAt: at ?? '2026-01-01T12:00:00.000Z',
        lastMessageSenderID: senderId,
        lastMessageType: 0,
        lastMessageStatus: 1,
        unreadCount: unread,
        isPinned: false,
        isArchived: false,
        participants: const [],
      );
    }

    LocalConversationsCompanion fromServer(Conversation s) {
      return LocalConversationsCompanion(
        conversID: Value(s.conversID),
        isGroup: Value(s.isGroup),
        lastMessage: Value(s.lastMessage),
        lastMessageAt: Value(
          s.lastMessageAt != null ? DateTime.tryParse(s.lastMessageAt!) : null,
        ),
        lastMessageSenderID: Value(s.lastMessageSenderID),
        lastMessageType: Value(s.lastMessageType),
        lastMessageStatus: Value(s.lastMessageStatus),
        unreadCount: Value(s.unreadCount),
        isPinned: Value(s.isPinned),
        isArchived: Value(s.isArchived),
        participantsJson: const Value('[]'),
      );
    }

    test('preserves local unread when local already has preview (no flash)', () {
      const myId = 7;
      final local = localConv(unread: 0, senderId: 9);
      final server = serverConv(unread: 3, senderId: 9);
      final merged = ConversationMerge.mergeConversation(
        server: server,
        fromServer: fromServer(server),
        local: local,
        myId: myId,
        hasLocalPendingNewer: false,
      );
      expect(merged.unreadCount.value, 0);
    });

    test('preserves local unread even if last message is mine (reducer owns 0)', () {
      const myId = 7;
      final local = localConv(unread: 4, senderId: myId);
      final server = serverConv(unread: 4, senderId: myId);
      final merged = ConversationMerge.mergeConversation(
        server: server,
        fromServer: fromServer(server),
        local: local,
        myId: myId,
        hasLocalPendingNewer: false,
      );
      expect(merged.unreadCount.value, 4);
    });

    test('preserves local unread when server claims newer (until msg sync)', () {
      const myId = 7;
      final local = localConv(
        unread: 0,
        senderId: 9,
        at: DateTime.utc(2026, 1, 1, 12),
      );
      final server = serverConv(
        unread: 2,
        senderId: 9,
        at: '2026-01-01T13:00:00.000Z',
      );
      final merged = ConversationMerge.mergeConversation(
        server: server,
        fromServer: fromServer(server),
        local: local,
        myId: myId,
        hasLocalPendingNewer: false,
      );
      expect(merged.unreadCount.value, 0);
    });

    test('preserves local unread + preview when pending newer', () {
      const myId = 7;
      final local = localConv(unread: 0, senderId: myId, preview: 'pending');
      final server = serverConv(unread: 5, senderId: 9, preview: 'old');
      final merged = ConversationMerge.mergeConversation(
        server: server,
        fromServer: fromServer(server),
        local: local,
        myId: myId,
        hasLocalPendingNewer: true,
      );
      expect(merged.lastMessage.value, 'pending');
      expect(merged.unreadCount.value, 0);
    });

    test('previewOrUnreadDiffers détecte unread / aperçu / nouvelle conv', () {
      DateTime? parse(dynamic v) =>
          v == null ? null : DateTime.tryParse(v.toString());

      expect(
        ConversationMerge.previewOrUnreadDiffers(
          local: null,
          server: serverConv(unread: 1),
          parseDate: parse,
        ),
        isTrue,
      );
      expect(
        ConversationMerge.previewOrUnreadDiffers(
          local: localConv(unread: 0),
          server: serverConv(unread: 2),
          parseDate: parse,
        ),
        isTrue,
      );
      expect(
        ConversationMerge.previewOrUnreadDiffers(
          local: localConv(unread: 1, preview: 'same', senderId: 9),
          server: serverConv(unread: 1, preview: 'same', senderId: 9),
          parseDate: parse,
        ),
        isFalse,
      );
    });

    test('serverPreviewAhead true seulement si serveur strictement plus récent', () {
      final local = localConv(
        unread: 0,
        at: DateTime.utc(2026, 1, 1, 12),
      );
      expect(
        ConversationMerge.serverPreviewAhead(
          local: local,
          serverAt: DateTime.utc(2026, 1, 1, 13),
          hasLocalPendingNewer: false,
        ),
        isTrue,
      );
      expect(
        ConversationMerge.serverPreviewAhead(
          local: local,
          serverAt: DateTime.utc(2026, 1, 1, 11),
          hasLocalPendingNewer: false,
        ),
        isFalse,
      );
      expect(
        ConversationMerge.serverPreviewAhead(
          local: local,
          serverAt: DateTime.utc(2026, 1, 1, 13),
          hasLocalPendingNewer: true,
        ),
        isFalse,
      );
    });
  });
}
