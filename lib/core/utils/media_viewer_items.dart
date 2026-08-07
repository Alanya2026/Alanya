import 'dart:io';

import '../db/app_database.dart';
import '../services/chat/chat_repository.dart';
import '../../screens/chats/media_viewer_screen.dart';

/// Prépare les [MediaViewerItem] pour la visionneuse (cache + export inclus).
///
/// Ne télécharge que l'élément focal ([loadingForIndex]) s'il manque en local.
/// Les autres items restent en URL réseau / chemin déjà connu — évite de
/// télécharger tout un album dès l'ouverture d'une seule photo.
Future<List<MediaViewerItem>> buildMediaViewerItems(
  List<LocalMessage> messages,
  ChatRepository repo, {
  int? loadingForIndex,
  void Function()? onLoadingVideo,
  void Function()? onLoadingDone,
  int? myId,
}) async {
  final prepared = <MediaViewerItem>[];
  for (var i = 0; i < messages.length; i++) {
    final msg = messages[i];
    String? localPath =
        (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
            ? msg.localMediaPath
            : null;

    final canPersist = !msg.isViewOnce &&
        (msg.type == 1 || msg.type == 2 || msg.type == 4) &&
        msg.msgID != 0;
    final isFocused =
        loadingForIndex == null ? messages.length == 1 : i == loadingForIndex;

    if (canPersist && localPath != null) {
      // Déjà en cache : export appareil idempotent (reçus uniquement).
      final isMine = myId != null && msg.senderID == myId;
      await repo.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl ?? '',
        type: msg.type,
        isMine: isMine,
        isViewOnce: false,
        mediaName: msg.mediaName,
        existingLocalPath: localPath,
      );
    } else if (canPersist &&
        localPath == null &&
        isFocused &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty) {
      final showLoader = true;
      if (showLoader) onLoadingVideo?.call();
      final isMine = myId != null && msg.senderID == myId;
      final resolved = await repo.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl!,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (resolved != null) localPath = resolved;
      if (showLoader) onLoadingDone?.call();
    }

    prepared.add(MediaViewerItem(
      isVideo: msg.type == 2,
      localPath: localPath,
      networkUrl: msg.mediaUrl,
      title: msg.mediaName,
      msgID: msg.msgID,
      // Une vue unique ne laisse aucune trace : pas d'enregistrement possible.
      canSave: !msg.isViewOnce,
    ));
  }
  return prepared;
}
