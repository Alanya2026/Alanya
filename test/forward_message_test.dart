import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/utils/forward_message.dart';

LocalMessage _msg({
  int type = 0,
  String? content,
  String? mediaUrl,
  String? mediaName,
  String? pendingUploadPath,
  String? localMediaPath,
  bool isDeleted = false,
}) {
  return LocalMessage(
    clientId: 'test',
    msgID: 1,
    conversationID: 10,
    senderID: 2,
    content: content,
    type: type,
    status: 1,
    sendAt: DateTime.utc(2026, 1, 1),
    mediaUrl: mediaUrl,
    mediaName: mediaName,
    pendingUploadPath: pendingUploadPath,
    localMediaPath: localMediaPath,
    isEdited: false,
    isDeleted: isDeleted,
    isStatusReply: 0,
    isForwarded: false,
    syncPending: false,
    retryCount: 0,
  );
}

void main() {
  group('canForwardMessage', () {
    test('texte valide', () {
      expect(canForwardMessage(_msg(content: 'Bonjour')), isTrue);
    });

    test('texte vide refusé', () {
      expect(canForwardMessage(_msg(content: '   ')), isFalse);
    });

    test('supprimé refusé', () {
      expect(
        canForwardMessage(_msg(content: 'x', isDeleted: true)),
        isFalse,
      );
    });

    test('média avec URL', () {
      expect(
        canForwardMessage(_msg(type: 1, mediaUrl: 'https://cdn/x.jpg')),
        isTrue,
      );
    });

    test('média sans URL ni fichier local refusé', () {
      expect(canForwardMessage(_msg(type: 1)), isFalse);
    });
  });

  group('resolveForwardCaption', () {
    test('caption utilisateur prioritaire', () {
      final source = _msg(type: 1, content: 'ancienne');
      expect(resolveForwardCaption(source, '  nouvelle  '), 'nouvelle');
    });

    test('fallback sur contenu source pour média', () {
      final source = _msg(type: 1, content: 'légende');
      expect(resolveForwardCaption(source, null), 'légende');
    });

    test('null pour texte sans caption utilisateur', () {
      final source = _msg(content: 'hello');
      expect(resolveForwardCaption(source, null), isNull);
    });
  });

  group('previewTextForForward', () {
    test('texte tronqué tel quel', () {
      expect(previewTextForForward(_msg(content: 'Salut')), 'Salut');
    });

    test('média avec libellé', () {
      expect(
        previewTextForForward(_msg(type: 1, mediaName: 'pic.jpg')),
        'Photo',
      );
    });

    test('album marker affiche libellé album', () {
      expect(
        previewTextForForward(_msg(
          type: 1,
          content: '__talky_album__|alb1|0|4',
          mediaUrl: 'https://cdn/x.jpg',
        )),
        'Album · 4 médias',
      );
    });
  });

  group('resolveForwardCaption album', () {
    test('ignore album marker content', () {
      final source = _msg(
        type: 1,
        content: '__talky_album__|alb1|0|3',
        mediaUrl: 'https://cdn/x.jpg',
      );
      expect(resolveForwardCaption(source, null), isNull);
    });
  });
}
