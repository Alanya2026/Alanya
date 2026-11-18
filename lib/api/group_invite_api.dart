// Lien et QR code d'invitation de groupe (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension GroupInviteApi on TalkyApiClient {
  String get _conv => '${TalkyApiClient.baseUrl}/conversations';
  String get _invite => '${TalkyApiClient.baseUrl}/groups/invite';

  Map<String, dynamic> _map(Object? data) => Map<String, dynamic>.from(data as Map);

  /// Réglages du lien et droits de l'appelant. Ne crée aucun lien.
  Future<GroupInviteSettings> getGroupInviteSettings(int conversationId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$_conv/$conversationId/invite-settings'), headers: _headers),
    );
    return GroupInviteSettings.fromJson(_map(data));
  }

  /// Lien du groupe, créé à la première demande.
  Future<GroupInviteLinkInfo> getGroupInviteLink(int conversationId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$_conv/$conversationId/invite-link'), headers: _headers),
    );
    return GroupInviteLinkInfo.fromJson(_map(data));
  }

  /// Nouveau lien : l'ancien lien et l'ancien QR cessent de fonctionner.
  Future<GroupInviteLinkInfo> resetGroupInviteLink(int conversationId) async {
    final data = await _handleRequest(
      () => _client.post(Uri.parse('$_conv/$conversationId/invite-link/reset'), headers: _headers),
    );
    return GroupInviteLinkInfo.fromJson(_map(data));
  }

  /// Bascule les réglages du lien (administrateurs).
  Future<void> updateGroupInviteSettings(
    int conversationId, {
    bool? onlyAdminsCanShareLink,
    bool? approveNewMembers,
  }) async {
    await _handleRequest(
      () => _client.patch(
        Uri.parse('$_conv/$conversationId/settings'),
        headers: _headers,
        body: jsonEncode({
          if (onlyAdminsCanShareLink != null) 'onlyAdminsCanShareLink': onlyAdminsCanShareLink ? 1 : 0,
          if (approveNewMembers != null) 'approveNewMembers': approveNewMembers ? 1 : 0,
        }),
      ),
    );
  }

  Future<List<GroupJoinRequest>> getGroupJoinRequests(int conversationId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$_conv/$conversationId/join-requests'), headers: _headers),
    );
    final list = _map(data)['requests'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => GroupJoinRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> decideGroupJoinRequest(int conversationId, int userId, {required bool approve}) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('$_conv/$conversationId/join-requests/$userId/${approve ? 'approve' : 'reject'}'),
        headers: _headers,
      ),
    );
  }

  /// Renvoie `(acceptées, groupe complet)`.
  Future<({int approved, bool full})> approveAllGroupJoinRequests(int conversationId) async {
    final data = _map(await _handleRequest(
      () => _client.post(Uri.parse('$_conv/$conversationId/join-requests/approve-all'), headers: _headers),
    ));
    return (
      approved: (data['approved'] as num?)?.toInt() ?? 0,
      full: data['full'] == true,
    );
  }

  /// Aperçu d'un groupe pour qui détient le lien. Ne modifie rien.
  Future<GroupInvitePreview> previewGroupInvite(String token) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('$_invite/${Uri.encodeComponent(token)}'), headers: _headers),
    );
    return GroupInvitePreview.fromJson(token, _map(data));
  }

  /// Rejoint le groupe, ou envoie une demande si l'approbation est active.
  Future<GroupJoinResult> joinGroupByInvite(String token) async {
    final data = await _handleRequest(
      () => _client.post(Uri.parse('$_invite/${Uri.encodeComponent(token)}/join'), headers: _headers),
    );
    return GroupJoinResult.fromJson(_map(data));
  }

  Future<void> cancelGroupJoinRequest(String token) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('$_invite/${Uri.encodeComponent(token)}/request'), headers: _headers),
    );
  }
}
