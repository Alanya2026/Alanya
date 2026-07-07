import 'dart:io';

import 'package:flutter/foundation.dart';

import '../db/chat_dao.dart';
import 'media_cache_service.dart';

enum VoiceLocalSource { dbPath, pendingUpload, mediaCache }

class VoiceLocalFile {
  final String path;
  final VoiceLocalSource source;

  const VoiceLocalFile({required this.path, required this.source});
}

/// Résout de façon déterministe le fichier audio local d'un message vocal.
class VoiceAssetResolver {
  VoiceAssetResolver({
    required MediaCacheService mediaCache,
    required ChatDao dao,
  })  : _mediaCache = mediaCache,
        _dao = dao;

  final MediaCacheService _mediaCache;
  final ChatDao _dao;

  static bool fileExists(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  Future<VoiceLocalFile?> resolve({
    required int serverMsgId,
    required bool isMe,
    String? dbPath,
    String? pendingPath,
    String? mediaUrl,
  }) async {
    if (fileExists(dbPath)) {
      return VoiceLocalFile(path: dbPath!, source: VoiceLocalSource.dbPath);
    }

    if (dbPath != null && dbPath.isNotEmpty && serverMsgId != 0) {
      await _dao.clearLocalMediaPath(serverMsgId);
    }

    if (isMe && fileExists(pendingPath)) {
      return VoiceLocalFile(
        path: pendingPath!,
        source: VoiceLocalSource.pendingUpload,
      );
    }

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        final cached = await _mediaCache.cachedPathFor(mediaUrl);
        if (fileExists(cached)) {
          if (serverMsgId != 0) {
            await _dao.setLocalMediaPath(serverMsgId, cached!);
          }
          return VoiceLocalFile(
            path: cached!,
            source: VoiceLocalSource.mediaCache,
          );
        }
      } catch (e) {
        debugPrint('[VoiceAssetResolver] cache lookup échoué: $e');
      }
    }

    return null;
  }
}
