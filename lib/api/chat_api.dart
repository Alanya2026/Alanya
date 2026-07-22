// Endpoints conversations & messages (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension ChatHttpApi on TalkyApiClient {
  // ── CONVERSATIONS ─────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/conversations'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Crée une conversation 1-1 — le backend attend { participantID }
  Future<Map<String, dynamic>> createConversation({required int participantID}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations'),
        headers: _headers,
        body: jsonEncode({'participantID': participantID}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Crée un groupe — le backend attend { participantIDs[], groupName, groupPhoto }
  Future<Map<String, dynamic>> createGroup({
    required List<int> participantIDs,
    required String groupName,
    String? groupPhoto,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/group'),
        headers: _headers,
        body: jsonEncode({
          'participantIDs': participantIDs,
          'groupName': groupName,
          if (groupPhoto != null) 'groupPhoto': groupPhoto,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversation(int conversID) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> markConversationAsRead(int conversID) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/read'), headers: _headers),
    );
  }

  Future<void> leaveGroup(int conversID) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/leave'), headers: _headers),
    );
  }

  /// Ajoute des participants à un groupe existant. Idempotent côté serveur
  /// (les IDs déjà membres sont ignorés). L'appelant doit être membre.
  Future<Map<String, dynamic>> addParticipants(
    int conversID,
    List<int> participantIDs,
  ) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/participants'),
        headers: _headers,
        body: jsonEncode({'participantIDs': participantIDs}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteConversation(int conversID) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID'), headers: _headers),
    );
  }

  Future<void> deleteConversations(List<int> conversationIDs) async {
    if (conversationIDs.isEmpty) return;
    if (conversationIDs.length == 1) {
      return deleteConversation(conversationIDs.first);
    }
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/batch-delete'),
        headers: _headers,
        body: jsonEncode({'conversationIDs': conversationIDs}),
      ),
    );
  }

  /// Met à jour les flags par-utilisateur d'une conversation (épinglage,
  /// archivage). Le backend les stocke dans conv_participants.
  Future<void> updateConversation(
    int conversID, {
    bool? isPinned,
    bool? isArchived,
  }) async {
    final body = <String, dynamic>{};
    if (isPinned != null) body['isPinned'] = isPinned ? 1 : 0;
    if (isArchived != null) body['isArchived'] = isArchived ? 1 : 0;
    if (body.isEmpty) return;
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> updateConversationsBatch(
    List<int> conversationIDs, {
    bool? isPinned,
    bool? isArchived,
  }) async {
    if (conversationIDs.isEmpty) return;
    if (conversationIDs.length == 1) {
      return updateConversation(
        conversationIDs.first,
        isPinned: isPinned,
        isArchived: isArchived,
      );
    }
    final body = <String, dynamic>{'conversationIDs': conversationIDs};
    if (isPinned != null) body['isPinned'] = isPinned ? 1 : 0;
    if (isArchived != null) body['isArchived'] = isArchived ? 1 : 0;
    if (body.length == 1) return;
    await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/batch'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  // ── MESSAGES ──────────────────────────────────────────────────────

  Future<List<dynamic>> getMessages(
    int conversID, {
    int limit = 50,
    int? before,
    int? after,
  }) async {
    String url = '${TalkyApiClient.baseUrl}/conversations/$conversID/messages?limit=$limit';
    if (before != null) url += '&before=$before';
    if (after != null) url += '&after=$after';
    final data = await _handleRequest(
      () => _client.get(Uri.parse(url), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Sync delta globale : rapatrie en UNE requête tous les messages
  /// `msgID > curseur` de plusieurs conversations. [cursors] = { conversID:
  /// dernierMsgIDLocal }. Renvoie `{ messages: [...], hasMore: bool }`.
  ///
  /// Curseur PAR conversation (pas global) : sinon, être à jour dans une conv
  /// masquerait des messages anciens manquants d'une autre.
  Future<Map<String, dynamic>> syncMessagesGlobal(
    Map<int, int> cursors, {
    int limit = 300,
  }) async {
    if (cursors.isEmpty) {
      return const {'messages': <dynamic>[], 'hasMore': false};
    }
    final body = {
      'limit': limit,
      'cursors': [
        for (final e in cursors.entries) {'c': e.key, 'm': e.value},
      ],
    };
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/sync'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const {'messages': <dynamic>[], 'hasMore': false};
  }

  Future<Map<String, dynamic>> sendMessage({
    required int conversID,
    String? content,
    int type = 0,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? mediaSize,
    int? mediaPageCount,
    int? replyToID,
    String? replyToContent,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/messages'),
        headers: _headers,
        body: jsonEncode({
          if (content != null) 'content': content,
          'type': type,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (mediaName != null) 'mediaName': mediaName,
          if (mediaDuration != null) 'mediaDuration': mediaDuration,
          if (mediaSize != null) 'mediaSize': mediaSize,
          if (mediaPageCount != null) 'mediaPageCount': mediaPageCount,
          if (replyToID != null && replyToID > 0) 'replyToID': replyToID,
          if (replyToContent != null) 'replyToContent': replyToContent,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editMessage(int msgID, String content) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID'),
        headers: _headers,
        body: jsonEncode({'content': content}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteMessage(int msgID, {bool forAll = false}) async {
    await deleteMessages([msgID], forAll: forAll);
  }

  Future<void> deleteMessages(List<int> msgIDs, {bool forAll = false}) async {
    if (msgIDs.isEmpty) return;
    if (msgIDs.length == 1) {
      await _handleRequest(
        () => _client.delete(
          Uri.parse(
            '${TalkyApiClient.baseUrl}/messages/${msgIDs.first}${forAll ? '?all=true' : ''}',
          ),
          headers: _headers,
        ),
      );
      return;
    }
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/batch-delete'),
        headers: _headers,
        body: jsonEncode({'msgIDs': msgIDs, 'all': forAll}),
      ),
    );
  }

  Future<Map<String, dynamic>> batchForward({
    required List<int> sourceMsgIDs,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/batch-forward'),
        headers: _headers,
        body: jsonEncode({
          'sourceMsgIDs': sourceMsgIDs,
          'targetConversationIDs': targetConversationIDs,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// (Dés)épingle un message. Le backend diffuse `message:pinned` aux
  /// participants connectés à la conversation.
  Future<void> pinMessage(int msgID, bool pinned) async {
    await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID/pin'),
        headers: _headers,
        body: jsonEncode({'isPinned': pinned ? 1 : 0}),
      ),
    );
  }

  /// Signale qu'un média à vue unique a été consulté. Le backend enregistre la
  /// vue, supprime le fichier si tous les destinataires ont vu, et diffuse
  /// `message:viewed`.
  Future<void> markViewed(int msgID) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID/view'),
        headers: _headers,
      ),
    );
  }

  /// Rattrapage outbox : le serveur a-t-il déjà persisté ce clientId ?
  Future<Map<String, dynamic>> getMessageStatusByClientId(String clientId) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse(
          '${TalkyApiClient.baseUrl}/messages/status?clientId=${Uri.encodeQueryComponent(clientId)}',
        ),
        headers: _headers,
      ),
    );
    return data is Map ? Map<String, dynamic>.from(data) : {'found': false};
  }

  /// Messages sortants récents encore au statut « envoyé » côté serveur.
  Future<List<dynamic>> getPendingOutgoingMessages() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/pending'),
        headers: _headers,
      ),
    );
    if (data is Map && data['messages'] is List) {
      return List<dynamic>.from(data['messages'] as List);
    }
    return const [];
  }
}
