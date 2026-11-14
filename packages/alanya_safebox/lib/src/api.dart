// Coffre-fort : routes `/api/safebox` et transferts directs vers le stockage.
//
// Conception : backend/docs/conception/coffre-fort.html. Le serveur ne voit
// passer aucun octet de fichier : il réserve l'espace et signe des adresses ;
// les blocs vont et viennent directement entre l'appareil et le stockage.
//
// [SafeboxCalls] s'ajoute au client de chaque application (`with
// SafeboxCalls`), qui fournit [SafeboxCalls.safeboxHttp].

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cipher.dart';
import 'http.dart';
import 'models.dart';
import 'upload_stall_guard.dart';

mixin SafeboxCalls {
  SafeboxHttp get safeboxHttp;

  Future<Map<String, dynamic>> _json(String method, String path, {Map<String, String>? query, Object? body}) async {
    final data = await safeboxHttp.send(method, path, query: query, body: body);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Ouvre le coffre : espace, dossiers racines (créés à la première visite), limites.
  Future<SafeboxOverview> fetchSafebox() async => SafeboxOverview.fromJson(await _json('GET', ''));

  Future<SafeboxFolderPage> fetchSafeboxFolder(int folderId, {int? cursor}) async => SafeboxFolderPage.fromJson(
        await _json('GET', '/folders/$folderId', query: cursor == null ? null : {'cursor': '$cursor'}),
      );

  /// Les albums de l'accueil en une demande : les derniers remplis.
  Future<List<SafeboxRecentAlbum>> fetchSafeboxRecentAlbums({int limit = 3}) async =>
      SafeboxRecentAlbum.listFromJson(await _json('GET', '/albums/recent', query: {'limit': '$limit'}));

  Future<SafeboxFolder> createSafeboxFolder({required int parentId, required String name}) async =>
      SafeboxFolder.fromJson(await _json('POST', '/folders', body: {'parentId': parentId, 'name': name}));

  Future<SafeboxFolder> updateSafeboxFolder(int folderId, {String? name, int? parentId}) async =>
      SafeboxFolder.fromJson(await _json('PATCH', '/folders/$folderId', body: {
        if (name != null) 'name': name,
        if (parentId != null) 'parentId': parentId,
      }));

  Future<void> trashSafeboxFolder(int folderId) => _json('DELETE', '/folders/$folderId');

  Future<SafeboxFolder> restoreSafeboxFolder(int folderId) async =>
      SafeboxFolder.fromJson(await _json('POST', '/folders/$folderId/restore'));

  Future<SafeboxFile> updateSafeboxFile(int fileId, {String? name, int? folderId}) async =>
      SafeboxFile.fromJson(await _json('PATCH', '/files/$fileId', body: {
        if (name != null) 'name': name,
        if (folderId != null) 'folderId': folderId,
      }));

  /// À la corbeille : cet exemplaire, ou avec [everywhere] tous les
  /// exemplaires du même contenu dans le coffre (Photos et albums).
  Future<void> trashSafeboxFile(int fileId, {bool everywhere = false}) =>
      _json('DELETE', '/files/$fileId', query: everywhere ? {'everywhere': '1'} : null);

  /// Ajoute des fichiers du coffre à un album, sans copie. Rend leurs
  /// exemplaires dans l'album.
  Future<List<SafeboxFile>> addSafeboxFilesToFolder(int folderId, List<int> fileIds) async {
    final r = await _json('POST', '/folders/$folderId/files', body: {'fileIds': fileIds});
    final liste = r['files'] is List ? r['files'] as List : const [];
    return liste.whereType<Map>().map((e) => SafeboxFile.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ── Commentaire d'une photo (privé) ──────────────────────────────────────

  /// Texte du commentaire ; null ou vide l'efface. Rend le commentaire, ou null.
  Future<SafeboxNote?> setSafeboxNoteText(int fileId, String? text) async =>
      SafeboxNote.fromJson((await _json('PUT', '/files/$fileId/note', body: {'text': text}))['note']);

  /// Réserve la place de l'audio (5 minutes au plus) : adresse d'envoi à taille exacte.
  Future<String> reserveSafeboxNoteAudio(int fileId, {required int size, required int plainSize, required int durationMs}) async =>
      '${(await _json('POST', '/files/$fileId/note/audio', body: {'size': size, 'plainSize': plainSize, 'durationMs': durationMs}))['url']}';

  Future<SafeboxNote?> completeSafeboxNoteAudio(int fileId, Uint8List key) async => SafeboxNote.fromJson(
        (await _json('POST', '/files/$fileId/note/audio/complete', body: {'key': base64Encode(key)}))['note'],
      );

  Future<SafeboxNote?> deleteSafeboxNoteAudio(int fileId) async =>
      SafeboxNote.fromJson((await _json('DELETE', '/files/$fileId/note/audio'))['note']);

  Future<SafeboxFile> restoreSafeboxFile(int fileId) async =>
      SafeboxFile.fromJson(await _json('POST', '/files/$fileId/restore'));

  /// Les plus gros fichiers du coffre et le poids de la corbeille
  /// (« Libérer de l'espace »).
  Future<({List<SafeboxFile> files, int trashBytes})> fetchSafeboxLargest({int limit = 50}) async {
    final j = await _json('GET', '/largest', query: {'limit': '$limit'});
    return (
      files: (j['files'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SafeboxFile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      trashBytes: (j['trashBytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Clé du fichier et adresses de lecture de tous ses blocs (15 minutes).
  Future<SafeboxDownloadPlan> fetchSafeboxDownload(int fileId) async =>
      SafeboxDownloadPlan.fromJson(await _json('GET', '/files/$fileId/download'));

  /// Réserve l'espace d'un fichier ; rend la taille des blocs et les premières adresses.
  Future<SafeboxUploadTicket> reserveSafeboxUpload({
    required int folderId,
    required String name,
    required String? mime,
    required int size,
    required int plainSize,
    required String cipherFormat,
    int? originalSize,
    bool compressed = false,
    String? quality,
    int previewSize = 0,
    Map<String, dynamic>? meta,
    String? sourceFp,
  }) async =>
      SafeboxUploadTicket.fromJson(await _json('POST', '/uploads', body: {
        'folderId': folderId,
        'name': name,
        'mime': mime,
        'size': size,
        'plainSize': plainSize,
        'cipherFormat': cipherFormat,
        if (originalSize != null) 'originalSize': originalSize,
        'compressed': compressed,
        if (quality != null) 'quality': quality,
        'previewSize': previewSize,
        if (meta != null && meta.isNotEmpty) 'meta': meta,
        'sourceFp': ?sourceFp,
      }));

  /// Blocs déjà reçus par le stockage, pour reprendre un envoi.
  Future<SafeboxUploadStatus> fetchSafeboxUploadStatus(int fileId) async =>
      SafeboxUploadStatus.fromJson(await _json('GET', '/uploads/$fileId/blocks'));

  /// Adresses d'envoi de blocs choisis (64 au plus) et, au besoin, de l'aperçu.
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> fetchSafeboxUploadUrls(
    int fileId, {
    List<int> blocks = const [],
    bool preview = false,
  }) async {
    final j = await _json('POST', '/uploads/$fileId/blocks', body: {'blocks': blocks, if (preview) 'preview': true});
    return (
      blocks: (j['blocks'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SafeboxSignedBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      preview: j['preview'] is Map ? SafeboxSignedBlock.fromJson(Map<String, dynamic>.from(j['preview'] as Map)) : null,
    );
  }

  /// Termine l'envoi : le serveur vérifie chaque bloc et range la clé.
  Future<SafeboxFile> completeSafeboxUpload(int fileId, Uint8List key) async =>
      SafeboxFile.fromJson(await _json('POST', '/uploads/$fileId/complete', body: {'key': base64Encode(key)}));

  Future<void> cancelSafeboxUpload(int fileId) => _json('DELETE', '/uploads/$fileId');

  Future<SafeboxTrash> fetchSafeboxTrash() async => SafeboxTrash.fromJson(await _json('GET', '/trash'));

  Future<void> emptySafeboxTrash() => _json('DELETE', '/trash');

  Future<void> deleteTrashedSafeboxFile(int fileId) => _json('DELETE', '/trash/files/$fileId');

  Future<void> deleteTrashedSafeboxFolder(int folderId) => _json('DELETE', '/trash/folders/$folderId');

  // ── Partage entre inscrits ───────────────────────────────────────────────

  /// Partage dans une discussion dont je suis membre : un fichier
  /// ([fileId]), plusieurs en un seul message ([fileIds], avec un [title]) ou
  /// un album ([folderId]). Plusieurs fichiers font un lot, une seule carte.
  Future<SafeboxShareCreated> createSafeboxShare({
    required int conversationId,
    int? fileId,
    List<int>? fileIds,
    int? folderId,
    String? title,
  }) async =>
      SafeboxShareCreated.fromJson(await _json('POST', '/shares', body: {
        'conversationId': conversationId,
        'fileId': ?fileId,
        'fileIds': ?fileIds,
        'folderId': ?folderId,
        'title': ?title,
      }));

  /// La carte : disponible ou retiré, expéditeur, aperçu, clé ; mosaïque
  /// d'un lot ; suivi pour l'expéditeur.
  Future<SafeboxShareInfo> fetchSafeboxShare(int shareId) async =>
      SafeboxShareInfo.fromJson(await _json('GET', '/shares/$shareId'));

  /// Les éléments d'un partage, par pages de 100 ; un fichier seul est l'élément 0.
  Future<SafeboxShareItemsPage> fetchSafeboxShareItems(int shareId, {int? cursor}) async => SafeboxShareItemsPage.fromJson(
        shareId,
        await _json('GET', '/shares/$shareId/items', query: cursor == null ? null : {'cursor': '$cursor'}),
      );

  /// Clé et adresses des blocs d'un fichier reçu, ou d'un élément d'un lot
  /// ([itemId]).
  Future<SafeboxDownloadPlan> fetchSafeboxShareDownload(int shareId, {int itemId = 0}) async => SafeboxDownloadPlan.fromJson(
        await _json('GET', '/shares/$shareId/download', query: itemId == 0 ? null : {'item': '$itemId'}),
      );

  /// Garde un fichier reçu, ou un élément d'un lot ([itemId]), dans mon coffre
  /// (aucune copie dans le stockage).
  Future<SafeboxFile> saveSafeboxShare(int shareId, {int itemId = 0, int? folderId}) async => SafeboxFile.fromJson(
        await _json('POST', '/shares/$shareId/save', body: {if (itemId != 0) 'itemId': itemId, 'folderId': ?folderId}),
      );

  /// Garde un lot entier : il devient un album dans mes Albums.
  Future<SafeboxFolder> saveSafeboxShareBatch(int shareId) async {
    final r = await _json('POST', '/shares/$shareId/save', body: const <String, dynamic>{});
    return SafeboxFolder.fromJson(Map<String, dynamic>.from(r['folder'] as Map));
  }

  /// L'onglet « Reçus », du plus récent au plus ancien.
  Future<SafeboxReceivedPage> fetchReceivedSafeboxShares({int? cursor}) async => SafeboxReceivedPage.fromJson(
        await _json('GET', '/shares/received', query: cursor == null ? null : {'cursor': '$cursor'}),
      );

  /// Le suivi d'un partage, pour son expéditeur.
  Future<SafeboxShareRecipients> fetchSafeboxShareRecipients(int shareId) async =>
      SafeboxShareRecipients.fromJson(await _json('GET', '/shares/$shareId/recipients'));

  /// « Retirer le partage » : la carte dira « retiré par l'expéditeur ».
  Future<void> revokeSafeboxShare(int shareId) =>
      _json('POST', '/shares/$shareId/revoke', body: const <String, dynamic>{});

  // ── Sauvegarde automatique (lot 10) ──────────────────────────────────────

  /// Ce que le coffre a de ces originaux (empreintes) ; `link` ajoute sans
  /// copie au dossier de son type ce qui n'est qu'ailleurs.
  Future<Map<String, String>> checkSafeboxBackup(List<String> fps, {bool link = true}) async {
    final r = await _json('POST', '/backup/check', body: {'fps': fps, 'link': link});
    final res = r['results'] is Map ? r['results'] as Map : const {};
    return {
      for (final e in res.entries)
        if (e.value is Map) '${e.key}': '${(e.value as Map)['state']}',
    };
  }

  /// Comme [checkSafeboxBackup], avec `original` : une copie du coffre est en
  /// qualité Original (null : serveur d'avant le 11/11/2026).
  Future<Map<String, ({String state, bool? original})>> checkSafeboxBackupQuality(List<String> fps,
      {bool link = true}) async {
    final r = await _json('POST', '/backup/check', body: {'fps': fps, 'link': link});
    final res = r['results'] is Map ? r['results'] as Map : const {};
    return {
      for (final e in res.entries)
        if (e.value is Map)
          '${e.key}': (
            state: '${(e.value as Map)['state']}',
            original: (e.value as Map)['original'] is bool ? (e.value as Map)['original'] as bool : null,
          ),
    };
  }

  /// Comme [checkSafeboxBackup], avec le fichier du coffre qui a déjà ce
  /// contenu (`saved`, `elsewhere`) : l'application de bureau l'ajoute sans
  /// copie à un album au lieu de le renvoyer.
  Future<Map<String, ({String state, int? fileId})>> checkSafeboxSources(List<String> fps, {bool link = false}) async {
    final r = await _json('POST', '/backup/check', body: {'fps': fps, 'link': link});
    final res = r['results'] is Map ? r['results'] as Map : const {};
    return {
      for (final e in res.entries)
        if (e.value is Map)
          '${e.key}': (
            state: '${(e.value as Map)['state']}',
            fileId: (e.value as Map)['fileId'] is num ? ((e.value as Map)['fileId'] as num).toInt() : null,
          ),
    };
  }

  /// « Ne plus sauvegarder » ces originaux.
  Future<void> skipSafeboxBackup(List<String> fps) => _json('POST', '/backup/skip', body: {'fps': fps});

  // ── Transferts directs vers le stockage ──────────────────────────────────
  //
  // Le jeton de l'API n'est jamais joint : l'adresse signée suffit, et le
  // jeton n'a rien à faire chez un tiers. Un transfert qui n'avance plus
  // pendant [SafeboxHttp.stallTimeout] est coupé (statut 0) : l'appelant
  // réessaie.

  /// Envoie un bloc chiffré à son adresse signée. La taille est signée : un
  /// corps d'une autre taille est refusé (403).
  /// [cancel] : se complète pour couper l'envoi tout de suite (pause, annulation).
  Future<void> putSafeboxBlock(
    String url,
    Uint8List bytes, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final h = safeboxHttp;
    final guard = UploadStallGuard(stallTimeout: h.stallTimeout);
    unawaited(cancel?.then((_) => guard.abortNow()));
    final request = http.AbortableStreamedRequest('PUT', Uri.parse(url), abortTrigger: guard.abortTrigger);
    request.contentLength = bytes.length;
    const tranche = 64 * 1024;
    var envoye = 0;
    unawaited(() async {
      try {
        for (var i = 0; i < bytes.length; i += tranche) {
          final fin = i + tranche < bytes.length ? i + tranche : bytes.length;
          request.sink.add(Uint8List.sublistView(bytes, i, fin));
          envoye = fin;
          guard.tick();
          onProgress?.call(envoye);
          // Laisse la main : sans cela, tout le bloc part dans le tampon d'un
          // coup et la progression comme la surveillance ne voient rien.
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        await request.sink.close();
      }
    }());
    final response = await _sendGuarded(h, request, guard);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw h.transferFailure(SafeboxTransferFailure.rejected, status: response.statusCode, code: 'SAFEBOX_BLOCK_REJECTED');
    }
  }

  /// Lit un bloc chiffré depuis [from] (reprise après coupure). Les octets
  /// déjà reçus sont passés à [onBytes] au fil de l'eau : une coupure n'en
  /// perd aucun.
  Future<void> getSafeboxBlock(
    String url, {
    int from = 0,
    required void Function(List<int> bytes) onBytes,
  }) async {
    final h = safeboxHttp;
    final guard = UploadStallGuard(stallTimeout: h.stallTimeout);
    final request = http.AbortableRequest('GET', Uri.parse(url), abortTrigger: guard.abortTrigger);
    if (from > 0) request.headers['Range'] = 'bytes=$from-';
    try {
      final streamed = await Future.any([
        h.transferClient.send(request),
        guard.abortTrigger.then<http.StreamedResponse>((_) => throw http.RequestAbortedException(request.url)),
      ]);
      final attendu = from > 0 ? 206 : 200;
      if (streamed.statusCode != attendu) {
        await streamed.stream.drain<void>();
        throw h.transferFailure(SafeboxTransferFailure.rejected, status: streamed.statusCode, code: 'SAFEBOX_BLOCK_UNAVAILABLE');
      }
      await for (final morceau in streamed.stream) {
        guard.tick();
        onBytes(morceau);
      }
    } on http.RequestAbortedException catch (e) {
      throw h.transferFailure(SafeboxTransferFailure.timeout, cause: e);
    } on http.ClientException catch (e) {
      throw h.transferFailure(SafeboxTransferFailure.network, cause: e);
    } on SocketException catch (e) {
      throw h.transferFailure(SafeboxTransferFailure.network, cause: e);
    } finally {
      guard.stop();
    }
  }

  /// Aperçu chiffré (petit) : lu d'un bloc.
  Future<Uint8List> getSafeboxPreview(String url) async {
    final out = <int>[];
    await getSafeboxBlock(url, onBytes: out.addAll);
    return Uint8List.fromList(out);
  }

  /// L'audio d'un commentaire, en clair (m4a) : un seul bloc chiffré.
  Future<Uint8List> fetchSafeboxNoteAudio(SafeboxNoteAudio audio) async {
    final recu = BytesBuilder(copy: false);
    await getSafeboxBlock(audio.url, onBytes: recu.add);
    final plan = safeboxPlanBlock(1, plainSize: audio.plainBytes, blockSize: kSafeboxNoteAudioBlockBytes);
    return safeboxDecryptBlock(audio.key, recu.takeBytes(), plan);
  }
}

/// Taille de bloc d'un audio de commentaire (5 minutes tiennent dans un bloc).
const int kSafeboxNoteAudioBlockBytes = 8 << 20;

/// Envoie [request] sous la surveillance de [guard]. Un envoi bloqué lève
/// une erreur réseau (statut 0). La course avec [guard] ne dépend pas du
/// client : même un client qui ignore l'interruption rend la main.
Future<http.Response> _sendGuarded(SafeboxHttp h, http.BaseRequest request, UploadStallGuard guard) async {
  Future<T> stalled<T>() => guard.abortTrigger.then<T>((_) => throw http.RequestAbortedException(request.url));
  try {
    final streamed = await Future.any([h.transferClient.send(request), stalled()]);
    return await Future.any([http.Response.fromStream(streamed), stalled()]);
  } on http.RequestAbortedException catch (e) {
    throw h.transferFailure(SafeboxTransferFailure.timeout, cause: e);
  } finally {
    guard.stop();
  }
}

/// Le client du coffre pour une application qui n'en a pas d'autre
/// (l'application de bureau).
class SafeboxClient with SafeboxCalls {
  SafeboxClient(this.safeboxHttp);

  @override
  final SafeboxHttp safeboxHttp;
}
