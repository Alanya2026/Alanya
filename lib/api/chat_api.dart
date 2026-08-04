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

  /// Crée un groupe — le backend attend { participantIDs[], groupName, groupPhoto,
  /// description?, onlyAdminsCanSend?, onlyAdminsCanEditInfo?,
  /// hideHistoryForNewMembers?, onlyAdminsCanAddMembers? }
  Future<Map<String, dynamic>> createGroup({
    required List<int> participantIDs,
    required String groupName,
    String? groupPhoto,
    String? description,
    bool onlyAdminsCanSend = false,
    bool onlyAdminsCanEditInfo = false,
    bool hideHistoryForNewMembers = false,
    bool onlyAdminsCanAddMembers = false,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/group'),
        headers: _headers,
        body: jsonEncode({
          'participantIDs': participantIDs,
          'groupName': groupName,
          if (groupPhoto != null) 'groupPhoto': groupPhoto,
          if (description != null) 'description': description,
          if (onlyAdminsCanSend) 'onlyAdminsCanSend': 1,
          if (onlyAdminsCanEditInfo) 'onlyAdminsCanEditInfo': 1,
          if (hideHistoryForNewMembers) 'hideHistoryForNewMembers': 1,
          if (onlyAdminsCanAddMembers) 'onlyAdminsCanAddMembers': 1,
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

  /// Accusé de remise en HTTP. Équivalent de l'event socket `message:delivered`,
  /// utilisé pour rejouer les accusés déposés par la couche push native quand
  /// l'app était fermée.
  Future<void> markConversationDelivered(int conversID) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/delivered'),
        headers: _headers,
        body: jsonEncode({'conversationId': conversID}),
      ),
    );
  }

  /// Quitte le groupe. Si j'en suis le propriétaire, le serveur transmet la
  /// propriété au plus ancien admin (à défaut au plus ancien membre) : un
  /// groupe n'est jamais laissé sans propriétaire.
  Future<void> leaveGroup(int conversID) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/leave'), headers: _headers),
    );
  }

  /// Renomme le groupe / change sa photo / sa description.
  ///
  /// Route dédiée et non `PUT /conversations/:id` : cette dernière porte une
  /// sémantique **par utilisateur** (épinglage, archivage) avec une règle
  /// d'autorisation différente, et les mélanger est précisément ce qui avait
  /// laissé n'importe qui renommer n'importe quel groupe.
  Future<Map<String, dynamic>> updateGroupInfo(
    int conversID, {
    String? groupName,
    String? groupPhoto,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (groupName != null) body['GroupName'] = groupName;
    if (groupPhoto != null) body['groupPhoto'] = groupPhoto;
    if (description != null) body['description'] = description;
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/group'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Verrous du groupe : mode annonce, édition des infos, historique, ajout.
  Future<Map<String, dynamic>> updateGroupSettings(
    int conversID, {
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? hideHistoryForNewMembers,
    bool? onlyAdminsCanAddMembers,
  }) async {
    final body = <String, dynamic>{};
    if (onlyAdminsCanSend != null) {
      body['onlyAdminsCanSend'] = onlyAdminsCanSend ? 1 : 0;
    }
    if (onlyAdminsCanEditInfo != null) {
      body['onlyAdminsCanEditInfo'] = onlyAdminsCanEditInfo ? 1 : 0;
    }
    if (hideHistoryForNewMembers != null) {
      body['hideHistoryForNewMembers'] = hideHistoryForNewMembers ? 1 : 0;
    }
    if (onlyAdminsCanAddMembers != null) {
      body['onlyAdminsCanAddMembers'] = onlyAdminsCanAddMembers ? 1 : 0;
    }
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/settings'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Nouvel ajouté : « Rester » → clear pendingJoinMsgID (sync multi-appareil).
  Future<Map<String, dynamic>> ackGroupJoin(
    int conversID, {
    int? msgID,
  }) async {
    final body = <String, dynamic>{};
    if (msgID != null) body['msgID'] = msgID;
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/ack-join'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Retire un membre du groupe (admin ou propriétaire).
  Future<Map<String, dynamic>> removeParticipant(
    int conversID,
    int userId,
  ) async {
    final data = await _handleRequest(
      () => _client.delete(
        Uri.parse(
          '${TalkyApiClient.baseUrl}/conversations/$conversID/participants/$userId',
        ),
        headers: _headers,
      ),
    );
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Promeut (`role = 1`) ou rétrograde (`role = 0`) un membre.
  /// Réservé au propriétaire côté serveur.
  Future<Map<String, dynamic>> setParticipantRole(
    int conversID,
    int userId,
    int role,
  ) async {
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse(
          '${TalkyApiClient.baseUrl}/conversations/$conversID/participants/$userId/role',
        ),
        headers: _headers,
        body: jsonEncode({'role': role}),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
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

  /// Mute / unmute une conversation pour l'utilisateur courant.
  Future<Map<String, dynamic>> updateConversationMute(
    int conversID, {
    bool unmute = false,
    bool muteForever = false,
    DateTime? mutedUntil,
    bool? mentionsOnly,
  }) async {
    final body = <String, dynamic>{};
    if (unmute) {
      body['unmute'] = true;
    } else if (muteForever) {
      body['muteForever'] = true;
    } else if (mutedUntil != null) {
      body['mutedUntil'] = mutedUntil.toUtc().toIso8601String();
    }
    if (mentionsOnly != null) body['mentionsOnly'] = mentionsOnly ? 1 : 0;
    final data = await _handleRequest(
      () => _client.patch(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/mute'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return Map<String, dynamic>.from(data as Map);
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

  // ── RÉACTIONS ─────────────────────────────────────────────────────
  //
  // Contrat backend (Alanya-Backend, à implémenter côté serveur) :
  // - PUT    /messages/:msgID/reactions     body { emoji } → pose/remplace,
  //          diffuse socket `message:reaction` { msgID, conversationID, userID, emoji }
  // - DELETE /messages/:msgID/reactions   → retire ma réaction,
  //          diffuse `message:reaction` avec emoji absent/vide
  // - GET    /conversations/:conversID/reactions → [{ msgID, userID, emoji, reactedAt }, …]

  /// Pose/remplace ma réaction sur un message. Le backend diffuse
  /// `message:reaction` (avec `emoji`) aux participants connectés.
  Future<void> setReaction(int msgID, String emoji) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID/reactions'),
        headers: _headers,
        body: jsonEncode({'emoji': emoji}),
      ),
    );
  }

  /// Retire ma réaction. Le backend diffuse `message:reaction` (sans `emoji`).
  Future<void> removeReaction(int msgID) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/messages/$msgID/reactions'),
        headers: _headers,
      ),
    );
  }

  /// Toutes les réactions d'une conversation (hydratation initiale à
  /// l'ouverture du chat ; les mises à jour suivantes arrivent par socket).
  Future<List<dynamic>> getReactions(int conversID) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/conversations/$conversID/reactions'),
        headers: _headers,
      ),
    );
    return data is List ? data : [];
  }
}
