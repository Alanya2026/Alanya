// Coffre-fort : routes `/api/safebox` et transferts directs chez MEGA S4
// (part of talky_api_client.dart).
//
// Conception : backend/docs/conception/coffre-fort.html. Le serveur ne voit
// passer aucun octet de fichier : il réserve l'espace et signe des adresses ;
// les blocs vont et viennent directement entre le téléphone et MEGA.
part of '../talky_api_client.dart';

extension SafeboxApi on TalkyApiClient {
  Uri _safebox(String path, [Map<String, String>? query]) =>
      Uri.parse('${TalkyApiClient.baseUrl}/safebox$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _safeboxJson(Future<http.Response> Function() request) async {
    final data = await _handleRequest(request);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Ouvre le coffre : espace, dossiers racines (créés à la première visite), limites.
  Future<SafeboxOverview> fetchSafebox() async => SafeboxOverview.fromJson(
        await _safeboxJson(() => _client.get(_safebox(''), headers: _headers)),
      );

  Future<SafeboxFolderPage> fetchSafeboxFolder(int folderId, {int? cursor}) async =>
      SafeboxFolderPage.fromJson(await _safeboxJson(() => _client.get(
            _safebox('/folders/$folderId', cursor == null ? null : {'cursor': '$cursor'}),
            headers: _headers,
          )));

  Future<SafeboxFolder> createSafeboxFolder({required int parentId, required String name}) async =>
      SafeboxFolder.fromJson(await _safeboxJson(() => _client.post(
            _safebox('/folders'),
            headers: _headers,
            body: jsonEncode({'parentId': parentId, 'name': name}),
          )));

  Future<SafeboxFolder> updateSafeboxFolder(int folderId, {String? name, int? parentId}) async =>
      SafeboxFolder.fromJson(await _safeboxJson(() => _client.patch(
            _safebox('/folders/$folderId'),
            headers: _headers,
            body: jsonEncode({
              if (name != null) 'name': name,
              if (parentId != null) 'parentId': parentId,
            }),
          )));

  Future<void> trashSafeboxFolder(int folderId) =>
      _safeboxJson(() => _client.delete(_safebox('/folders/$folderId'), headers: _headers));

  Future<SafeboxFolder> restoreSafeboxFolder(int folderId) async => SafeboxFolder.fromJson(
        await _safeboxJson(() => _client.post(_safebox('/folders/$folderId/restore'), headers: _headers)),
      );

  Future<SafeboxFile> updateSafeboxFile(int fileId, {String? name, int? folderId}) async =>
      SafeboxFile.fromJson(await _safeboxJson(() => _client.patch(
            _safebox('/files/$fileId'),
            headers: _headers,
            body: jsonEncode({
              if (name != null) 'name': name,
              if (folderId != null) 'folderId': folderId,
            }),
          )));

  /// À la corbeille : cet exemplaire, ou avec [everywhere] tous les
  /// exemplaires du même contenu dans le coffre (Photos et albums).
  Future<void> trashSafeboxFile(int fileId, {bool everywhere = false}) => _safeboxJson(
      () => _client.delete(_safebox('/files/$fileId${everywhere ? '?everywhere=1' : ''}'), headers: _headers));

  /// Ajoute des fichiers du coffre à un album, sans copie. Rend leurs
  /// exemplaires dans l'album.
  Future<List<SafeboxFile>> addSafeboxFilesToFolder(int folderId, List<int> fileIds) async {
    final r = await _safeboxJson(() => _client.post(
          _safebox('/folders/$folderId/files'),
          headers: _headers,
          body: jsonEncode({'fileIds': fileIds}),
        ));
    final liste = r['files'] is List ? r['files'] as List : const [];
    return liste.whereType<Map>().map((e) => SafeboxFile.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ── Commentaire d'une photo (privé) ──────────────────────────────────────

  /// Texte du commentaire ; null ou vide l'efface. Rend le commentaire, ou null.
  Future<SafeboxNote?> setSafeboxNoteText(int fileId, String? text) async => SafeboxNote.fromJson(
        (await _safeboxJson(() => _client.put(
              _safebox('/files/$fileId/note'),
              headers: _headers,
              body: jsonEncode({'text': text}),
            )))['note'],
      );

  /// Réserve la place de l'audio (5 minutes au plus) : adresse d'envoi à taille exacte.
  Future<String> reserveSafeboxNoteAudio(int fileId, {required int size, required int plainSize, required int durationMs}) async =>
      '${(await _safeboxJson(() => _client.post(
            _safebox('/files/$fileId/note/audio'),
            headers: _headers,
            body: jsonEncode({'size': size, 'plainSize': plainSize, 'durationMs': durationMs}),
          )))['url']}';

  Future<SafeboxNote?> completeSafeboxNoteAudio(int fileId, Uint8List key) async => SafeboxNote.fromJson(
        (await _safeboxJson(() => _client.post(
              _safebox('/files/$fileId/note/audio/complete'),
              headers: _headers,
              body: jsonEncode({'key': base64Encode(key)}),
            )))['note'],
      );

  Future<SafeboxNote?> deleteSafeboxNoteAudio(int fileId) async => SafeboxNote.fromJson(
        (await _safeboxJson(() => _client.delete(_safebox('/files/$fileId/note/audio'), headers: _headers)))['note'],
      );

  Future<SafeboxFile> restoreSafeboxFile(int fileId) async => SafeboxFile.fromJson(
        await _safeboxJson(() => _client.post(_safebox('/files/$fileId/restore'), headers: _headers)),
      );

  /// Les plus gros fichiers du coffre et le poids de la corbeille
  /// (« Libérer de l'espace »).
  Future<({List<SafeboxFile> files, int trashBytes})> fetchSafeboxLargest({int limit = 50}) async {
    final j = await _safeboxJson(() => _client.get(_safebox('/largest', {'limit': '$limit'}), headers: _headers));
    return (
      files: (j['files'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SafeboxFile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      trashBytes: (j['trashBytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Clé du fichier et adresses de lecture de tous ses blocs (15 minutes).
  Future<SafeboxDownloadPlan> fetchSafeboxDownload(int fileId) async => SafeboxDownloadPlan.fromJson(
        await _safeboxJson(() => _client.get(_safebox('/files/$fileId/download'), headers: _headers)),
      );

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
  }) async =>
      SafeboxUploadTicket.fromJson(await _safeboxJson(() => _client.post(
            _safebox('/uploads'),
            headers: _headers,
            body: jsonEncode({
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
            }),
          )));

  /// Blocs déjà reçus chez MEGA, pour reprendre un envoi.
  Future<SafeboxUploadStatus> fetchSafeboxUploadStatus(int fileId) async => SafeboxUploadStatus.fromJson(
        await _safeboxJson(() => _client.get(_safebox('/uploads/$fileId/blocks'), headers: _headers)),
      );

  /// Adresses d'envoi de blocs choisis (64 au plus) et, au besoin, de l'aperçu.
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> fetchSafeboxUploadUrls(
    int fileId, {
    List<int> blocks = const [],
    bool preview = false,
  }) async {
    final j = await _safeboxJson(() => _client.post(
          _safebox('/uploads/$fileId/blocks'),
          headers: _headers,
          body: jsonEncode({'blocks': blocks, if (preview) 'preview': true}),
        ));
    return (
      blocks: (j['blocks'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SafeboxSignedBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      preview: j['preview'] is Map
          ? SafeboxSignedBlock.fromJson(Map<String, dynamic>.from(j['preview'] as Map))
          : null,
    );
  }

  /// Termine l'envoi : le serveur vérifie chaque bloc chez MEGA et range la clé.
  Future<SafeboxFile> completeSafeboxUpload(int fileId, Uint8List key) async =>
      SafeboxFile.fromJson(await _safeboxJson(() => _client.post(
            _safebox('/uploads/$fileId/complete'),
            headers: _headers,
            body: jsonEncode({'key': base64Encode(key)}),
          )));

  Future<void> cancelSafeboxUpload(int fileId) =>
      _safeboxJson(() => _client.delete(_safebox('/uploads/$fileId'), headers: _headers));

  Future<SafeboxTrash> fetchSafeboxTrash() async =>
      SafeboxTrash.fromJson(await _safeboxJson(() => _client.get(_safebox('/trash'), headers: _headers)));

  Future<void> emptySafeboxTrash() =>
      _safeboxJson(() => _client.delete(_safebox('/trash'), headers: _headers));

  Future<void> deleteTrashedSafeboxFile(int fileId) =>
      _safeboxJson(() => _client.delete(_safebox('/trash/files/$fileId'), headers: _headers));

  Future<void> deleteTrashedSafeboxFolder(int folderId) =>
      _safeboxJson(() => _client.delete(_safebox('/trash/folders/$folderId'), headers: _headers));

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
      SafeboxShareCreated.fromJson(await _safeboxJson(() => _client.post(
            _safebox('/shares'),
            headers: _headers,
            body: jsonEncode({
              'conversationId': conversationId,
              'fileId': ?fileId,
              'fileIds': ?fileIds,
              'folderId': ?folderId,
              'title': ?title,
            }),
          )));

  /// La carte : disponible ou retiré, expéditeur, aperçu, clé, téléchargements
  /// restants ; mosaïque d'un lot ; suivi pour l'expéditeur.
  Future<SafeboxShareInfo> fetchSafeboxShare(int shareId) async => SafeboxShareInfo.fromJson(
        await _safeboxJson(() => _client.get(_safebox('/shares/$shareId'), headers: _headers)),
      );

  /// Les éléments d'un partage, par pages de 100 ; un fichier seul est l'élément 0.
  Future<SafeboxShareItemsPage> fetchSafeboxShareItems(int shareId, {int? cursor}) async =>
      SafeboxShareItemsPage.fromJson(
        shareId,
        await _safeboxJson(() => _client.get(
              _safebox('/shares/$shareId/items', cursor == null ? null : {'cursor': '$cursor'}),
              headers: _headers,
            )),
      );

  /// Clé et adresses des blocs d'un fichier reçu, ou d'un élément d'un lot
  /// ([itemId]). Compte un téléchargement : une fois par partage et par
  /// fenêtre de deux heures, 3 par 24 h.
  Future<SafeboxDownloadPlan> fetchSafeboxShareDownload(int shareId, {int itemId = 0}) async =>
      SafeboxDownloadPlan.fromJson(await _safeboxJson(() => _client.get(
            _safebox('/shares/$shareId/download', itemId == 0 ? null : {'item': '$itemId'}),
            headers: _headers,
          )));

  /// Garde un fichier reçu, ou un élément d'un lot ([itemId]), dans mon coffre
  /// (aucune copie chez MEGA).
  Future<SafeboxFile> saveSafeboxShare(int shareId, {int itemId = 0, int? folderId}) async =>
      SafeboxFile.fromJson(await _safeboxJson(() => _client.post(
            _safebox('/shares/$shareId/save'),
            headers: _headers,
            body: jsonEncode({if (itemId != 0) 'itemId': itemId, 'folderId': ?folderId}),
          )));

  /// Garde un lot entier : il devient un album dans mes Albums.
  Future<SafeboxFolder> saveSafeboxShareBatch(int shareId) async {
    final r = await _safeboxJson(() => _client.post(_safebox('/shares/$shareId/save'), headers: _headers, body: '{}'));
    return SafeboxFolder.fromJson(Map<String, dynamic>.from(r['folder'] as Map));
  }

  /// L'onglet « Reçus », du plus récent au plus ancien.
  Future<SafeboxReceivedPage> fetchReceivedSafeboxShares({int? cursor}) async =>
      SafeboxReceivedPage.fromJson(await _safeboxJson(() => _client.get(
            _safebox('/shares/received', cursor == null ? null : {'cursor': '$cursor'}),
            headers: _headers,
          )));

  /// Le suivi d'un partage, pour son expéditeur.
  Future<SafeboxShareRecipients> fetchSafeboxShareRecipients(int shareId) async => SafeboxShareRecipients.fromJson(
        await _safeboxJson(() => _client.get(_safebox('/shares/$shareId/recipients'), headers: _headers)),
      );

  /// « Retirer le partage » : la carte dira « retiré par l'expéditeur ».
  Future<void> revokeSafeboxShare(int shareId) =>
      _safeboxJson(() => _client.post(_safebox('/shares/$shareId/revoke'), headers: _headers, body: '{}'));

  // ── Transferts directs chez MEGA ─────────────────────────────────────────
  //
  // Le jeton de l'API n'est jamais joint : l'adresse signée suffit, et le
  // jeton n'a rien à faire chez un tiers. Un transfert qui n'avance plus
  // pendant [uploadStallTimeout] est coupé (statut 0) : l'appelant réessaie.

  /// Envoie un bloc chiffré à son adresse signée. La taille est signée : un
  /// corps d'une autre taille est refusé par MEGA (403).
  Future<void> putSafeboxBlock(
    String url,
    Uint8List bytes, {
    void Function(int sent)? onProgress,
  }) async {
    final guard = UploadStallGuard(stallTimeout: uploadStallTimeout);
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
    final response = await _sendGuarded(request, guard);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TalkyException(resolveL10n().serverError, response.statusCode, code: 'SAFEBOX_BLOCK_REJECTED');
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
    final guard = UploadStallGuard(stallTimeout: uploadStallTimeout);
    final request = http.AbortableRequest('GET', Uri.parse(url), abortTrigger: guard.abortTrigger);
    if (from > 0) request.headers['Range'] = 'bytes=$from-';
    try {
      final streamed = await Future.any([
        _client.send(request),
        guard.abortTrigger.then<http.StreamedResponse>((_) => throw http.RequestAbortedException(request.url)),
      ]);
      final attendu = from > 0 ? 206 : 200;
      if (streamed.statusCode != attendu) {
        await streamed.stream.drain<void>();
        throw TalkyException(resolveL10n().serverError, streamed.statusCode, code: 'SAFEBOX_BLOCK_UNAVAILABLE');
      }
      await for (final morceau in streamed.stream) {
        guard.tick();
        onBytes(morceau);
      }
    } on http.RequestAbortedException catch (e) {
      throw TalkyException(resolveL10n().networkTimeout, 0, cause: e);
    } on http.ClientException catch (e) {
      throw TalkyException(resolveL10n().networkError, 0, cause: e);
    } on SocketException catch (e) {
      throw TalkyException(resolveL10n().networkError, 0, cause: e);
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
}
