import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../theme/locale_controller.dart';
import '../../utils/contact_payload.dart';
import '../../utils/location_payload.dart';
import '../../utils/media_album.dart';
import '../../utils/file_metadata.dart';
import '../../utils/media_staging.dart';
import '../../utils/upload_errors.dart';
import '../../utils/document_file_style.dart';
import '../image_thumbnail_service.dart';
import '../music_metadata_service.dart';
import '../pdf_thumbnail_service.dart';
import '../video_thumbnail_service.dart';
import '../../utils/audio_message_kind.dart';
import '../../../talky_api_client.dart' show TalkyException;
import '../../../talky_models.dart';
import 'chat_api.dart';
import 'conversation_merge.dart';
import 'message_path_tracer.dart';
import 'message_ack_watchdog.dart';

/// Envoi de messages (texte, média, album) + emit/upload.
class MessageSender {
  MessageSender({
    required ChatApi api,
    required ChatDao dao,
    required AppDatabase db,
    required int Function() myId,
    required Future<void> Function(int conversationID) recompute,
    required this.uploadProgress,
    required Set<String> inFlightUploads,
    MessageAckWatchdog? ackWatchdog,
  })  : _api = api,
        _dao = dao,
        _db = db,
        _myId = myId,
        _recompute = recompute,
        _inFlightUploads = inFlightUploads,
        _ackWatchdog = ackWatchdog;

  final ChatApi _api;
  final ChatDao _dao;
  final AppDatabase _db;
  final int Function() _myId;
  final Future<void> Function(int conversationID) _recompute;
  final ValueNotifier<Map<String, double>> uploadProgress;
  final Set<String> _inFlightUploads;
  final MessageAckWatchdog? _ackWatchdog;

  static const int maxAlbumItems = 30;

  Future<void> sendText({
    required int conversationID,
    required String content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendText ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final localNow = DateTime.now();
    final now = localNow.toUtc();
    MessagePathTracer.start(clientId);

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId(),
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: const Value(0),
      status: const Value(0),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isStatusReply: Value(isStatusReply),
      isForwarded: Value(isForwarded),
      syncPending: const Value(true),
    ));
    MessagePathTracer.mark(clientId, 'local_insert');

    emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: 0,
      replyToID: replyToID,
      replyToContent: replyToContent,
      isStatusReply: isStatusReply,
      isForwarded: isForwarded,
      clickSentAt: now,
    );
    unawaited(_recompute(conversationID));
  }

  /// Envoi d'une position géographique (`type = 5`, JSON dans content, pas d'upload).
  Future<void> sendLocation({
    required int conversationID,
    required LocationPayload location,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendLocation ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();
    final content = location.encode();

    MessagePathTracer.start(clientId);
    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId(),
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: const Value(5),
      status: const Value(0),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isForwarded: Value(isForwarded),
      syncPending: const Value(true),
    ));
    MessagePathTracer.mark(clientId, 'local_insert');

    emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: 5,
      replyToID: replyToID,
      replyToContent: replyToContent,
      isForwarded: isForwarded,
      clickSentAt: now,
    );
    unawaited(_recompute(conversationID));
  }

  /// Envoi d'un contact partagé (`type = 7`, JSON dans content, pas d'upload).
  Future<void> sendContact({
    required int conversationID,
    required ContactPayload contact,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendContact ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();
    final content = contact.encode();

    MessagePathTracer.start(clientId);
    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId(),
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: const Value(7),
      status: const Value(0),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isForwarded: Value(isForwarded),
      syncPending: const Value(true),
    ));
    MessagePathTracer.mark(clientId, 'local_insert');

    emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: 7,
      replyToID: replyToID,
      replyToContent: replyToContent,
      isForwarded: isForwarded,
      clickSentAt: now,
    );
    unawaited(_recompute(conversationID));
  }

  /// Aperçu canonique pour les messages média : on respecte le `content` saisi
  /// s'il existe, sinon on retombe sur l'emoji + libellé de type. Évite que
  /// l'aperçu de conv affiche un nom de fichier brut (`IMG_2026.jpg`).
  ///
  /// Pour une vue unique, la légende reste réservée à la visionneuse.
  static String previewForMedia(
    int type,
    String? content,
    String? mediaName, {
    bool isViewOnce = false,
  }) =>
      ConversationMerge.previewForMedia(
        type,
        content,
        mediaName,
        isViewOnce: isViewOnce,
      );


  Future<void> sendMedia({
    required int conversationID,
    required int type, // 1=image 2=vidéo 3=audio 4=fichier
    required String mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? mediaSize,
    int? mediaPageCount,
    String? mediaThumb,
    String? localMediaPath,
    String? content,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendMedia ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final localNow = DateTime.now();
    final now = localNow.toUtc();

    // Image / vidéo : réutilise la vignette fournie (transfert) sinon la génère
    // depuis le fichier local si disponible (aperçu destinataire hors DL).
    mediaThumb ??= await _mediaThumbFor(type, localMediaPath);
    MessagePathTracer.start(clientId);

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId(),
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaUrl: Value(mediaUrl),
      mediaName: Value(mediaName),
      mediaDuration: Value(mediaDuration),
      mediaSize: Value(mediaSize),
      mediaPageCount: Value(mediaPageCount),
      mediaThumb: Value(mediaThumb),
      localMediaPath: Value(localMediaPath),
      isForwarded: Value(isForwarded),
      isViewOnce: Value(isViewOnce),
      syncPending: const Value(true),
    ));
    MessagePathTracer.mark(clientId, 'local_insert');

    emitSend(
      clientId: clientId,
      conversationID: conversationID,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaDuration: mediaDuration,
      mediaSize: mediaSize,
      mediaPageCount: mediaPageCount,
      mediaThumb: mediaThumb,
      isForwarded: isForwarded,
      isViewOnce: isViewOnce,
      clickSentAt: now,
    );
    unawaited(_recompute(conversationID));
  }

  Future<void> sendMediaFile({
    required int conversationID,
    required int type, // 1=image 2=vidéo 3=audio 4=fichier
    required File file,
    String? mediaName,
    int? mediaDuration,
    String? content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendMediaFile ignoré : utilisateur non lié (myId=0)');
      return;
    }
    final clientId = _newClientId();
    final now = DateTime.now().toUtc();
    File uploadFile;
    try {
      uploadFile = file.path.contains('talky_outbox')
          ? file
          : await stageMediaFile(file);
    } catch (e) {
      debugPrint('[MessageSender] sendMediaFile staging échoué: $e');
      return;
    }
    final name = mediaName ?? uploadFile.path.split('/').last;

    final isMusic =
        type == 3 && audioKindFromName(name) == AudioMessageKind.music;

    int? fileMediaSize;
    int? fileMediaPageCount;
    // La musique affiche sa taille en sous-titre de bulle, comme un document.
    if (type == 4 || isMusic) {
      final meta = await fileMetadataForSend(uploadFile, mediaName: name);
      if (meta.size > 0) fileMediaSize = meta.size;
      fileMediaPageCount = meta.pageCount;
    }

    // Image / vidéo / pochette : mini-vignette base64 pour l'aperçu
    // destinataire (hors téléchargement).
    final mediaThumb =
        await _mediaThumbFor(type, uploadFile.path, mediaName: name);
    MessagePathTracer.start(clientId);

    await _dao.upsertMessage(LocalMessagesCompanion.insert(
      clientId: clientId,
      conversationID: conversationID,
      senderID: _myId(),
      sendAt: now,
      clickSentAt: Value(now),
      content: Value(content),
      type: Value(type),
      status: const Value(0),
      mediaName: Value(name),
      mediaDuration: Value(mediaDuration),
      mediaSize: Value(fileMediaSize),
      mediaPageCount: Value(fileMediaPageCount),
      mediaThumb: Value(mediaThumb),
      localMediaPath: Value(uploadFile.path),
      pendingUploadPath: Value(uploadFile.path),
      replyToID: Value(replyToID),
      replyToContent: Value(replyToContent),
      isStatusReply: Value(isStatusReply),
      isForwarded: Value(isForwarded),
      isViewOnce: Value(isViewOnce),
      syncPending: const Value(true),
    ));
    MessagePathTracer.mark(clientId, 'local_insert');
    unawaited(_recompute(conversationID));

    try {
      await uploadAndEmit(
        clientId: clientId,
        conversationID: conversationID,
        file: uploadFile,
        type: type,
        content: content,
        mediaName: name,
        mediaDuration: mediaDuration,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
        clickSentAt: now,
      );
    } catch (e) {
      await handleUploadFailure(clientId, e, 'upload média échoué');
    }
  }

  /// Envoie plusieurs documents / morceaux : **un message par fichier**, sans
  /// regroupement (le marqueur d'album ne décrit que des photos et vidéos).
  ///
  /// Les lignes locales sont toutes insérées d'abord pour que les bulles
  /// apparaissent d'un coup, puis les uploads partent en parallèle limité.
  Future<void> sendMediaFiles({
    required int conversationID,
    required List<AlbumSendItem> items,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendMediaFiles ignoré : utilisateur non lié (myId=0)');
      return;
    }
    if (items.isEmpty) return;
    if (items.length == 1) {
      final item = items.first;
      await sendMediaFile(
        conversationID: conversationID,
        type: item.type,
        file: item.file,
        mediaName: item.mediaName,
        mediaDuration: item.duration,
      );
      return;
    }

    final base = DateTime.now().toUtc();
    final pending = <_PendingMediaUpload>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      File uploadFile;
      try {
        uploadFile = item.file.path.contains('talky_outbox')
            ? item.file
            : await stageMediaFile(item.file);
      } catch (e) {
        debugPrint('[MessageSender] sendMediaFiles staging échoué: $e');
        continue;
      }

      final clientId = _newClientId();
      // Horodatage strictement croissant : préserve l'ordre de sélection.
      final now = base.add(Duration(milliseconds: i));
      final name = item.mediaName ?? uploadFile.path.split('/').last;
      final isMusic =
          item.type == 3 && audioKindFromName(name) == AudioMessageKind.music;

      int? fileMediaSize;
      int? fileMediaPageCount;
      // La musique affiche sa taille en sous-titre de bulle, comme un document.
      if (item.type == 4 || isMusic) {
        final meta = await fileMetadataForSend(uploadFile, mediaName: name);
        if (meta.size > 0) fileMediaSize = meta.size;
        fileMediaPageCount = meta.pageCount;
      }

      final mediaThumb =
          await _mediaThumbFor(item.type, uploadFile.path, mediaName: name);
      MessagePathTracer.start(clientId);

      await _dao.upsertMessage(LocalMessagesCompanion.insert(
        clientId: clientId,
        conversationID: conversationID,
        senderID: _myId(),
        sendAt: now,
        clickSentAt: Value(now),
        type: Value(item.type),
        status: const Value(0),
        mediaName: Value(name),
        mediaDuration: Value(item.duration),
        mediaSize: Value(fileMediaSize),
        mediaPageCount: Value(fileMediaPageCount),
        mediaThumb: Value(mediaThumb),
        localMediaPath: Value(uploadFile.path),
        pendingUploadPath: Value(uploadFile.path),
        syncPending: const Value(true),
      ));
      MessagePathTracer.mark(clientId, 'local_insert');

      pending.add(_PendingMediaUpload(
        clientId: clientId,
        file: uploadFile,
        type: item.type,
        mediaName: name,
        mediaDuration: item.duration,
        clickSentAt: now,
      ));
    }

    unawaited(_recompute(conversationID));

    await _runConcurrent(pending, 3, (p) async {
      try {
        await uploadAndEmit(
          clientId: p.clientId,
          conversationID: conversationID,
          file: p.file,
          type: p.type,
          mediaName: p.mediaName,
          mediaDuration: p.mediaDuration,
          clickSentAt: p.clickSentAt,
        );
      } catch (e) {
        await handleUploadFailure(p.clientId, e, 'upload fichier échoué');
      }
    });
  }

  /// Envoie plusieurs photos/vidéos regroupées en album (marqueur dans `content`).
  ///
  /// [content] est la légende optionnelle (stockée sur le premier item).
  Future<void> sendMediaAlbum({
    required int conversationID,
    required List<AlbumSendItem> items,
    String? content,
    bool isForwarded = false,
  }) async {
    if (_myId() == 0) {
      debugPrint('[MessageSender] sendMediaAlbum ignoré : utilisateur non lié (myId=0)');
      return;
    }
    if (items.isEmpty) return;
    final caption = content?.trim();
    final effectiveCaption =
        caption != null && caption.isNotEmpty ? caption : null;
    if (items.length == 1) {
      final item = items.first;
      await sendMediaFile(
        conversationID: conversationID,
        type: item.type,
        file: item.file,
        mediaName: item.mediaName,
        mediaDuration: item.duration,
        content: effectiveCaption,
        isForwarded: isForwarded,
      );
      return;
    }

    final albumId = newAlbumId();
    final total = items.length;
    final localNow = DateTime.now();
    final now = localNow.toUtc();
    final types = items.map((e) => e.type).toList();
    final counts = countAlbumMediaTypesFromTypes(types);

    final pending = <_PendingMediaUpload>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final clientId = _newClientId();
      final name = item.mediaName ?? item.file.path.split('/').last;
      final marker = encodeAlbumMarker(
        albumId: albumId,
        index: i,
        total: total,
        photoCount: counts.photos,
        videoCount: counts.videos,
        caption: effectiveCaption,
      );

      final mediaThumb = await _mediaThumbFor(item.type, item.file.path);
      MessagePathTracer.start(clientId);

      await _dao.upsertMessage(LocalMessagesCompanion.insert(
        clientId: clientId,
        conversationID: conversationID,
        senderID: _myId(),
        sendAt: now,
        clickSentAt: Value(now),
        content: Value(marker),
        type: Value(item.type),
        status: const Value(0),
        mediaName: Value(name),
        mediaDuration: Value(item.duration),
        mediaThumb: Value(mediaThumb),
        localMediaPath: Value(item.file.path),
        pendingUploadPath: Value(item.file.path),
        isForwarded: Value(isForwarded),
        syncPending: const Value(true),
      ));
      MessagePathTracer.mark(clientId, 'local_insert');

      pending.add(_PendingMediaUpload(
        clientId: clientId,
        file: item.file,
        type: item.type,
        content: marker,
        mediaName: name,
        mediaDuration: item.duration,
        isForwarded: isForwarded,
        clickSentAt: now,
      ));
    }

    unawaited(_recompute(conversationID));

    await _runConcurrent(pending, 3, (p) async {
      try {
        await uploadAndEmit(
          clientId: p.clientId,
          conversationID: conversationID,
          file: p.file,
          type: p.type,
          content: p.content,
          mediaName: p.mediaName,
          mediaDuration: p.mediaDuration,
          isForwarded: p.isForwarded,
          clickSentAt: p.clickSentAt,
        );
      } catch (e) {
        await handleUploadFailure(p.clientId, e, 'upload album item échoué');
      }
    });
  }

  void _setUploadProgress(String clientId, double? progress) {
    final next = Map<String, double>.from(uploadProgress.value);
    if (progress == null) {
      next.remove(clientId);
    } else {
      next[clientId] = progress.clamp(0.0, 1.0);
    }
    uploadProgress.value = next;
  }


  Future<File?> resolvePendingUploadFile(LocalMessage m) async {
    final pending = m.pendingUploadPath;
    if (pending != null && pending.isNotEmpty) {
      final f = File(pending);
      if (f.existsSync()) return f;
    }
    final local = m.localMediaPath;
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (f.existsSync()) {
        try {
          return await stageMediaFile(f);
        } catch (e) {
          debugPrint('[MessageSender] re-stage échoué: $e');
        }
      }
    }
    return null;
  }

  Future<void> uploadAndEmit({
    required String clientId,
    required int conversationID,
    required File file,
    required int type,
    String? content,
    String? mediaName,
    int? mediaDuration,
    bool isForwarded = false,
    bool isViewOnce = false,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    DateTime? clickSentAt,
  }) async {
    if (!_inFlightUploads.add(clientId)) {
      debugPrint('[MessageSender] upload déjà en cours pour $clientId');
      return;
    }
    try {
      var attempt429 = 0;
      while (true) {
        try {
          final res = await _api.uploadMedia(
            file,
            onProgress: (p) => _setUploadProgress(clientId, p),
          );
          _setUploadProgress(clientId, null);
          final url = res['url'] as String?;
          if (url == null) {
            throw Exception(LocaleController.instance.l10n.invalidUploadResponse);
          }

          await (_db.update(_db.localMessages)..where((m) => m.clientId.equals(clientId)))
              .write(LocalMessagesCompanion(
            mediaUrl: Value(url),
            pendingUploadPath: const Value(null),
          ));

          // Vignette base64 déjà générée et stockée à l'insertion (image/vidéo) :
          // on la relit pour la transmettre au destinataire.
          final row = await (_db.select(_db.localMessages)
                ..where((m) => m.clientId.equals(clientId)))
              .getSingleOrNull();

          emitSend(
            clientId: clientId,
            conversationID: conversationID,
            content: content,
            type: type,
            mediaUrl: url,
            mediaName: mediaName,
            mediaDuration: mediaDuration,
            mediaSize: row?.mediaSize,
            mediaPageCount: row?.mediaPageCount,
            mediaThumb: row?.mediaThumb,
            replyToID: replyToID,
            replyToContent: replyToContent,
            isStatusReply: isStatusReply,
            isForwarded: isForwarded,
            isViewOnce: isViewOnce,
            // Sans ce champ, les médias (photo/vidéo) envoyés via upload de
            // fichier n'avaient jamais de clickSentAt : la ligne « Appui sur
            // envoyer » restait vide côté destinataire. On retombe sur
            // `row?.clickSentAt` (valeur locale déjà persistée à l'insertion)
            // si l'appelant ne l'a pas fournie explicitement.
            clickSentAt: clickSentAt ?? row?.clickSentAt,
          );
          return;
        } catch (e) {
          _setUploadProgress(clientId, null);
          if (e is TalkyException && e.statusCode == 429 && attempt429 < 2) {
            attempt429++;
            await Future.delayed(Duration(seconds: attempt429 == 1 ? 2 : 5));
            continue;
          }
          rethrow;
        }
      }
    } finally {
      _inFlightUploads.remove(clientId);
    }
  }

  void emitPendingMessage(LocalMessage m) {
    emitSend(
      clientId: m.clientId,
      conversationID: m.conversationID,
      content: m.content,
      type: m.type,
      mediaUrl: m.mediaUrl,
      mediaName: m.mediaName,
      mediaDuration: m.mediaDuration,
      mediaSize: m.mediaSize,
      mediaPageCount: m.mediaPageCount,
      mediaThumb: m.mediaThumb,
      replyToID: m.replyToID,
      replyToContent: m.replyToContent,
      isStatusReply: m.isStatusReply,
      isForwarded: m.isForwarded,
      isViewOnce: m.isViewOnce,
      clickSentAt: m.clickSentAt,
    );
  }

  Future<void> handleUploadFailure(
    String clientId,
    Object e,
    String logLabel,
  ) async {
    debugPrint('[MessageSender] $logLabel: $e');
    if (isTransientUploadError(e)) {
      debugPrint('[MessageSender] upload différé — pending intact pour rejeu');
    } else {
      await _dao.markFailed(clientId);
    }
  }

  Future<void> _runConcurrent<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) fn,
  ) async {
    if (items.isEmpty) return;
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index;
        if (i >= items.length) return;
        index++;
        await fn(items[i]);
      }
    }
    final workers = concurrency.clamp(1, items.length);
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  /// Vignette base64 : image (1), vidéo (2), PDF fichier (4), pochette d'un
  /// morceau (3 + nom de fichier musical).
  ///
  /// [mediaName] et non [path] décide du sort d'un audio : un vocal est stagé
  /// en `voice_<timestamp>.m4a` et son extension le ferait passer pour de la
  /// musique.
  Future<String?> _mediaThumbFor(
    int type,
    String? path, {
    String? mediaName,
  }) async {
    if (path == null || path.isEmpty) return null;
    if (type == 1) return ImageThumbnailService.base64ForFile(path);
    if (type == 2) return VideoThumbnailService.base64ForFile(path);
    if (type == 3 && audioKindFromName(mediaName) == AudioMessageKind.music) {
      return MusicMetadataService.coverBase64(path);
    }
    if (type == 4 && DocumentFileStyle.fromFileName(path).isPdf) {
      return PdfThumbnailService.base64ForFile(path);
    }
    return null;
  }

  void emitSend({
    required String clientId,
    required int conversationID,
    String? content,
    required int type,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? mediaSize,
    int? mediaPageCount,
    String? mediaThumb,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
    DateTime? clickSentAt,
  }) {
    // Garde stricte : tant que le socket n'est pas authentifié, le serveur
    // ignore l'emit silencieusement. On laisse la ligne `syncPending=true` ;
    // `flushOutbox` (texte ET média déjà uploadé) la rejouera quand
    // `auth:verified` aura déclenché _onSocketReady.
    if (!_api.isSocketReady) {
      debugPrint('[MessageSender] _emitSend différé (socket non prêt) clientId=$clientId');
      return;
    }
    MessagePathTracer.mark(clientId, 'socket_emit');
    _api.sendSocketEvent(SocketEvents.messageSend, {
      'clientId': clientId,
      'conversationID': conversationID,
      if (content != null) 'content': content,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaName != null) 'mediaName': mediaName,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (mediaSize != null) 'mediaSize': mediaSize,
      if (mediaPageCount != null) 'mediaPageCount': mediaPageCount,
      if (mediaThumb != null) 'mediaThumb': mediaThumb,
      if (replyToID != null && replyToID > 0) 'replyToID': replyToID,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (isStatusReply != 0) 'isStatusReply': isStatusReply,
      if (isForwarded) 'isForwarded': 1,
      if (isViewOnce) 'isViewOnce': 1,
      if (clickSentAt != null) 'clickSentAt': clickSentAt.toIso8601String(),
    });
    // Marque la ligne comme « tout juste émise » → backoff outbox.
    _dao.touchEmitted(clientId);
    _ackWatchdog?.arm(clientId, conversationID);
  }



  String _newClientId() =>
      'c_${_myId()}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';
}

class _PendingMediaUpload {
  const _PendingMediaUpload({
    required this.clientId,
    required this.file,
    required this.type,
    required this.mediaName,
    required this.clickSentAt,
    this.content,
    this.mediaDuration,
    this.isForwarded = false,
  });

  final String clientId;
  final File file;
  final int type;
  /// Marqueur d'album, ou `null` pour un envoi fichier par fichier.
  final String? content;
  final String mediaName;
  final int? mediaDuration;
  final bool isForwarded;
  final DateTime clickSentAt;
}
