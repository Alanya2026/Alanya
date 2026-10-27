// Les 10 points de code du plan §7.3 : un type 10 n'expose jamais son JSON.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/chat/conversation_merge.dart';
import 'package:talky_flutter/core/services/chat/message_search.dart';
import 'package:talky_flutter/core/services/notifications/notification_body.dart';
import 'package:talky_flutter/core/services/translation/translatable_content.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/forward_message.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';
import 'package:talky_flutter/talky_models.dart';

const _valide =
    '{"v":1,"pack":"mboa","sid":4812,"emoji":"😂","w":512,"h":512,"a":0}';
const _futur = '{"v":7,"pack":"mboa","sid":4812,"emoji":"😂","nouveau":{"x":1}}';

LocalMessage _msg(String? content, {String? url = 'https://x/y.webp'}) =>
    LocalMessage(
      clientId: 'c1',
      msgID: 10,
      conversationID: 1,
      senderID: 2,
      content: content,
      type: kStickerMessageType,
      status: 1,
      sendAt: DateTime.utc(2026, 1, 1),
      mediaUrl: url,
      mediaName: 'Sticker 😂',
      isEdited: false,
      isDeleted: false,
      isStatusReply: 0,
      isForwarded: false,
      isPinned: false,
      isViewOnce: false,
      isSensitive: false,
      syncPending: false,
      retryCount: 0,
      translationState: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late final dynamic l;
  setUpAll(() {
    LocaleController();
    l = LocaleController.instance.l10n;
  });

  test('3 — displayContent', () {
    Message m(String? c) => Message(
          msgID: 1,
          senderID: 2,
          conversationID: 1,
          content: c,
          type: kStickerMessageType,
          status: 1,
          sendAt: '2026-01-01T00:00:00Z',
          mediaName: 'Sticker 😂',
          isEdited: false,
          isDeleted: false,
          isStatusReply: 0,
        );
    expect(m(_valide).displayContent, l.stickerPreview('😂'));
    expect(m(_futur).displayContent, l.stickerPreview('😂'));
    expect(m('{cassé').displayContent, l.stickerWord);
  });

  test('4 — aperçu de conversation', () {
    expect(ConversationMerge.previewForMedia(10, _valide, 'Sticker 😂'),
        l.stickerPreview('😂'));
    expect(ConversationMerge.previewForMedia(10, _futur, null),
        l.stickerPreview('😂'));
  });

  test('5 — citation : JSON recopié par le serveur remplacé', () {
    expect(sanitizeQuotedContent(_valide), l.stickerPreview('😂'));
    expect(sanitizeQuotedContent('bonjour {x}'), 'bonjour {x}');
    expect(sanitizeQuotedContent('{"a":1}'), '{"a":1}');
  });

  test('6 — transfert : par référence, jamais en légende', () {
    expect(canForwardMessage(_msg(_valide)), isTrue);
    expect(canForwardMessage(_msg(_futur)), isFalse);
    expect(canForwardMessage(_msg('{cassé')), isFalse);
    expect(resolveForwardCaption(_msg(_valide), null), isNull);
    expect(previewTextForForward(_msg(_valide)), l.stickerPreview('😂'));
    expect(canBatchForwardOnServer([_msg(_valide)]), isTrue);
  });

  test('8 — corps de notification', () {
    expect(NotificationBody.stickerBody('😀 Sticker'), '😀 Sticker');
    expect(NotificationBody.stickerBody(_valide), l.stickerPreview('😂'));
    expect(NotificationBody.stickerBody(''), l.stickerWord);
    expect(NotificationBody.stickerBody('Ama: $_valide'), l.stickerWord);
  });

  test('9 — traduction : « inutile »', () {
    expect(kTranslatableMessageTypes.contains(kStickerMessageType), isFalse);
    expect(translatableTextOf(_msg(_valide)), isNull);
  });

  test('10 — médias, recherche : exclus', () {
    expect(kMyMediaTypes.contains(kStickerMessageType), isFalse);
    expect(kSearchableMessageTypes.contains(kStickerMessageType), isFalse);
  });
}
