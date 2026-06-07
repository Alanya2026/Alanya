// Endpoints conversations & messages (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension ChatApi on TalkyApiClient {
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

  Future<Map<String, dynamic>> sendMessage({
    required int conversID,
    String? content,
    int type = 0,
    String? mediaUrl,
    String? mediaName,
    int? mediaDuration,
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
          if (replyToID != null) 'replyToID': replyToID,
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
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID${forAll ? '?all=true' : ''}'),
        headers: _headers,
      ),
    );
  }
}
