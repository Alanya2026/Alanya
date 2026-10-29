import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';
import '../utils/contact_payload.dart';
import '../utils/forward_message.dart';
import '../utils/location_payload.dart';
import '../utils/sticker_payload.dart';
import 'stickers/sticker_cache.dart';
import 'stickers/sticker_trust.dart';
import 'chat/chat_repository.dart';

/// Partage externe (share sheet OS) — distinct du transfert interne Alanya.
class MessageShareService {
  MessageShareService._();
  static final MessageShareService instance = MessageShareService._();

  /// Partage un message vers une app externe (WhatsApp, Mail, Fichiers…).
  /// Retourne `true` si le sheet système a été ouvert.
  Future<bool> shareMessage({
    required LocalMessage message,
    required ChatRepository repository,
    Rect? shareOrigin,
  }) async {
    if (!canForwardMessage(message)) return false;

    try {
      if (message.type == 0) {
        final text = message.content?.trim();
        if (text == null || text.isEmpty) return false;
        await _shareText(text, shareOrigin: shareOrigin);
        return true;
      }

      if (message.type == 5) {
        final loc = LocationPayload.tryParse(message.content);
        if (loc == null) return false;
        final label = loc.displayLabel;
        final maps =
            'https://maps.google.com/?q=${loc.lat},${loc.lng}';
        await _shareText('$label\n$maps', shareOrigin: shareOrigin);
        return true;
      }

      // Sticker : l'image elle-même (fichier du cache dédié ou téléchargé),
      // jamais le JSON. Repli : « 😂 Sticker » en texte.
      if (message.type == kStickerMessageType) {
        return _shareSticker(message, shareOrigin: shareOrigin);
      }

      if (message.type == 7) {
        final contact = ContactPayload.tryParse(message.content);
        if (contact == null) return false;
        final lines = <String>[contact.displayLabel];
        final phone = contact.alanyaPhone?.trim();
        if (phone != null && phone.isNotEmpty) lines.add(phone);
        final pseudo = contact.pseudo?.trim();
        if (pseudo != null && pseudo.isNotEmpty) lines.add('@$pseudo');
        await _shareText(lines.join('\n'), shareOrigin: shareOrigin);
        return true;
      }

      final local = localMediaFileForForward(message);
      String? path = local?.path;

      if ((path == null || !File(path).existsSync()) &&
          message.mediaUrl != null &&
          message.mediaUrl!.isNotEmpty) {
        path = await repository.ensureReceivedMediaLocal(
          msgID: message.msgID,
          mediaUrl: message.mediaUrl!,
          type: message.type,
          isMine: message.senderID == repository.myId,
          isViewOnce: message.isViewOnce,
          mediaName: message.mediaName,
          existingLocalPath: message.localMediaPath,
        );
      }

      if (path == null || !File(path).existsSync()) return false;

      final name = message.mediaName?.trim().isNotEmpty == true
          ? message.mediaName!.trim()
          : p.basename(path);
      final caption = message.content?.trim();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, name: name)],
          text: (caption != null && caption.isNotEmpty) ? caption : null,
          sharePositionOrigin: shareOrigin,
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('[MessageShare] échec: $e\n$st');
      return false;
    }
  }

  /// Partage hors app d'un sticker : le fichier WebP (cache dédié), jamais le
  /// JSON. Fichier retiré, URL non fiable ou réseau absent : repli en texte
  /// « 😂 Sticker ».
  Future<bool> _shareSticker(LocalMessage message, {Rect? shareOrigin}) async {
    final url = message.mediaUrl;
    // URL non Alanya : on ne télécharge pas, on ne partage pas de fichier.
    final file = !StickerTrust.isTrustedStickerUrl(url)
        ? null
        : await StickerCache.instance.fileFor(url!);
    if (file != null && file.existsSync()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: 'sticker.webp', mimeType: 'image/webp')],
          sharePositionOrigin: shareOrigin,
        ),
      );
      return true;
    }
    await _shareText(stickerPreviewLabel(message.content),
        shareOrigin: shareOrigin);
    return true;
  }

  Future<void> _shareText(String text, {Rect? shareOrigin}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: shareOrigin,
      ),
    );
  }
}
