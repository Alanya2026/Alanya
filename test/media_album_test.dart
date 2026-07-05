import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/utils/forward_message.dart';
import 'package:talky_flutter/core/utils/media_album.dart';

LocalMessage _mediaMsg({
  required String clientId,
  String? content,
  int type = 1,
  int senderID = 1,
  String? mediaUrl,
}) {
  return LocalMessage(
    clientId: clientId,
    msgID: clientId.hashCode,
    conversationID: 1,
    senderID: senderID,
    sendAt: DateTime.utc(2026, 1, 1, 12, 0),
    content: content,
    type: type,
    status: 1,
    mediaUrl: mediaUrl ?? 'https://example.com/$clientId.jpg',
    isEdited: false,
    isDeleted: false,
    isPinned: false,
    isViewOnce: false,
    isStatusReply: 0,
    isForwarded: false,
    syncPending: false,
    retryCount: 0,
  );
}

void main() {
  group('encodeAlbumMarker / parseAlbumMarker', () {
    test('round-trip', () {
      const id = 'alb_test_123';
      final encoded = encodeAlbumMarker(
        albumId: id,
        index: 2,
        total: 5,
        photoCount: 4,
        videoCount: 1,
      );
      expect(encoded, '__talky_album__|alb_test_123|2|5|4|1');

      final parsed = parseAlbumMarker(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.albumId, id);
      expect(parsed.index, 2);
      expect(parsed.total, 5);
      expect(parsed.photoCount, 4);
      expect(parsed.videoCount, 1);
    });

    test('legacy format without counts still parses', () {
      final parsed = parseAlbumMarker('__talky_album__|alb1|0|3');
      expect(parsed, isNotNull);
      expect(parsed!.total, 3);
      expect(parsed.photoCount, isNull);
      expect(parsed.videoCount, isNull);
      expect(previewLabelForAlbumMarker(parsed), '📷 3 photos');
    });

    test('returns null for normal caption', () {
      expect(parseAlbumMarker('Bonjour'), isNull);
      expect(parseAlbumMarker(null), isNull);
    });

    test('returns null for invalid marker', () {
      expect(parseAlbumMarker('__talky_album__|id|x|5'), isNull);
      expect(parseAlbumMarker('__talky_album__|id|0|1'), isNull);
    });

    test('round-trip with caption on first item', () {
      const id = 'alb_cap';
      final withCaption = encodeAlbumMarker(
        albumId: id,
        index: 0,
        total: 3,
        photoCount: 2,
        videoCount: 1,
        caption: '  Coucou  ',
      );
      expect(withCaption, '__talky_album__|alb_cap|0|3|2|1\nCoucou');
      expect(parseAlbumMarker(withCaption)!.albumId, id);
      expect(albumCaptionFromContent(withCaption), 'Coucou');
      expect(
        previewLabelForAlbumMarker(parseAlbumMarker(withCaption)!),
        '📷 2 photos, 🎥 Vidéo',
      );

      final other = encodeAlbumMarker(
        albumId: id,
        index: 1,
        total: 3,
        photoCount: 2,
        videoCount: 1,
        caption: 'ignorée',
      );
      expect(other, '__talky_album__|alb_cap|1|3|2|1');
      expect(albumCaptionFromContent(other), isNull);
    });
  });

  group('groupMessagesForDisplay', () {
    test('single messages stay single', () {
      final msgs = [
        _mediaMsg(clientId: 'a', content: 'hello', type: 0),
        _mediaMsg(clientId: 'b', content: null, type: 1),
      ];
      final items = groupMessagesForDisplay(msgs);
      expect(items.length, 2);
      expect(items[0], isA<ChatListSingle>());
      expect(items[1], isA<ChatListSingle>());
    });

    test('groups 2+ album items with same albumId', () {
      const id = 'alb_group';
      final msgs = [
        _mediaMsg(
          clientId: 'a',
          content: encodeAlbumMarker(albumId: id, index: 0, total: 3),
        ),
        _mediaMsg(
          clientId: 'b',
          content: encodeAlbumMarker(albumId: id, index: 1, total: 3),
        ),
        _mediaMsg(
          clientId: 'c',
          content: encodeAlbumMarker(albumId: id, index: 2, total: 3),
        ),
      ];
      final items = groupMessagesForDisplay(msgs);
      expect(items.length, 1);
      expect(items.first, isA<ChatListAlbum>());
      expect((items.first as ChatListAlbum).messages.length, 3);
    });

    test('does not group different albumIds', () {
      final msgs = [
        _mediaMsg(
          clientId: 'a',
          content: encodeAlbumMarker(albumId: 'alb1', index: 0, total: 2),
        ),
        _mediaMsg(
          clientId: 'b',
          content: encodeAlbumMarker(albumId: 'alb2', index: 0, total: 2),
        ),
      ];
      final items = groupMessagesForDisplay(msgs);
      expect(items.length, 2);
    });

    test('single album marker falls back to single bubble', () {
      final msgs = [
        _mediaMsg(
          clientId: 'a',
          content: encodeAlbumMarker(albumId: 'alb1', index: 0, total: 2),
        ),
      ];
      final items = groupMessagesForDisplay(msgs);
      expect(items.length, 1);
      expect(items.first, isA<ChatListSingle>());
    });
  });

  group('normalizeConversationPreview', () {
    test('remplace le marqueur album par le décompte', () {
      expect(
        normalizeConversationPreview('__talky_album__|alb1|0|5|4|1'),
        '📷 4 photos, 🎥 Vidéo',
      );
      expect(
        normalizeConversationPreview('__talky_album__|alb1|2|3'),
        '📷 3 photos',
      );
    });

    test('laisse le texte normal intact', () {
      expect(normalizeConversationPreview('Bonjour'), 'Bonjour');
      expect(normalizeConversationPreview(null), '');
    });
  });

  group('albumPreviewLabel', () {
    test('photos only', () {
      expect(
        albumPreviewLabel(photoCount: 5, videoCount: 0),
        '📷 5 photos',
      );
    });

    test('videos only', () {
      expect(
        albumPreviewLabel(photoCount: 0, videoCount: 3),
        '🎥 3 vidéos',
      );
    });

    test('mixed media', () {
      expect(
        albumPreviewLabel(photoCount: 5, videoCount: 1),
        '📷 5 photos, 🎥 Vidéo',
      );
    });
  });

  group('forward album helpers', () {
    test('canForwardAlbum requires all items forwardable', () {
      final items = [
        _mediaMsg(
          clientId: 'a',
          content: encodeAlbumMarker(albumId: 'x', index: 0, total: 2),
        ),
        _mediaMsg(
          clientId: 'b',
          content: encodeAlbumMarker(albumId: 'x', index: 1, total: 2),
        ),
      ];
      expect(canForwardAlbum(items), isTrue);
    });

    test('previewTextForForwardAlbum', () {
      final items = [
        _mediaMsg(
          clientId: 'a',
          content: encodeAlbumMarker(albumId: 'x', index: 0, total: 2),
          type: 1,
        ),
        _mediaMsg(
          clientId: 'b',
          content: encodeAlbumMarker(albumId: 'x', index: 1, total: 2),
          type: 2,
        ),
      ];
      expect(
        previewTextForForwardAlbum(items),
        '📷 Photo, 🎥 Vidéo',
      );
    });

    test('reencodeAlbumMarkerForForward', () {
      final marker = reencodeAlbumMarkerForForward(
        newAlbumId: 'new_id',
        index: 1,
        total: 4,
      );
      final parsed = parseAlbumMarker(marker);
      expect(parsed!.albumId, 'new_id');
      expect(parsed.index, 1);
      expect(parsed.total, 4);
    });
  });
}
