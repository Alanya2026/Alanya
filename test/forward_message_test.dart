import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/utils/forward_message.dart';
import 'package:talky_flutter/core/services/media_expiry_policy.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'support/french_locale.dart';

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
    isPinned: false,
    isViewOnce: false,
    isStatusReply: 0,
    isForwarded: false,
    syncPending: false,
    retryCount: 0,
    translationState: 0,
  );
}

void main() {
  useFrenchLocale();

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

    test('item d\'album seul affiche le type de média', () {
      expect(
        previewTextForForward(_msg(
          type: 1,
          content: '__talky_album__|alb1|0|4',
          mediaUrl: 'https://cdn/x.jpg',
        )),
        'Photo',
      );
      expect(
        previewTextForForward(_msg(
          type: 2,
          content: '__talky_album__|alb1|1|4',
          mediaUrl: 'https://cdn/x.mp4',
        )),
        'Vidéo',
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

    test('item d\'album reste transférable individuellement', () {
      final source = _msg(
        type: 1,
        content: '__talky_album__|alb1|2|5',
        mediaUrl: 'https://cdn/x.jpg',
      );
      expect(canForwardMessage(source), isTrue);
    });
  });

  group('canForwardMessage — média expiré', () {
    setUp(() => MediaExpiryPolicy.resetForTests(retentionDays: 30));
    tearDown(() => MediaExpiryPolicy.resetForTests());

    const vivant =
        'https://alanya237.com/uploads/media/2099-01-01/images/media_2_1.jpg';
    const expire =
        'https://alanya237.com/uploads/media/2020-01-01/images/media_2_1.jpg';

    test('un média encore servi reste transférable', () {
      expect(canForwardMessage(_msg(type: 1, mediaUrl: vivant)), isTrue);
    });

    test('un média expiré côté serveur ne l\'est plus', () {
      // Son adresse est toujours en base — le stockage partitionné ne l'efface
      // jamais — mais le fichier n'existe plus. Le transférer produirait chez
      // le destinataire un message impossible à ouvrir.
      expect(canForwardMessage(_msg(type: 1, mediaUrl: expire)), isFalse);
    });

    test('une copie locale rend le transfert possible malgré l\'expiration', () {
      // L'appareil renverra son propre fichier : la disparition côté serveur
      // ne l'en empêche pas. Le fichier doit exister pour de vrai —
      // `_localMediaPath` vérifie sa présence, pas seulement le chemin.
      final dir = Directory.systemTemp.createTempSync('alanya-forward-');
      final fichier = File(p.join(dir.path, 'photo.jpg'))..writeAsStringSync('x');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        canForwardMessage(
          _msg(type: 1, mediaUrl: expire, localMediaPath: fichier.path),
        ),
        isTrue,
      );
    });

    test('rétention inconnue : on ne présume rien, le transfert reste ouvert', () {
      MediaExpiryPolicy.resetForTests();
      expect(canForwardMessage(_msg(type: 1, mediaUrl: expire)), isTrue);
    });
  });
}