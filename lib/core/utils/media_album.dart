import 'dart:io';
import 'dart:math';

import '../db/app_database.dart';

/// Préfixe du marqueur album stocké dans [LocalMessage.content].
const albumMarkerPrefix = '__talky_album__';

/// Métadonnées d'appartenance à un album (encodées dans `content`).
class AlbumMarker {
  const AlbumMarker({
    required this.albumId,
    required this.index,
    required this.total,
  });

  final String albumId;
  final int index;
  final int total;
}

/// Item d'affichage dans la liste de messages (message seul ou album).
sealed class ChatListItem {
  const ChatListItem();
}

class ChatListSingle extends ChatListItem {
  const ChatListSingle(this.message);
  final LocalMessage message;
}

class ChatListAlbum extends ChatListItem {
  const ChatListAlbum({
    required this.albumId,
    required this.messages,
  });

  final String albumId;
  final List<LocalMessage> messages;
}

/// Encode le marqueur album dans `content`.
String encodeAlbumMarker({
  required String albumId,
  required int index,
  required int total,
}) {
  return '$albumMarkerPrefix|$albumId|$index|$total';
}

/// Décode le marqueur album depuis `content`, ou `null` si absent.
AlbumMarker? parseAlbumMarker(String? content) {
  if (content == null || !content.startsWith(albumMarkerPrefix)) return null;
  final parts = content.split('|');
  if (parts.length != 4) return null;
  final index = int.tryParse(parts[2]);
  final total = int.tryParse(parts[3]);
  if (parts[1].isEmpty || index == null || total == null || total < 2) {
    return null;
  }
  return AlbumMarker(albumId: parts[1], index: index, total: total);
}

bool isAlbumMarkerContent(String? content) => parseAlbumMarker(content) != null;

/// Libellé d'aperçu pour la liste des conversations.
String albumPreviewLabel({
  required int photoCount,
  required int videoCount,
}) {
  final parts = <String>[];
  if (photoCount > 0) {
    parts.add(photoCount == 1 ? '📷 Photo' : '📷 $photoCount photos');
  }
  if (videoCount > 0) {
    parts.add(videoCount == 1 ? '🎥 Vidéo' : '🎥 $videoCount vidéos');
  }
  if (parts.isEmpty) return '📷 Album';
  return parts.join(', ');
}

/// Fichier à envoyer dans un album.
class AlbumSendItem {
  const AlbumSendItem({
    required this.file,
    required this.type,
    this.mediaName,
    this.duration,
  });

  final File file;
  final int type; // 1=image 2=vidéo
  final String? mediaName;
  final int? duration;
}

String newAlbumId() =>
    'alb_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

String previewLabelForAlbumTypes(List<int> types) {
  var photos = 0;
  var videos = 0;
  for (final t in types) {
    if (t == 1) {
      photos++;
    } else if (t == 2) {
      videos++;
    }
  }
  return albumPreviewLabel(photoCount: photos, videoCount: videos);
}

/// Compte photos/vidéos dans une liste de messages album.
({int photos, int videos}) countAlbumMediaTypes(List<LocalMessage> messages) {
  var photos = 0;
  var videos = 0;
  for (final m in messages) {
    if (m.type == 1) {
      photos++;
    } else if (m.type == 2) {
      videos++;
    }
  }
  return (photos: photos, videos: videos);
}

String previewLabelForAlbumMessages(List<LocalMessage> messages) {
  final counts = countAlbumMediaTypes(messages);
  return albumPreviewLabel(
    photoCount: counts.photos,
    videoCount: counts.videos,
  );
}

/// Regroupe les messages consécutifs partageant le même albumId.
List<ChatListItem> groupMessagesForDisplay(List<LocalMessage> messages) {
  if (messages.isEmpty) return const [];

  final items = <ChatListItem>[];
  var i = 0;

  while (i < messages.length) {
    final msg = messages[i];
    final marker = parseAlbumMarker(msg.content);

    if (marker == null || msg.type != 1 && msg.type != 2) {
      items.add(ChatListSingle(msg));
      i++;
      continue;
    }

    final albumMessages = <LocalMessage>[msg];
    var j = i + 1;
    while (j < messages.length) {
      final next = messages[j];
      final nextMarker = parseAlbumMarker(next.content);
      if (nextMarker == null ||
          nextMarker.albumId != marker.albumId ||
          next.senderID != msg.senderID ||
          (next.type != 1 && next.type != 2)) {
        break;
      }
      albumMessages.add(next);
      j++;
    }

    albumMessages.sort((a, b) {
      final ma = parseAlbumMarker(a.content);
      final mb = parseAlbumMarker(b.content);
      return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
    });

    if (albumMessages.length >= 2) {
      items.add(ChatListAlbum(
        albumId: marker.albumId,
        messages: albumMessages,
      ));
    } else {
      items.add(ChatListSingle(msg));
    }
    i = j;
  }

  return items;
}

/// Regénère le marqueur pour un transfert (nouvel albumId, indices recalculés).
String reencodeAlbumMarkerForForward({
  required String newAlbumId,
  required int index,
  required int total,
}) {
  return encodeAlbumMarker(
    albumId: newAlbumId,
    index: index,
    total: total,
  );
}

/// Extrait tous les messages d'un album à partir d'un message membre.
List<LocalMessage> collectAlbumMessages(
  LocalMessage anchor,
  List<LocalMessage> allMessages,
) {
  final marker = parseAlbumMarker(anchor.content);
  if (marker == null) return [anchor];

  final members = allMessages
      .where((m) {
        final m2 = parseAlbumMarker(m.content);
        return m2 != null &&
            m2.albumId == marker.albumId &&
            m.senderID == anchor.senderID &&
            (m.type == 1 || m.type == 2);
      })
      .toList()
    ..sort((a, b) {
      final ma = parseAlbumMarker(a.content);
      final mb = parseAlbumMarker(b.content);
      return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
    });

  return members.length >= 2 ? members : [anchor];
}
