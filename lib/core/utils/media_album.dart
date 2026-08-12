import 'dart:io';
import 'dart:math';

import '../db/app_database.dart';
import '../theme/locale_controller.dart';
import 'system_event_payload.dart';
import 'trip_payload.dart';

/// Préfixe du marqueur album stocké dans [LocalMessage.content].
const albumMarkerPrefix = '__talky_album__';

/// Métadonnées d'appartenance à un album (encodées dans `content`).
class AlbumMarker {
  const AlbumMarker({
    required this.albumId,
    required this.index,
    required this.total,
    this.photoCount,
    this.videoCount,
  });

  final String albumId;
  final int index;
  final int total;

  /// Nombre de photos dans l'album (absent sur les marqueurs legacy).
  final int? photoCount;

  /// Nombre de vidéos dans l'album (absent sur les marqueurs legacy).
  final int? videoCount;
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
///
/// Format : `__talky_album__|id|index|total|photos|videos`
/// Légende optionnelle (premier item uniquement) : après un saut de ligne.
String encodeAlbumMarker({
  required String albumId,
  required int index,
  required int total,
  int photoCount = 0,
  int videoCount = 0,
  String? caption,
}) {
  final base =
      '$albumMarkerPrefix|$albumId|$index|$total|$photoCount|$videoCount';
  final trimmed = caption?.trim();
  if (trimmed != null && trimmed.isNotEmpty && index == 0) {
    return '$base\n$trimmed';
  }
  return base;
}

/// Décode le marqueur album depuis `content`, ou `null` si absent.
///
/// Accepte le format legacy (`|id|index|total`) et le format avec comptes
/// photos/vidéos (`|id|index|total|photos|videos`).
AlbumMarker? parseAlbumMarker(String? content) {
  if (content == null || !content.startsWith(albumMarkerPrefix)) return null;
  final header = content.split('\n').first;
  final parts = header.split('|');
  if (parts.length != 4 && parts.length != 6) return null;
  final index = int.tryParse(parts[2]);
  final total = int.tryParse(parts[3]);
  if (parts[1].isEmpty || index == null || total == null || total < 2) {
    return null;
  }
  int? photoCount;
  int? videoCount;
  if (parts.length == 6) {
    photoCount = int.tryParse(parts[4]);
    videoCount = int.tryParse(parts[5]);
    if (photoCount == null || videoCount == null) return null;
  }
  return AlbumMarker(
    albumId: parts[1],
    index: index,
    total: total,
    photoCount: photoCount,
    videoCount: videoCount,
  );
}

bool isAlbumMarkerContent(String? content) => parseAlbumMarker(content) != null;

/// Légende utilisateur attachée à un marqueur album (si présente).
String? albumCaptionFromContent(String? content) {
  if (content == null || !content.startsWith(albumMarkerPrefix)) return null;
  final nl = content.indexOf('\n');
  if (nl < 0 || nl + 1 >= content.length) return null;
  final caption = content.substring(nl + 1).trim();
  return caption.isEmpty ? null : caption;
}

/// Première légende trouvée parmi les messages d'un album.
String? albumCaptionFromMessages(List<LocalMessage> messages) {
  for (final m in messages) {
    final caption = albumCaptionFromContent(m.content);
    if (caption != null) return caption;
  }
  return null;
}

/// Libellé d'aperçu pour la liste des conversations.
///
/// Ex. `📷 5 photos`, `🎥 3 vidéos`, `📷 5 photos, 🎥 Vidéo`.
String albumPreviewLabel({
  required int photoCount,
  required int videoCount,
}) {
  final parts = <String>[];
  if (photoCount > 0) {
    parts.add(photoCount == 1 ? LocaleController.instance.l10n.photo : LocaleController.instance.l10n.photosCount(photoCount));
  }
  if (videoCount > 0) {
    parts.add(videoCount == 1 ? LocaleController.instance.l10n.video : LocaleController.instance.l10n.videosCount(videoCount));
  }
  if (parts.isEmpty) return LocaleController.instance.l10n.album;
  return parts.join(', ');
}

/// Aperçu conversation à partir d'un marqueur album (jamais la légende).
String previewLabelForAlbumMarker(AlbumMarker marker) {
  final photos = marker.photoCount;
  final videos = marker.videoCount;
  if (photos != null && videos != null) {
    return albumPreviewLabel(photoCount: photos, videoCount: videos);
  }
  // Legacy sans comptes : total affiché comme photos.
  return marker.total == 1 ? LocaleController.instance.l10n.photo : LocaleController.instance.l10n.photosCount(marker.total);
}

/// Normalise un aperçu de conversation : marqueur album → décompte photos/vidéos.
///
/// À utiliser à l'affichage et à l'écriture de `lastMessage`, car le serveur
/// peut encore stocker le marqueur brut (`__talky_album__|…`).
///
/// Ne localise pas la sentinelle « message supprimé » — pour l'UI utiliser
/// [displayConversationPreview].
String normalizeConversationPreview(String? text) {
  if (text == null || text.isEmpty) return text ?? '';
  final marker = parseAlbumMarker(text);
  if (marker != null) return previewLabelForAlbumMarker(marker);
  // Legacy : aperçu recalculé avant le support type 6 → JSON brut en base.
  if (text.trimLeft().startsWith('{')) {
    final payload = SystemEventPayload.tryParse(text);
    if (payload != null) {
      return payload.previewLabel(resolveL10n());
    }
    // Idem pour les trajets : les lignes écrites avant le support du type 9
    // portent le JSON de la carte. Sans ce rattrapage, elles resteraient
    // illisibles jusqu'au prochain message de la conversation.
    final trajet = TripCardPayload.tryParse(text);
    if (trajet != null) {
      return trajet.previewLabel(resolveL10n());
    }
  }
  return text;
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

({int photos, int videos}) countAlbumMediaTypesFromTypes(List<int> types) {
  var photos = 0;
  var videos = 0;
  for (final t in types) {
    if (t == 1) {
      photos++;
    } else if (t == 2) {
      videos++;
    }
  }
  return (photos: photos, videos: videos);
}

String previewLabelForAlbumTypes(List<int> types) {
  final counts = countAlbumMediaTypesFromTypes(types);
  return albumPreviewLabel(
    photoCount: counts.photos,
    videoCount: counts.videos,
  );
}

/// Compte photos/vidéos dans une liste de messages album.
({int photos, int videos}) countAlbumMediaTypes(List<LocalMessage> messages) {
  return countAlbumMediaTypesFromTypes(messages.map((m) => m.type).toList());
}

String previewLabelForAlbumMessages(List<LocalMessage> messages) {
  final counts = countAlbumMediaTypes(messages);
  return albumPreviewLabel(
    photoCount: counts.photos,
    videoCount: counts.videos,
  );
}

/// True si [items] forment un album complet (même albumId, tous les indices présents).
bool isCompleteAlbumSelection(List<LocalMessage> items) {
  if (items.length < 2) return false;

  final firstMarker = parseAlbumMarker(items.first.content);
  if (firstMarker == null) return false;

  final albumId = firstMarker.albumId;
  final total = firstMarker.total;
  final senderID = items.first.senderID;
  final indices = <int>{};

  for (final item in items) {
    if (item.type != 1 && item.type != 2) return false;
    if (item.senderID != senderID) return false;
    final marker = parseAlbumMarker(item.content);
    if (marker == null || marker.albumId != albumId || marker.total != total) {
      return false;
    }
    indices.add(marker.index);
  }

  if (indices.length != items.length || items.length != total) return false;
  for (var i = 0; i < total; i++) {
    if (!indices.contains(i)) return false;
  }
  return true;
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
  int photoCount = 0,
  int videoCount = 0,
  String? caption,
}) {
  return encodeAlbumMarker(
    albumId: newAlbumId,
    index: index,
    total: total,
    photoCount: photoCount,
    videoCount: videoCount,
    caption: caption,
  );
}

/// Trie les messages d'un album par index du marqueur.
List<LocalMessage> sortAlbumMessages(List<LocalMessage> messages) {
  return List<LocalMessage>.from(messages)
    ..sort((a, b) {
      final ma = parseAlbumMarker(a.content);
      final mb = parseAlbumMarker(b.content);
      return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
    });
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
