import 'dart:io';

import '../db/app_database.dart';
import '../services/chat_repository.dart';
import '../../screens/chats/media_viewer_screen.dart';

/// Prépare les [MediaViewerItem] pour la visionneuse (cache vidéo inclus).
Future<List<MediaViewerItem>> buildMediaViewerItems(
  List<LocalMessage> messages,
  ChatRepository repo, {
  int? loadingForIndex,
  void Function()? onLoadingVideo,
  void Function()? onLoadingDone,
}) async {
  final prepared = <MediaViewerItem>[];
  for (var i = 0; i < messages.length; i++) {
    final msg = messages[i];
    String? localPath =
        (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
            ? msg.localMediaPath
            : null;

    final isVideo = msg.type == 2;
    if (isVideo && localPath == null && msg.mediaUrl != null) {
      if (loadingForIndex != null && i == loadingForIndex) {
        onLoadingVideo?.call();
      }
      localPath = await repo.mediaCache.ensureCached(msg.mediaUrl!);
      if (localPath != null && msg.msgID != 0) {
        await repo.dao.setLocalMediaPath(msg.msgID, localPath);
      }
      if (loadingForIndex != null && i == loadingForIndex) {
        onLoadingDone?.call();
      }
    }

    prepared.add(MediaViewerItem(
      isVideo: isVideo,
      localPath: localPath,
      networkUrl: msg.mediaUrl,
      title: msg.mediaName,
    ));
  }
  return prepared;
}
